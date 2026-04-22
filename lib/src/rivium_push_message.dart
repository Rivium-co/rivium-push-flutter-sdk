/// Event fired when a notification action button is tapped
class NotificationActionEvent {
  /// The action ID that was tapped
  final String actionId;

  /// The notification title
  final String? title;

  /// The notification body
  final String? body;

  /// Custom data payload from the notification
  final Map<String, dynamic>? data;

  /// Message ID for tracking
  final String? messageId;

  const NotificationActionEvent({
    required this.actionId,
    this.title,
    this.body,
    this.data,
    this.messageId,
  });

  factory NotificationActionEvent.fromMap(Map<dynamic, dynamic> map) {
    return NotificationActionEvent(
      actionId: map['actionId'] as String? ?? '',
      title: map['title'] as String?,
      body: map['body'] as String?,
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'] as Map)
          : null,
      messageId: map['messageId'] as String?,
    );
  }

  @override
  String toString() {
    return 'NotificationActionEvent(actionId: $actionId, title: $title, data: $data)';
  }
}

/// Action button for notifications
class NotificationAction {
  /// Unique action identifier
  final String id;

  /// Button text
  final String title;

  /// Deep link or action identifier
  final String? action;

  /// Icon name (Android)
  final String? icon;

  /// Show as destructive/red (iOS)
  final bool destructive;

  /// Requires device unlock (iOS)
  final bool authRequired;

  const NotificationAction({
    required this.id,
    required this.title,
    this.action,
    this.icon,
    this.destructive = false,
    this.authRequired = false,
  });

  factory NotificationAction.fromMap(Map<dynamic, dynamic> map) {
    return NotificationAction(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      action: map['action'] as String?,
      icon: map['icon'] as String?,
      destructive: map['destructive'] as bool? ?? false,
      authRequired: map['authRequired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (action != null) 'action': action,
      if (icon != null) 'icon': icon,
      'destructive': destructive,
      'authRequired': authRequired,
    };
  }
}

/// Localized content for notifications
class LocalizedContent {
  /// Locale code (e.g., 'en', 'fa', 'de')
  final String locale;

  /// Localized title
  final String title;

  /// Localized body
  final String body;

  const LocalizedContent({
    required this.locale,
    required this.title,
    required this.body,
  });

  factory LocalizedContent.fromMap(Map<dynamic, dynamic> map) {
    return LocalizedContent(
      locale: map['locale'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'locale': locale,
      'title': title,
      'body': body,
    };
  }
}

/// Push notification message with rich notification support
class RiviumPushMessage {
  /// Notification title
  final String title;

  /// Notification body
  final String body;

  /// Custom data payload
  final Map<String, dynamic>? data;

  /// If true, message is delivered without showing a notification
  final bool silent;

  // === Rich Notification Fields ===

  /// Large image URL to display in notification
  final String? imageUrl;

  /// Small icon URL (Android)
  final String? iconUrl;

  /// Action buttons (max 3)
  final List<NotificationAction>? actions;

  /// Deep link URL to open when notification is tapped
  final String? deepLink;

  /// Badge count to set on app icon
  final int? badge;

  /// Badge action type: 'set', 'increment', 'decrement', 'clear'
  final String? badgeAction;

  /// Sound file name or 'default'
  final String? sound;

  /// Thread ID for grouping notifications (iOS)
  final String? threadId;

  /// Collapse key - replaces previous notification with same key (Android)
  final String? collapseKey;

  /// iOS notification category for action buttons
  final String? category;

  /// Notification priority: 'default', 'high', 'low'
  final String? priority;

  /// Time to live in seconds
  final int? ttl;

  /// Localized versions of title and body
  final List<LocalizedContent>? localizations;

  /// IANA timezone for device-local delivery
  final String? timezone;

  /// Message ID for tracking
  final String? messageId;

  /// Campaign ID for analytics
  final String? campaignId;

  const RiviumPushMessage({
    required this.title,
    required this.body,
    this.data,
    this.silent = false,
    this.imageUrl,
    this.iconUrl,
    this.actions,
    this.deepLink,
    this.badge,
    this.badgeAction,
    this.sound,
    this.threadId,
    this.collapseKey,
    this.category,
    this.priority,
    this.ttl,
    this.localizations,
    this.timezone,
    this.messageId,
    this.campaignId,
  });

  factory RiviumPushMessage.fromMap(Map<dynamic, dynamic> map) {
    return RiviumPushMessage(
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'] as Map)
          : null,
      silent: map['silent'] as bool? ?? false,
      imageUrl: map['imageUrl'] as String?,
      iconUrl: map['iconUrl'] as String?,
      actions: map['actions'] != null
          ? (map['actions'] as List)
              .map((a) => NotificationAction.fromMap(a as Map))
              .toList()
          : null,
      deepLink: map['deepLink'] as String?,
      badge: map['badge'] as int?,
      badgeAction: map['badgeAction'] as String?,
      sound: map['sound'] as String?,
      threadId: map['threadId'] as String?,
      collapseKey: map['collapseKey'] as String?,
      category: map['category'] as String?,
      priority: map['priority'] as String?,
      ttl: map['ttl'] as int?,
      localizations: map['localizations'] != null
          ? (map['localizations'] as List)
              .map((l) => LocalizedContent.fromMap(l as Map))
              .toList()
          : null,
      timezone: map['timezone'] as String?,
      messageId: map['messageId'] as String?,
      campaignId: map['campaignId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      if (data != null) 'data': data,
      'silent': silent,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (iconUrl != null) 'iconUrl': iconUrl,
      if (actions != null) 'actions': actions!.map((a) => a.toMap()).toList(),
      if (deepLink != null) 'deepLink': deepLink,
      if (badge != null) 'badge': badge,
      if (badgeAction != null) 'badgeAction': badgeAction,
      if (sound != null) 'sound': sound,
      if (threadId != null) 'threadId': threadId,
      if (collapseKey != null) 'collapseKey': collapseKey,
      if (category != null) 'category': category,
      if (priority != null) 'priority': priority,
      if (ttl != null) 'ttl': ttl,
      if (localizations != null)
        'localizations': localizations!.map((l) => l.toMap()).toList(),
      if (timezone != null) 'timezone': timezone,
      if (messageId != null) 'messageId': messageId,
      if (campaignId != null) 'campaignId': campaignId,
    };
  }

  /// Get the localized title for the given locale, or the default title
  String getLocalizedTitle(String locale) {
    if (localizations == null) return title;
    final localized = localizations!.where((l) => l.locale == locale).firstOrNull;
    return localized?.title ?? title;
  }

  /// Get the localized body for the given locale, or the default body
  String getLocalizedBody(String locale) {
    if (localizations == null) return body;
    final localized = localizations!.where((l) => l.locale == locale).firstOrNull;
    return localized?.body ?? body;
  }

  @override
  String toString() {
    return 'RiviumPushMessage(title: $title, body: $body, data: $data, silent: $silent, '
        'imageUrl: $imageUrl, actions: ${actions?.length ?? 0}, deepLink: $deepLink)';
  }
}
