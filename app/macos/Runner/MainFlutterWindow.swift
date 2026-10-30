import Cocoa
import FlutterMacOS
import UserNotifications

private func formattingChip() -> String {
  var size = 0
  guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0 else { return "" }
  var bytes = [CChar](repeating: 0, count: size)
  guard sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 else { return "" }
  return String(cString: bytes)
}

private func formattingAvailableMemory() -> UInt64? {
  var stats = vm_statistics64()
  var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
  let status = withUnsafeMutablePointer(to: &stats) { pointer in
    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
      host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
    }
  }
  guard status == KERN_SUCCESS else { return nil }
  return (UInt64(stats.free_count) + UInt64(stats.inactive_count)) * UInt64(vm_kernel_page_size)
}

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
                  "availableMemoryBytes": formattingAvailableMemory() ?? 0,
                  "hardwareIdentity": "macos:\(formattingChip())",
                  "runtimeIdentity": "macos:\(ProcessInfo.processInfo.operatingSystemVersionString)",
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
