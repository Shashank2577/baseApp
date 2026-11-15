#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
import Foundation

/// Real on-device inference on iOS and macOS (shared source): Gemma through
/// LiteRT-LM and the Desert Ant specialists. Both are Swift package
/// dependencies of this plugin (Package.swift), so `flutter build ios|macos`
/// fetches and links them. Without Swift Package Manager (CocoaPods) the
/// bridges still compile (canImport) and report the models as unavailable.
public class BaseAiNativePlugin: NSObject, FlutterPlugin {
  private static var bridges: [AnyObject] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    bridges = [LlmBridge(messenger: messenger), SpecialistBridge(messenger: messenger)]
  }
}
