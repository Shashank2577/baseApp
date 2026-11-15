import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Room for the list and a talk side by side; never narrower than one column.
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: max(windowFrame.width, 1100), height: max(windowFrame.height, 760))
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 720, height: 560)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
