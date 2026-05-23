#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"
#import "Runner-Swift.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  [WidgetReloadPlugin registerWithRegistrar:[self registrarForPlugin:@"WidgetReloadPlugin"]];
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
