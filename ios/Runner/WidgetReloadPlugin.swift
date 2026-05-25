import Flutter
import WidgetKit

/// Flushes App Group UserDefaults and forces WidgetKit timeline reload.
/// home_widget writes defaults but does not call synchronize() before reloadTimelines,
/// which can leave the widget extension reading stale values on iOS.
@objc public class WidgetReloadPlugin: NSObject, FlutterPlugin {
  private static let appGroupId = "group.com.app.nutrilog.app"

  @objc public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.app.nutrilog.app/widget_reload",
      binaryMessenger: registrar.messenger()
    )
    let instance = WidgetReloadPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  /// Вызывается из ObjC AppDelegate при уходе в фон.
  /// WidgetCenter — Swift-only класс, поэтому вызов идёт через этот мост.
  @objc public static func reloadAllWidgetTimelines() {
    let defaults = UserDefaults(suiteName: appGroupId)
    defaults?.synchronize()
    WidgetCenter.shared.reloadAllTimelines()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "flushAndReload":
      let defaults = UserDefaults(suiteName: Self.appGroupId)
      defaults?.synchronize()
      WidgetCenter.shared.reloadTimelines(ofKind: "NutriLogWidget")
      WidgetCenter.shared.reloadTimelines(ofKind: "NutriLogWaterWidget")
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
