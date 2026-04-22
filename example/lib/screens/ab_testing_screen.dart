import 'package:flutter/material.dart';
import 'package:rivium_push/rivium_push.dart';

import '../services/rivium_push_service.dart';

class ABTestingScreen extends StatefulWidget {
  const ABTestingScreen({super.key});

  @override
  State<ABTestingScreen> createState() => _ABTestingScreenState();
}

class _ABTestingScreenState extends State<ABTestingScreen> {
  final _riviumPushService = RiviumPushService.instance;
  final _testIdController = TextEditingController();

  List<ABTestSummary> _activeTests = [];
  Map<String, ABTestVariant> _assignedVariants = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadActiveTests();
  }

  @override
  void dispose() {
    _testIdController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveTests() async {
    setState(() => _isLoading = true);
    try {
      final tests = await _riviumPushService.getActiveABTests();
      setState(() => _activeTests = tests);

      // Load assigned variants for each test
      for (final test in tests) {
        final variant = await _riviumPushService.getABTestVariant(test.id);
        if (variant != null) {
          setState(() => _assignedVariants[test.id] = variant);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tests: $e')),
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
        title: const Text('A/B Testing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveTests,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Manual Test Lookup
          _buildSectionCard(
            title: 'Manual Test Lookup',
            icon: Icons.search,
            children: [
              const Text(
                'Enter a test ID to fetch variant assignment:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _testIdController,
                decoration: const InputDecoration(
                  labelText: 'Test ID',
                  hintText: 'e.g., test_button_color_123',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _lookupVariant,
                      icon: const Icon(Icons.search),
                      label: const Text('Get Variant'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _forceRefreshVariant,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Force Refresh'),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Active Tests
          _buildSectionCard(
            title: 'Active Tests (${_activeTests.length})',
            icon: Icons.science,
            children: [
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_activeTests.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.science, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No active A/B tests', style: TextStyle(color: Colors.grey)),
                        Text('Create one in the console', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                ..._activeTests.map((test) => _buildTestTile(test)),
            ],
          ),

          const SizedBox(height: 16),

          // Assigned Variants
          if (_assignedVariants.isNotEmpty)
            _buildSectionCard(
              title: 'Your Assigned Variants',
              icon: Icons.assignment,
              children: _assignedVariants.entries
                  .map((entry) => _buildVariantTile(entry.key, entry.value))
                  .toList(),
            ),

          const SizedBox(height: 16),

          // Demo Section
          _buildSectionCard(
            title: 'A/B Testing Demo',
            icon: Icons.play_arrow,
            children: [
              const Text(
                'This section demonstrates how A/B test variants can affect UI:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildDemoContent(),
            ],
          ),

          const SizedBox(height: 16),

          // Info Section
          _buildSectionCard(
            title: 'How It Works',
            icon: Icons.info_outline,
            children: [
              _buildInfoTile(
                icon: Icons.shuffle,
                title: 'Variant Assignment',
                description: 'Users are randomly assigned to control or test variants',
              ),
              _buildInfoTile(
                icon: Icons.analytics,
                title: 'Tracking',
                description: 'Track impressions, opens, and clicks for each variant',
              ),
              _buildInfoTile(
                icon: Icons.cached,
                title: 'Caching',
                description: 'Variants are cached locally for consistent experience',
              ),
              _buildInfoTile(
                icon: Icons.bar_chart,
                title: 'Statistics',
                description: 'View conversion rates and statistical significance',
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

  Widget _buildTestTile(ABTestSummary test) {
    final hasVariant = _assignedVariants.containsKey(test.id);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: hasVariant ? Colors.teal : Colors.grey,
        child: Icon(
          hasVariant ? Icons.check : Icons.science,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(test.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${test.id}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          Text(
            'Variants: ${test.variantCount}${test.hasControlGroup ? ' (with control)' : ''}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline),
        onPressed: () => _showTestDetails(test),
      ),
      onTap: () => _showTestDetails(test),
    );
  }

  Widget _buildVariantTile(String testId, ABTestVariant variant) {
    final isControl = variant.isControlGroup;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isControl ? Colors.blue : Colors.orange,
        child: Text(
          isControl ? 'C' : 'T',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(variant.variantName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Test: $testId', style: const TextStyle(fontSize: 11)),
          Text(
            isControl ? 'Control Group' : 'Test Variant',
            style: TextStyle(
              color: isControl ? Colors.blue : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _handleVariantAction(action, testId, variant),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'impression',
            child: Text('Track Impression'),
          ),
          const PopupMenuItem(
            value: 'opened',
            child: Text('Track Opened'),
          ),
          const PopupMenuItem(
            value: 'clicked',
            child: Text('Track Clicked'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.teal.withValues(alpha: 0.1),
        child: Icon(icon, color: Colors.teal, size: 20),
      ),
      title: Text(title),
      subtitle: Text(description),
    );
  }

  Widget _buildDemoContent() {
    // Demo with hypothetical button_color test
    final buttonColorVariant = _assignedVariants['button_color_test'];
    final buttonColor = _getButtonColorFromVariant(buttonColorVariant);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              const Text(
                'CTA Button Demo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                buttonColorVariant != null
                    ? 'Variant: ${buttonColorVariant.variantName}'
                    : 'No variant assigned',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (buttonColorVariant != null) {
                    _trackClick('button_color_test', buttonColorVariant.variantId);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Button clicked!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Sign Up Now'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'The button color above would be determined by the A/B test variant. '
          'Control might show blue, while the test variant might show green.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Color _getButtonColorFromVariant(ABTestVariant? variant) {
    if (variant == null) return Colors.blue;

    // Parse variant content for button color
    final content = variant.content;
    if (content?.data != null && content!.data!['buttonColor'] != null) {
      final colorHex = content.data!['buttonColor'] as String;
      try {
        return Color(int.parse(colorHex.replaceAll('#', '0xFF')));
      } catch (_) {
        return Colors.blue;
      }
    }

    // Default based on control vs variant
    return variant.isControlGroup ? Colors.blue : Colors.green;
  }

  void _showTestDetails(ABTestSummary test) {
    final variant = _assignedVariants[test.id];

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
                Text(test.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildDetailRow('Test ID', test.id),
                _buildDetailRow('Variants', '${test.variantCount}'),
                _buildDetailRow('Has Control', test.hasControlGroup ? 'Yes' : 'No'),
                const SizedBox(height: 16),
                if (variant != null) ...[
                  const Text('Your Assignment:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: variant.isControlGroup
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: variant.isControlGroup ? Colors.blue : Colors.orange,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variant.variantName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          variant.isControlGroup ? 'Control Group' : 'Test Variant',
                          style: TextStyle(
                            color: variant.isControlGroup ? Colors.blue : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Variant ID: ${variant.variantId}',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                        if (variant.content != null) ...[
                          const SizedBox(height: 8),
                          const Text('Content:', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            variant.content.toString(),
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Track Events:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _trackImpression(test.id, variant.variantId),
                          child: const Text('Impression'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _trackOpened(test.id, variant.variantId),
                          child: const Text('Opened'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _trackClick(test.id, variant.variantId),
                          child: const Text('Clicked'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _getVariantForTest(test.id);
                      },
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Get Variant Assignment'),
                    ),
                  ),
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
            width: 80,
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
      case 'clear_cache':
        await _clearCache();
        break;
    }
  }

  void _handleVariantAction(String action, String testId, ABTestVariant variant) {
    switch (action) {
      case 'impression':
        _trackImpression(testId, variant.variantId);
        break;
      case 'opened':
        _trackOpened(testId, variant.variantId);
        break;
      case 'clicked':
        _trackClick(testId, variant.variantId);
        break;
    }
  }

  Future<void> _lookupVariant() async {
    final testId = _testIdController.text.trim();
    if (testId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a test ID')),
      );
      return;
    }

    await _getVariantForTest(testId);
  }

  Future<void> _forceRefreshVariant() async {
    final testId = _testIdController.text.trim();
    if (testId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a test ID')),
      );
      return;
    }

    await _getVariantForTest(testId, forceRefresh: true);
  }

  Future<void> _getVariantForTest(String testId, {bool forceRefresh = false}) async {
    try {
      final variant = await _riviumPushService.getABTestVariant(
        testId,
        forceRefresh: forceRefresh,
      );

      if (variant != null) {
        setState(() => _assignedVariants[testId] = variant);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Assigned to: ${variant.variantName}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No variant found for this test')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _trackImpression(String testId, String variantId) async {
    try {
      await _riviumPushService.trackABTestImpression(testId, variantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impression tracked')),
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

  Future<void> _trackOpened(String testId, String variantId) async {
    try {
      await RiviumPush.trackABTestOpened(testId, variantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opened event tracked')),
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

  Future<void> _trackClick(String testId, String variantId) async {
    try {
      await _riviumPushService.trackABTestClicked(testId, variantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Click tracked')),
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
      await RiviumPush.clearABTestCache();
      setState(() => _assignedVariants.clear());
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
}
