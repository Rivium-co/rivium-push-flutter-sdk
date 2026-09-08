#import "RiviumPushLaunchCatcher.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UNNotificationResponse *gPendingLaunchResponse = nil;
static BOOL gHookInstalled = NO;

@implementation RiviumPushLaunchCatcher

+ (void)store:(UNNotificationResponse *)response {
  if (response == nil || gPendingLaunchResponse != nil) {
    return;
  }
  gPendingLaunchResponse = response;
}

+ (nullable UNNotificationResponse *)takePendingLaunchResponse {
  UNNotificationResponse *response = gPendingLaunchResponse;
  gPendingLaunchResponse = nil;
  return response;
}

+ (void)load {
  if (![self rp_installSceneHook]) {
    // Flutter.framework may not be loaded yet — dynamic framework load order is
    // not guaranteed, so FlutterSceneDelegate can still be Nil here. Retry at
    // didFinishLaunching, which is always before the first scene connects.
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(rp_applicationDidFinishLaunching)
               name:UIApplicationDidFinishLaunchingNotification
             object:nil];
  }
}

+ (void)rp_applicationDidFinishLaunching {
  [self rp_installSceneHook];
}

+ (BOOL)rp_installSceneHook {
  if (gHookInstalled) {
    return YES;
  }

  Class sceneDelegateClass = NSClassFromString(@"FlutterSceneDelegate");
  if (sceneDelegateClass == Nil) {
    return NO;
  }

  SEL selector = @selector(scene:willConnectToSession:options:);
  Method method = class_getInstanceMethod(sceneDelegateClass, selector);
  if (method == NULL) {
    return NO;
  }

  IMP originalImp = method_getImplementation(method);
  IMP replacementImp = imp_implementationWithBlock(
      ^(id delegateSelf, UIScene *scene, UISceneSession *session,
        UISceneConnectionOptions *connectionOptions) {
        // Run Flutter's implementation first: it forwards to plugins, so the
        // plugin exists to receive the replay.
        ((void (*)(id, SEL, UIScene *, UISceneSession *,
                   UISceneConnectionOptions *))originalImp)(
            delegateSelf, selector, scene, session, connectionOptions);

        UNNotificationResponse *response = connectionOptions.notificationResponse;
        if (response != nil) {
          gPendingLaunchResponse = response;
        }
      });

  method_setImplementation(method, replacementImp);
  gHookInstalled = YES;
  return YES;
}

@end
