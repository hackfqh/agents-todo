import Cocoa
import FlutterMacOS
import UserNotifications

class TodoNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(macOS 11.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }
}

class MainFlutterWindow: NSWindow {
  private let notificationDelegate = TodoNotificationDelegate()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let projectFoldersChannel = FlutterMethodChannel(
      name: "todo_desk/project_folders",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    projectFoldersChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickFolder" else {
        result(FlutterMethodNotImplemented)
        return
      }

      DispatchQueue.main.async {
        NSApp.activate(ignoringOtherApps: true)
        self?.makeKeyAndOrderFront(nil)

        let panel = NSOpenPanel()
        panel.message = "Select project folder"
        panel.prompt = "Select Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK {
          result(panel.url?.path)
        } else {
          result(nil)
        }
      }
    }

    UNUserNotificationCenter.current().delegate = notificationDelegate
    let notificationsChannel = FlutterMethodChannel(
      name: "todo_desk/notifications",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    notificationsChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "showNotification" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let title = arguments["title"] as? String,
        let body = arguments["body"] as? String
      else {
        result(FlutterError(
          code: "bad_arguments",
          message: "Expected title and body for desktop notification.",
          details: nil))
        return
      }

      guard let self = self else {
        result(false)
        return
      }
      self.showDesktopNotification(title: title, body: body, result: result)
    }

    super.awakeFromNib()
  }

  private func showDesktopNotification(
    title: String,
    body: String,
    result: @escaping FlutterResult
  ) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "notification_authorization_failed",
            message: error.localizedDescription,
            details: nil))
        }
        return
      }

      guard granted else {
        DispatchQueue.main.async {
          result(false)
        }
        return
      }

      center.getNotificationSettings { settings in
        guard settings.authorizationStatus == .authorized else {
          DispatchQueue.main.async {
            result(false)
          }
          return
        }

        guard settings.alertSetting == .enabled else {
          DispatchQueue.main.async {
            result(false)
          }
          return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
          identifier: UUID().uuidString,
          content: content,
          trigger: nil)
        center.add(request) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(
                code: "notification_delivery_failed",
                message: error.localizedDescription,
                details: nil))
            } else {
              result(true)
            }
          }
        }
      }
    }
  }
}
