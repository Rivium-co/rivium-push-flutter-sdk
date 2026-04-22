import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rivium_push/rivium_push.dart';

import '../services/rivium_push_service.dart';

class PushNotificationsScreen extends StatefulWidget {
  const PushNotificationsScreen({super.key});

  @override
  State<PushNotificationsScreen> createState() => _PushNotificationsScreenState();
}

class _PushNotificationsScreenState extends State<PushNotificationsScreen> {
  final _riviumPushService = RiviumPushService.instance;
  final _userIdController = TextEditingController();
  final _topicController = TextEditingController();
  final _messages = <RiviumPushMessage>[];

  bool _isRegistered = false;
  String? _deviceId;
  final _subscribedTopics = <String>{};

  @override
  void initState() {
    super.initState();
    _loadState();
    _setupMessageListener();
  }

  Future<void> _loadState() async {
    final deviceId = await _riviumPushService.getDeviceId();
    setState(() {
      _deviceId = deviceId;
      _isRegistered = deviceId != null;
    });
  }

  void _setupMessageListener() {
    _riviumPushService.onMessageReceived = (message) {
      setState(() {
        _messages.insert(0, message);
      });
      _showMessageSnackbar(message);
    };
  }

  void _showMessageSnackbar(RiviumPushMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(message.body),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _showMessageDetails(message),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _topicController.dispose();
    _riviumPushService.onMessageReceived = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Registration Section
          _buildSectionCard(
            title: 'Device Registration',
            icon: Icons.app_registration,
            children: [
              if (_isRegistered) ...[
                _buildInfoTile('Device ID', _deviceId ?? 'Unknown'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyDeviceId,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy ID'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _unregister,
                        icon: const Icon(Icons.logout),
                        label: const Text('Unregister'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID (optional)',
                    hintText: 'Enter user ID for targeting',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _register,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register Device'),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // User ID Section (only when registered)
          if (_isRegistered) ...[
            _buildSectionCard(
              title: 'User Association',
              icon: Icons.person,
              children: [
                TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    hintText: 'Associate device with user',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _setUserId,
                        child: const Text('Set User ID'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearUserId,
                        child: const Text('Clear User ID'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Topics Section
          _buildSectionCard(
            title: 'Topic Subscriptions',
            icon: Icons.topic,
            children: [
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic Name',
                  hintText: 'e.g., news, promotions, updates',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _subscribeTopic,
                      icon: const Icon(Icons.add),
                      label: const Text('Subscribe'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _unsubscribeTopic,
                      icon: const Icon(Icons.remove),
                      label: const Text('Unsubscribe'),
                    ),
                  ),
                ],
              ),
              if (_subscribedTopics.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const Text('Subscribed Topics:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _subscribedTopics.map((topic) {
                    return Chip(
                      label: Text(topic),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _unsubscribeFromTopic(topic),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Received Messages Section
          _buildSectionCard(
            title: 'Received Messages (${_messages.length})',
            icon: Icons.message,
            children: [
              if (_messages.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No messages yet', style: TextStyle(color: Colors.grey)),
                        Text('Send a push from the console', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                ...(_messages.take(10).map((msg) => _buildMessageTile(msg))),
              if (_messages.length > 10)
                TextButton(
                  onPressed: () => _showAllMessages(),
                  child: Text('View all ${_messages.length} messages'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(RiviumPushMessage message) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: message.silent ? Colors.grey : Colors.blue,
        child: Icon(
          message.silent ? Icons.notifications_off : Icons.notifications,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(message.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(message.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: message.imageUrl != null ? const Icon(Icons.image, size: 16) : null,
      onTap: () => _showMessageDetails(message),
    );
  }

  void _showMessageDetails(RiviumPushMessage message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
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
                Text(message.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(message.body),
                const SizedBox(height: 16),
                if (message.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.imageUrl!,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildDetailRow('Silent', message.silent.toString()),
                _buildDetailRow('Message ID', message.messageId ?? 'N/A'),
                _buildDetailRow('Campaign ID', message.campaignId ?? 'N/A'),
                _buildDetailRow('Deep Link', message.deepLink ?? 'N/A'),
                _buildDetailRow('Sound', message.sound ?? 'default'),
                _buildDetailRow('Badge', message.badge?.toString() ?? 'N/A'),
                if (message.data != null) ...[
                  const SizedBox(height: 8),
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
                      message.data.toString(),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
                if (message.actions != null && message.actions!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Actions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...message.actions!.map((action) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.touch_app, size: 20),
                    title: Text(action.title),
                    subtitle: Text('ID: ${action.id}'),
                  )),
                ],
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Actions
  Future<void> _register() async {
    try {
      await _riviumPushService.register(
        userId: _userIdController.text.isNotEmpty ? _userIdController.text : null,
        metadata: {'platform': 'flutter_example'},
      );
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device registered successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    }
  }

  Future<void> _unregister() async {
    try {
      await _riviumPushService.unregister();
      setState(() {
        _isRegistered = false;
        _deviceId = null;
        _subscribedTopics.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device unregistered')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unregister failed: $e')),
        );
      }
    }
  }

  Future<void> _setUserId() async {
    if (_userIdController.text.isEmpty) return;
    try {
      await _riviumPushService.setUserId(_userIdController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ID set to: ${_userIdController.text}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Set user ID failed: $e')),
        );
      }
    }
  }

  Future<void> _clearUserId() async {
    try {
      await _riviumPushService.clearUserId();
      _userIdController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User ID cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clear user ID failed: $e')),
        );
      }
    }
  }

  Future<void> _subscribeTopic() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    try {
      await _riviumPushService.subscribeTopic(topic);
      setState(() => _subscribedTopics.add(topic));
      _topicController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscribed to: $topic')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscribe failed: $e')),
        );
      }
    }
  }

  Future<void> _unsubscribeTopic() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    await _unsubscribeFromTopic(topic);
    _topicController.clear();
  }

  Future<void> _unsubscribeFromTopic(String topic) async {
    try {
      await _riviumPushService.unsubscribeTopic(topic);
      setState(() => _subscribedTopics.remove(topic));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unsubscribed from: $topic')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unsubscribe failed: $e')),
        );
      }
    }
  }

  void _copyDeviceId() {
    if (_deviceId != null) {
      Clipboard.setData(ClipboardData(text: _deviceId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device ID copied to clipboard')),
      );
    }
  }

  void _showAllMessages() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Messages (${_messages.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _messages.clear());
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _buildMessageTile(_messages[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
