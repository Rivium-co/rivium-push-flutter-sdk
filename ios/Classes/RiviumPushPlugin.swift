import Flutter
import UIKit
import UserNotifications
import RiviumPushSDK

/// Flutter plugin that wraps the native RiviumPush iOS SDK
/// This is similar to how the Android plugin wraps the AAR
public class RiviumPushPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private static var instance: RiviumPushPlugin?
    private var showNotificationInForeground: Bool = true

    // Queue for messages that arrive when Flutter is not attached
    private static var pendingMessages: [(String, Any?)] = []
    private static let pendingMessagesLock = NSLock()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "co.rivium.push/main", binaryMessenger: registrar.messenger())
        let instance = RiviumPushPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        RiviumPushPlugin.instance = instance

        // Set up delegate to receive callbacks from native SDK
        RiviumPush.shared.delegate = instance

        // Deliver any pending messages
        instance.deliverPendingMessages()

        Log.d("Plugin", "Flutter plugin registered")
    }

    // MARK: - APNs Token Forwarding
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        RiviumPush.shared.setAPNsToken(deviceToken)
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Log.d("Plugin", "APNs token forwarded: \(String(token.prefix(20)))...")
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.d("Plugin", "APNs registration failed: \(error.localizedDescription)")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // MARK: - Core Methods
        case "init":
            handleInit(call: call, result: result)

        case "register":
            handleRegister(call: call, result: result)

        case "unregister":
            RiviumPush.shared.unregister()
            result(nil)

        case "isConnected":
            result(RiviumPush.shared.isConnected)

        case "getDeviceId":
            result(RiviumPush.shared.getDeviceId())

        case "setLogLevel":
            if let args = call.arguments as? [String: Any],
               let level = args["level"] as? String {
                RiviumPush.shared.setLogLevel(RiviumPushLogLevel.fromString(level))
            }
            result(nil)

        // MARK: - Topic Subscriptions
        case "subscribeTopic":
            if let args = call.arguments as? [String: Any],
               let topic = args["topic"] as? String {
                RiviumPush.shared.subscribeTopic(topic)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Topic is required", details: nil))
            }

        case "unsubscribeTopic":
            if let args = call.arguments as? [String: Any],
               let topic = args["topic"] as? String {
                RiviumPush.shared.unsubscribeTopic(topic)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Topic is required", details: nil))
            }

        // MARK: - User Management
        case "setUserId":
            if let args = call.arguments as? [String: Any],
               let userId = args["userId"] as? String {
                RiviumPush.shared.setUserId(userId)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "User ID is required", details: nil))
            }

        case "clearUserId":
            RiviumPush.shared.clearUserId()
            result(nil)

        // MARK: - Initial Message
        case "getInitialMessage":
            if let message = RiviumPush.shared.getInitialMessage() {
                RiviumPush.shared.clearInitialMessage()
                result(message.toDictionary())
            } else {
                result(nil)
            }

        // MARK: - In-App Messages
        case "fetchInAppMessages":
            RiviumPush.shared.fetchInAppMessages { messages in
                result(messages.map { $0.toDictionary() })
            }

        case "triggerInAppOnAppOpen":
            RiviumPush.shared.triggerInAppOnAppOpen()
            result(nil)

        case "triggerInAppEvent":
            if let args = call.arguments as? [String: Any],
               let eventName = args["eventName"] as? String {
                let properties = args["properties"] as? [String: Any]
                RiviumPush.shared.triggerInAppEvent(eventName, properties: properties)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Event name is required", details: nil))
            }

        case "triggerInAppOnSessionStart":
            RiviumPush.shared.triggerInAppOnSessionStart()
            result(nil)

        case "showInAppMessage":
            if let args = call.arguments as? [String: Any],
               let messageId = args["messageId"] as? String {
                RiviumPush.shared.showInAppMessage(messageId)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Message ID is required", details: nil))
            }

        case "dismissInAppMessage":
            RiviumPush.shared.dismissInAppMessage()
            result(nil)

        // MARK: - Inbox
        case "getInboxMessages":
            handleGetInboxMessages(call: call, result: result)

        case "getInboxMessage":
            handleGetInboxMessage(call: call, result: result)

        case "markInboxMessageAsRead":
            handleMarkInboxMessageAsRead(call: call, result: result)

        case "archiveInboxMessage":
            handleArchiveInboxMessage(call: call, result: result)

        case "deleteInboxMessage":
            handleDeleteInboxMessage(call: call, result: result)

        case "markMultipleInboxMessages":
            handleMarkMultipleInboxMessages(call: call, result: result)

        case "markAllInboxMessagesAsRead":
            RiviumPush.shared.markAllInboxMessagesAsRead(
                onSuccess: { result(nil) },
                onError: { error in result(FlutterError(code: "ERROR", message: error, details: nil)) }
            )

        case "getInboxUnreadCount":
            result(RiviumPush.shared.getInboxUnreadCount())

        case "fetchInboxUnreadCount":
            RiviumPush.shared.fetchInboxUnreadCount(
                onSuccess: { count in result(count) },
                onError: { error in result(FlutterError(code: "ERROR", message: error, details: nil)) }
            )

        case "getCachedInboxMessages":
            result(RiviumPush.shared.getCachedInboxMessages().map { $0.toDictionary() })

        case "clearInboxCache":
            RiviumPush.shared.clearInboxCache()
            result(nil)

        // MARK: - A/B Testing
        case "getActiveABTests":
            RiviumPush.shared.getActiveABTests { testResult in
                switch testResult {
                case .success(let tests):
                    result(tests.map { $0.toDictionary() })
                case .failure(let error):
                    result(FlutterError(code: "ABTEST_ERROR", message: error.localizedDescription, details: nil))
                }
            }

        case "getABTestVariant":
            if let args = call.arguments as? [String: Any],
               let testId = args["testId"] as? String {
                let forceRefresh = args["forceRefresh"] as? Bool ?? false
                RiviumPush.shared.getABTestVariant(testId: testId, forceRefresh: forceRefresh) { variantResult in
                    switch variantResult {
                    case .success(let variant):
                        result(variant.toDictionary())
                    case .failure(let error):
                        result(FlutterError(code: "ABTEST_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Test ID is required", details: nil))
            }

        case "getCachedABTestVariant":
            if let args = call.arguments as? [String: Any],
               let testId = args["testId"] as? String {
                let variant = RiviumPush.shared.getCachedABTestVariant(testId: testId)
                result(variant?.toDictionary())
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Test ID is required", details: nil))
            }

        case "trackABTestImpression":
            if let args = call.arguments as? [String: Any],
               let testId = args["testId"] as? String,
               let variantId = args["variantId"] as? String {
                RiviumPush.shared.trackABTestImpression(testId: testId, variantId: variantId) { trackResult in
                    switch trackResult {
                    case .success:
                        result(nil)
                    case .failure(let error):
                        result(FlutterError(code: "ABTEST_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Test ID and Variant ID are required", details: nil))
            }

        case "trackABTestOpened":
            if let args = call.arguments as? [String: Any],
               let testId = args["testId"] as? String,
               let variantId = args["variantId"] as? String {
                RiviumPush.shared.trackABTestOpened(testId: testId, variantId: variantId) { trackResult in
                    switch trackResult {
                    case .success:
                        result(nil)
                    case .failure(let error):
                        result(FlutterError(code: "ABTEST_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Test ID and Variant ID are required", details: nil))
            }

        case "trackABTestClicked":
            if let args = call.arguments as? [String: Any],
               let testId = args["testId"] as? String,
               let variantId = args["variantId"] as? String {
                RiviumPush.shared.trackABTestClicked(testId: testId, variantId: variantId) { trackResult in
                    switch trackResult {
                    case .success:
                        result(nil)
                    case .failure(let error):
                        result(FlutterError(code: "ABTEST_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Test ID and Variant ID are required", details: nil))
            }

        case "trackABTestDisplay":
            if let args = call.arguments as? [String: Any],
               let testId = args["testId"] as? String,
               let variantId = args["variantId"] as? String {
                // Create a minimal variant for tracking
                let variant = ABTestVariant(testId: testId, variantId: variantId, variantName: "", content: nil)
                RiviumPush.shared.trackABTestDisplay(variant: variant) { trackResult in
                    switch trackResult {
                    case .success:
                        result(nil)
                    case .failure(let error):
                        result(FlutterError(code: "ABTEST_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Test ID and Variant ID are required", details: nil))
            }

        case "clearABTestCache":
            RiviumPush.shared.clearABTestCache()
            result(nil)

        // Log level
        case "getLogLevel":
            result(nil) // iOS doesn't expose log level as a string getter

        // Badge management
        case "getBadgeCount":
            result(UIApplication.shared.applicationIconBadgeNumber)
        case "setBadgeCount":
            if let badgeArgs = call.arguments as? [String: Any],
               let count = badgeArgs["count"] as? Int {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
            result(nil)
        case "clearBadge":
            UIApplication.shared.applicationIconBadgeNumber = 0
            result(nil)
        case "incrementBadge":
            UIApplication.shared.applicationIconBadgeNumber += 1
            result(nil)
        case "decrementBadge":
            let current = UIApplication.shared.applicationIconBadgeNumber
            UIApplication.shared.applicationIconBadgeNumber = max(0, current - 1)
            result(nil)

        // State getters
        case "getNetworkState":
            result(["isAvailable": true, "networkType": "unknown"])
        case "getAppState":
            let foreground = UIApplication.shared.applicationState == .active
            result(["isInForeground": foreground])

        // Service notification (Android-only, no-op on iOS)
        case "isServiceNotificationHidden":
            result(true)
        case "openServiceNotificationSettings":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Handler Methods

    private func handleInit(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments required", details: nil))
            return
        }

        let config = RiviumPushConfig(
            apiKey: args["apiKey"] as? String ?? "",
            pnHost: args["pnHost"] as? String ?? args["mqttHost"] as? String ?? "",
            pnPort: UInt16(args["pnPort"] as? Int ?? args["mqttPort"] as? Int ?? 1883),
            pnToken: args["pnToken"] as? String ?? args["mqttPassword"] as? String,
            usePushKit: args["usePushKit"] as? Bool ?? false,
            showNotificationInForeground: args["showNotificationInForeground"] as? Bool ?? true,
            autoConnect: args["autoConnect"] as? Bool ?? true
        )

        RiviumPush.shared.initialize(config: config)
        self.showNotificationInForeground = args["showNotificationInForeground"] as? Bool ?? true

        // Set notification center delegate for foreground notification display
        UNUserNotificationCenter.current().delegate = self

        // Request notification permission and register for APNs
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }

        // Set up callbacks after SDK is initialized (slight delay to ensure SDK is ready)
        DispatchQueue.main.async {
            RiviumPush.shared.setInboxCallback(self)
            RiviumPush.shared.setInAppMessageCallback(self)
            RiviumPush.shared.setABTestingDelegate(self)
        }

        result(nil)
    }

    private func handleRegister(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let userId = args?["userId"] as? String
        let metadata = args?["metadata"] as? [String: String]

        RiviumPush.shared.register(userId: userId, metadata: metadata)
        result(nil)
    }

    private func handleGetInboxMessages(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        var filter = InboxFilter()

        if let filterArgs = args?["filter"] as? [String: Any] {
            filter = InboxFilter(
                status: filterArgs["status"] != nil ? InboxMessageStatus.fromString(filterArgs["status"] as! String) : nil,
                category: filterArgs["category"] as? String,
                limit: filterArgs["limit"] as? Int ?? 50,
                offset: filterArgs["offset"] as? Int ?? 0
            )
        }

        RiviumPush.shared.getInboxMessages(
            filter: filter,
            onSuccess: { response in
                result(response.toDictionary())
            },
            onError: { error in
                result(FlutterError(code: "ERROR", message: error, details: nil))
            }
        )
    }

    private func handleGetInboxMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let messageId = args["messageId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Message ID is required", details: nil))
            return
        }

        RiviumPush.shared.getInboxMessage(
            messageId: messageId,
            onSuccess: { message in result(message.toDictionary()) },
            onError: { error in result(FlutterError(code: "ERROR", message: error, details: nil)) }
        )
    }

    private func handleMarkInboxMessageAsRead(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let messageId = args["messageId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Message ID is required", details: nil))
            return
        }

        RiviumPush.shared.markInboxMessageAsRead(
            messageId: messageId,
            onSuccess: { result(nil) },
            onError: { error in result(FlutterError(code: "ERROR", message: error, details: nil)) }
        )
    }

    private func handleArchiveInboxMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let messageId = args["messageId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Message ID is required", details: nil))
            return
        }

        RiviumPush.shared.archiveInboxMessage(
            messageId: messageId,
            onSuccess: { result(nil) },
            onError: { error in result(FlutterError(code: "ERROR", message: error, details: nil)) }
        )
    }

    private func handleDeleteInboxMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let messageId = args["messageId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Message ID is required", details: nil))
            return
        }

        RiviumPush.shared.deleteInboxMessage(
            messageId: messageId,
            onSuccess: { result(nil) },
            onError: { error in result(FlutterError(code: "ERROR", message: error, details: nil)) }
        )
    }

    private func handleMarkMultipleInboxMessages(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let messageIds = args["messageIds"] as? [String],
              let statusStr = args["status"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Message IDs and status are required", details: nil))
            return
        }

        RiviumPush.shared.markMultipleInboxMessages(
            messageIds: messageIds,
            status: InboxMessageStatus.fromString(statusStr),
            onSuccess: { result(nil) },
            onError: { error in result(FlutterError(code: "ERROR", message: error, details: nil)) }
        )
    }

    // MARK: - Flutter Method Invocation

    private func invokeMethod(_ method: String, arguments: Any?) {
        NSLog("[RiviumPush.Plugin] invokeMethod called: %@, isMainThread: %d", method, Thread.isMainThread ? 1 : 0)
        DispatchQueue.main.async {
            NSLog("[RiviumPush.Plugin] Inside main thread dispatch for: %@", method)
            if let channel = self.channel {
                NSLog("[RiviumPush.Plugin] Channel exists, invoking method: %@", method)
                channel.invokeMethod(method, arguments: arguments)
                NSLog("[RiviumPush.Plugin] Method invoked on channel: %@", method)
            } else {
                // Queue the message for later delivery
                NSLog("[RiviumPush.Plugin] Channel is nil! Queueing method: %@", method)
                RiviumPushPlugin.pendingMessagesLock.lock()
                RiviumPushPlugin.pendingMessages.append((method, arguments))
                RiviumPushPlugin.pendingMessagesLock.unlock()
            }
        }
    }

    private func deliverPendingMessages() {
        RiviumPushPlugin.pendingMessagesLock.lock()
        defer { RiviumPushPlugin.pendingMessagesLock.unlock() }

        guard !RiviumPushPlugin.pendingMessages.isEmpty else { return }

        let messages = RiviumPushPlugin.pendingMessages
        RiviumPushPlugin.pendingMessages.removeAll()

        DispatchQueue.main.async {
            for (method, arguments) in messages {
                self.channel?.invokeMethod(method, arguments: arguments)
            }
        }
    }
}

// MARK: - RiviumPushDelegate
extension RiviumPushPlugin: RiviumPushDelegate {
    public func riviumPush(_ riviumPush: RiviumPush, didReceiveMessage message: RiviumPushMessage) {
        invokeMethod("onMessage", arguments: message.toDictionary())
    }

    public func riviumPush(_ riviumPush: RiviumPush, didChangeConnectionState connected: Bool) {
        invokeMethod("onConnectionState", arguments: connected)
    }

    public func riviumPush(_ riviumPush: RiviumPush, didRegisterWithDeviceId deviceId: String) {
        invokeMethod("onRegistered", arguments: deviceId)
    }

    public func riviumPush(_ riviumPush: RiviumPush, didReceiveVoIPToken token: String) {
        // Internal - not exposed to Flutter
    }

    public func riviumPush(_ riviumPush: RiviumPush, didFailWithError error: Error) {
        invokeMethod("onError", arguments: error.localizedDescription)
    }

    public func riviumPush(_ riviumPush: RiviumPush, didFailWithDetailedError error: RiviumPushError) {
        invokeMethod("onDetailedError", arguments: error.toDictionary())
    }

    public func riviumPush(_ riviumPush: RiviumPush, didStartReconnecting state: ReconnectionState) {
        invokeMethod("onReconnecting", arguments: state.toDictionary())
    }

    public func riviumPush(_ riviumPush: RiviumPush, didChangeNetworkState state: NetworkState) {
        invokeMethod("onNetworkState", arguments: state.toDictionary())
    }

    public func riviumPush(_ riviumPush: RiviumPush, didChangeAppState state: AppState) {
        invokeMethod("onAppState", arguments: state.toDictionary())
    }

    public func riviumPush(_ riviumPush: RiviumPush, didDetectAppUpdate info: AppUpdateInfo) {
        invokeMethod("onAppUpdated", arguments: info.toDictionary())
    }

    public func riviumPush(_ riviumPush: RiviumPush, didReceiveNotificationAction action: NotificationAction, forMessage message: RiviumPushMessage) {
        invokeMethod("onNotificationAction", arguments: [
            "action": action.toDictionary(),
            "message": message.toDictionary()
        ])
    }

    public func riviumPush(_ riviumPush: RiviumPush, didTapNotification message: RiviumPushMessage) {
        NSLog("[RiviumPush.Plugin] didTapNotification called: title=%@", message.title ?? "nil")
        NSLog("[RiviumPush.Plugin] Invoking Flutter method onNotificationTapped")
        invokeMethod("onNotificationTapped", arguments: message.toDictionary())
        NSLog("[RiviumPush.Plugin] onNotificationTapped invoked")
    }
}

// MARK: - InAppMessageCallback
extension RiviumPushPlugin: InAppMessageCallback {
    public func inAppMessageReady(_ message: InAppMessage) {
        invokeMethod("onInAppMessageReady", arguments: message.toDictionary())
    }

    public func inAppMessageButtonClicked(_ message: InAppMessage, button: InAppButton) {
        invokeMethod("onInAppButtonClick", arguments: [
            "message": message.toDictionary(),
            "button": button.toDictionary()
        ])
    }

    public func inAppMessageDismissed(_ message: InAppMessage) {
        invokeMethod("onInAppMessageDismissed", arguments: message.toDictionary())
    }

    public func inAppMessageError(_ error: String) {
        invokeMethod("onError", arguments: error)
    }
}

// MARK: - InboxCallback
extension RiviumPushPlugin: InboxCallback {
    public func inboxMessageReceived(_ message: InboxMessage) {
        invokeMethod("onInboxMessageReceived", arguments: message.toDictionary())
    }

    public func inboxMessageStatusChanged(messageId: String, status: InboxMessageStatus) {
        invokeMethod("onInboxMessageStatusChanged", arguments: [
            "messageId": messageId,
            "status": status.rawValue
        ])
    }
}

// MARK: - ABTestingDelegate
extension RiviumPushPlugin: ABTestingDelegate {
    public func abTestingManager(_ manager: ABTestingManager, didAssignVariant variant: ABTestVariant) {
        invokeMethod("onABTestVariantAssigned", arguments: variant.toDictionary())
    }

    public func abTestingManager(_ manager: ABTestingManager, didFailWithError error: Error, forTest testId: String?) {
        invokeMethod("onABTestError", arguments: [
            "testId": testId ?? "",
            "error": error.localizedDescription
        ])
    }
}

// MARK: - UNUserNotificationCenterDelegate (foreground notification display)
extension RiviumPushPlugin: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if showNotificationInForeground {
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        } else {
            completionHandler([])
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let message = RiviumPushMessage.from(payload: userInfo) {
            invokeMethod("onNotificationTapped", arguments: message.toDictionary())
        }
        completionHandler()
    }
}
