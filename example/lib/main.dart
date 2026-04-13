import 'package:configbee_flutter/configbee_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final cb = ConfigbeeClient.init(ConfigbeeClientParams(
    accountId: "YOUR_ACCOUNT_ID",
    projectId: "YOUR_PROJECT_ID",
    environmentId: "YOUR_ENVIRONMENT_ID",
  ));
  runApp(ConfigbeeProvider(client: cb, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Configbee Flutter Demo',
      home: ConfigbeeDemo(),
    );
  }
}

class ConfigbeeDemo extends StatelessWidget {
  const ConfigbeeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configbee Flutter Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Status ---
          ConfigbeeBuilder(
            builder: (context, status, client) => Text(
              'Status: ${status.name}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: status == CbStatus.active ? Colors.green : Colors.orange,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Feature Flag ---
          const Text('Feature Flag', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ConfigbeeFlag(
            flagKey: 'new_checkout_ui',
            onLoading: const Center(child: CircularProgressIndicator()),
            onEnabled: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.green[100],
              child: const Text('✅ new_checkout_ui is ENABLED'),
            ),
            onDisabled: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red[100],
              child: const Text('❌ new_checkout_ui is DISABLED'),
            ),
          ),

          const SizedBox(height: 24),

          // --- Config Values ---
          const Text('Config Values', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ConfigbeeBuilder(
            builder: (context, status, client) {
              if (status != CbStatus.active) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = [
                ...?client.getAllFlags()?.entries.map((e) => '🚩 ${e.key}: ${e.value}'),
                ...?client.getAllTexts()?.entries.map((e) => '📝 ${e.key}: ${e.value}'),
                ...?client.getAllNumbers()?.entries.map((e) => '🔢 ${e.key}: ${e.value}'),
                ...?client.getAllJsons()?.entries.map((e) => '📦 ${e.key}: ${e.value}'),
              ];
              if (entries.isEmpty) return const Text('No config values found.');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(e),
                )).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // --- Targeting ---
          const Text('Targeting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => ConfigbeeProvider.of(context).setTargetProperties({
                  'user_id': 'user_123',
                  'plan': 'premium',
                }),
                child: const Text('Set User'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => ConfigbeeProvider.of(context).unsetTargetProperties(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConfigbeeBuilder(
            builder: (context, status, client) => Text(
              'Targeting status: ${client.targetingStatus.name}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
