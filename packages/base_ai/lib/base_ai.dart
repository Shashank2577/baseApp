/// On-device AI engines behind one interface, ported from PhoneDots.
///
/// * [LlmEngine]: Gemma-family models through LiteRT-LM (chat, tools, thinking).
/// * [Embedder]: EmbeddingGemma, with [LexicalEmbedder] as the offline fallback.
/// * [SpecialistEngine]: Desert Ant specialist models (speech, vision, text).
/// * [DeviceActions]: OS integrations (calendar, contacts, intents).
///
/// The platform implementations talk to native bridges over the channels in
/// docs/NATIVE_BRIDGE.md; the demo implementations run everywhere else (web,
/// desktop, tests) and always say they are a demo. Model files come from the
/// shared model store (base_models): pass `store.pathOf(id, file)` to `load`.
library;

export 'src/demo_engines.dart';
export 'src/engine_types.dart';
export 'src/engines.dart';
export 'src/platform_engines.dart';
export 'src/runtime.dart';
