package co.rivium.push.flutter

import android.app.Activity
import android.content.Context
import androidx.annotation.NonNull
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// Import from native SDK (AAR)
import co.rivium.push.sdk.RiviumPush
import co.rivium.push.sdk.RiviumPushCallback
import co.rivium.push.sdk.RiviumPushCallbackAdapter
import co.rivium.push.sdk.RiviumPushConfig
import co.rivium.push.sdk.RiviumPushError
import co.rivium.push.sdk.RiviumPushLogLevel
import co.rivium.push.sdk.RiviumPushMessage
import co.rivium.push.sdk.RiviumPushService
import co.rivium.push.sdk.Log
import co.rivium.push.sdk.inapp.InAppMessage
import co.rivium.push.sdk.inapp.InAppButton
import co.rivium.push.sdk.inapp.InAppMessageCallback
import co.rivium.push.sdk.inbox.InboxCallback
import co.rivium.push.sdk.inbox.InboxCallbackAdapter
import co.rivium.push.sdk.inbox.InboxFilter
import co.rivium.push.sdk.inbox.InboxMessage
import co.rivium.push.sdk.inbox.InboxMessageStatus
import co.rivium.push.sdk.inbox.toMap
import co.rivium.push.sdk.abtesting.ABTestingCallback
import co.rivium.push.sdk.abtesting.ABTestVariant
import co.rivium.push.sdk.abtesting.ABTestSummary
import co.rivium.push.sdk.NetworkState
import co.rivium.push.sdk.AppState

// Extension functions for A/B testing types to convert to Map for Flutter bridge
fun ABTestVariant.toMap(): Map<String, Any?> {
    return mapOf(
        "testId" to testId,
        "variantId" to variantId,
        "variantName" to variantName,
        "isControlGroup" to isControlGroup,
        "content" to content?.let {
            mapOf(
                "title" to it.title,
                "body" to it.body,
                "data" to it.data,
                "imageUrl" to it.imageUrl,
                "deepLink" to it.deepLink,
                "actions" to it.actions?.map { action ->
                    mapOf(
                        "id" to action.id,
                        "title" to action.title,
                        "action" to action.action
                    )
                }
            )
        }
    )
}

fun ABTestSummary.toMap(): Map<String, Any?> {
    return mapOf(
        "id" to id,
        "name" to name,
        "variantCount" to variantCount,
        "hasControlGroup" to hasControlGroup
    )
}

class RiviumPushPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    private var activity: Activity? = null
    private var lifecycleObserver: LifecycleEventObserver? = null
    private var isInForeground = true

    companion object {
        private const val TAG = "Plugin"
        private const val CHANNEL_NAME = "co.rivium.push/main"

        var instance: RiviumPushPlugin? = null

        // Queue for messages that arrive when Flutter is not attached
        private val pendingMessages = mutableListOf<Pair<String, Any?>>()

        // Track lifecycle observer registration
        private var lifecycleObserverRegistered = false

        // Track if Flutter/app is in foreground - accessible by RiviumPushService
        @Volatile
        var isFlutterInForeground = false
            private set

        /**
         * Check if Flutter engine is active and app is in foreground.
         * Used by RiviumPushService to decide whether to show native notifications.
         */
        fun isFlutterActive(): Boolean {
            return instance != null && isFlutterInForeground
        }
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "====== PLUGIN ATTACHED TO ENGINE ======")
        Log.d(TAG, "Existing instance: ${instance != null}")
        Log.d(TAG, "Pending messages: ${pendingMessages.size}")
        Log.d(TAG, "=======================================")

        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        instance = this

        // Deliver any pending messages that arrived while Flutter was detached
        deliverPendingMessages()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "====== PLUGIN DETACHED FROM ENGINE ======")
        Log.d(TAG, "=========================================")

        channel.setMethodCallHandler(null)
        instance = null
        Log.d(TAG, "Plugin detached from engine")
    }

    private fun invokeFlutterMethod(method: String, arguments: Any?) {
        try {
            Log.d(TAG, "====== INVOKE FLUTTER METHOD ======")
            Log.d(TAG, "Method: $method")
            Log.d(TAG, "Arguments: $arguments")
            Log.d(TAG, "===================================")

            val currentInstance = instance
            if (currentInstance != null && currentInstance::channel.isInitialized) {
                currentInstance.channel.invokeMethod(method, arguments)
                Log.d(TAG, "invokeFlutterMethod succeeded")
            } else {
                Log.w(TAG, "Channel not available! Queueing message for later delivery")
                synchronized(pendingMessages) {
                    pendingMessages.add(Pair(method, arguments))
                    Log.d(TAG, "Message queued. Total pending: ${pendingMessages.size}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "invokeFlutterMethod failed: ${e.message}")
        }
    }

    private fun deliverPendingMessages() {
        synchronized(pendingMessages) {
            if (pendingMessages.isEmpty()) {
                Log.d(TAG, "No pending messages to deliver")
                return
            }

            Log.d(TAG, "====== DELIVERING PENDING MESSAGES ======")
            Log.d(TAG, "Count: ${pendingMessages.size}")

            val messages = pendingMessages.toList()
            pendingMessages.clear()

            for ((method, arguments) in messages) {
                try {
                    Log.d(TAG, "Delivering: $method -> $arguments")
                    if (::channel.isInitialized) {
                        channel.invokeMethod(method, arguments)
                        Log.d(TAG, "Delivered successfully")
                    } else {
                        Log.e(TAG, "Channel still not initialized!")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to deliver pending message: ${e.message}")
                }
            }
            Log.d(TAG, "========================================")
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "init" -> {
                val config = call.arguments as Map<*, *>
                initRiviumPush(config)
                result.success(null)
            }
            "register" -> {
                val userId = call.argument<String>("userId")
                val metadata = call.argument<Map<String, Any>>("metadata")
                try {
                    RiviumPush.register(userId, metadata)
                    result.success(null)
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Register failed: ${e.message}", e)
                    result.error("REGISTER_ERROR", e.message, null)
                }
            }
            "unregister" -> {
                RiviumPush.unregister()
                result.success(null)
            }
            "subscribeTopic" -> {
                val topic = call.argument<String>("topic")
                if (topic != null) {
                    RiviumPush.subscribeTopic(topic)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Topic cannot be null", null)
                }
            }
            "unsubscribeTopic" -> {
                val topic = call.argument<String>("topic")
                if (topic != null) {
                    RiviumPush.unsubscribeTopic(topic)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Topic cannot be null", null)
                }
            }
            "isConnected" -> {
                result.success(RiviumPush.isConnected())
            }
            "getDeviceId" -> {
                result.success(RiviumPush.getDeviceId())
            }
            "setUserId" -> {
                val userId = call.argument<String>("userId")
                if (userId != null) {
                    RiviumPush.setUserId(userId)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "User ID cannot be null", null)
                }
            }
            "clearUserId" -> {
                RiviumPush.clearUserId()
                result.success(null)
            }
            "getInitialMessage" -> {
                val message = RiviumPush.getInitialMessage()
                if (message != null) {
                    RiviumPush.clearInitialMessage()
                    result.success(message.toMap())
                } else {
                    result.success(null)
                }
            }
            "getClickedAction" -> {
                val action = RiviumPush.getClickedAction()
                result.success(action)
            }
            "setLogLevel" -> {
                val level = call.argument<String>("level") ?: "debug"
                val logLevel = when (level.lowercase()) {
                    "none" -> RiviumPushLogLevel.NONE
                    "error" -> RiviumPushLogLevel.ERROR
                    "warning" -> RiviumPushLogLevel.WARNING
                    "info" -> RiviumPushLogLevel.INFO
                    "debug" -> RiviumPushLogLevel.DEBUG
                    "verbose" -> RiviumPushLogLevel.VERBOSE
                    else -> RiviumPushLogLevel.DEBUG
                }
                RiviumPush.setLogLevel(logLevel)
                Log.d(TAG, "Log level set to: $logLevel")
                result.success(null)
            }
            // In-App Messages
            "fetchInAppMessages" -> {
                RiviumPush.fetchInAppMessages { messages ->
                    val messageList = messages.map { it.toMap() }
                    result.success(messageList)
                }
            }
            "triggerInAppOnAppOpen" -> {
                RiviumPush.triggerInAppOnAppOpen()
                result.success(null)
            }
            "triggerInAppEvent" -> {
                val eventName = call.argument<String>("eventName")
                val properties = call.argument<Map<String, Any>>("properties")
                if (eventName != null) {
                    RiviumPush.triggerInAppEvent(eventName, properties)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Event name cannot be null", null)
                }
            }
            "triggerInAppOnSessionStart" -> {
                RiviumPush.triggerInAppOnSessionStart()
                result.success(null)
            }
            "showInAppMessage" -> {
                val messageId = call.argument<String>("messageId")
                if (messageId != null) {
                    RiviumPush.showInAppMessage(messageId)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Message ID cannot be null", null)
                }
            }
            "dismissInAppMessage" -> {
                RiviumPush.dismissInAppMessage()
                result.success(null)
            }
            // Inbox Methods
            "getInboxMessages" -> {
                val status = call.argument<String>("status")
                val category = call.argument<String>("category")
                val limit = call.argument<Int>("limit") ?: 50
                val offset = call.argument<Int>("offset") ?: 0

                val filter = InboxFilter(
                    status = status?.let {
                        when (it.lowercase()) {
                            "unread" -> InboxMessageStatus.UNREAD
                            "read" -> InboxMessageStatus.READ
                            "archived" -> InboxMessageStatus.ARCHIVED
                            else -> null
                        }
                    },
                    category = category,
                    limit = limit,
                    offset = offset
                )

                RiviumPush.getInboxMessages(
                    filter = filter,
                    onSuccess = { response ->
                        result.success(mapOf(
                            "messages" to response.messages.map { it.toMap() },
                            "total" to response.total,
                            "unreadCount" to response.unreadCount
                        ))
                    },
                    onError = { error ->
                        result.error("INBOX_ERROR", error, null)
                    }
                )
            }
            "getInboxMessage" -> {
                val messageId = call.argument<String>("messageId")
                if (messageId != null) {
                    RiviumPush.getInboxMessage(
                        messageId = messageId,
                        onSuccess = { message ->
                            result.success(message.toMap())
                        },
                        onError = { error ->
                            result.error("INBOX_ERROR", error, null)
                        }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Message ID cannot be null", null)
                }
            }
            "markInboxMessageAsRead" -> {
                val messageId = call.argument<String>("messageId")
                if (messageId != null) {
                    RiviumPush.markInboxMessageAsRead(
                        messageId = messageId,
                        onSuccess = { result.success(null) },
                        onError = { error -> result.error("INBOX_ERROR", error, null) }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Message ID cannot be null", null)
                }
            }
            "archiveInboxMessage" -> {
                val messageId = call.argument<String>("messageId")
                if (messageId != null) {
                    RiviumPush.archiveInboxMessage(
                        messageId = messageId,
                        onSuccess = { result.success(null) },
                        onError = { error -> result.error("INBOX_ERROR", error, null) }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Message ID cannot be null", null)
                }
            }
            "deleteInboxMessage" -> {
                val messageId = call.argument<String>("messageId")
                if (messageId != null) {
                    RiviumPush.deleteInboxMessage(
                        messageId = messageId,
                        onSuccess = { result.success(null) },
                        onError = { error -> result.error("INBOX_ERROR", error, null) }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Message ID cannot be null", null)
                }
            }
            "markMultipleInboxMessages" -> {
                val messageIds = call.argument<List<String>>("messageIds")
                val statusStr = call.argument<String>("status")
                if (messageIds != null && statusStr != null) {
                    val status = when (statusStr.lowercase()) {
                        "unread" -> InboxMessageStatus.UNREAD
                        "read" -> InboxMessageStatus.READ
                        "archived" -> InboxMessageStatus.ARCHIVED
                        "deleted" -> InboxMessageStatus.DELETED
                        else -> InboxMessageStatus.READ
                    }
                    RiviumPush.markMultipleInboxMessages(
                        messageIds = messageIds,
                        status = status,
                        onSuccess = { result.success(null) },
                        onError = { error -> result.error("INBOX_ERROR", error, null) }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Message IDs and status cannot be null", null)
                }
            }
            "markAllInboxMessagesAsRead" -> {
                RiviumPush.markAllInboxMessagesAsRead(
                    onSuccess = { result.success(null) },
                    onError = { error -> result.error("INBOX_ERROR", error, null) }
                )
            }
            "getInboxUnreadCount" -> {
                result.success(RiviumPush.getInboxUnreadCount())
            }
            "fetchInboxUnreadCount" -> {
                RiviumPush.fetchInboxUnreadCount(
                    onSuccess = { count -> result.success(count) },
                    onError = { error -> result.error("INBOX_ERROR", error, null) }
                )
            }
            "getCachedInboxMessages" -> {
                val messages = RiviumPush.getCachedInboxMessages()
                result.success(messages.map { it.toMap() })
            }
            "clearInboxCache" -> {
                RiviumPush.clearInboxCache()
                result.success(null)
            }
            // A/B Testing Methods
            "getActiveABTests" -> {
                RiviumPush.getActiveABTests(
                    onSuccess = { tests ->
                        result.success(tests.map { it.toMap() })
                    },
                    onError = { error ->
                        result.error("ABTEST_ERROR", error, null)
                    }
                )
            }
            "getABTestVariant" -> {
                val testId = call.argument<String>("testId")
                val forceRefresh = call.argument<Boolean>("forceRefresh") ?: false
                if (testId != null) {
                    RiviumPush.getABTestVariant(
                        testId = testId,
                        forceRefresh = forceRefresh,
                        onSuccess = { variant ->
                            result.success(variant.toMap())
                        },
                        onError = { error ->
                            result.error("ABTEST_ERROR", error, null)
                        }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Test ID cannot be null", null)
                }
            }
            "getCachedABTestVariant" -> {
                val testId = call.argument<String>("testId")
                if (testId != null) {
                    val variant = RiviumPush.getCachedABTestVariant(testId)
                    result.success(variant?.toMap())
                } else {
                    result.error("INVALID_ARGUMENT", "Test ID cannot be null", null)
                }
            }
            "trackABTestImpression" -> {
                val testId = call.argument<String>("testId")
                val variantId = call.argument<String>("variantId")
                if (testId != null && variantId != null) {
                    RiviumPush.trackABTestImpression(
                        testId = testId,
                        variantId = variantId,
                        onSuccess = { result.success(null) },
                        onError = { error -> result.error("ABTEST_ERROR", error, null) }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Test ID and Variant ID cannot be null", null)
                }
            }
            "trackABTestOpened" -> {
                val testId = call.argument<String>("testId")
                val variantId = call.argument<String>("variantId")
                if (testId != null && variantId != null) {
                    RiviumPush.trackABTestOpened(
                        testId = testId,
                        variantId = variantId,
                        onSuccess = { result.success(null) },
                        onError = { error -> result.error("ABTEST_ERROR", error, null) }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Test ID and Variant ID cannot be null", null)
                }
            }
            "trackABTestClicked" -> {
                val testId = call.argument<String>("testId")
                val variantId = call.argument<String>("variantId")
                if (testId != null && variantId != null) {
                    RiviumPush.trackABTestClicked(
                        testId = testId,
                        variantId = variantId,
                        onSuccess = { result.success(null) },
                        onError = { error -> result.error("ABTEST_ERROR", error, null) }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Test ID and Variant ID cannot be null", null)
                }
            }
            "trackABTestDisplay" -> {
                val testId = call.argument<String>("testId")
                val variantId = call.argument<String>("variantId")
                if (testId != null && variantId != null) {
                    // trackDisplay sends impression then opened - replicate this behavior
                    RiviumPush.trackABTestImpression(
                        testId = testId,
                        variantId = variantId,
                        onSuccess = {
                            RiviumPush.trackABTestOpened(
                                testId = testId,
                                variantId = variantId,
                                onSuccess = { result.success(null) },
                                onError = { error -> result.error("ABTEST_ERROR", error, null) }
                            )
                        },
                        onError = { error -> result.error("ABTEST_ERROR", error, null) }
                    )
                } else {
                    result.error("INVALID_ARGUMENT", "Test ID and Variant ID cannot be null", null)
                }
            }
            "clearABTestCache" -> {
                RiviumPush.clearABTestingCache()
                result.success(null)
            }
            // Log Level
            "getLogLevel" -> {
                result.success(RiviumPush.getLogLevel().name.lowercase())
            }
            // Badge Management
            "getBadgeCount" -> {
                result.success(RiviumPush.getBadgeCount())
            }
            "setBadgeCount" -> {
                val count = call.argument<Int>("count") ?: 0
                RiviumPush.setBadgeCount(count)
                result.success(null)
            }
            "clearBadge" -> {
                RiviumPush.clearBadge()
                result.success(null)
            }
            "incrementBadge" -> {
                val by = call.argument<Int>("by") ?: 1
                RiviumPush.incrementBadge(by)
                result.success(null)
            }
            "decrementBadge" -> {
                val by = call.argument<Int>("by") ?: 1
                RiviumPush.decrementBadge(by)
                result.success(null)
            }
            // State Getters
            "getNetworkState" -> {
                val state = RiviumPush.getNetworkState()
                result.success(mapOf(
                    "isAvailable" to state.isAvailable,
                    "networkType" to state.networkType.name.lowercase()
                ))
            }
            "getAppState" -> {
                val state = RiviumPush.getAppState()
                result.success(mapOf(
                    "isInForeground" to state.isInForeground,
                    "currentActivity" to state.currentActivity
                ))
            }
            // Service Notification
            "isServiceNotificationHidden" -> {
                result.success(RiviumPush.isServiceNotificationHidden())
            }
            "openServiceNotificationSettings" -> {
                RiviumPush.openServiceNotificationSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initRiviumPush(config: Map<*, *>) {
        // Build config - only apiKey is required from Flutter
        // MQTT config is fetched automatically from server
        val riviumPushConfig = RiviumPushConfig(
            apiKey = config["apiKey"] as String,
            notificationIcon = config["notificationIcon"] as? String,
            showServiceNotification = (config["showServiceNotification"] as? Boolean) ?: true,
            showNotificationInForeground = (config["showNotificationInForeground"] as? Boolean) ?: true
        )

        // Initialize native SDK
        RiviumPush.init(context, riviumPushConfig)

        // Set up callback to forward events to Flutter
        RiviumPush.setCallback(object : RiviumPushCallbackAdapter() {
            override fun onMessageReceived(message: RiviumPushMessage) {
                Log.d(TAG, "Message received: ${message.title}")
                invokeFlutterMethod("onMessage", message.toMap())
            }

            override fun onConnectionStateChanged(connected: Boolean) {
                Log.d(TAG, "Connection state changed: $connected")
                invokeFlutterMethod("onConnectionState", connected)
            }

            override fun onRegistered(deviceId: String) {
                Log.d(TAG, "Device registered: $deviceId")
                invokeFlutterMethod("onRegistered", deviceId)
            }

            override fun onError(error: String) {
                Log.e(TAG, "Error: $error")
                invokeFlutterMethod("onError", error)
            }

            override fun onDetailedError(error: RiviumPushError) {
                Log.e(TAG, "Detailed error: ${error.code} - ${error.message}")
                invokeFlutterMethod("onDetailedError", error.toMap())
            }

            override fun onReconnecting(attempt: Int, nextRetryMs: Long) {
                Log.d(TAG, "Reconnecting: attempt=$attempt, nextRetry=${nextRetryMs}ms")
                invokeFlutterMethod("onReconnecting", mapOf(
                    "retryAttempt" to attempt,
                    "nextRetryMs" to nextRetryMs
                ))
            }

            override fun onNetworkStateChanged(isAvailable: Boolean, networkType: String) {
                Log.d(TAG, "Network state: available=$isAvailable, type=$networkType")
                invokeFlutterMethod("onNetworkState", mapOf(
                    "isAvailable" to isAvailable,
                    "networkType" to networkType
                ))
            }

            override fun onAppStateChanged(isInForeground: Boolean) {
                Log.d(TAG, "App state: foreground=$isInForeground")
                invokeFlutterMethod("onAppState", mapOf(
                    "isInForeground" to isInForeground
                ))
            }

            override fun onAppUpdated(previousVersion: String, currentVersion: String, needsReregistration: Boolean) {
                Log.d(TAG, "App updated: $previousVersion -> $currentVersion")
                invokeFlutterMethod("onAppUpdated", mapOf(
                    "previousVersion" to previousVersion,
                    "currentVersion" to currentVersion,
                    "needsReregistration" to needsReregistration
                ))
            }

            override fun onNotificationTapped(message: RiviumPushMessage) {
                Log.d(TAG, "Notification tapped: ${message.title}")
                invokeFlutterMethod("onNotificationTapped", message.toMap())
            }
        })

        // Set up in-app message callback to forward events to Flutter
        RiviumPush.setInAppMessageCallback(object : InAppMessageCallback {
            override fun onMessageReady(message: InAppMessage) {
                Log.d(TAG, "In-app message ready: ${message.name}")
                invokeFlutterMethod("onInAppMessageReady", message.toMap())
            }

            override fun onButtonClicked(message: InAppMessage, button: InAppButton) {
                Log.d(TAG, "In-app button clicked: ${button.text}")
                invokeFlutterMethod("onInAppButtonClick", mapOf(
                    "message" to message.toMap(),
                    "button" to button.toMap()
                ))
            }

            override fun onMessageDismissed(message: InAppMessage) {
                Log.d(TAG, "In-app message dismissed: ${message.name}")
                invokeFlutterMethod("onInAppMessageDismissed", message.toMap())
            }

            override fun onError(error: String) {
                Log.e(TAG, "In-app message error: $error")
                invokeFlutterMethod("onError", error)
            }
        })

        // Set up inbox callback to forward real-time inbox updates to Flutter
        RiviumPush.getInboxManager().setCallback(object : InboxCallback {
            override fun onMessageReceived(message: co.rivium.push.sdk.inbox.InboxMessage) {
                Log.d(TAG, "Inbox message received: ${message.content.title}")
                invokeFlutterMethod("onInboxMessageReceived", mapOf(
                    "id" to message.id,
                    "title" to message.content.title,
                    "body" to message.content.body,
                    "imageUrl" to message.content.imageUrl,
                    "deepLink" to message.content.deepLink,
                    "category" to message.category,
                    "status" to (message.status.name.lowercase()),
                    "createdAt" to message.createdAt
                ))
            }

            override fun onMessageStatusChanged(messageId: String, status: co.rivium.push.sdk.inbox.InboxMessageStatus) {
                Log.d(TAG, "Inbox message status changed: $messageId -> $status")
                invokeFlutterMethod("onInboxMessageStatusChanged", mapOf(
                    "messageId" to messageId,
                    "status" to status.name.lowercase()
                ))
            }
        })

        // Set up A/B testing callback to forward events to Flutter
        RiviumPush.setABTestingCallback(object : ABTestingCallback {
            override fun onVariantAssigned(variant: ABTestVariant) {
                Log.d(TAG, "A/B test variant assigned: ${variant.variantName}")
                invokeFlutterMethod("onABTestVariantAssigned", variant.toMap())
            }

            override fun onError(testId: String?, error: String) {
                Log.e(TAG, "A/B test error for $testId: $error")
                invokeFlutterMethod("onABTestError", mapOf(
                    "testId" to (testId ?: ""),
                    "error" to error
                ))
            }
        })

        Log.d(TAG, "RiviumPush SDK initialized with native AAR")
    }

    // Called from native to send events to Flutter
    fun invokeMethod(method: String, arguments: Any?) {
        invokeFlutterMethod(method, arguments)
    }

    // MARK: - ActivityAware implementation
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "====== ATTACHED TO ACTIVITY ======")
        activity = binding.activity
        isFlutterInForeground = true
        setupLifecycleObserver()
        // Set activity for in-app messages
        RiviumPush.setCurrentActivity(activity)
        Log.d(TAG, "==================================")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "Detached from activity for config changes")
        activity = null
        RiviumPush.setCurrentActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "Reattached to activity for config changes")
        activity = binding.activity
        RiviumPush.setCurrentActivity(activity)
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "====== DETACHED FROM ACTIVITY ======")
        activity = null
        RiviumPush.setCurrentActivity(null)
        Log.d(TAG, "====================================")
    }

    private fun setupLifecycleObserver() {
        if (lifecycleObserverRegistered) {
            Log.d(TAG, "Lifecycle observer already registered")
            return
        }

        lifecycleObserver = LifecycleEventObserver { _, event ->
            Log.d(TAG, "====== LIFECYCLE EVENT: ${event.name} ======")

            when (event) {
                Lifecycle.Event.ON_START -> {
                    if (!isInForeground) {
                        isInForeground = true
                        isFlutterInForeground = true
                        Log.d(TAG, "App returned to foreground - checking MQTT connection")
                        onAppForeground()
                    }
                }
                Lifecycle.Event.ON_STOP -> {
                    isInForeground = false
                    isFlutterInForeground = false
                    Log.d(TAG, "App went to background")
                    onAppBackground()
                }
                else -> {}
            }
        }

        try {
            ProcessLifecycleOwner.get().lifecycle.addObserver(lifecycleObserver!!)
            lifecycleObserverRegistered = true
            Log.d(TAG, "Lifecycle observer registered successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register lifecycle observer: ${e.message}")
        }
    }

    private fun onAppForeground() {
        Log.d(TAG, "Flutter foreground state: true")

        // Trigger MQTT reconnection if not connected
        if (!RiviumPush.isConnected()) {
            Log.d(TAG, "MQTT not connected - triggering reconnect on foreground")
            RiviumPushService.reconnectNow()
        } else {
            Log.d(TAG, "MQTT already connected")
        }

        invokeFlutterMethod("onAppState", mapOf("isInForeground" to true))
    }

    private fun onAppBackground() {
        Log.d(TAG, "Flutter foreground state: false")
        invokeFlutterMethod("onAppState", mapOf("isInForeground" to false))
    }
}
