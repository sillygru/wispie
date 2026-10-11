import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Dock icon only; Finder keeps showing the bundled icon.
    let iconChannel = FlutterMethodChannel(
      name: "wispie/app_icon",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    iconChannel.setMethodCallHandler { call, result in
      guard call.method == "setAppIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let suffix = args?["name"] as? String ?? "New"
      NSApplication.shared.applicationIconImage = NSImage(named: "Icon\(suffix)")
      result(nil)
    }

    super.awakeFromNib()
  }
}
