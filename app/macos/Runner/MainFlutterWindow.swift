import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // The journal is a single reading column; keep a comfortable phone-like
    // width instead of letting the layout stretch across a wide desktop.
    self.minSize = NSSize(width: 420, height: 640)
    self.setContentSize(NSSize(width: 460, height: 820))
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
