import 'package:flutter/material.dart';
import 'package:rivium_push/rivium_push.dart';

import '../services/rivium_push_service.dart';
import '../widgets/inapp_message_widget.dart';

class InAppMessagesScreen extends StatefulWidget {
  const InAppMessagesScreen({super.key});

  @override
  State<InAppMessagesScreen> createState() => _InAppMessagesScreenState();
}

class _InAppMessagesScreenState extends State<InAppMessagesScreen> {
  final _riviumPushService = RiviumPushService.instance;
  final _eventController = TextEditingController();

  List<InAppMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
    _fetchMessages();
  }

  void _setupCallbacks() {
    _riviumPushService.onInAppMessageReady = (message) {
      _showInAppMessage(message);
    };

    _riviumPushService.onInAppButtonClick = (message, button) {
      _handleButtonClick(message, button);
    };
  }

  @override
  void dispose() {
    _eventController.dispose();
    _riviumPushService.onInAppMessageReady = null;
    _riviumPushService.onInAppButtonClick = null;
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _riviumPushService.fetchInAppMessages();
      setState(() => _messages = messages);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch messages: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showInAppMessage(InAppMessage message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => InAppMessageWidget(
        message: message,
        onButtonClick: (button) {
          Navigator.pop(context);
          _handleButtonClick(message, button);
        },
        onDismiss: () {
          Navigator.pop(context);
          _riviumPushService.dismissInAppMessage();
        },
      ),
    );
  }

  void _handleButtonClick(InAppMessage message, InAppButton button) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Button clicked: ${button.text} (${button.action.value})'),
        action: button.value != null
            ? SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // Handle deep link or URL
                  debugPrint('Opening: ${button.value}');
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('In-App Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMessages,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Trigger Events Section
          _buildSectionCard(
            title: 'Trigger Events',
            icon: Icons.play_arrow,
            children: [
              const Text(
                'Trigger in-app messages based on events:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _triggerAppOpen,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('App Open'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _triggerSessionStart,
                      icon: const Icon(Icons.login),
                      label: const Text('Session Start'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _eventController,
                decoration: const InputDecoration(
                  labelText: 'Custom Event Name',
                  hintText: 'e.g., purchase_complete, level_up',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _triggerCustomEvent,
                  icon: const Icon(Icons.send),
                  label: const Text('Trigger Custom Event'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Available Messages Section
          _buildSectionCard(
            title: 'Available Messages (${_messages.length})',
            icon: Icons.message,
            children: [
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_messages.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No in-app messages', style: TextStyle(color: Colors.grey)),
                        Text('Create one in the console', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                ..._messages.map((msg) => _buildMessageTile(msg)),
            ],
          ),

          const SizedBox(height: 16),

          // Message Types Info
          _buildSectionCard(
            title: 'Message Types',
            icon: Icons.info_outline,
            children: [
              _buildTypeTile(
                icon: Icons.crop_square,
                title: 'Modal',
                description: 'Centered dialog with overlay',
                color: Colors.blue,
              ),
              _buildTypeTile(
                icon: Icons.horizontal_rule,
                title: 'Banner',
                description: 'Top or bottom banner',
                color: Colors.green,
              ),
              _buildTypeTile(
                icon: Icons.fullscreen,
                title: 'Fullscreen',
                description: 'Full screen takeover',
                color: Colors.purple,
              ),
              _buildTypeTile(
                icon: Icons.credit_card,
                title: 'Card',
                description: 'Floating card style',
                color: Colors.orange,
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

  Widget _buildMessageTile(InAppMessage message) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _getTypeColor(message.type),
        child: Icon(_getTypeIcon(message.type), color: Colors.white, size: 20),
      ),
      title: Text(message.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Type: ${message.type.value}'),
          Text('Trigger: ${message.triggerType.value}', style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline),
        color: Colors.grey,
        onPressed: () => _showMessageDetails(message),
      ),
      // Tap on message row shows the styled in-app message
      onTap: () => _showMessage(message),
    );
  }

  Widget _buildTypeTile({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(description),
    );
  }

  Color _getTypeColor(InAppMessageType type) {
    switch (type) {
      case InAppMessageType.modal:
        return Colors.blue;
      case InAppMessageType.banner:
        return Colors.green;
      case InAppMessageType.fullscreen:
        return Colors.purple;
      case InAppMessageType.card:
        return Colors.orange;
    }
  }

  IconData _getTypeIcon(InAppMessageType type) {
    switch (type) {
      case InAppMessageType.modal:
        return Icons.crop_square;
      case InAppMessageType.banner:
        return Icons.horizontal_rule;
      case InAppMessageType.fullscreen:
        return Icons.fullscreen;
      case InAppMessageType.card:
        return Icons.credit_card;
    }
  }

  void _showMessageDetails(InAppMessage message) {
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
                Text(message.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildDetailRow('ID', message.id),
                _buildDetailRow('Type', message.type.value),
                _buildDetailRow('Trigger', message.triggerType.value),
                if (message.triggerEvent != null)
                  _buildDetailRow('Event', message.triggerEvent!),
                _buildDetailRow('Max Impressions', message.maxImpressions.toString()),
                _buildDetailRow('Min Sessions', message.minSessionCount.toString()),
                _buildDetailRow('Delay (sec)', message.delaySeconds.toString()),
                _buildDetailRow('Priority', message.priority.toString()),
                const SizedBox(height: 16),
                const Text('Content:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Title: ${message.content.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Body: ${message.content.body}'),
                      if (message.content.imageUrl != null) ...[
                        const SizedBox(height: 8),
                        Text('Image: ${message.content.imageUrl}', style: const TextStyle(fontSize: 12)),
                      ],
                      if (message.content.buttons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Buttons: ${message.content.buttons.length}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage(message);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Preview Message'),
                  ),
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
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Actions
  Future<void> _triggerAppOpen() async {
    await _riviumPushService.triggerInAppOnAppOpen();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Triggered: App Open')),
      );
    }
  }

  Future<void> _triggerSessionStart() async {
    await RiviumPush.triggerInAppOnSessionStart();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Triggered: Session Start')),
      );
    }
  }

  Future<void> _triggerCustomEvent() async {
    final event = _eventController.text.trim();
    if (event.isEmpty) return;

    await _riviumPushService.triggerInAppEvent(
      event,
      properties: {'source': 'example_app'},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Triggered: $event')),
      );
    }
  }

  Future<void> _showMessage(InAppMessage message) async {
    await _riviumPushService.showInAppMessage(message.id);
  }
}
