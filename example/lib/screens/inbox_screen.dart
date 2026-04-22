import 'package:flutter/material.dart';
import 'package:rivium_push/rivium_push.dart';

import '../services/rivium_push_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  final _riviumPushService = RiviumPushService.instance;
  late TabController _tabController;

  List<InboxMessage> _allMessages = [];
  List<InboxMessage> _unreadMessages = [];
  List<InboxMessage> _archivedMessages = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupCallbacks();
    _loadMessages();
  }

  void _setupCallbacks() {
    _riviumPushService.onInboxMessage = (message) {
      setState(() {
        _allMessages.insert(0, message);
        _unreadMessages.insert(0, message);
      });
      _showNewMessageSnackbar(message);
    };
  }

  void _showNewMessageSnackbar(InboxMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New message: ${message.content.title}'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _showMessageDetails(message),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _riviumPushService.onInboxMessage = null;
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      // Load all messages
      final allResponse = await _riviumPushService.getInboxMessages();
      _allMessages = allResponse.messages;

      // Load unread messages
      final unreadResponse = await _riviumPushService.getInboxMessages(
        status: InboxMessageStatus.unread,
      );
      _unreadMessages = unreadResponse.messages;

      // Load archived messages
      final archivedResponse = await _riviumPushService.getInboxMessages(
        status: InboxMessageStatus.archived,
      );
      _archivedMessages = archivedResponse.messages;

      // Get unread count
      _unreadCount = await _riviumPushService.getInboxUnreadCount();

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: ListTile(
                  leading: Icon(Icons.done_all),
                  title: Text('Mark All as Read'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_cache',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('Clear Cache'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All'),
                  if (_allMessages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Badge(
                        label: Text('${_allMessages.length}'),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unread'),
                  if (_unreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Badge(
                        label: Text('$_unreadCount'),
                        backgroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: 'Archived'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMessageList(_allMessages, 'No messages yet'),
                _buildMessageList(_unreadMessages, 'No unread messages'),
                _buildMessageList(_archivedMessages, 'No archived messages'),
              ],
            ),
    );
  }

  Widget _buildMessageList(List<InboxMessage> messages, String emptyText) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(emptyText, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.separated(
        itemCount: messages.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final message = messages[index];
          return _buildMessageTile(message);
        },
      ),
    );
  }

  Widget _buildMessageTile(InboxMessage message) {
    final isUnread = message.status == InboxMessageStatus.unread;

    return Dismissible(
      key: Key(message.id),
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _archiveMessage(message);
          return true;
        } else {
          return await _confirmDelete(message);
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUnread
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
          child: Icon(
            _getCategoryIcon(message.category),
            color: isUnread ? Colors.white : Colors.grey.shade600,
          ),
        ),
        title: Text(
          message.content.title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (message.category != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      message.category!,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatDate(message.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleMessageAction(action, message),
          itemBuilder: (context) => [
            if (isUnread)
              const PopupMenuItem(
                value: 'read',
                child: Text('Mark as Read'),
              )
            else
              const PopupMenuItem(
                value: 'unread',
                child: Text('Mark as Unread'),
              ),
            if (message.status != InboxMessageStatus.archived)
              const PopupMenuItem(
                value: 'archive',
                child: Text('Archive'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => _showMessageDetails(message),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'promotions':
        return Icons.local_offer;
      case 'updates':
        return Icons.system_update;
      case 'news':
        return Icons.newspaper;
      case 'alerts':
        return Icons.warning;
      default:
        return Icons.mail;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _showMessageDetails(InboxMessage message) {
    // Mark as read when viewing
    if (message.status == InboxMessageStatus.unread) {
      _markAsRead(message);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (message.content.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      message.content.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  message.content.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (message.category != null) ...[
                      Chip(
                        label: Text(message.category!),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _formatDate(message.createdAt),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(message.content.body),
                const SizedBox(height: 24),
                _buildDetailRow('Message ID', message.id),
                _buildDetailRow('Status', message.status.name),
                _buildDetailRow('Created', message.createdAt.toString()),
                if (message.expiresAt != null)
                  _buildDetailRow('Expires', message.expiresAt.toString()),
                if (message.content.deepLink != null)
                  _buildDetailRow('Deep Link', message.content.deepLink!),
                if (message.content.data != null && message.content.data!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Custom Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      message.content.data.toString(),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _archiveMessage(message);
                        },
                        icon: const Icon(Icons.archive),
                        label: const Text('Archive'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteMessage(message);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Actions
  void _handleMenuAction(String action) async {
    switch (action) {
      case 'mark_all_read':
        await _markAllAsRead();
        break;
      case 'clear_cache':
        await _clearCache();
        break;
    }
  }

  void _handleMessageAction(String action, InboxMessage message) {
    switch (action) {
      case 'read':
        _markAsRead(message);
        break;
      case 'unread':
        _markAsUnread(message);
        break;
      case 'archive':
        _archiveMessage(message);
        break;
      case 'delete':
        _deleteMessage(message);
        break;
    }
  }

  Future<void> _markAsRead(InboxMessage message) async {
    try {
      await _riviumPushService.markInboxMessageAsRead(message.id);
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e')),
        );
      }
    }
  }

  Future<void> _markAsUnread(InboxMessage message) async {
    try {
      await RiviumPush.markMultipleInboxMessages(
        [message.id],
        InboxMessageStatus.unread,
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as unread: $e')),
        );
      }
    }
  }

  Future<void> _archiveMessage(InboxMessage message) async {
    try {
      await _riviumPushService.archiveInboxMessage(message.id);
      await _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message archived')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive: $e')),
        );
      }
    }
  }

  Future<bool> _confirmDelete(InboxMessage message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteMessage(message);
      return true;
    }
    return false;
  }

  Future<void> _deleteMessage(InboxMessage message) async {
    try {
      await _riviumPushService.deleteInboxMessage(message.id);
      await _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _riviumPushService.markAllInboxMessagesAsRead();
      await _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All messages marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    try {
      await RiviumPush.clearInboxCache();
      await _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }
}
