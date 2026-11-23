# base_ai_native

Opt-in native bridges for `base_ai`: Gemma through LiteRT-LM 0.19 and the Desert Ant 4.2.1 specialists, on Android (Kotlin) and iOS + macOS (Swift, one shared `darwin/` source; macOS is Apple silicon only because desert-ant-core uses Float16). Ported from PhoneDots. Adds about 200 MB of native libraries, so apps opt in: see the `on-device-ai` skill.
