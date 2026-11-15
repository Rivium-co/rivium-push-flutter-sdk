import 'rivium_push_auth.dart';
import 'rivium_push_version.dart';

/// Configuration for RiviumPush SDK
///
/// Only apiKey is required. MQTT configuration is automatically
/// fetched from the server during initialization.
class RiviumPushConfig {
  /// Your RiviumPush API key (required)
  final String apiKey;

  /// Android notification icon resource name (e.g., "ic_notification")
  final String? notificationIcon;

  /// Enable PushKit VoIP for iOS (default: true)
  final bool usePushKit;

  /// Show persistent "Push notifications active" notification on Android (default: true)
  /// Set to false to hide the foreground service notification.
  /// Note: The service still runs in foreground mode for reliability,
  /// but the notification will be minimized/hidden.
  final bool showServiceNotification;

  /// Show notifications when app is in foreground (default: true)
  /// When true, notifications will be displayed even when the app is active.
  final bool showNotificationInForeground;

  /// Auto-connect to MQTT when app enters foreground (default: true)
  final bool autoConnect;

  /// iOS only. App Group shared with a Notification Service Extension, used
  /// to confirm notification delivery (e.g. "group.com.example.app").
  ///
  /// An extension runs in its own process and cannot read the app's storage,
  /// so delivery confirmation needs a shared container. Enable the same App
  /// Group on both targets and pass it here. Ignored on Android, where the
  /// SDK confirms delivery directly.
  final String? appGroup;

  /// Refresh this device's registration automatically on launch (default: true).
  ///
  /// Only applies to installs that registered before. The native SDK
  /// re-registers in the background when 24 hours have passed or the app
  /// version, SDK version, push token or user id changed. It never prompts
  /// for permission. An explicit `register()` always registers.
  final bool autoRefresh;

  /// Returns the signed user token for the signed-in user, or null when no
  /// user is signed in (optional). The same function you pass to Rivium Chat
  /// works here. Can also be set later with `RiviumPush.setTokenProvider`.
  final RiviumPushTokenProvider? tokenProvider;

  /// Send counts of the SDK's own errors, by error code, with its requests
  /// (default: true). Counts only, no personal data.
  final bool sendDiagnostics;

  /// Web only: notifications while the web app is closed, through the browser's Web Push (default: false).
  ///
  /// Without it a Flutter web app gets messages only while it is open. With it, the Rivium Push service worker
  /// receives them in the background, also in an iPhone home-screen app (iOS 16.4+). Setup: run
  /// `dart run rivium_push:web_push_setup` in the app's folder once (it copies `rivium-push-sw.js` into `web/`), and
  /// on iOS call `register()` from a button tap inside the home-screen app. The worker has its own scope, so
  /// Flutter's own service worker is untouched. Without the file the app works as without this option.
  /// Android and iOS apps ignore it.
  final bool webPush;

  /// Web, with [webPush]: register the service worker at the app's root so it controls the page, instead of its own
  /// scope (`rivium-push/`). Some iPhones accept a Web Push subscription only from a worker that controls the page.
  /// The app must then not start Flutter's own service worker (it would replace this one and remove it):
  /// `dart run rivium_push:web_push_setup --root` writes a `web/flutter_bootstrap.js` that does not.
  final bool webPushAtRoot;

  const RiviumPushConfig({
    required this.apiKey,
    this.notificationIcon,
    this.usePushKit = true,
    this.showServiceNotification = true,
    this.showNotificationInForeground = true,
    this.autoConnect = true,
    this.appGroup,
    this.autoRefresh = true,
    this.tokenProvider,
    this.sendDiagnostics = true,
    this.webPush = false,
    this.webPushAtRoot = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'notificationIcon': notificationIcon,
      'usePushKit': usePushKit,
      'showServiceNotification': showServiceNotification,
      'showNotificationInForeground': showNotificationInForeground,
      'autoConnect': autoConnect,
      'appGroup': appGroup,
      'autoRefresh': autoRefresh,
      'wrapperSdkName': riviumPushSdkName,
      'wrapperSdkVersion': riviumPushSdkVersion,
      'sendDiagnostics': sendDiagnostics,
      // Web only; left out when off, so the native SDKs get the same map as before.
      if (webPush) 'webPush': true,
      if (webPush && webPushAtRoot) 'webPushAtRoot': true,
    };
  }
}
