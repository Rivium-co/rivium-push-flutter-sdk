/// Status of an inbox message.
enum InboxMessageStatus {
  unread,
  read,
  archived,
  deleted;

  static InboxMessageStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'unread':
        return InboxMessageStatus.unread;
      case 'read':
        return InboxMessageStatus.read;
      case 'archived':
        return InboxMessageStatus.archived;
      case 'deleted':
        return InboxMessageStatus.deleted;
      default:
        return InboxMessageStatus.unread;
    }
  }
}

/// Content of an inbox message.
class InboxContent {
  final String title;
  final String body;
  final String? imageUrl;
  final String? iconUrl;
  final String? deepLink;
  final Map<String, dynamic>? data;

  InboxContent({
    required this.title,
    required this.body,
    this.imageUrl,
    this.iconUrl,
    this.deepLink,
    this.data,
  });

  factory InboxContent.fromMap(Map<String, dynamic> map) {
    return InboxContent(
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      iconUrl: map['iconUrl'] as String?,
      deepLink: map['deepLink'] as String?,
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'iconUrl': iconUrl,
      'deepLink': deepLink,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'InboxContent(title: $title, body: $body)';
  }
}

/// Represents an inbox message.
class InboxMessage {
  final String id;
  final String? userId;
  final String? deviceId;
  final InboxContent content;
  final InboxMessageStatus status;
  final String? category;
  final String? expiresAt;
  final String? readAt;
  final String createdAt;
  final String? updatedAt;

  InboxMessage({
    required this.id,
    this.userId,
    this.deviceId,
    required this.content,
    this.status = InboxMessageStatus.unread,
    this.category,
    this.expiresAt,
    this.readAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory InboxMessage.fromMap(Map<String, dynamic> map) {
    return InboxMessage(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String?,
      deviceId: map['deviceId'] as String?,
      content: InboxContent.fromMap(
        Map<String, dynamic>.from(map['content'] as Map? ?? {}),
      ),
      status: InboxMessageStatus.fromString(map['status'] as String? ?? 'unread'),
      category: map['category'] as String?,
      expiresAt: map['expiresAt'] as String?,
      readAt: map['readAt'] as String?,
      createdAt: map['createdAt'] as String? ?? '',
      updatedAt: map['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'deviceId': deviceId,
      'content': content.toMap(),
      'status': status.name,
      'category': category,
      'expiresAt': expiresAt,
      'readAt': readAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  String toString() {
    return 'InboxMessage(id: $id, status: $status, content: $content)';
  }
}

/// Response from getInboxMessages.
class InboxMessagesResponse {
  final List<InboxMessage> messages;
  final int total;
  final int unreadCount;

  InboxMessagesResponse({
    required this.messages,
    required this.total,
    required this.unreadCount,
  });

  factory InboxMessagesResponse.fromMap(Map<String, dynamic> map) {
    final messagesList = (map['messages'] as List<dynamic>?)
            ?.map((item) => InboxMessage.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList() ??
        [];

    return InboxMessagesResponse(
      messages: messagesList,
      total: map['total'] as int? ?? 0,
      unreadCount: map['unreadCount'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'InboxMessagesResponse(total: $total, unread: $unreadCount, messages: ${messages.length})';
  }
}

/// Filter options for fetching inbox messages.
class InboxFilter {
  final InboxMessageStatus? status;
  final String? category;
  final int limit;
  final int offset;

  InboxFilter({
    this.status,
    this.category,
    this.limit = 50,
    this.offset = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (status != null) 'status': status!.name,
      if (category != null) 'category': category,
      'limit': limit,
      'offset': offset,
    };
  }
}
