#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

/// Captures the notification tap that launched the app on scene-based hosts.
///
/// Under the UIScene lifecycle (the Flutter default since 3.35, via
/// `FlutterSceneDelegate` in Info.plist) the Flutter engine — and therefore
/// plugin registration — happens in `-scene:willConnectToSession:options:`,
/// which runs AFTER `-application:didFinishLaunchingWithOptions:` returns.
/// iOS requires a `UNUserNotificationCenter` delegate to exist before that
/// method returns or it DISCARDS the launch tap; it is never queued. So no
/// plugin can win that race, and a tap on a killed app delivered nothing.
///
/// UIKit does still hand the tap over on the scene path, as
/// `UISceneConnectionOptions.notificationResponse`. This class swizzles
/// `FlutterSceneDelegate` to read it and hands it to the plugin, so integrating
/// apps need no native changes.
@interface RiviumPushLaunchCatcher : NSObject

/// Returns the captured launch response and clears it. Returns nil if none.
+ (nullable UNNotificationResponse *)takePendingLaunchResponse;

/// Records a launch response captured through Flutter's supported
/// FlutterSceneLifeCycleDelegate hook, used when the swizzle did not install.
+ (void)store:(UNNotificationResponse *)response;

@end

NS_ASSUME_NONNULL_END
