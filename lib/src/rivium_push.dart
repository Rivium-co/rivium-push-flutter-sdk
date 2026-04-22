import 'dart:async';
import 'package:flutter/services.dart';
import 'rivium_push_config.dart';
import 'rivium_push_message.dart';
import 'rivium_push_error.dart';
import 'inapp_message.dart';
import 'inbox_message.dart';
import 'ab_test.dart';

/// Callback for receiving push messages
typedef OnMessageCallback = void Function(RiviumPushMessage message);

/// Callback for connection state changes
typedef OnConnectionStateCallback = void Function(bool connected);

/// Callback for registration success
typedef OnRegisteredCallback = void Function(String deviceId);

/// Callback for errors (simple string message)
typedef OnErrorCallback = void Function(String error);

/// Callback for detailed errors with error codes
typedef OnDetailedErrorCallback = void Function(RiviumPushError error);

/// Callback for reconnection state changes during auto-retry
typedef OnReconnectingCallback = void Function(ReconnectionState state);

/// Callback for network state changes
typedef OnNetworkStateCallback = void Function(NetworkState state);

/// Callback for app state changes (foreground/background)
typedef OnAppStateCallback = void Function(AppState state);

/// Callback for app update detection
typedef OnAppUpdatedCallback = void Function(AppUpdateInfo info);

/// Callback when an in-app message is ready to be displayed
typedef OnInAppMessageReadyCallback = void Function(InAppMessage message);

/// Callback when an in-app message button is clicked
typedef OnInAppButtonClickCallback = void Function(InAppMessage message, InAppButton button);

/// Callback when an in-app message is dismissed
typedef OnInAppMessageDismissedCallback = void Function(InAppMessage message);

/// Callback when a new inbox message is received
typedef OnInboxMessageCallback = void Function(InboxMessage message);

/// Callback when inbox message status changes
typedef OnInboxMessageStatusChangedCallback = void Function(String messageId, InboxMessageStatus status);

/// Callback when a notification action button is tapped
typedef OnNotificationActionCallback = void Function(NotificationActionEvent event);

/// Callback when an A/B test variant is assigned
typedef OnABTestVariantAssignedCallback = void Function(ABTestVariant variant);

/// Callback for A/B test errors
typedef OnABTestErrorCallback = void Function(String testId, String error);

/// Callback when a notification is tapped (for foreground handling)
typedef OnNotificationTappedCallback = void Function(RiviumPushMessage message);

/// Log levels for the RiviumPush SDK.
/// Controls verbosity of logging output on both iOS and Android.
enum RiviumPushLogLevel {
  /// No logging at all (for production)
  none,

  /// Only errors
  error,

  /// Errors and warnings
  warning,

  /// Errors, warnings, and info messages
  info,

  /// All messages including debug output (default for development)
  debug,

  /// Everything including very detailed traces
  verbose,
}

/// Analytics event types for tracking SDK usage.
/// Use with [RiviumPush.setAnalyticsHandler] to track SDK events.
enum RiviumPushAnalyticsEvent {
  /// SDK was initialized
  sdkInitialized,

  /// Device was registered
  deviceRegistered,

  /// Device was unregistered
  deviceUnregistered,

  /// Push message was received
  messageReceived,

  /// Push message was displayed as notification
  messageDisplayed,

  /// MQTT connected successfully
  connected,

  /// MQTT disconnected
  disconnected,

  /// Connection error occurred
  connectionError,

  /// Retry attempt started (during exponential backoff)
  retryStarted,

  /// Topic subscribed
  topicSubscribed,

  /// Topic unsubscribed
  topicUnsubscribed,

  /// Network state changed
  networkStateChanged,

  /// App state changed (foreground/background)
  appStateChanged,

  /// App was updated
  appUpdated,

  /// In-app message was displayed
  inAppMessageDisplayed,

  /// In-app message button was clicked
  inAppButtonClicked,

  /// In-app message was dismissed
  inAppMessageDismissed,

  /// In-app messages were fetched
  inAppMessagesFetched,

  /// Inbox messages were fetched
  inboxMessagesFetched,

  /// Inbox message was read
  inboxMessageRead,

  /// Inbox message was archived
  inboxMessageArchived,

  /// Inbox message was deleted
  inboxMessageDeleted,

  /// A/B test variant was assigned
  abTestVariantAssigned,

  /// A/B test impression was tracked
  abTestImpression,

  /// A/B test opened was tracked
  abTestOpened,

  /// A/B test clicked was tracked
  abTestClicked,
}

/// Callback for analytics events.
/// Parameters:
/// - event: The type of analytics event
/// - properties: Optional properties associated with the event
typedef RiviumPushAnalyticsCallback = void Function(
  RiviumPushAnalyticsEvent event,
  Map<String, dynamic>? properties,
);

/// Main RiviumPush class - entry point for the SDK
class RiviumPush {
  static const MethodChannel _channel = MethodChannel('co.rivium.push/main');

  static OnMessageCallback? _onMessage;
  static OnConnectionStateCallback? _onConnectionState;
  static OnRegisteredCallback? _onRegistered;
  static OnErrorCallback? _onError;
  static OnDetailedErrorCallback? _onDetailedError;
  static OnReconnectingCallback? _onReconnecting;
  static OnNetworkStateCallback? _onNetworkState;
  static OnAppStateCallback? _onAppState;
  static OnAppUpdatedCallback? _onAppUpdated;
  static OnInAppMessageReadyCallback? _onInAppMessageReady;
  static OnInAppButtonClickCallback? _onInAppButtonClick;
  static OnInAppMessageDismissedCallback? _onInAppMessageDismissed;
  static OnInboxMessageCallback? _onInboxMessage;
  static OnInboxMessageStatusChangedCallback? _onInboxMessageStatusChanged;
  static OnNotificationActionCallback? _onNotificationAction;
  static OnABTestVariantAssignedCallback? _onABTestVariantAssigned;
  static OnABTestErrorCallback? _onABTestError;
  static OnNotificationTappedCallback? _onNotificationTapped;

  /// Analytics callback for tracking SDK events
  static RiviumPushAnalyticsCallback? _analyticsCallback;

  /// Whether analytics tracking is enabled
  static bool _analyticsEnabled = false;

  static bool _initialized = false;

  /// Initialize the SDK with configuration
  static Future<void> init(RiviumPushConfig config) async {
    if (_initialized) return;

    _channel.setMethodCallHandler(_handleMethod);

    await _channel.invokeMethod('init', config.toMap());
    _initialized = true;

    _trackEvent(RiviumPushAnalyticsEvent.sdkInitialized, {});
  }

  /// Set callback for push messages
  static void onMessage(OnMessageCallback callback) {
    _onMessage = callback;
  }

  /// Set callback for connection state changes
  static void onConnectionState(OnConnectionStateCallback callback) {
    _onConnectionState = callback;
  }

  /// Set callback for registration success
  static void onRegistered(OnRegisteredCallback callback) {
    _onRegistered = callback;
  }

  /// Set callback for errors (simple string message)
  static void onError(OnErrorCallback callback) {
    _onError = callback;
  }

  /// Set callback for detailed errors with error codes
  /// This provides more structured error information including:
  /// - Error code (int) for programmatic handling
  /// - Error message (String) for display
  /// - Additional details (String?) for debugging
  static void onDetailedError(OnDetailedErrorCallback callback) {
    _onDetailedError = callback;
  }

  /// Set callback for reconnection state changes
  /// Called when the SDK is automatically retrying connection with exponential backoff.
  /// Provides:
  /// - Current retry attempt number
  /// - Time until next retry in milliseconds
  static void onReconnecting(OnReconnectingCallback callback) {
    _onReconnecting = callback;
  }

  /// Set callback for network state changes
  /// Called when network connectivity changes (e.g., WiFi connected/disconnected).
  /// The SDK automatically reconnects MQTT when network becomes available.
  /// Provides:
  /// - Whether network is available
  /// - The type of network (wifi, cellular, etc.)
  static void onNetworkState(OnNetworkStateCallback callback) {
    _onNetworkState = callback;
  }

  /// Set callback for app state changes (foreground/background)
  /// Called when the app transitions between foreground and background.
  /// The SDK automatically reconnects MQTT when app returns to foreground.
  /// Provides:
  /// - Whether app is in foreground
  static void onAppState(OnAppStateCallback callback) {
    _onAppState = callback;
  }

  /// Set callback for app update detection
  /// Called during init when the SDK detects the app was updated.
  /// When needsReregistration is true, call register() to refresh the device token.
  /// This ensures push notifications continue working after app updates.
  static void onAppUpdated(OnAppUpdatedCallback callback) {
    _onAppUpdated = callback;
  }

  /// Set callback for notification action button taps
  /// Called when user taps an action button on a notification.
  /// Provides the action ID and original notification data.
  ///
  /// Example:
  /// ```dart
  /// RiviumPush.onNotificationAction((event) {
  ///   print('Action tapped: ${event.actionId}');
  ///   if (event.actionId == 'view') {
  ///     Navigator.pushNamed(context, '/product/${event.data?['productId']}');
  ///   }
  /// });
  /// ```
  static void onNotificationAction(OnNotificationActionCallback callback) {
    _onNotificationAction = callback;
  }

  /// Set callback for when a notification is tapped.
  /// This is called when the user taps on a notification, regardless of whether
  /// the app is in foreground or background. Use this for real-time handling
  /// of notification taps instead of relying only on getInitialMessage().
  ///
  /// Example:
  /// ```dart
  /// RiviumPush.onNotificationTapped((message) {
  ///   print('Notification tapped: ${message.title}');
  ///   // Navigate to relevant screen or show dialog
  /// });
  /// ```
  static void onNotificationTapped(OnNotificationTappedCallback callback) {
    _onNotificationTapped = callback;
  }

  /// Register device for push notifications
  static Future<void> register({
    String? userId,
    Map<String, String>? metadata,
  }) async {
    await _channel.invokeMethod('register', {
      'userId': userId,
      'metadata': metadata,
    });
  }

  /// Unregister device and stop push service
  static Future<void> unregister() async {
    await _channel.invokeMethod('unregister');
  }

  /// Subscribe to a topic to receive targeted messages
  static Future<void> subscribeTopic(String topic) async {
    await _channel.invokeMethod('subscribeTopic', {'topic': topic});
  }

  /// Unsubscribe from a topic to stop receiving its messages
  static Future<void> unsubscribeTopic(String topic) async {
    await _channel.invokeMethod('unsubscribeTopic', {'topic': topic});
  }

  /// Check if MQTT is connected
  static Future<bool> isConnected() async {
    final result = await _channel.invokeMethod<bool>('isConnected');
    return result ?? false;
  }

  /// Get current device ID
  static Future<String?> getDeviceId() async {
    return await _channel.invokeMethod<String>('getDeviceId');
  }

  /// Set or update user ID for the current device
  /// Call this after user login to associate the device with the user
  static Future<void> setUserId(String userId) async {
    await _channel.invokeMethod('setUserId', {'userId': userId});
  }

  /// Clear user ID (call on logout)
  static Future<void> clearUserId() async {
    await _channel.invokeMethod('clearUserId');
  }

  /// Get the message that launched the app (when user tapped a notification)
  /// Returns null if the app was not launched from a notification tap
  /// This should be called early in your app initialization (e.g., in main())
  static Future<RiviumPushMessage?> getInitialMessage() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialMessage');
    if (result == null) return null;
    return RiviumPushMessage.fromMap(result);
  }

  /// Set the log level for native SDK logging.
  /// This controls how verbose the native logging is on both iOS and Android.
  ///
  /// Recommended usage:
  /// - Development: [RiviumPushLogLevel.debug] (default)
  /// - Production: [RiviumPushLogLevel.error] or [RiviumPushLogLevel.none]
  ///
  /// Example:
  /// ```dart
  /// // In production, reduce logging
  /// if (kReleaseMode) {
  ///   await RiviumPush.setLogLevel(RiviumPushLogLevel.error);
  /// }
  /// ```
  static Future<void> setLogLevel(RiviumPushLogLevel level) async {
    await _channel.invokeMethod('setLogLevel', {'level': level.name});
  }

  // ==================== In-App Messages ====================

  /// Set callback for when an in-app message is ready to be displayed
  static void onInAppMessageReady(OnInAppMessageReadyCallback callback) {
    _onInAppMessageReady = callback;
  }

  /// Set callback for when an in-app message button is clicked
  static void onInAppButtonClick(OnInAppButtonClickCallback callback) {
    _onInAppButtonClick = callback;
  }

  /// Set callback for when an in-app message is dismissed
  static void onInAppMessageDismissed(OnInAppMessageDismissedCallback callback) {
    _onInAppMessageDismissed = callback;
  }

  /// Fetch in-app messages from the server
  /// Returns a list of available in-app messages
  static Future<List<InAppMessage>> fetchInAppMessages() async {
    final result = await _channel.invokeMethod<List<dynamic>>('fetchInAppMessages');
    if (result == null) return [];

    final messages = result
        .map((item) => InAppMessage.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    _trackEvent(RiviumPushAnalyticsEvent.inAppMessagesFetched, {
      'count': messages.length,
    });

    return messages;
  }

  /// Trigger in-app messages for app open event
  /// Call this when your app becomes active to potentially show messages
  static Future<void> triggerInAppOnAppOpen() async {
    await _channel.invokeMethod('triggerInAppOnAppOpen');
  }

  /// Trigger in-app messages for a custom event
  /// Use this to show messages based on user actions in your app
  static Future<void> triggerInAppEvent(String eventName, {Map<String, dynamic>? properties}) async {
    await _channel.invokeMethod('triggerInAppEvent', {
      'eventName': eventName,
      'properties': properties,
    });
  }

  /// Trigger in-app messages for session start
  /// Call this when a new user session begins
  static Future<void> triggerInAppOnSessionStart() async {
    await _channel.invokeMethod('triggerInAppOnSessionStart');
  }

  /// Show a specific in-app message by its ID
  static Future<void> showInAppMessage(String messageId) async {
    await _channel.invokeMethod('showInAppMessage', {'messageId': messageId});
  }

  /// Dismiss the currently displayed in-app message
  static Future<void> dismissInAppMessage() async {
    await _channel.invokeMethod('dismissInAppMessage');
  }

  // ==================== Inbox ====================

  /// Set callback for when a new inbox message is received
  static void onInboxMessage(OnInboxMessageCallback callback) {
    _onInboxMessage = callback;
  }

  /// Set callback for when inbox message status changes
  static void onInboxMessageStatusChanged(OnInboxMessageStatusChangedCallback callback) {
    _onInboxMessageStatusChanged = callback;
  }

  /// Get inbox messages with optional filters
  ///
  /// [status] - Filter by message status ('unread', 'read', 'archived')
  /// [category] - Filter by category
  /// [limit] - Maximum number of messages to return (default: 50)
  /// [offset] - Offset for pagination (default: 0)
  static Future<InboxMessagesResponse> getInboxMessages({
    InboxMessageStatus? status,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInboxMessages', {
      if (status != null) 'status': status.name,
      if (category != null) 'category': category,
      'limit': limit,
      'offset': offset,
    });

    if (result == null) {
      return InboxMessagesResponse(messages: [], total: 0, unreadCount: 0);
    }

    final response = InboxMessagesResponse.fromMap(Map<String, dynamic>.from(result));

    _trackEvent(RiviumPushAnalyticsEvent.inboxMessagesFetched, {
      'count': response.messages.length,
      'total': response.total,
      'unread': response.unreadCount,
    });

    return response;
  }

  /// Get a single inbox message by ID
  static Future<InboxMessage?> getInboxMessage(String messageId) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getInboxMessage',
      {'messageId': messageId},
    );

    if (result == null) return null;
    return InboxMessage.fromMap(Map<String, dynamic>.from(result));
  }

  /// Mark an inbox message as read
  static Future<void> markInboxMessageAsRead(String messageId) async {
    await _channel.invokeMethod('markInboxMessageAsRead', {'messageId': messageId});
    _trackEvent(RiviumPushAnalyticsEvent.inboxMessageRead, {'message_id': messageId});
  }

  /// Archive an inbox message
  static Future<void> archiveInboxMessage(String messageId) async {
    await _channel.invokeMethod('archiveInboxMessage', {'messageId': messageId});
    _trackEvent(RiviumPushAnalyticsEvent.inboxMessageArchived, {'message_id': messageId});
  }

  /// Delete an inbox message
  static Future<void> deleteInboxMessage(String messageId) async {
    await _channel.invokeMethod('deleteInboxMessage', {'messageId': messageId});
    _trackEvent(RiviumPushAnalyticsEvent.inboxMessageDeleted, {'message_id': messageId});
  }

  /// Mark multiple inbox messages with a status
  static Future<void> markMultipleInboxMessages(
    List<String> messageIds,
    InboxMessageStatus status,
  ) async {
    await _channel.invokeMethod('markMultipleInboxMessages', {
      'messageIds': messageIds,
      'status': status.name,
    });
  }

  /// Mark all inbox messages as read
  static Future<void> markAllInboxMessagesAsRead() async {
    await _channel.invokeMethod('markAllInboxMessagesAsRead');
  }

  /// Get unread inbox count (from cache, synchronous)
  static Future<int> getInboxUnreadCount() async {
    final result = await _channel.invokeMethod<int>('getInboxUnreadCount');
    return result ?? 0;
  }

  /// Fetch unread inbox count from server
  static Future<int> fetchInboxUnreadCount() async {
    final result = await _channel.invokeMethod<int>('fetchInboxUnreadCount');
    return result ?? 0;
  }

  /// Get cached inbox messages without network call
  static Future<List<InboxMessage>> getCachedInboxMessages() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getCachedInboxMessages');
    if (result == null) return [];

    return result
        .map((item) => InboxMessage.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Clear inbox cache
  static Future<void> clearInboxCache() async {
    await _channel.invokeMethod('clearInboxCache');
  }

  // ==================== A/B Testing ====================

  /// Set callback for when an A/B test variant is assigned
  static void onABTestVariantAssigned(OnABTestVariantAssignedCallback callback) {
    _onABTestVariantAssigned = callback;
  }

  /// Set callback for A/B test errors
  static void onABTestError(OnABTestErrorCallback callback) {
    _onABTestError = callback;
  }

  /// Get active A/B tests for the app
  ///
  /// Returns a list of all running A/B tests that the app can participate in.
  static Future<List<ABTestSummary>> getActiveABTests() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getActiveABTests');
    if (result == null) return [];

    return result
        .map((item) => ABTestSummary.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Get variant assignment for a specific A/B test
  ///
  /// [testId] - The ID of the A/B test
  /// [forceRefresh] - If true, fetches fresh assignment from server (default: false)
  ///
  /// Returns the variant assigned to this device for the test.
  /// The assignment is cached locally and persists across app restarts.
  static Future<ABTestVariant?> getABTestVariant(
    String testId, {
    bool forceRefresh = false,
  }) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getABTestVariant',
      {
        'testId': testId,
        'forceRefresh': forceRefresh,
      },
    );

    if (result == null) return null;

    final variant = ABTestVariant.fromMap(result);
    _trackEvent(RiviumPushAnalyticsEvent.abTestVariantAssigned, {
      'test_id': testId,
      'variant_id': variant.variantId,
      'variant_name': variant.variantName,
    });

    return variant;
  }

  /// Get cached variant for an A/B test (synchronous, no network call)
  ///
  /// Returns the cached variant if available, null otherwise.
  /// Use this for quick checks without making network requests.
  static Future<ABTestVariant?> getCachedABTestVariant(String testId) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getCachedABTestVariant',
      {'testId': testId},
    );

    if (result == null) return null;
    return ABTestVariant.fromMap(result);
  }

  /// Track A/B test impression
  ///
  /// Call this when the variant content is shown to the user.
  /// [testId] - The A/B test ID
  /// [variantId] - The variant ID that was displayed
  static Future<void> trackABTestImpression(
    String testId,
    String variantId,
  ) async {
    await _channel.invokeMethod('trackABTestImpression', {
      'testId': testId,
      'variantId': variantId,
    });
    _trackEvent(RiviumPushAnalyticsEvent.abTestImpression, {
      'test_id': testId,
      'variant_id': variantId,
    });
  }

  /// Track A/B test opened
  ///
  /// Call this when the user views/opens the variant content.
  /// [testId] - The A/B test ID
  /// [variantId] - The variant ID that was viewed
  static Future<void> trackABTestOpened(
    String testId,
    String variantId,
  ) async {
    await _channel.invokeMethod('trackABTestOpened', {
      'testId': testId,
      'variantId': variantId,
    });
    _trackEvent(RiviumPushAnalyticsEvent.abTestOpened, {
      'test_id': testId,
      'variant_id': variantId,
    });
  }

  /// Track A/B test clicked
  ///
  /// Call this when the user clicks a CTA in the variant content.
  /// [testId] - The A/B test ID
  /// [variantId] - The variant ID where the CTA was clicked
  static Future<void> trackABTestClicked(
    String testId,
    String variantId,
  ) async {
    await _channel.invokeMethod('trackABTestClicked', {
      'testId': testId,
      'variantId': variantId,
    });
    _trackEvent(RiviumPushAnalyticsEvent.abTestClicked, {
      'test_id': testId,
      'variant_id': variantId,
    });
  }

  /// Track display of an A/B test variant (impression + opened)
  ///
  /// Convenience method that tracks both impression and opened events.
  /// Use this when showing variant content to users.
  static Future<void> trackABTestDisplay(ABTestVariant variant) async {
    await _channel.invokeMethod('trackABTestDisplay', {
      'testId': variant.testId,
      'variantId': variant.variantId,
    });
    _trackEvent(RiviumPushAnalyticsEvent.abTestImpression, {
      'test_id': variant.testId,
      'variant_id': variant.variantId,
    });
    _trackEvent(RiviumPushAnalyticsEvent.abTestOpened, {
      'test_id': variant.testId,
      'variant_id': variant.variantId,
    });
  }

  /// Clear A/B test cache
  ///
  /// Clears all cached variant assignments. Next call to getABTestVariant
  /// will fetch fresh data from the server.
  static Future<void> clearABTestCache() async {
    await _channel.invokeMethod('clearABTestCache');
  }

  /// Enable analytics tracking with a custom handler.
  ///
  /// The callback will be invoked for each SDK event (connect, disconnect,
  /// message received, errors, etc.). You can use this to send events to
  /// your analytics service (e.g., Firebase Analytics, Mixpanel, Amplitude).
  ///
  /// Example:
  /// ```dart
  /// RiviumPush.setAnalyticsHandler((event, properties) {
  ///   // Send to Firebase Analytics
  ///   FirebaseAnalytics.instance.logEvent(
  ///     name: 'rivium_push_${event.name}',
  ///     parameters: properties,
  ///   );
  /// });
  /// ```
  static void setAnalyticsHandler(RiviumPushAnalyticsCallback callback) {
    _analyticsCallback = callback;
    _analyticsEnabled = true;
  }

  /// Disable analytics tracking.
  static void disableAnalytics() {
    _analyticsCallback = null;
    _analyticsEnabled = false;
  }

  /// Check if analytics tracking is enabled.
  static bool get isAnalyticsEnabled => _analyticsEnabled;

  /// Enable analytics tracking.
  /// Note: You must also set a handler with setAnalyticsHandler() to receive events.
  static void enableAnalytics() {
    _analyticsEnabled = true;
  }

  // ==================== Log Level ====================

  /// Get current log level from native SDK
  static Future<RiviumPushLogLevel> getLogLevel() async {
    final result = await _channel.invokeMethod<String>('getLogLevel');
    if (result == null) return RiviumPushLogLevel.debug;
    switch (result.toLowerCase()) {
      case 'none':
        return RiviumPushLogLevel.none;
      case 'error':
        return RiviumPushLogLevel.error;
      case 'warning':
        return RiviumPushLogLevel.warning;
      case 'info':
        return RiviumPushLogLevel.info;
      case 'debug':
        return RiviumPushLogLevel.debug;
      case 'verbose':
        return RiviumPushLogLevel.verbose;
      default:
        return RiviumPushLogLevel.debug;
    }
  }

  // ==================== Badge Management ====================

  /// Get current badge count
  static Future<int> getBadgeCount() async {
    final result = await _channel.invokeMethod<int>('getBadgeCount');
    return result ?? 0;
  }

  /// Set badge count
  static Future<void> setBadgeCount(int count) async {
    await _channel.invokeMethod('setBadgeCount', {'count': count});
  }

  /// Clear badge (set to 0)
  static Future<void> clearBadge() async {
    await _channel.invokeMethod('clearBadge');
  }

  /// Increment badge count by a value
  static Future<void> incrementBadge({int by = 1}) async {
    await _channel.invokeMethod('incrementBadge', {'by': by});
  }

  /// Decrement badge count by a value (minimum 0)
  static Future<void> decrementBadge({int by = 1}) async {
    await _channel.invokeMethod('decrementBadge', {'by': by});
  }

  // ==================== Service Notification ====================

  /// Check if the service notification is currently hidden.
  /// Returns true if the user has disabled the notification channel.
  /// On Android 8.0+, users can disable individual notification channels.
  /// When the push service channel is disabled, the notification disappears
  /// but the foreground service keeps running.
  static Future<bool> isServiceNotificationHidden() async {
    final result = await _channel.invokeMethod<bool>('isServiceNotificationHidden');
    return result ?? false;
  }

  /// Open system settings for the push service notification channel.
  /// The user can toggle the channel off to hide the persistent notification
  /// while keeping the push service alive in the background.
  /// Only works on Android 8.0+ (API 26+). No-op on iOS and older Android.
  static Future<void> openServiceNotificationSettings() async {
    await _channel.invokeMethod('openServiceNotificationSettings');
  }

  // ==================== State Getters ====================

  /// Get current network state
  static Future<NetworkState> getNetworkState() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getNetworkState');
    if (result == null) {
      return NetworkState(isAvailable: false, networkType: NetworkType.unknown);
    }
    return NetworkState.fromMap(result);
  }

  /// Get current app state (foreground/background)
  static Future<AppState> getAppState() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppState');
    if (result == null) {
      return AppState(isInForeground: false);
    }
    return AppState.fromMap(result);
  }

  /// Check if the app is currently in foreground
  static Future<bool> isInForeground() async {
    final state = await getAppState();
    return state.isInForeground;
  }

  /// Internal method to track analytics events.
  static void _trackEvent(
    RiviumPushAnalyticsEvent event, [
    Map<String, dynamic>? properties,
  ]) {
    if (_analyticsEnabled && _analyticsCallback != null) {
      try {
        _analyticsCallback!(event, properties);
      } catch (e) {
        print('[RiviumPush] Analytics callback error: $e');
      }
    }
  }

  /// Handle method calls from native side
  static Future<void> _handleMethod(MethodCall call) async {
    print('[RiviumPush] _handleMethod called: ${call.method}');
    print('[RiviumPush] Arguments: ${call.arguments}');

    switch (call.method) {
      case 'onMessage':
        print('[RiviumPush] onMessage handler - callback set: ${_onMessage != null}');
        if (_onMessage != null) {
          final message = RiviumPushMessage.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] Parsed message: $message');
          _onMessage!(message);
          _trackEvent(RiviumPushAnalyticsEvent.messageReceived, {
            'title': message.title,
            'silent': message.silent,
          });
        } else {
          print('[RiviumPush] WARNING: onMessage callback is null!');
        }
        break;

      case 'onConnectionState':
        print('[RiviumPush] onConnectionState handler - callback set: ${_onConnectionState != null}');
        final connected = call.arguments as bool;
        _onConnectionState?.call(connected);
        _trackEvent(
          connected
              ? RiviumPushAnalyticsEvent.connected
              : RiviumPushAnalyticsEvent.disconnected,
        );
        break;

      case 'onRegistered':
        print('[RiviumPush] onRegistered handler - callback set: ${_onRegistered != null}');
        final deviceId = call.arguments as String;
        _onRegistered?.call(deviceId);
        _trackEvent(RiviumPushAnalyticsEvent.deviceRegistered, {
          'device_id': deviceId,
        });
        break;

      case 'onError':
        print('[RiviumPush] onError handler - callback set: ${_onError != null}');
        final errorMsg = call.arguments as String;
        _onError?.call(errorMsg);
        _trackEvent(RiviumPushAnalyticsEvent.connectionError, {
          'error': errorMsg,
        });
        break;

      case 'onDetailedError':
        print('[RiviumPush] onDetailedError handler - callback set: ${_onDetailedError != null}');
        if (call.arguments is Map) {
          final error = RiviumPushError.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] Parsed error: $error');
          _onDetailedError?.call(error);
          _trackEvent(RiviumPushAnalyticsEvent.connectionError, {
            'error_code': error.code,
            'error_message': error.message,
          });
        }
        break;

      case 'onReconnecting':
        print('[RiviumPush] onReconnecting handler - callback set: ${_onReconnecting != null}');
        if (call.arguments is Map) {
          final state = ReconnectionState.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] Reconnection state: $state');
          _onReconnecting?.call(state);
          _trackEvent(RiviumPushAnalyticsEvent.retryStarted, {
            'retry_attempt': state.retryAttempt,
            'next_retry_ms': state.nextRetryMs,
          });
        }
        break;

      case 'onNetworkState':
        print('[RiviumPush] onNetworkState handler - callback set: ${_onNetworkState != null}');
        if (call.arguments is Map) {
          final state = NetworkState.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] Network state: $state');
          _onNetworkState?.call(state);
          _trackEvent(RiviumPushAnalyticsEvent.networkStateChanged, {
            'is_available': state.isAvailable,
            'network_type': state.networkType.name,
          });
        }
        break;

      case 'onAppState':
        print('[RiviumPush] onAppState handler - callback set: ${_onAppState != null}');
        if (call.arguments is Map) {
          final state = AppState.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] App state: $state');
          _onAppState?.call(state);
          _trackEvent(RiviumPushAnalyticsEvent.appStateChanged, {
            'is_in_foreground': state.isInForeground,
          });
        }
        break;

      case 'onAppUpdated':
        print('[RiviumPush] onAppUpdated handler - callback set: ${_onAppUpdated != null}');
        if (call.arguments is Map) {
          final info = AppUpdateInfo.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] App update info: $info');
          _onAppUpdated?.call(info);
          _trackEvent(RiviumPushAnalyticsEvent.appUpdated, {
            'previous_version': info.previousVersion,
            'current_version': info.currentVersion,
            'needs_reregistration': info.needsReregistration,
          });
        }
        break;

      // In-App Message handlers
      case 'onInAppMessageReady':
        print('[RiviumPush] onInAppMessageReady handler - callback set: ${_onInAppMessageReady != null}');
        if (call.arguments is Map) {
          final message = InAppMessage.fromMap(
            Map<String, dynamic>.from(call.arguments as Map),
          );
          print('[RiviumPush] In-app message ready: ${message.name}');
          _onInAppMessageReady?.call(message);
          _trackEvent(RiviumPushAnalyticsEvent.inAppMessageDisplayed, {
            'message_id': message.id,
            'message_name': message.name,
            'type': message.type.value,
          });
        }
        break;

      case 'onInAppButtonClick':
        print('[RiviumPush] onInAppButtonClick handler - callback set: ${_onInAppButtonClick != null}');
        if (call.arguments is Map) {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final message = InAppMessage.fromMap(
            Map<String, dynamic>.from(args['message']),
          );
          final button = InAppButton.fromMap(
            Map<String, dynamic>.from(args['button']),
          );
          print('[RiviumPush] In-app button clicked: ${button.text}');
          _onInAppButtonClick?.call(message, button);
          _trackEvent(RiviumPushAnalyticsEvent.inAppButtonClicked, {
            'message_id': message.id,
            'button_id': button.id,
            'button_action': button.action.value,
          });
        }
        break;

      case 'onInAppMessageDismissed':
        print('[RiviumPush] onInAppMessageDismissed handler - callback set: ${_onInAppMessageDismissed != null}');
        if (call.arguments is Map) {
          final message = InAppMessage.fromMap(
            Map<String, dynamic>.from(call.arguments as Map),
          );
          print('[RiviumPush] In-app message dismissed: ${message.name}');
          _onInAppMessageDismissed?.call(message);
          _trackEvent(RiviumPushAnalyticsEvent.inAppMessageDismissed, {
            'message_id': message.id,
            'message_name': message.name,
          });
        }
        break;

      case 'onNotificationAction':
        print('[RiviumPush] onNotificationAction handler - callback set: ${_onNotificationAction != null}');
        if (call.arguments is Map) {
          final event = NotificationActionEvent.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] Notification action tapped: ${event.actionId}');
          _onNotificationAction?.call(event);
        }
        break;

      // A/B Testing handlers
      case 'onABTestVariantAssigned':
        print('[RiviumPush] onABTestVariantAssigned handler - callback set: ${_onABTestVariantAssigned != null}');
        if (call.arguments is Map) {
          final variant = ABTestVariant.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] A/B test variant assigned: ${variant.variantName}');
          _onABTestVariantAssigned?.call(variant);
          _trackEvent(RiviumPushAnalyticsEvent.abTestVariantAssigned, {
            'test_id': variant.testId,
            'variant_id': variant.variantId,
            'variant_name': variant.variantName,
          });
        }
        break;

      case 'onABTestError':
        print('[RiviumPush] onABTestError handler - callback set: ${_onABTestError != null}');
        if (call.arguments is Map) {
          final args = call.arguments as Map<dynamic, dynamic>;
          final testId = args['testId'] as String? ?? '';
          final error = args['error'] as String? ?? 'Unknown error';
          print('[RiviumPush] A/B test error for $testId: $error');
          _onABTestError?.call(testId, error);
        }
        break;

      case 'onNotificationTapped':
        print('[RiviumPush] onNotificationTapped handler - callback set: ${_onNotificationTapped != null}');
        if (_onNotificationTapped != null && call.arguments is Map) {
          final message = RiviumPushMessage.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          print('[RiviumPush] Notification tapped: ${message.title}');
          _onNotificationTapped!(message);
        }
        break;

      // Inbox real-time handlers
      case 'onInboxMessageReceived':
        print('[RiviumPush] onInboxMessageReceived handler');
        if (_onInboxMessage != null && call.arguments is Map) {
          final message = InboxMessage.fromMap(
            Map<String, dynamic>.from(call.arguments as Map),
          );
          _onInboxMessage!(message);
        }
        break;

      case 'onInboxMessageStatusChanged':
        print('[RiviumPush] onInboxMessageStatusChanged handler');
        if (_onInboxMessageStatusChanged != null && call.arguments is Map) {
          final args = call.arguments as Map<dynamic, dynamic>;
          final messageId = args['messageId'] as String? ?? '';
          final statusStr = args['status'] as String? ?? 'unread';
          final status = InboxMessageStatus.values.firstWhere(
            (s) => s.name == statusStr,
            orElse: () => InboxMessageStatus.unread,
          );
          _onInboxMessageStatusChanged!(messageId, status);
        }
        break;

      default:
        print('[RiviumPush] Unknown method: ${call.method}');
    }
  }
}
