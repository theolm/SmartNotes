import Flutter
import os

private func formattingModel() -> String {
  #if targetEnvironment(simulator)
  return "simulator"
  #else
  var size = 0
  guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0 else { return "" }
  var bytes = [CChar](repeating: 0, count: size)
  guard sysctlbyname("hw.machine", &bytes, &size, nil, 0) == 0 else { return "" }
  return String(cString: bytes)
  #endif
}
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    ModelDownloads.shared.launch()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication,
                            handleEventsForBackgroundURLSession identifier: String,
                            completionHandler: @escaping () -> Void) {
    if identifier == ModelDownloads.sessionIdentifier {
      ModelDownloads.shared.handleBackgroundEvents(completion: completionHandler)
    } else {
      super.application(application, handleEventsForBackgroundURLSession: identifier,
                        completionHandler: completionHandler)
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SmartNotesDevice") {
      ModelDownloads.shared.attach(registrar.messenger())
      ProcessingNotifications.shared.attach(registrar.messenger())
      FlutterMethodChannel(
        name: "dev.theolm.smartnotes/device",
        binaryMessenger: registrar.messenger()
      ).setMethodCallHandler { call, result in
        switch call.method {
        case "profile":
          result([
            "memoryBytes": ProcessInfo.processInfo.physicalMemory,
            "availableMemoryBytes": os_proc_available_memory(),
            "hardwareIdentity": "ios:\(formattingModel())",
            "runtimeIdentity": "ios:\(ProcessInfo.processInfo.operatingSystemVersionString)",
            "is64Bit": MemoryLayout<Int>.size == 8,
            "processors": ProcessInfo.processInfo.activeProcessorCount,
          ])
        case "freeStorage":
          let attributes = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
          )
          result(attributes?[.systemFreeSize])
        case "excludeFromBackup":
          guard let path = call.arguments as? String else {
            result(FlutterError(
              code: "invalid-arguments",
              message: "A file-system path is required.",
              details: nil
            ))
            return
          }
          do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = URL(fileURLWithPath: path)
            try url.setResourceValues(values)
            result(nil)
          } catch {
            result(FlutterError(
              code: "backup-exclusion-failed",
              message: "Could not exclude the local model from iCloud Backup.",
              details: error.localizedDescription
            ))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.list])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let entryId = response.notification.request.content.userInfo["entryId"] as? String {
      ProcessingNotifications.shared.open(entryId)
    }
    completionHandler()
  }
}

final class ProcessingNotifications {
  static let shared = ProcessingNotifications()
  private let identifier = "note-processing"
  private var channel: FlutterMethodChannel?
  private var pendingEntryId: String?

  func attach(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "dev.theolm.smartnotes/processing_feedback",
      binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "show":
        guard let arguments = call.arguments as? [String: Any],
          let entryId = arguments["entryId"] as? String,
          let title = arguments["title"] as? String,
          let body = arguments["body"] as? String,
          let detail = arguments["detail"] as? String
        else {
          result(FlutterError(code: "invalid-arguments", message: nil, details: nil))
          return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.subtitle = detail
        content.userInfo = ["entryId": entryId]
        if #available(iOS 15.0, *) { content.interruptionLevel = .passive }
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [self.identifier])
        center.removePendingNotificationRequests(withIdentifiers: [self.identifier])
        center.add(UNNotificationRequest(identifier: self.identifier, content: content, trigger: nil)) {
          error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "notification", message: error.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        }
      case "dismiss":
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [self.identifier])
        center.removePendingNotificationRequests(withIdentifiers: [self.identifier])
        result(nil)
      case "notificationsAllowed":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let allowed = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
          DispatchQueue.main.async { result(allowed) }
        }
      case "requestNotifications":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { allowed, _ in
          DispatchQueue.main.async { result(allowed) }
        }
      case "takePendingEntry":
        result(self.pendingEntryId)
        self.pendingEntryId = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func open(_ entryId: String) {
    guard let channel = channel else {
      pendingEntryId = entryId
      return
    }
    channel.invokeMethod("openEntry", arguments: entryId)
  }
}
