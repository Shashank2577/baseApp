# The shared model store

Every app on the platform gets its AI models from one catalog (`catalog/models.json`) and keeps them in one store per device. A model is downloaded once, then every app that needs it uses that copy. It is deleted only when the last app that uses it lets it go.

```dart
final s = BaseScope.of(context);
await s.ensureModel('gemma-4-e2b');                         // shared copy, sibling copy, or download
final path = s.models.pathOf('gemma-4-e2b', 'gemma-4-E2B-it.litertlm');
await s.ai.llm.load(modelId: 'gemma-4-e2b', path: path);
```

## Where the store lives

The location comes from `platform.yaml` (`vendor`, `sharedModels`), so every app agrees on it.

| Platform | Location | How apps share it |
| --- | --- | --- |
| **iOS** | App Group container `group.com.showcase.shared` / `SharedModels` | In place. Every app joins the same App Group (entitlement). |
| **macOS** (store / sandboxed) | App Group container, same group | In place. On macOS a team-prefixed id (`TEAMID.group…`) also works. |
| **macOS** (dev, not sandboxed) | `~/Library/Application Support/Showcase Labs/SharedModels` | In place. |
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
- **Release** removes this app from `users`; the files go when `users` is empty. **Delete everywhere** removes the model for all apps.
- **Uninstalled apps** can't release their claims. Every app refreshes its claim times at startup, and claims not refreshed for 180 days are dropped. The files then go when the remaining users release the model; an app that comes back simply downloads it again.
- A damaged `registry.json` is treated as empty rather than crashing every app.

## SDK-managed models (Desert Ant)

Some vendors' SDKs download their own weights. For those the catalog entry has `"source": "sdk"`, and the store hands the SDK a folder inside the store (`<store>/desertant.voz/`) through the `SdkInstaller` that `base_ai` provides. On Android, `base_ai_native` passes that folder to the SDK, so these weights are shared too. On iOS the Desert Ant SDK uses its own location, so SDK models are per-app there, removing one does not free its space, and the privacy page's download total does not include them (known limits; see the on-device-ai skill). Elsewhere, an SDK model's size in the store is added to the download total once installed.

## Adding a model

Use the `shared-models` skill. In short: add an entry to `catalog/models.json`, run `./base checksums` (fills SHA-256 and sizes from Hugging Face), `./base gen`, `./base check`, and list the id in the app's `requiredModels` or `optionalModels`. Never download a model from app code: `./base check` fails on it.

## Verified

`packages/base_models/test/store_test.dart` runs against a local HTTP server: two apps sharing one store with no second download, release semantics, "never go online", checksum failure, resume from a partial file, and a deleted file making the model absent. The Android provider and the App Group code compile in the starter's builds but have not been run on two installed apps on a real device yet.
