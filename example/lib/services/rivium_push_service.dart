import 'package:flutter/foundation.dart';
import 'package:rivium_push/rivium_push.dart';
// VoIP temporarily disabled - pods not publicly available yet
// import 'package:rivium_push_voip/rivium_push_voip.dart';

/// Service class for managing RiviumPush SDK initialization and callbacks.
///
/// This demonstrates the recommended way to integrate RiviumPush in your app.
class RiviumPushService {
  RiviumPushService._();
  static final RiviumPushService instance = RiviumPushService._();

  // ============================================================
  // IMPORTANT: Replace with your actual API key from Rivium Console
  // ============================================================
  // Replace with your API key from Rivium Console (https://console.rivium.co)
  static const String _apiKey = 'rv_live_your_api_key_here';
  // static const String _appName = 'RiviumPush Example';

  // State
  bool _initialized = false;
  bool get isInitialized => _initialized;

  String? _deviceId;
  String? get deviceId => _deviceId;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Callbacks for UI updates
  ValueNotifier<bool> connectionState = ValueNotifier(false);
  ValueNotifier<int> unreadInboxCount = ValueNotifier(0);
  ValueNotifier<RiviumPushMessage?> lastMessage = ValueNotifier(null);
  // VoIP temporarily disabled
  // ValueNotifier<CallData?> incomingCall = ValueNotifier(null);

  // Callback functions that screens can set
  Function(RiviumPushMessage)? onMessageReceived;
  Function(InAppMessage)? onInAppMessageReady;
  Function(InAppMessage, InAppButton)? onInAppButtonClick;
  Function(InboxMessage)? onInboxMessage;
  Function(RiviumPushMessage)? onNotificationTapped;

  // Store pending notification tap if callback isn't set yet
  RiviumPushMessage? _pendingNotificationTap;
  // VoIP temporarily disabled
  // Function(CallData)? onCallAccepted;
  // Function(CallData)? onCallDeclined;

  /// Initialize the RiviumPush SDK with all callbacks
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set log level based on build mode
      if (kReleaseMode) {
        await RiviumPush.setLogLevel(RiviumPushLogLevel.error);
      } else {
        await RiviumPush.setLogLevel(RiviumPushLogLevel.debug);
      }

      // Initialize RiviumPush with config
      // Note: usePushKit must be false for iOS simulator testing
      // (VoIP/PushKit doesn't work on simulator)
      await RiviumPush.init(
        const RiviumPushConfig(
          apiKey: _apiKey,
          notificationIcon: 'ic_notification',
          showServiceNotification: false,
          showNotificationInForeground: true,
          usePushKit: false, // Disable VoIP for simulator compatibility
        ),
      );

      // Setup all callbacks
      _setupCallbacks();

      // Setup analytics handler
      _setupAnalytics();

      // VoIP temporarily disabled
      // await _initializeVoIP();

      _initialized = true;
      debugPrint('[RiviumPushService] Initialized successfully');

      // Auto-register device for push notifications
      debugPrint('[RiviumPushService] Registering device...');
      await register();
      debugPrint('[RiviumPushService] Device registration initiated');
    } catch (e, stackTrace) {
      debugPrint('[RiviumPushService] Initialization error: $e');
      debugPrint('[RiviumPushService] Stack trace: $stackTrace');
      // Don't rethrow - allow app to run even if SDK init fails
    }
  }

  /// Setup all RiviumPush callbacks
  void _setupCallbacks() {
    // ==================== Connection Callbacks ====================

    RiviumPush.onConnectionState((connected) {
      debugPrint('[RiviumPushService] Connection state: $connected');
      _isConnected = connected;
      connectionState.value = connected;
    });

    RiviumPush.onRegistered((deviceId) {
      debugPrint('[RiviumPushService] Registered with device ID: $deviceId');
      _deviceId = deviceId;
    });

    RiviumPush.onError((error) {
      debugPrint('[RiviumPushService] Error: $error');
    });

    RiviumPush.onDetailedError((error) {
      debugPrint(
        '[RiviumPushService] Detailed error: ${error.code} - ${error.message}',
      );
    });

    RiviumPush.onReconnecting((state) {
      debugPrint(
        '[RiviumPushService] Reconnecting: attempt ${state.retryAttempt}, next in ${state.nextRetryMs}ms',
      );
    });

    RiviumPush.onNetworkState((state) {
      debugPrint(
        '[RiviumPushService] Network: ${state.isAvailable ? "available" : "unavailable"} (${state.networkType.name})',
      );
    });

    RiviumPush.onAppState((state) {
      debugPrint(
        '[RiviumPushService] App state: ${state.isInForeground ? "foreground" : "background"}',
      );
    });

    RiviumPush.onAppUpdated((info) {
      debugPrint(
        '[RiviumPushService] App updated from ${info.previousVersion} to ${info.currentVersion}',
      );
      if (info.needsReregistration) {
        // Re-register device after app update
        register();
      }
    });

    // ==================== Message Callbacks ====================

    RiviumPush.onMessage((message) {
      debugPrint('[RiviumPushService] Message received: ${message.title}');
      lastMessage.value = message;
      onMessageReceived?.call(message);
    });

    RiviumPush.onNotificationAction((event) {
      debugPrint('[RiviumPushService] Notification action: ${event.actionId}');
      // Handle notification action button taps
      _handleNotificationAction(event);
    });

    RiviumPush.onNotificationTapped((message) {
      debugPrint('[RiviumPushService] Notification tapped: ${message.title}');
      debugPrint(
          '[RiviumPushService] onNotificationTapped callback is: ${onNotificationTapped != null ? "SET" : "NULL"}');
      // Notify the UI about the tapped notification
      if (onNotificationTapped != null) {
        debugPrint(
            '[RiviumPushService] Calling onNotificationTapped callback...');
        onNotificationTapped!(message);
        debugPrint(
            '[RiviumPushService] onNotificationTapped callback completed');
      } else {
        debugPrint(
            '[RiviumPushService] WARNING: No onNotificationTapped callback registered! Storing as pending...');
        _pendingNotificationTap = message;
      }
    });

    // ==================== In-App Message Callbacks ====================

    RiviumPush.onInAppMessageReady((message) {
      debugPrint('[RiviumPushService] In-app message ready: ${message.name}');
      onInAppMessageReady?.call(message);
    });

    RiviumPush.onInAppButtonClick((message, button) {
      debugPrint('[RiviumPushService] In-app button clicked: ${button.text}');
      onInAppButtonClick?.call(message, button);
    });

    RiviumPush.onInAppMessageDismissed((message) {
      debugPrint(
          '[RiviumPushService] In-app message dismissed: ${message.name}');
    });

    // ==================== Inbox Callbacks ====================

    RiviumPush.onInboxMessage((message) {
      debugPrint(
        '[RiviumPushService] New inbox message: ${message.content.title}',
      );
      onInboxMessage?.call(message);
      _refreshUnreadCount();
    });

    RiviumPush.onInboxMessageStatusChanged((messageId, status) {
      debugPrint(
        '[RiviumPushService] Inbox message $messageId status changed to: $status',
      );
      _refreshUnreadCount();
    });

    // ==================== A/B Testing Callbacks ====================

    RiviumPush.onABTestVariantAssigned((variant) {
      debugPrint(
        '[RiviumPushService] A/B test variant assigned: ${variant.variantName} for test ${variant.testId}',
      );
    });

    RiviumPush.onABTestError((testId, error) {
      debugPrint('[RiviumPushService] A/B test error for $testId: $error');
    });
  }

  /// Setup analytics handler
  void _setupAnalytics() {
    RiviumPush.setAnalyticsHandler((event, properties) {
      debugPrint('[RiviumPushService] Analytics: ${event.name} - $properties');

      // TODO: Send to your analytics service (rivium trace, Firebase, Mixpanel, etc.)
      // Example:
      // FirebaseAnalytics.instance.logEvent(
      //   name: 'rivium_push_${event.name}',
      //   parameters: properties,
      // );
    });
  }

  // VoIP temporarily disabled
  // /// Initialize VoIP plugin
  // Future<void> _initializeVoIP() async { ... }

  /// Handle notification action button taps
  void _handleNotificationAction(NotificationActionEvent event) {
    switch (event.actionId) {
      case 'view':
        debugPrint('User tapped View action');
        // Navigate to content
        break;
      case 'dismiss':
        debugPrint('User tapped Dismiss action');
        break;
      case 'reply':
        debugPrint('User tapped Reply action');
        // Show reply input
        break;
      default:
        debugPrint('Unknown action: ${event.actionId}');
    }
  }

  /// Refresh unread inbox count
  Future<void> _refreshUnreadCount() async {
    final count = await RiviumPush.getInboxUnreadCount();
    unreadInboxCount.value = count;
  }

  // ==================== Public Methods ====================

  /// Set the notification tapped callback and check for pending taps
  void setNotificationTappedCallback(Function(RiviumPushMessage)? callback) {
    debugPrint(
        '[RiviumPushService] setNotificationTappedCallback called, callback is ${callback != null ? "SET" : "NULL"}');
    onNotificationTapped = callback;

    // Check for pending notification tap
    if (callback != null && _pendingNotificationTap != null) {
      debugPrint(
          '[RiviumPushService] Found pending notification tap, delivering now: ${_pendingNotificationTap!.title}');
      final pending = _pendingNotificationTap!;
      _pendingNotificationTap = null;
      callback(pending);
    }
  }

  /// Get pending notification tap (for cold start scenarios)
  RiviumPushMessage? getPendingNotificationTap() {
    final pending = _pendingNotificationTap;
    _pendingNotificationTap = null;
    return pending;
  }

  /// Register device for push notifications
  Future<void> register({String? userId, Map<String, String>? metadata}) async {
    await RiviumPush.register(userId: userId, metadata: metadata);
    _deviceId = await RiviumPush.getDeviceId();
  }

  /// Unregister device
  Future<void> unregister() async {
    await RiviumPush.unregister();
    _deviceId = null;
  }

  /// Set user ID (after login)
  Future<void> setUserId(String userId) async {
    await RiviumPush.setUserId(userId);
  }

  /// Clear user ID (after logout)
  Future<void> clearUserId() async {
    await RiviumPush.clearUserId();
  }

  /// Subscribe to a topic
  Future<void> subscribeTopic(String topic) async {
    await RiviumPush.subscribeTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeTopic(String topic) async {
    await RiviumPush.unsubscribeTopic(topic);
  }

  /// Check connection status
  Future<bool> checkConnection() async {
    return await RiviumPush.isConnected();
  }

  /// Get device ID
  Future<String?> getDeviceId() async {
    return await RiviumPush.getDeviceId();
  }

  // ==================== In-App Messages ====================

  /// Fetch in-app messages
  Future<List<InAppMessage>> fetchInAppMessages() async {
    return await RiviumPush.fetchInAppMessages();
  }

  /// Trigger in-app on app open
  Future<void> triggerInAppOnAppOpen() async {
    await RiviumPush.triggerInAppOnAppOpen();
  }

  /// Trigger custom event
  Future<void> triggerInAppEvent(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    await RiviumPush.triggerInAppEvent(eventName, properties: properties);
  }

  /// Show specific in-app message
  Future<void> showInAppMessage(String messageId) async {
    await RiviumPush.showInAppMessage(messageId);
  }

  /// Dismiss current in-app message
  Future<void> dismissInAppMessage() async {
    await RiviumPush.dismissInAppMessage();
  }

  // ==================== Inbox ====================

  /// Get inbox messages
  Future<InboxMessagesResponse> getInboxMessages({
    InboxMessageStatus? status,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    return await RiviumPush.getInboxMessages(
      status: status,
      category: category,
      limit: limit,
      offset: offset,
    );
  }

  /// Mark inbox message as read
  Future<void> markInboxMessageAsRead(String messageId) async {
    await RiviumPush.markInboxMessageAsRead(messageId);
    await _refreshUnreadCount();
  }

  /// Archive inbox message
  Future<void> archiveInboxMessage(String messageId) async {
    await RiviumPush.archiveInboxMessage(messageId);
  }

  /// Delete inbox message
  Future<void> deleteInboxMessage(String messageId) async {
    await RiviumPush.deleteInboxMessage(messageId);
  }

  /// Mark all as read
  Future<void> markAllInboxMessagesAsRead() async {
    await RiviumPush.markAllInboxMessagesAsRead();
    await _refreshUnreadCount();
  }

  /// Get unread count
  Future<int> getInboxUnreadCount() async {
    final count = await RiviumPush.getInboxUnreadCount();
    unreadInboxCount.value = count;
    return count;
  }

  // ==================== A/B Testing ====================

  /// Get active A/B tests
  Future<List<ABTestSummary>> getActiveABTests() async {
    return await RiviumPush.getActiveABTests();
  }

  /// Get A/B test variant
  Future<ABTestVariant?> getABTestVariant(
    String testId, {
    bool forceRefresh = false,
  }) async {
    return await RiviumPush.getABTestVariant(testId,
        forceRefresh: forceRefresh);
  }

  /// Track A/B test impression
  Future<void> trackABTestImpression(String testId, String variantId) async {
    await RiviumPush.trackABTestImpression(testId, variantId);
  }

  /// Track A/B test click
  Future<void> trackABTestClicked(String testId, String variantId) async {
    await RiviumPush.trackABTestClicked(testId, variantId);
  }

  // ==================== VoIP ====================
  // VoIP temporarily disabled - pods not publicly available yet
  // Future<void> endCall(String callId) async { ... }
  // Future<void> reportCallConnected(String callId) async { ... }
  // Future<void> showIncomingCall(CallData callData) async { ... }
}
