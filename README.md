# RiviumPush Flutter SDK

Real-time push notifications, in-app messages, inbox, A/B testing, and more for Flutter apps. No Firebase dependency.

## Features

- Push Notifications (Android & iOS)
- In-App Messages (modal, banner, fullscreen)
- Inbox (persistent message center with read/archive)
- A/B Testing (experiments and variant assignment)
- Topic Subscriptions
- Silent Messages
- Notification Tap Handling
- Analytics Tracking
- Auto-reconnection with exponential backoff

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  rivium_push: ^0.1.2
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize

```dart
import 'package:rivium_push/rivium_push.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RiviumPush.init(RiviumPushConfig(
    apiKey: 'rv_live_your_api_key',  // Get from Rivium Console
  ));

  runApp(MyApp());
}
```

### 2. Register & Listen

```dart
@override
void initState() {
  super.initState();

  // Listen for messages
  RiviumPush.onMessage((message) {
    print('Title: ${message.title}');
    print('Body: ${message.body}');
    print('Data: ${message.data}');
  });

  // Connection status
  RiviumPush.onConnectionState((connected) {
    print(connected ? 'Connected' : 'Disconnected');
  });

  // Register device
  RiviumPush.register(userId: 'user_123');
}
```

### 3. Done!

Your app now receives push notifications.

## Platform Setup

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### iOS

Enable in Xcode -> Signing & Capabilities:
- Push Notifications
- Background Modes -> Remote notifications

## Configuration

```dart
await RiviumPush.init(RiviumPushConfig(
  apiKey: 'rv_live_...',              // Required - from Rivium Console
  notificationIcon: 'ic_notification', // Optional - Android notification icon
  usePushKit: false,                   // Optional - iOS VoIP mode for calling apps
  showServiceNotification: true,       // Optional - foreground service notification (Android)
  showNotificationInForeground: true,  // Optional - show notifications when app is in foreground
));
```

> **Note:** Connection configuration is automatically fetched from the server using your API key. No manual setup needed.

## Callbacks

```dart
// Receive push messages
RiviumPush.onMessage((RiviumPushMessage message) {
  print('${message.title}: ${message.body}');
  print('Data: ${message.data}');
  print('Silent: ${message.silent}');
});

// Connection status
RiviumPush.onConnectionState((bool connected) {});

// Registration complete
RiviumPush.onRegistered((String deviceId) {});

// Notification tapped (while app is running)
RiviumPush.onNotificationTapped((RiviumPushMessage message) {});

// Errors
RiviumPush.onError((String error) {});

// Detailed errors with error codes
RiviumPush.onDetailedError((RiviumPushError error) {
  print('Code: ${error.code}, Message: ${error.message}');
});

// Reconnection attempts
RiviumPush.onReconnecting((state) {
  print('Attempt ${state.retryAttempt}, next in ${state.nextRetryMs}ms');
});

// Network state changes
RiviumPush.onNetworkState((state) {
  print('Network: ${state.isAvailable ? "available" : "unavailable"}');
});

// App foreground/background
RiviumPush.onAppState((state) {
  print('Foreground: ${state.isInForeground}');
});
```

## Notification Tap Handling

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiviumPush.init(config);

  // Check if app was launched by tapping a notification
  final initialMessage = await RiviumPush.getInitialMessage();
  if (initialMessage != null) {
    runApp(MyApp(initialRoute: getRouteFromMessage(initialMessage)));
  } else {
    runApp(MyApp());
  }
}
```

## Topics

```dart
// Subscribe to topic
await RiviumPush.subscribeTopic('news');
await RiviumPush.subscribeTopic('promotions');

// Unsubscribe
await RiviumPush.unsubscribeTopic('promotions');
```

## User Management

```dart
// Set user ID after login
await RiviumPush.setUserId('user_123');

// Clear user ID on logout
await RiviumPush.clearUserId();

// Register with user ID and metadata
await RiviumPush.register(
  userId: 'user_123',
  metadata: {'appVersion': '1.0.0', 'language': 'en'},
);
```

## In-App Messages

```dart
// Trigger in-app messages on app open
await RiviumPush.triggerInAppOnAppOpen();

// Trigger custom event
await RiviumPush.triggerInAppEvent('purchase_complete', properties: {
  'amount': 29.99,
});

// Listen for in-app messages
RiviumPush.onInAppMessageReady((message) {
  print('In-app message: ${message.name}');
});

RiviumPush.onInAppButtonClick((message, button) {
  print('Button clicked: ${button.text}');
});
```

## Inbox

```dart
// Get inbox messages
final response = await RiviumPush.getInboxMessages(
  status: InboxMessageStatus.unread,
  limit: 50,
);

// Mark as read
await RiviumPush.markInboxMessageAsRead(messageId);

// Archive
await RiviumPush.archiveInboxMessage(messageId);

// Get unread count
final count = await RiviumPush.getInboxUnreadCount();

// Listen for new inbox messages
RiviumPush.onInboxMessage((message) {
  print('New inbox message: ${message.content.title}');
});
```

## A/B Testing

```dart
// Get active tests
final tests = await RiviumPush.getActiveABTests();

// Get variant for a test
final variant = await RiviumPush.getABTestVariant('test_id');
if (variant != null) {
  print('Variant: ${variant.variantName}');
  print('Content: ${variant.content}');
}

// Track events
await RiviumPush.trackABTestImpression('test_id', 'variant_id');
await RiviumPush.trackABTestClicked('test_id', 'variant_id');

// Listen for variant assignments
RiviumPush.onABTestVariantAssigned((variant) {
  print('Assigned to: ${variant.variantName}');
});
```

## Analytics Tracking

Track SDK events for your analytics service:

```dart
RiviumPush.setAnalyticsHandler((event, properties) {
  // Send to your analytics service
  FirebaseAnalytics.instance.logEvent(
    name: 'rivium_push_${event.name}',
    parameters: properties,
  );
});
```

## Log Levels

```dart
import 'package:flutter/foundation.dart';

if (kReleaseMode) {
  await RiviumPush.setLogLevel(RiviumPushLogLevel.error);
} else {
  await RiviumPush.setLogLevel(RiviumPushLogLevel.debug);
}

// Available: none, error, warning, info, debug, verbose
```

## Utilities

```dart
final connected = await RiviumPush.isConnected();
final deviceId = await RiviumPush.getDeviceId();
await RiviumPush.unregister();
```

## Example

See the [example](example/) directory for a complete working app with all features demonstrated.

## VoIP Calls (Optional)

For apps with calling features, add the [rivium_push_voip](https://pub.dev/packages/rivium_push_voip) plugin for native incoming call UI:

```yaml
dependencies:
  rivium_push: ^0.1.2
  rivium_push_voip: ^0.1.0  # Optional - for calling apps
```

```dart
// Initialize VoIP after RiviumPush
await RiviumPushVoIP.init(
  config: RiviumPushVoIPConfig(appName: 'MyApp'),
  onCallAccepted: (callData) => navigateToCallScreen(callData),
  onCallDeclined: (callData) => notifyCallDeclined(callData.callId),
);

// Set API key for VoIP token registration
final deviceId = await RiviumPush.getDeviceId();
await RiviumPushVoIP.setApiKey(apiKey: 'rv_live_...', deviceId: deviceId);
```

To trigger an incoming call, send a push with `type: "voip_call"` in the data:

```json
{
  "title": "Incoming Call",
  "body": "John Doe is calling",
  "data": {
    "type": "voip_call",
    "callerName": "John Doe",
    "callerId": "user_456",
    "callerAvatar": "https://example.com/avatar.jpg",
    "callType": "video"
  }
}
```

The `type: "voip_call"` triggers VoIP delivery (PushKit on iOS, high-priority on Android). Without it, the message is delivered as a regular push notification. See the [rivium_push_voip README](https://pub.dev/packages/rivium_push_voip) for full setup guide.

## Links

- [Rivium Push](https://rivium.co/cloud/rivium-push) - Learn more about Rivium Push
- [Documentation](https://rivium.co/cloud/rivium-push/docs/quick-start) - Full documentation and guides
- [Rivium Console](https://console.rivium.co) - Manage your push notifications

## License

MIT License - see [LICENSE](LICENSE) for details.
