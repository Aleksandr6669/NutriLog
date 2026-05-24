#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"
#import "Runner-Swift.h"
@import WidgetKit;

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  [WidgetReloadPlugin registerWithRegistrar:[self registrarForPlugin:@"WidgetReloadPlugin"]];
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  // Перезагружаем все виджеты при уходе в фон.
  // К этому моменту Flutter записал данные в UserDefaults через App Group.
  if (@available(iOS 16.0, *)) {
    [WidgetCenter.shared reloadAllTimelines];
  }
  [super applicationDidEnterBackground:application];
}

@end
