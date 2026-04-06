import 'package:configbee_flutter/configbee_flutter.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _logger = Logger('AppLogger');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configbee Flutter SDK Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ConfigbeeDemo(),
    );
  }
}

class ConfigbeeDemo extends StatefulWidget {
  const ConfigbeeDemo({super.key});

  @override
  State<ConfigbeeDemo> createState() => _ConfigbeeDemoState();
}

class _ConfigbeeDemoState extends State<ConfigbeeDemo> {
  ConfigbeeClient? _configbee;
  bool _isLoading = true;
  String _statusMessage = 'Initializing Configbee...';

  @override
  void initState() {
    super.initState();
    _initializeConfigbee();
  }

  Future<void> _initializeConfigbee() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing Configbee...';
    });

    try {
      // Initialize Configbee client
      // Replace with your actual account, project, and environment IDs
      _configbee = ConfigbeeClient.init(
        ConfigbeeClientParams(
          accountId: "YOUR_ACCOUNT_ID",
          projectId: "YOUR_PROJECT_ID",
          environmentId: "YOUR_ENVIRONMENT_ID",
          onReady: () {
            setState(() {
              _statusMessage = 'Configbee is ready!';
              _isLoading = false;
            });
            _logger.info('Configbee onReady called');
          },
          onUpdate: () {
            setState(() {
              _statusMessage = 'Configuration updated!';
            });
            _logger.info('Configbee onUpdate called');
          },
        ),
      );

      // Wait for initialization with timeout
      final status = await _configbee!
          .waitToLoad(timeout: const Duration(milliseconds: 10000));

      if (status == CbStatus.active) {
        setState(() {
          _statusMessage = 'Configbee loaded successfully!';
          _isLoading = false;
        });
      } else if (status == CbStatus.error) {
        setState(() {
          _statusMessage = 'Failed to load Configbee';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
      _logger.severe('Error initializing Configbee!', e);
    }
  }

  @override
  void dispose() {
    _configbee?.dispose();
    super.dispose();
  }

  Widget _buildFeatureFlagsSection() {
    if (_configbee == null || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final flags = _configbee!.getAllFlags() ?? {};

    if (flags.isEmpty) {
      return const Center(
        child: Text('No feature flags configured'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: flags.length,
      itemBuilder: (context, index) {
        final entry = flags.entries.elementAt(index);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Switch(
              value: entry.value ?? false,
              onChanged: null, // Read-only
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfigurationsSection() {
    if (_configbee == null || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final numbers = _configbee!.getAllNumbers() ?? {};
    final texts = _configbee!.getAllTexts() ?? {};
    final jsons = _configbee!.getAllJsons() ?? {};

    final allConfigs = [
      ...numbers.entries.map((e) => MapEntry(e.key, 'Number: ${e.value}')),
      ...texts.entries.map((e) => MapEntry(e.key, 'Text: ${e.value}')),
      ...jsons.entries.map((e) => MapEntry(e.key, 'JSON: ${e.value}')),
    ];

    if (allConfigs.isEmpty) {
      return const Center(
        child: Text('No configurations available'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allConfigs.length,
      itemBuilder: (context, index) {
        final entry = allConfigs[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              entry.value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  void _showTargetingDialog() {
    final userIdController = TextEditingController();
    final segmentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Target Properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'Enter user ID',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: segmentController,
              decoration: const InputDecoration(
                labelText: 'User Segment',
                hintText: 'e.g., premium, free',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _configbee?.setTargetProperties({
                'user_id': userIdController.text,
                'user_segment': segmentController.text,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Target properties updated')),
              );
            },
            child: const Text('Set'),
          ),
          TextButton(
            onPressed: () {
              _configbee?.unsetTargetProperties();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Target properties cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configbee Flutter Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _showTargetingDialog,
            tooltip: 'Set Target Properties',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeConfigbee,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              margin: const EdgeInsets.all(16),
              color: _isLoading
                  ? Colors.orange[100]
                  : (_configbee?.status == CbStatus.active
                      ? Colors.green[100]
                      : Colors.red[100]),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _configbee?.status == CbStatus.active
                            ? Icons.check_circle
                            : Icons.error,
                        color: _configbee?.status == CbStatus.active
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${_configbee?.status.toString().split('.').last ?? 'unknown'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_statusMessage),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Feature Flags Section
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Feature Flags',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildFeatureFlagsSection(),

            // Configurations Section
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Configurations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildConfigurationsSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
