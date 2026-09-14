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

  const RiviumPushConfig({
    required this.apiKey,
    this.notificationIcon,
    this.usePushKit = true,
    this.showServiceNotification = true,
    this.showNotificationInForeground = true,
    this.autoConnect = true,
    this.appGroup,
    this.autoRefresh = true,
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
    };
  }
}
