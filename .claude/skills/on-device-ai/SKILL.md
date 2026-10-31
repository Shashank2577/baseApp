---
name: on-device-ai
description: Run real on-device AI (Gemma via LiteRT-LM, Desert Ant specialists) in an app on the base platform, or work on the engines and native bridges. Use when an app needs chat, tool calling, embeddings, transcription, speaker labels, redaction or image understanding on the device, or when switching from the demo engine to real inference.
---

# On-device AI

Interfaces: `packages/base_ai` (`LlmEngine`, `Embedder`, `SpecialistEngine`, `DeviceActions`), ported from PhoneDots. Native bridges: `packages/base_ai_native` (Kotlin + Swift). Channel contract: `docs/NATIVE_BRIDGE.md`.

## Turn on real inference in an app (Android, iOS)

1. Add the dependency in `apps/<app>/pubspec.yaml`:
   ```yaml
   dependencies:
     base_ai_native: any
   ```
2. Set `nativeAi: true` in `lib/app_config.dart`. `AiRuntime.forPlatform` then uses the platform engines on Android and iOS, and the demo engines everywhere else (web, desktop, tests), which always label their output as a demo.
3. Android: `minSdk` is already 26. Expect about +200 MB of native libraries (arm64 only in release: add `--target-platform android-arm64`). Both LiteRT-LM and Desert Ant ship `libLiteRt.so`; on a real phone, check that Gemma and a specialist both load.
4. iOS (Xcode 26, iOS 18+, Swift Package Manager on, the Flutter default): the plugin's `Package.swift` already depends on LiteRT-LM (from 0.19.0, product **LiteRTLM**) and desert-ant-core (from 4.2.1: Voz, Who, Ear, Clear, Uhm, Redact, Tongue, Emo, Gist, Eye, Moderator), so `flutter build ios` fetches them; nothing to add to the Runner. CocoaPods is not supported for this plugin (neither SDK ships a pod): without SwiftPM the bridges compile and report models as unavailable. Build to a device (the simulator has no ANE/Metal path). If Git LFS errors: `GIT_LFS_SKIP_SMUDGE=1 xcodebuild -resolvePackageDependencies -workspace ios/Runner.xcworkspace -scheme Runner`.

## Use the engines

```dart
final s = BaseScope.of(context);
await s.ensureModel('gemma-4-e2b');
await s.ai.llm.load(modelId: 'gemma-4-e2b', path: s.models.pathOf('gemma-4-e2b', 'gemma-4-E2B-it.litertlm'));
await for (final e in s.ai.llm.generate(GenerationRequest(
  modelId: 'gemma-4-e2b', sessionId: 'notes',
  history: [EngineTurn(role: TurnRole.user, text: question)],
))) { if (e is TokenEvent) ...; if (e is ToolCallsEvent) ...; if (e is DoneEvent) ...; }

final redacted = await s.ai.specialists.run('desertant.redact', 'redact', {'text': input});
```

- Send the full history every turn; the native side keeps one conversation per `sessionId` and only prefills the new turn.
- Tools: Android does constrained tool calling (`supportsNativeTools`); iOS parses calls from text. PhoneDots' agent loop (`lib/agent`) and skills (`lib/skills`) are the reference for a tool-using app.
- Desert Ant models are SDK-managed (`source: sdk`): `ensureModel` asks the SDK to download into the shared store (Android). On iOS the SDK uses its own folder, so those weights are per-app there.
- Check `ModelSpec.fits(totalRamMb)` (from `s.ai.llm.deviceProfile()`) before offering big models; Gemma 4 E2B wants ~6 GB RAM, E4B ~10 GB.
- Record what the AI did in the ledger with the app's own `LedgerEntry` ("transcribed %d talks").

## Change the engines

- New capability: add it to the interface in `base_ai`, to `DemoLlmEngine`/`DemoSpecialistEngine` (scripted, labelled), to `platform_engines.dart`, and to both bridges; document it in `docs/NATIVE_BRIDGE.md`.
- New runtime (ONNX for the speech packs, LiteRT-LM desktop for macOS/Windows/Linux): a new engine class behind the same interface, picked in `AiRuntime.forPlatform`. The catalog's `runtime` and `platforms` fields say which models it can run.
- After any change: `flutter analyze`, `flutter test`, and `cd apps/starter && flutter build apk --debug` with `base_ai_native` added, to compile the Kotlin.
