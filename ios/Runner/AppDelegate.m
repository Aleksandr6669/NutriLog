#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"
#import "Runner-Swift.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  [WidgetReloadPlugin registerWithRegistrar:[self registrarForPlugin:@"WidgetReloadPlugin"]];
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  // WidgetCenter — Swift-only класс, вызываем через Swift bridge (Runner-Swift.h).
  // WidgetReloadPlugin.reloadAllWidgetTimelines() делает synchronize() + reloadAllTimelines().
  [WidgetReloadPlugin reloadAllWidgetTimelines];
  [super applicationDidEnterBackground:application];
}

@end
