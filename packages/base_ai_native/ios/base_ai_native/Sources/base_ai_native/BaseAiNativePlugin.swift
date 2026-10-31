import Flutter
import UIKit

/// Real on-device inference on iOS: Gemma through LiteRT-LM and the Desert Ant
/// specialists. Both bridges compile without their Swift packages (canImport)
/// and report the models as unavailable until the packages are added; see the
/// on-device-ai skill for the Xcode steps.
public class BaseAiNativePlugin: NSObject, FlutterPlugin {
  private static var bridges: [AnyObject] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    bridges = [LlmBridge(messenger: registrar.messenger()), SpecialistBridge(messenger: registrar.messenger())]
  }
}
