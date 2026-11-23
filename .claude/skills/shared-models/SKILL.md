---
name: shared-models
description: Add, change or use an on-device AI model through the shared model store, so every app downloads it once per device. Use when an app needs a model (LLM, embeddings, speech, vision, a Desert Ant specialist, an ONNX pack), when touching catalog/models.json, model downloads, checksums, or where models are stored.
---

# Shared models

How the store works and where it lives on each platform: `docs/MODEL_STORE.md`. Never download a model from app code; never store one anywhere else.

## Use a model in an app

1. Find it in `catalog/models.json` (or add it, below).
2. List its id in the app's `BaseAppConfig.requiredModels` (onboarding offers it) or `optionalModels` (used if present, offered on the models page).
3. In code:

```dart
final s = BaseScope.of(context);
if (!s.models.isReady(id)) await s.ensureModel(id);   // shared copy → sibling copy (Android) → download
final spec = s.models.spec(id);
final path = s.models.pathOf(id, spec.files.first.name);
await s.ai.llm.load(modelId: id, path: path);
```

Handle `OfflineException` ("never go online" is on) with a `DoneNote` that says how to turn it off. Listen to `s.models` (a `ChangeNotifier`) for progress: `stateOf(id).progress`, `.busyElsewhere` (another app is downloading it), `.users` (which apps share it).

Never call `release` or `deleteEverywhere` without asking the user: other apps may rely on it, and the models page already offers "remove" with the right wording.

## Add a model to the catalog

1. Add an entry to `catalog/models.json`:

```json
{
  "id": "family-variant",              // stable forever: it is the folder name on every device
  "name": "Human Name",
  "family": "gemma",                   // gemma, desertant, indicconformer, ...
  "runtime": "litert-lm",              // litert-lm, desertant-sdk, onnx, ...
  "role": "planner",                   // planner, router, embedder, specialist, speech, ...
  "summary": "One sentence a person understands.",
  "capabilities": ["text"],
  "license": "…",
  "minRamMb": 2000,
  "platforms": ["android", "ios"],     // where an engine exists, not where files can be stored
  "recommended": false,
  "source": "file",                    // or "sdk" with an "sdk": {name, version, key} block and approxBytes
  "files": [{ "name": "model.bin", "url": "https://huggingface.co/<org>/<repo>/resolve/main/<path>", "sha256": null, "bytes": null }]
}
```

2. `./base checksums` fills every missing `sha256` and `bytes` for Hugging Face files (LFS hashes from the API; small files are downloaded and hashed). For other hosts, download once and run `sha256sum`.
3. `./base gen` and `./base check` (a file without a checksum is a warning; fix it before release).
4. Gated models (Gemma): users accept the licence on Hugging Face and paste a token in settings (`BaseSettings.hfToken`); the store sends it only to huggingface.co.
5. `./base sync` so Burrow, PhoneDots and Spreix see the same catalog (`sync-downstream`).

Rules: ids never change once shipped (they are folder names on users' devices); a new version of a model is a new id; https only; one entry per model, not per app; multi-file models (an ONNX model + `tokens.txt`) are one entry with several files.

## Change how the store works

The store is in `packages/base_models/lib/src/store_io.dart` (Android, iOS, macOS, Windows, Linux) and `store_web.dart` (browser). Native parts: `android/…/SharedModelStore.kt` (the whole store in Kotlin, for native Android apps such as Burrow), `AndroidSiblings.kt` + `BaseModelsProvider.kt` (sibling listing and copy), `BaseModelsPlugin.kt` (the Flutter channel), `ios|macos/…/BaseModelsPlugin.swift` (App Group). The Dart and Kotlin stores implement one standard (protocol v1, `docs/MODEL_STORE.md`): change both together, run both test suites (`flutter test packages/base_models` and, from `apps/starter/android`, `./gradlew :base_models:testDebugUnitTest`), then `./base sync` so Burrow gets the Kotlin files. Keep these invariants, and extend `test/store_test.dart` for any change:

- ready = registry entry + every file present at its recorded size;
- downloads go through `.part`, resume with `Range`, verify SHA-256 before the rename;
- registry writes under `.registry.lock`, atomically; one downloader per model via `.download.lock`;
- files are deleted only when no app uses them;
- the Android provider serves only complete, registered files, read-only, behind the signature permission;
- "never go online" is checked before every network request.

Changing `platform.yaml → sharedModels` moves the store for every app: existing users would download everything again. Don't, after the first release.
