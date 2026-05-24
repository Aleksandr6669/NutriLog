import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Перезагружаем все виджеты при уходе приложения в фон.
    // К этому моменту Flutter уже успел записать данные в UserDefaults через App Group.
    // Минимальная версия проекта — iOS 16.0, WidgetKit доступен без #available проверки.
    WidgetCenter.shared.reloadAllTimelines()
    super.applicationDidEnterBackground(application)
  }
}
