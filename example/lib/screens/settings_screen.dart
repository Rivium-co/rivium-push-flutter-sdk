import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rivium_push/rivium_push.dart';

import '../services/rivium_push_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _riviumPushService = RiviumPushService.instance;

  RiviumPushLogLevel _currentLogLevel = RiviumPushLogLevel.debug;
  bool _analyticsEnabled = true;
  String? _deviceId;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final deviceId = await _riviumPushService.getDeviceId();
    final isConnected = await _riviumPushService.checkConnection();

    setState(() {
      _deviceId = deviceId;
      _isConnected = isConnected;
      _analyticsEnabled = RiviumPush.isAnalyticsEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadState,
          ),
        ],
      ),
      body: ListView(
        children: [
          // SDK Status Section
          _buildSectionHeader('SDK Status'),
          _buildStatusTile(
            icon: Icons.check_circle,
            title: 'Initialized',
            value: _riviumPushService.isInitialized,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _riviumPushService.connectionState,
            builder: (context, connected, _) {
              return _buildStatusTile(
                icon: Icons.cloud,
                title: 'Connected',
                value: connected,
              );
            },
          ),
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.perm_device_info),
            ),
            title: const Text('Device ID'),
            subtitle: Text(
              _deviceId ?? 'Not registered',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            trailing: _deviceId != null
                ? IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _deviceId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device ID copied')),
                      );
                    },
                  )
                : null,
          ),

          const Divider(),

          // Logging Section
          _buildSectionHeader('Logging'),
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.bug_report),
            ),
            title: const Text('Log Level'),
            subtitle: Text(_currentLogLevel.name),
            trailing: DropdownButton<RiviumPushLogLevel>(
              value: _currentLogLevel,
              underline: const SizedBox(),
              items: RiviumPushLogLevel.values.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level.name),
                );
              }).toList(),
              onChanged: (level) {
                if (level != null) {
                  _setLogLevel(level);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: RiviumPushLogLevel.values.map((level) {
                final isSelected = level == _currentLogLevel;
                return ChoiceChip(
                  label: Text(level.name),
                  selected: isSelected,
                  onSelected: (_) => _setLogLevel(level),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          const Divider(),

          // Analytics Section
          _buildSectionHeader('Analytics'),
          SwitchListTile(
            secondary: const CircleAvatar(
              child: Icon(Icons.analytics),
            ),
            title: const Text('Analytics Enabled'),
            subtitle: const Text('Send SDK events to your analytics service'),
            value: _analyticsEnabled,
            onChanged: (value) {
              setState(() => _analyticsEnabled = value);
              if (value) {
                // Re-enable analytics (would need to set handler again)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Analytics enabled')),
                );
              } else {
                RiviumPush.disableAnalytics();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Analytics disabled')),
                );
              }
            },
          ),

          const Divider(),

          // Cache Management Section
          _buildSectionHeader('Cache Management'),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.inbox, color: Colors.white),
            ),
            title: const Text('Clear Inbox Cache'),
            subtitle: const Text('Remove cached inbox messages'),
            onTap: _clearInboxCache,
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.science, color: Colors.white),
            ),
            title: const Text('Clear A/B Test Cache'),
            subtitle: const Text('Reset variant assignments'),
            onTap: _clearABTestCache,
          ),

          const Divider(),

          // Debug Actions Section
          _buildSectionHeader('Debug Actions'),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.network_check, color: Colors.white),
            ),
            title: const Text('Check Connection'),
            subtitle: Text(_isConnected ? 'Connected' : 'Disconnected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _checkConnection,
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.purple,
              child: Icon(Icons.play_arrow, color: Colors.white),
            ),
            title: const Text('Trigger App Open Event'),
            subtitle: const Text('Simulate app open for in-app messages'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _triggerAppOpen,
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.login, color: Colors.white),
            ),
            title: const Text('Trigger Session Start'),
            subtitle: const Text('Simulate session start event'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _triggerSessionStart,
          ),

          const Divider(),

          // Danger Zone
          _buildSectionHeader('Danger Zone', color: Colors.red),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.red,
              child: Icon(Icons.logout, color: Colors.white),
            ),
            title: const Text('Unregister Device'),
            subtitle: const Text('Remove this device from push notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _confirmUnregister,
          ),

          const SizedBox(height: 32),

          // SDK Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'RiviumPush SDK',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Part of Rivium Ecosystem',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'flutter_example v1.0.0',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: color ?? Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required bool value,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: value ? Colors.green : Colors.red,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title),
      trailing: Icon(
        value ? Icons.check_circle : Icons.cancel,
        color: value ? Colors.green : Colors.red,
      ),
    );
  }

  // Actions
  Future<void> _setLogLevel(RiviumPushLogLevel level) async {
    try {
      await RiviumPush.setLogLevel(level);
      setState(() => _currentLogLevel = level);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Log level set to: ${level.name}')),
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

  Future<void> _clearInboxCache() async {
    try {
      await RiviumPush.clearInboxCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inbox cache cleared')),
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

  Future<void> _clearABTestCache() async {
    try {
      await RiviumPush.clearABTestCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A/B test cache cleared')),
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

  Future<void> _checkConnection() async {
    final isConnected = await _riviumPushService.checkConnection();
    setState(() => _isConnected = isConnected);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isConnected ? 'Connected to server' : 'Not connected'),
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _triggerAppOpen() async {
    try {
      await _riviumPushService.triggerInAppOnAppOpen();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App open event triggered')),
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

  Future<void> _triggerSessionStart() async {
    try {
      await RiviumPush.triggerInAppOnSessionStart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session start event triggered')),
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

  Future<void> _confirmUnregister() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unregister Device'),
        content: const Text(
          'This will remove this device from push notifications. '
          'You will stop receiving notifications until you register again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unregister'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _unregister();
    }
  }

  Future<void> _unregister() async {
    try {
      await _riviumPushService.unregister();
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device unregistered')),
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
}
