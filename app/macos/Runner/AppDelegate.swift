import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().delegate = ProcessingNotifications.shared
    super.applicationDidFinishLaunching(notification)
  }
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

final class ProcessingNotifications: NSObject, UNUserNotificationCenterDelegate {
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
          let allowed = [.authorized, .provisional].contains(settings.authorizationStatus)
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

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(macOS 11.0, *) {
      completionHandler([.list])
    } else {
      completionHandler([.alert])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let entryId = response.notification.request.content.userInfo["entryId"] as? String {
      if let channel = channel {
        channel.invokeMethod("openEntry", arguments: entryId)
      } else {
        pendingEntryId = entryId
      }
    }
    completionHandler()
  }
}
