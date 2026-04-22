import 'package:flutter/material.dart';
import 'package:rivium_push/rivium_push.dart';

import '../services/rivium_push_service.dart';
import 'ab_testing_screen.dart';
import 'inapp_messages_screen.dart';
import 'inbox_screen.dart';
import 'push_notifications_screen.dart';
// VoIP temporarily disabled - pods not publicly available yet
// import 'voip_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final RiviumPushMessage? initialMessage;

  const HomeScreen({super.key, this.initialMessage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _riviumPushService = RiviumPushService.instance;

  @override
  void initState() {
    super.initState();

    // Handle initial message if app was launched from notification
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInitialMessageDialog(widget.initialMessage!);
      });
    }

    // Listen for notification taps while app is running (foreground)
    // Use the new method that also checks for pending taps
    _riviumPushService.setNotificationTappedCallback((message) {
      debugPrint('[HomeScreen] onNotificationTapped callback triggered: ${message.title}');
      // Use a small delay to ensure the app is fully in foreground and UI is settled
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          debugPrint('[HomeScreen] Showing dialog after delay...');
          _showInitialMessageDialog(message);
        } else {
          debugPrint('[HomeScreen] Widget not mounted after delay');
        }
      });
    });

    // Trigger in-app messages on app open
    _riviumPushService.triggerInAppOnAppOpen();

    // Check actual connection state (in case callback was missed)
    _checkConnectionState();
  }

  Future<void> _checkConnectionState() async {
    final connected = await _riviumPushService.checkConnection();
    if (connected != _riviumPushService.connectionState.value) {
      _riviumPushService.connectionState.value = connected;
    }
  }

  @override
  void dispose() {
    // Clean up callback using the setter method
    _riviumPushService.setNotificationTappedCallback(null);
    super.dispose();
  }

  void _showInitialMessageDialog(RiviumPushMessage message) {
    debugPrint('[HomeScreen] _showInitialMessageDialog called: ${message.title}');
    debugPrint('[HomeScreen] mounted=$mounted');
    debugPrint('[HomeScreen] context.mounted=${context.mounted}');

    if (!mounted) {
      debugPrint('[HomeScreen] Widget not mounted, cannot show dialog');
      return;
    }

    try {
      debugPrint('[HomeScreen] About to call showDialog...');
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          debugPrint('[HomeScreen] Dialog builder executing...');
          try {
            final dialog = AlertDialog(
              title: Text('Notification: ${message.title}'),
              content: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(message.body),
                    if (message.imageUrl != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: Image.network(
                          message.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ],
                    if (message.data != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Data: ${message.data}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
            debugPrint('[HomeScreen] Dialog widget created successfully');
            return dialog;
          } catch (e, st) {
            debugPrint('[HomeScreen] Error building dialog: $e');
            debugPrint('[HomeScreen] Stack: $st');
            return AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to show notification: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          }
        },
      ).then((_) {
        debugPrint('[HomeScreen] Dialog closed normally');
      }).catchError((error, stackTrace) {
        debugPrint('[HomeScreen] Dialog Future error: $error');
        debugPrint('[HomeScreen] Stack trace: $stackTrace');
      });
      debugPrint('[HomeScreen] showDialog() returned');
    } catch (e, stackTrace) {
      debugPrint('[HomeScreen] Exception calling showDialog: $e');
      debugPrint('[HomeScreen] Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RiviumPush Example'),
        actions: [
          // Connection status indicator
          ValueListenableBuilder<bool>(
            valueListenable: _riviumPushService.connectionState,
            builder: (context, connected, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  connected ? Icons.cloud_done : Icons.cloud_off,
                  color: connected ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          _buildStatusCard(),
          const SizedBox(height: 24),

          // Feature Cards
          const Text(
            'SDK Features',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildFeatureCard(
            icon: Icons.notifications_active,
            title: 'Push Notifications',
            subtitle: 'Send and receive push messages',
            color: Colors.blue,
            onTap: () => _navigateTo(const PushNotificationsScreen()),
          ),

          _buildFeatureCard(
            icon: Icons.message,
            title: 'In-App Messages',
            subtitle: 'Modal, banner, fullscreen messages',
            color: Colors.purple,
            onTap: () => _navigateTo(const InAppMessagesScreen()),
          ),

          _buildFeatureCard(
            icon: Icons.inbox,
            title: 'Inbox',
            subtitle: 'Message inbox with read/archive',
            color: Colors.orange,
            badge: _riviumPushService.unreadInboxCount,
            onTap: () => _navigateTo(const InboxScreen()),
          ),

          _buildFeatureCard(
            icon: Icons.science,
            title: 'A/B Testing',
            subtitle: 'Experiments and variants',
            color: Colors.teal,
            onTap: () => _navigateTo(const ABTestingScreen()),
          ),

          // VoIP temporarily disabled - pods not publicly available yet
          // _buildFeatureCard(
          //   icon: Icons.phone,
          //   title: 'VoIP Calls',
          //   subtitle: 'Native incoming call UI',
          //   color: Colors.green,
          //   onTap: () => _navigateTo(const VoIPScreen()),
          // ),

          _buildFeatureCard(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'SDK configuration and debug',
            color: Colors.grey,
            onTap: () => _navigateTo(const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Text(
                  'SDK Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildStatusRow('Initialized', _riviumPushService.isInitialized),
            ValueListenableBuilder<bool>(
              valueListenable: _riviumPushService.connectionState,
              builder: (context, connected, _) {
                return _buildStatusRow('Connected', connected);
              },
            ),
            FutureBuilder<String?>(
              future: _riviumPushService.getDeviceId(),
              builder: (context, snapshot) {
                return _buildInfoRow(
                  'Device ID',
                  snapshot.data ?? 'Not registered',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Icon(
                value ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: value ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(value ? 'Yes' : 'No'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    ValueNotifier<int>? badge,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: badge != null
            ? ValueListenableBuilder<int>(
                valueListenable: badge,
                builder: (context, count, _) {
                  if (count == 0) return const Icon(Icons.chevron_right);
                  return Badge(
                    label: Text('$count'),
                    child: const Icon(Icons.chevron_right),
                  );
                },
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}
