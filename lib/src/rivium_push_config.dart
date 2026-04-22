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

  const RiviumPushConfig({
    required this.apiKey,
    this.notificationIcon,
    this.usePushKit = true,
    this.showServiceNotification = true,
    this.showNotificationInForeground = true,
    this.autoConnect = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'notificationIcon': notificationIcon,
      'usePushKit': usePushKit,
      'showServiceNotification': showServiceNotification,
      'showNotificationInForeground': showNotificationInForeground,
      'autoConnect': autoConnect,
    };
  }
}
