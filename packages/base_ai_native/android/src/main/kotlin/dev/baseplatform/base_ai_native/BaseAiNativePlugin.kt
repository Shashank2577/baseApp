package dev.baseplatform.base_ai_native

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Real on-device inference for apps on the base platform: Gemma through
 * LiteRT-LM (LlmBridge) and the Desert Ant specialists (SpecialistBridge).
 * Ported from PhoneDots; the channel contract is docs/NATIVE_BRIDGE.md.
 * Apps opt in by depending on base_ai_native and calling
 * `AiRuntime.forPlatform(nativeBridges: true)`.
 */
class BaseAiNativePlugin : FlutterPlugin {
  private var llm: LlmBridge? = null
  private var specialists: SpecialistBridge? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    llm = LlmBridge(binding.applicationContext, binding.binaryMessenger)
    specialists = SpecialistBridge(binding.applicationContext, binding.binaryMessenger)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    llm?.dispose()
    llm = null
    specialists = null
  }
}
