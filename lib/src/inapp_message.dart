/// In-App Message types
enum InAppMessageType {
  modal,
  banner,
  fullscreen,
  card;

  static InAppMessageType fromString(String value) {
    switch (value) {
      case 'modal':
        return InAppMessageType.modal;
      case 'banner':
        return InAppMessageType.banner;
      case 'fullscreen':
        return InAppMessageType.fullscreen;
      case 'card':
        return InAppMessageType.card;
      default:
        return InAppMessageType.modal;
    }
  }

  String get value {
    switch (this) {
      case InAppMessageType.modal:
        return 'modal';
      case InAppMessageType.banner:
        return 'banner';
      case InAppMessageType.fullscreen:
        return 'fullscreen';
      case InAppMessageType.card:
        return 'card';
    }
  }
}

/// In-App Message trigger types
enum InAppTriggerType {
  onAppOpen,
  onEvent,
  onSessionStart,
  scheduled,
  manual;

  static InAppTriggerType fromString(String value) {
    switch (value) {
      case 'on_app_open':
        return InAppTriggerType.onAppOpen;
      case 'on_event':
        return InAppTriggerType.onEvent;
      case 'on_session_start':
        return InAppTriggerType.onSessionStart;
      case 'scheduled':
        return InAppTriggerType.scheduled;
      case 'manual':
        return InAppTriggerType.manual;
      default:
        return InAppTriggerType.onAppOpen;
    }
  }

  String get value {
    switch (this) {
      case InAppTriggerType.onAppOpen:
        return 'on_app_open';
      case InAppTriggerType.onEvent:
        return 'on_event';
      case InAppTriggerType.onSessionStart:
        return 'on_session_start';
      case InAppTriggerType.scheduled:
        return 'scheduled';
      case InAppTriggerType.manual:
        return 'manual';
    }
  }
}

/// Button style for in-app message buttons
enum InAppButtonStyle {
  primary,
  secondary,
  text,
  destructive;

  static InAppButtonStyle fromString(String value) {
    switch (value) {
      case 'primary':
        return InAppButtonStyle.primary;
      case 'secondary':
        return InAppButtonStyle.secondary;
      case 'text':
        return InAppButtonStyle.text;
      case 'destructive':
        return InAppButtonStyle.destructive;
      default:
        return InAppButtonStyle.primary;
    }
  }

  String get value {
    switch (this) {
      case InAppButtonStyle.primary:
        return 'primary';
      case InAppButtonStyle.secondary:
        return 'secondary';
      case InAppButtonStyle.text:
        return 'text';
      case InAppButtonStyle.destructive:
        return 'destructive';
    }
  }
}

/// Button action type
enum InAppButtonAction {
  dismiss,
  deepLink,
  url,
  custom;

  static InAppButtonAction fromString(String value) {
    switch (value) {
      case 'dismiss':
        return InAppButtonAction.dismiss;
      case 'deep_link':
        return InAppButtonAction.deepLink;
      case 'url':
        return InAppButtonAction.url;
      case 'custom':
        return InAppButtonAction.custom;
      default:
        return InAppButtonAction.dismiss;
    }
  }

  String get value {
    switch (this) {
      case InAppButtonAction.dismiss:
        return 'dismiss';
      case InAppButtonAction.deepLink:
        return 'deep_link';
      case InAppButtonAction.url:
        return 'url';
      case InAppButtonAction.custom:
        return 'custom';
    }
  }
}

/// In-App Message button
class InAppButton {
  final String id;
  final String text;
  final InAppButtonAction action;
  final String? value;
  final InAppButtonStyle style;

  InAppButton({
    required this.id,
    required this.text,
    required this.action,
    this.value,
    this.style = InAppButtonStyle.primary,
  });

  factory InAppButton.fromMap(Map<String, dynamic> map) {
    return InAppButton(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      action: InAppButtonAction.fromString(map['action'] ?? 'dismiss'),
      value: map['value'],
      style: InAppButtonStyle.fromString(map['style'] ?? 'primary'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'action': action.value,
      'value': value,
      'style': style.value,
    };
  }

  @override
  String toString() =>
      'InAppButton(id: $id, text: $text, action: $action, style: $style)';
}

/// In-App Message content
class InAppMessageContent {
  final String title;
  final String body;
  final String? imageUrl;
  final String? backgroundColor;
  final String? textColor;
  final List<InAppButton> buttons;

  InAppMessageContent({
    required this.title,
    required this.body,
    this.imageUrl,
    this.backgroundColor,
    this.textColor,
    this.buttons = const [],
  });

  factory InAppMessageContent.fromMap(Map<String, dynamic> map) {
    final buttonsList = <InAppButton>[];
    if (map['buttons'] != null) {
      for (final btn in (map['buttons'] as List)) {
        buttonsList.add(InAppButton.fromMap(Map<String, dynamic>.from(btn)));
      }
    }

    return InAppMessageContent(
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      imageUrl: map['imageUrl'],
      backgroundColor: map['backgroundColor'],
      textColor: map['textColor'],
      buttons: buttonsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'buttons': buttons.map((b) => b.toMap()).toList(),
    };
  }
}

/// Localized content for in-app messages
class InAppLocalizedContent {
  final String locale;
  final InAppMessageContent content;

  InAppLocalizedContent({
    required this.locale,
    required this.content,
  });

  factory InAppLocalizedContent.fromMap(Map<String, dynamic> map) {
    return InAppLocalizedContent(
      locale: map['locale'] ?? '',
      content:
          InAppMessageContent.fromMap(Map<String, dynamic>.from(map['content'])),
    );
  }
}

/// In-App Message
class InAppMessage {
  final String id;
  final String name;
  final InAppMessageType type;
  final InAppMessageContent content;
  final List<InAppLocalizedContent> localizations;
  final InAppTriggerType triggerType;
  final String? triggerEvent;
  final DateTime? startDate;
  final DateTime? endDate;
  final int maxImpressions;
  final int minSessionCount;
  final int delaySeconds;
  final int priority;

  InAppMessage({
    required this.id,
    required this.name,
    required this.type,
    required this.content,
    this.localizations = const [],
    required this.triggerType,
    this.triggerEvent,
    this.startDate,
    this.endDate,
    this.maxImpressions = 1,
    this.minSessionCount = 0,
    this.delaySeconds = 0,
    this.priority = 0,
  });

  factory InAppMessage.fromMap(Map<String, dynamic> map) {
    final locList = <InAppLocalizedContent>[];
    if (map['localizations'] != null) {
      for (final loc in (map['localizations'] as List)) {
        locList.add(InAppLocalizedContent.fromMap(Map<String, dynamic>.from(loc)));
      }
    }

    return InAppMessage(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: InAppMessageType.fromString(map['type'] ?? 'modal'),
      content:
          InAppMessageContent.fromMap(Map<String, dynamic>.from(map['content'])),
      localizations: locList,
      triggerType:
          InAppTriggerType.fromString(map['triggerType'] ?? 'on_app_open'),
      triggerEvent: map['triggerEvent'],
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startDate'])
          : null,
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'])
          : null,
      maxImpressions: map['maxImpressions'] ?? 1,
      minSessionCount: map['minSessionCount'] ?? 0,
      delaySeconds: map['delaySeconds'] ?? 0,
      priority: map['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.value,
      'content': content.toMap(),
      'triggerType': triggerType.value,
      'triggerEvent': triggerEvent,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'maxImpressions': maxImpressions,
      'minSessionCount': minSessionCount,
      'delaySeconds': delaySeconds,
      'priority': priority,
    };
  }

  /// Get localized content for a specific locale
  InAppMessageContent getLocalizedContent(String locale) {
    final deviceLocale = locale.split('-').first.toLowerCase();

    // Find exact match first
    for (final loc in localizations) {
      if (loc.locale.toLowerCase() == locale.toLowerCase()) {
        return loc.content;
      }
    }

    // Find language match
    for (final loc in localizations) {
      if (loc.locale.toLowerCase().startsWith(deviceLocale)) {
        return loc.content;
      }
    }

    // Fall back to default content
    return content;
  }

  @override
  String toString() =>
      'InAppMessage(id: $id, name: $name, type: $type, trigger: $triggerType)';
}

/// Impression action types
enum InAppImpressionAction {
  impression,
  click,
  dismiss,
  buttonClick;

  static InAppImpressionAction fromString(String value) {
    switch (value) {
      case 'impression':
        return InAppImpressionAction.impression;
      case 'click':
        return InAppImpressionAction.click;
      case 'dismiss':
        return InAppImpressionAction.dismiss;
      case 'button_click':
        return InAppImpressionAction.buttonClick;
      default:
        return InAppImpressionAction.impression;
    }
  }

  String get value {
    switch (this) {
      case InAppImpressionAction.impression:
        return 'impression';
      case InAppImpressionAction.click:
        return 'click';
      case InAppImpressionAction.dismiss:
        return 'dismiss';
      case InAppImpressionAction.buttonClick:
        return 'button_click';
    }
  }
}
