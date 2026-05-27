import Flutter
import WidgetKit

/// Flushes App Group UserDefaults and forces WidgetKit timeline reload.
/// home_widget writes defaults but does not call synchronize() before reloadTimelines,
/// which can leave the widget extension reading stale values on iOS.
@objc public class WidgetReloadPlugin: NSObject, FlutterPlugin {
  private static let appGroupId = "group.com.app.nutrilog.app.X4HMJXZ332"
  private static let widgetKeys = ["calories", "proteins", "fats", "carbs", "water", "water_value", "steps"]

  @objc public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.app.nutrilog.app/widget_reload",
      binaryMessenger: registrar.messenger()
    )
    let instance = WidgetReloadPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    NSLog("[WidgetReloadPlugin] ✅ Registered with channel 'com.app.nutrilog.app/widget_reload'")
  }

  /// Вызывается из ObjC AppDelegate при уходе в фон.
  /// WidgetCenter — Swift-only класс, поэтому вызов идёт через этот мост.
  @objc public static func reloadAllWidgetTimelines() {
    NSLog("[WidgetReloadPlugin] 🔄 reloadAllWidgetTimelines called (background)")
    logCurrentDefaults(prefix: "BG")
    let defaults = UserDefaults(suiteName: appGroupId)
    defaults?.synchronize()
    WidgetCenter.shared.reloadAllTimelines()
    NSLog("[WidgetReloadPlugin] ✅ reloadAllTimelines complete")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "flushAndReload":
      NSLog("[WidgetReloadPlugin] 🔄 flushAndReload called (from Flutter)")
      Self.logCurrentDefaults(prefix: "FG")
      let defaults = UserDefaults(suiteName: Self.appGroupId)
      defaults?.synchronize()
      WidgetCenter.shared.reloadTimelines(ofKind: "NutriLogWidget")
      WidgetCenter.shared.reloadTimelines(ofKind: "NutriLogWaterWidget")
      NSLog("[WidgetReloadPlugin] ✅ reloadTimelines complete for NutriLogWidget + NutriLogWaterWidget")
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func logCurrentDefaults(prefix: String) {
    let defaults = UserDefaults(suiteName: appGroupId)
    if defaults == nil {
      NSLog("[WidgetReloadPlugin] ❌ [\(prefix)] UserDefaults is NIL! App Group '\(appGroupId)' not accessible")
      return
    }
    for key in widgetKeys {
      let value = defaults?.string(forKey: key) ?? "<nil>"
      NSLog("[WidgetReloadPlugin] 📊 [\(prefix)] \(key) = \(value)")
    }
  }
}
