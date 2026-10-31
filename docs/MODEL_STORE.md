# The shared model store

Every app on the platform gets its AI models from one catalog (`catalog/models.json`) and keeps them in one store per device. A model is downloaded once, then every app that needs it uses that copy. It is deleted only when the last app that uses it lets it go.

```dart
final s = BaseScope.of(context);
await s.ensureModel('gemma-4-e2b');                         // shared copy, sibling copy, or download
final path = s.models.pathOf('gemma-4-e2b', 'gemma-4-E2B-it.litertlm');
await s.ai.llm.load(modelId: 'gemma-4-e2b', path: path);
```

## The standard (protocol v1)

Every app of the vendor follows this, whatever it is written in, so any app can find and use what any other app downloaded. Flutter apps get it from `base_models`; native Android (Kotlin) apps from the `:basemodels` module, the same Kotlin code (`packages/base_models/android`, synced by `./base sync`). A new framework must implement these rules before it ships a model.

1. **Ids and files come from the catalog** (`catalog/models.json`). A model lives in `<store>/<model id>/`, its files under their catalog names. SDK-managed models get `<store>/<model id>/` as the folder their SDK writes to (Desert Ant: `desertant.<key>`).
2. **One registry**, `<store>/registry.json`, `{"version": 1, "models": {<id>: entry}}`. An entry has `files` (`{name: {bytes, sha256, source}}`) or, for SDK models, `sdkReady`, `sdkBytes`, `sdkSource`, `sdkApps` and, for flat SDK folders, `sdkFiles`; plus `addedAt`, `addedBy` and `users` (`{app id: ISO-8601 UTC time}`). Unknown keys are kept.
3. **Locks:** registry changes are read-modify-write under an exclusive lock on `<store>/.registry.lock`, written to a temp file and renamed. Whoever installs a model holds `<store>/<id>/.download.lock` until it is registered. Nobody deletes a model's files while another app holds that lock.
4. **Ready** means the registry lists the model and every file is on disk at its recorded size. Downloads go through `<file>.part`, resume with `Range`, ask for `Accept-Encoding: identity`, and are checked against the catalog's SHA-256 before the rename.
5. **Claims:** an app adds itself to `users` when it uses a model, refreshes its time at every start, drops claims of apps not seen for 180 days, and removes itself on release. Files are deleted when `users` is empty.
6. **Where:** the locations in the table below. On iOS and macOS every app joins the App Group `group.com.showcase.shared`.
7. **Android siblings:** every app exports `BaseModelsProvider` at `<applicationId>.basemodels`, answering the action `com.showcase.action.SHARED_MODELS`, readable only with the signature permission `com.showcase.permission.SHARED_MODELS` (so every app is signed with the vendor's one release key). `content://<authority>/models` lists every complete file (`model_id`, `file`, `bytes`, `sha256`); `content://<authority>/<id>/<file>` reads one. Before downloading, an app copies from a sibling that lists the file, then verifies the checksum.
8. **Adopting old copies:** an app that stored models elsewhere before the store moves them in once (`adopt`), when they match the catalog, instead of downloading them again.

**Detecting models.** `isReady(id)` says a model is in this app's store. On Android, `stateOf(id).inSibling` (Dart) or `inSibling(id)` (Kotlin) says another app on the phone has every file, so using it is a copy, not a download; the models page shows these as "on this phone in another app". On iOS, macOS, Windows, Linux and the web there is one copy, so `isReady` already covers every app.

## Where the store lives

The location comes from `platform.yaml` (`vendor`, `sharedModels`), so every app agrees on it.

| Platform | Location | How apps share it |
| --- | --- | --- |
| **iOS** | App Group container `group.com.showcase.shared` / `SharedModels` | In place. Every app joins the same App Group (entitlement). |
| **macOS** | App Group container, same group | In place. On macOS a team-prefixed id (`TEAMID.group…`) also works. |
| **Windows** | `%LOCALAPPDATA%\Showcase Labs\SharedModels` | In place. |
| **Linux** | `$XDG_DATA_HOME/showcase/sharedmodels` (default `~/.local/share/…`) | In place. |
| **Android** | each app's `noBackupFilesDir/shared-models` (kept out of Auto Backup) | **Copy, not download.** See below. |
| **Web** | the browser's Cache Storage, `base-shared-models-v1` | In place, for every app served from the same origin. |
| fallback | the app's own support folder | None. Shown on the models page as "this app only (the App Group is not set up)". |

### Why Android copies

Android gives every app private storage and has no equivalent of App Groups (`sharedUserId` is deprecated, and shared external storage can't be read by other apps on Android 11+ without broad permissions that Play rejects). So on Android:

1. Each app keeps its models in its own `noBackupFilesDir/shared-models` (outside Auto Backup), with the same layout and registry as everywhere else.
2. Each app exposes `BaseModelsProvider` (from `base_models`): a read-only `ContentProvider` guarded by a **signature-level permission**, so only apps signed with the same key can read it. It serves only files the registry lists as complete.
3. Before downloading, the store asks every sibling (found by the discovery action in `platform.yaml`) for the file, copies it, and verifies the SHA-256. Only if no sibling has it does it go to the network.

The model crosses the network once per device; disk space is used once per app. Sibling copy covers files the store downloads itself (Gemma, the speech packs); SDK-managed models (Desert Ant) are fetched by each app's SDK, so on Android each app still downloads those once. The requirement: **every app is signed with the same release key** (the release skill handles this).

## Layout and registry

```
<store>/
  registry.json                 who uses what (below)
  .registry.lock                exclusive lock for registry updates
  gemma-4-e2b/
    gemma-4-E2B-it.litertlm
    .download.lock              held by the app that is downloading
  desertant.voz/                SDK-managed: the Desert Ant SDK writes here
```

```json
{
  "version": 1,
  "models": {
    "gemma-4-e2b": {
      "files": { "gemma-4-E2B-it.litertlm": { "bytes": 2588147712, "sha256": "1819…", "source": "network" } },
      "addedAt": "2026-10-31T09:12:00Z",
      "addedBy": "com.showcase.notes",
      "users": { "com.showcase.notes": "2026-10-31T09:12:00Z", "com.showcase.talks": "2026-11-02T18:40:00Z" }
    }
  }
}
```

Rules the code follows (`packages/base_models/lib/src/store_io.dart`):

- **Ready** means the registry lists the model and every file exists with the recorded size. A missing or truncated file makes the model absent again.
- **Downloads** go to `<file>.part`, resume with an HTTP `Range` header, and are verified against the catalog's SHA-256 before the rename. A mismatch deletes the part file.
- **Two apps at once:** the downloading app holds `<model>/.download.lock`. A second app sees the lock, shows "another app is downloading this", and picks the model up when it is ready instead of downloading it again. Registry writes are read-modify-write under `.registry.lock`, written to a temp file and renamed.
- **"Never go online"** (privacy page) makes every needed download fail with `OfflineException`; models already on the device keep working.
- **Release** removes this app from `users`; the files go when `users` is empty, unless another app holds the model's `.download.lock` (it is repairing or installing it and registers the files when done). **Delete everywhere** removes the model for all apps.
- **Web** streams each file from the network into Cache Storage, hashing it on the way, so even a 2.6 GB model never sits in memory; a wrong checksum deletes the cached copy.
- **Uninstalled apps** can't release their claims. Every app refreshes its claim times at startup, and claims not refreshed for 180 days are dropped. The files then go when the remaining users release the model; an app that comes back simply downloads it again.
- A damaged `registry.json` is treated as empty rather than crashing every app.

## SDK-managed models (Desert Ant)

Some vendors' SDKs download their own weights. For those the catalog entry has `"source": "sdk"`, and the store hands the SDK a folder inside the store (`<store>/desertant.voz/`) through the `SdkInstaller` that `base_ai` provides. On Android, `base_ai_native` passes that folder to the SDK, so these weights are shared too. On iOS the Desert Ant SDK uses its own location, so SDK models are per-app there (each app also keeps a marker in its own container, so a reinstalled app runs the installer again instead of trusting the shared registry), removing one does not free its space, and the privacy page's download total does not include them (known limits; see the on-device-ai skill). Elsewhere, an SDK model's size in the store is added to the download total once installed.

## Native Android apps (Kotlin)

```kotlin
// build.gradle.kts: implementation(project(":basemodels")) and the two manifestPlaceholders
// (baseModelsPermission, baseModelsDiscoveryAction) with the values above.
val store = SharedModelStore.open(context, offline = { neverOnline })   // catalog from assets/base/models.json
store.ensure("speech.indic.hi", progress = { p -> ... })                // blocking: call on Dispatchers.IO
val model = store.pathOf("speech.indic.hi", "model.int8.onnx")
store.ensure("desertant.voz", sdkInstall = { dir, _ -> if (!voz.isDownloaded()) runBlocking { voz.download() } })
store.release("speech.indic.hi")
```

Burrow is the reference: its Desert Ant models are created with `<store>/desertant.<key>` as their folder, and its speech packs are catalog models. `./base sync` copies the module's sources and the catalog asset; only `basemodels/build.gradle.kts` belongs to the app.

## Adding a model

Use the `shared-models` skill. In short: add an entry to `catalog/models.json`, run `./base checksums` (fills SHA-256 and sizes from Hugging Face), `./base gen`, `./base check`, and list the id in the app's `requiredModels` or `optionalModels`. Never download a model from app code: `./base check` fails on it.

## Verified

`packages/base_models/test/store_test.dart` runs against a local HTTP server: two apps sharing one store with no second download, release semantics, "never go online", checksum failure, resume from a partial file, a deleted file making the model absent, a reinstalled app re-running a per-app SDK installer, and a release leaving files alone while another process holds the download lock. `test/web_store_test.dart` runs the web store in Chrome (`flutter test --platform chrome`): streaming into Cache Storage, a bad checksum, cancel. `packages/base_models/android/src/test/.../SharedModelStoreTest.kt` runs the Kotlin store the same way (from an app: `./gradlew :base_models:testDebugUnitTest`): sharing, a registry in the Dart store's format, release, checksum, "never go online", resume, sibling copy with detection before the copy, SDK installs and adopting old files. The Android provider and the App Group code compile in the starter's builds but have not been run on two installed apps on a real device yet.
