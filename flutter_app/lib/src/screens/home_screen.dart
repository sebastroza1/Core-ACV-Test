import 'package:flutter/material.dart';

import '../services/ml_server_client.dart';
import 'test_screen.dart';
import 'validation_mode_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final client = MlServerClient();
  bool training = false;
  final List<String> logs = [];

  Future<void> _train() async {
    setState(() {
      training = true;
      logs.clear();
      logs.add('Starting /train ...');
    });
    try {
      final out = await client.train();
      setState(() {
        logs.add('Training finished: ${out['report']}');
      });
    } catch (e) {
      setState(() => logs.add('Error: $e'));
    } finally {
      setState(() => training = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAST Face - Home')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: training ? null : _train,
                  icon: const Icon(Icons.model_training),
                  label: const Text('Train Model'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TestScreen())),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Go to Test'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ValidationModeScreen())),
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Validation Mode'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Neutral may already show asymmetry. Relative analysis measures movement deficit. Absolute analysis measures structural asymmetry.',
            ),
            const SizedBox(height: 8),
            const Text(
              'This is NOT a medical diagnosis. If you suspect stroke, seek emergency medical care.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Training progress'),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(logs[i]),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
