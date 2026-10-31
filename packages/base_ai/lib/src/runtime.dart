import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'demo_engines.dart';
import 'engines.dart';
import 'platform_engines.dart';

/// Picks real or demo engines for this platform.
///
/// Real engines need the native bridges (LiteRT-LM, Desert Ant) compiled into
/// the app: see the on-device-ai skill. Until an app adds them, or on web,
/// desktop and in tests, the demo engines run and say so in the UI.
class AiRuntime {
  AiRuntime._(this.llm, this.embedder, this.specialists, this.device);

  factory AiRuntime.forPlatform({bool nativeBridges = false}) {
    final native =
        nativeBridges && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (!native) return AiRuntime.demo();
    return AiRuntime._(
      // Android's LiteRT-LM does constrained tool calling; iOS parses calls from text.
      PlatformLlmEngine(nativeTools: defaultTargetPlatform == TargetPlatform.android),
      PlatformEmbedder(),
      PlatformSpecialistEngine(),
      PlatformDeviceActions(),
    );
  }

  factory AiRuntime.demo() => AiRuntime._(DemoLlmEngine(), LexicalEmbedder(), DemoSpecialistEngine(), DemoDeviceActions());

  final LlmEngine llm;
  final Embedder embedder;
  final SpecialistEngine specialists;
  final DeviceActions device;

  bool get isDemo => llm.isDemo;

  /// Tells the native specialist bridge where the shared model store is, so
  /// SDK-managed weights (Desert Ant) live there too. Call once at startup.
  Future<void> attachStore(String root) async {
    if (isDemo) return;
    try {
      await Channels.specialist.invokeMethod<void>('setStoreRoot', {'root': root});
    } on MissingPluginException {
      // A bridge without store support keeps its own folder; never block startup on it.
    }
  }

  /// For the shared model store: lets an SDK-managed model (Desert Ant)
  /// download its weights into the store's folder for it.
  Future<void> installSdkModel(String modelId, String sdkKey, String dir, void Function(double) progress) async {
    await for (final p in specialists.download(modelId, dir: dir)) {
      progress(p);
    }
  }
}
