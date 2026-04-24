import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rivium_push/rivium_push.dart';
import 'package:rivium_push_voip/rivium_push_voip.dart';

import '../services/rivium_push_service.dart';

class VoIPScreen extends StatefulWidget {
  const VoIPScreen({super.key});

  @override
  State<VoIPScreen> createState() => _VoIPScreenState();
}

class _VoIPScreenState extends State<VoIPScreen> {
  bool _isVoipEnabled = false;
  String _voipStatus = 'Not Initialized';
  Color _statusColor = Colors.grey;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _restoreVoipState();
  }

  Future<void> _restoreVoipState() async {
    if (RiviumPushVoIP.isInitialized) {
      setState(() => _isVoipEnabled = true);
      _updateStatus();
      return;
    }
    // Check if VoIP was previously enabled
    final wasEnabled = await RiviumPushVoIP.isConfigured();
    if (wasEnabled) {
      await _initializeVoip();
    } else {
      _updateStatus();
    }
  }

  void _updateStatus() {
    setState(() {
      if (RiviumPushVoIP.isInitialized) {
        _voipStatus = 'VoIP Active';
        _statusColor = Colors.green;
      } else {
        _voipStatus = 'VoIP Disabled';
        _statusColor = Colors.grey;
      }
    });
  }

  void _addLog(String text) {
    setState(() {
      final time = TimeOfDay.now().format(context);
      _logs.add('[$time] $text');
      if (_logs.length > 50) _logs.removeAt(0);
    });
  }

  Future<void> _toggleVoip(bool enabled) async {
    setState(() => _isVoipEnabled = enabled);

    if (enabled) {
      await _initializeVoip();
    } else {
      _addLog('VoIP disabled');
      _updateStatus();
    }
  }

  Future<void> _initializeVoip() async {
    try {
      // Initialize VoIP plugin (handles PushKit independently from Push SDK)
      await RiviumPushVoIP.init(
        config: const RiviumPushVoIPConfig(
          appName: 'RiviumPush Example',
          callTimeout: 30,
        ),
        onCallAccepted: (callData) {
          _addLog('Call accepted: ${callData.callerName}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Call accepted: ${callData.callerName}')),
            );
          }
        },
        onCallDeclined: (callData) {
          _addLog('Call declined: ${callData.callerName}');
        },
        onCallTimeout: (callData) {
          _addLog('Call timed out: ${callData.callerName}');
        },
        onCallError: (error) {
          _addLog('Error: $error');
        },
      );
      // Set API key so VoIP plugin can send PushKit token to server
      final deviceId = await RiviumPush.getDeviceId();
      await RiviumPushVoIP.setApiKey(
        apiKey: RiviumPushService.apiKey,
        deviceId: deviceId,
      );

      _addLog('VoIP initialized + API key set');
      setState(() => _isVoipEnabled = true);
      _updateStatus();
    } catch (e) {
      _addLog('Init error: $e');
    }
  }

  void _simulateCall() {
    if (!RiviumPushVoIP.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initialize VoIP first')),
      );
      return;
    }

    final callData = CallData(
      callId: DateTime.now().millisecondsSinceEpoch.toString(),
      callerName: 'Test Caller',
      mediaType: CallMediaType.audio,
      receivedAt: DateTime.now(),
    );

    RiviumPushVoIP.showIncomingCall(callData);
    _addLog('Simulated call: ${callData.callId}');
  }

  void _checkStatus() {
    final status = StringBuffer()
      ..writeln('Initialized: ${RiviumPushVoIP.isInitialized}')
      ..writeln('Config: ${RiviumPushVoIP.config?.appName ?? "N/A"}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('VoIP Status'),
        content: Text(status.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    _addLog('Status checked');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VoIP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _voipStatus,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Toggle Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Enable VoIP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Switch(
                        value: _isVoipEnabled,
                        onChanged: _toggleVoip,
                      ),
                    ],
                  ),
                  const Text(
                    'Initialize VoIP SDK for incoming call handling. Required for apps with real calling features.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Requires real calling feature for App Store.',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text('Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _simulateCall,
                  icon: const Icon(Icons.phone),
                  label: const Text('Simulate Call'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.1), foregroundColor: Colors.green),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _checkStatus,
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Check Status'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.withValues(alpha: 0.1), foregroundColor: Colors.teal),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How VoIP Works', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildInfoTile('Standard APNs', 'Regular notifications. 100% App Store compliant.', Colors.blue),
                  _buildInfoTile('VoIP Push', 'Instant delivery when app killed. Requires real calling feature.', Colors.green),
                  _buildInfoTile('CallKit (iOS)', 'Native incoming call UI. Required by Apple since iOS 13.', Colors.orange),
                  _buildInfoTile('CallStyle (Android)', 'Full-screen incoming call notification on Android 12+.', Colors.purple),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Logs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Call Log', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => setState(() => _logs.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
          Container(
            height: 150,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _logs.isEmpty ? 'No logs yet' : _logs.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
