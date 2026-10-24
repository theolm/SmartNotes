import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Start with room for the journal sidebar and a bounded reading pane.
    // Small windows still use the same compact navigation as a phone.
    self.minSize = NSSize(width: 360, height: 480)
    let visibleSize = self.screen?.visibleFrame.size ?? NSSize(width: 1100, height: 800)
    self.setContentSize(NSSize(width: min(1100, visibleSize.width), height: min(800, visibleSize.height)))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    ProcessingNotifications.shared.attach(flutterViewController.engine.binaryMessenger)

    FlutterMethodChannel(name: "dev.theolm.smartnotes/device", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "profile":
          result(["memoryBytes": ProcessInfo.processInfo.physicalMemory,
                  "is64Bit": MemoryLayout<Int>.size == 8,
                  "processors": ProcessInfo.processInfo.activeProcessorCount])
        case "freeStorage":
          let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
          let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path)
          result(attributes?[.systemFreeSize])
        default: result(FlutterMethodNotImplemented)
        }
      }

    super.awakeFromNib()
  }
}
