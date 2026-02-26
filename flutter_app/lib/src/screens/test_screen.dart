import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../services/ml_server_client.dart';
import 'results_screen.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final picker = ImagePicker();
  final client = MlServerClient();
  final frames = {
    'Neutral': CaptureFrame(label: 'Neutral'),
    'Smile': CaptureFrame(label: 'Smile'),
    'Anger': CaptureFrame(label: 'Anger'),
  };
  String? error;
  double avgLandmarkMs = 0;

  Future<void> _capture(String key) async {
    setState(() => error = null);
    try {
      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 95);
      if (file == null) return;
      final resp = await client.extractLandmarks(File(file.path));
      final quality = resp['quality'] as Map<String, dynamic>;
      final ok = quality['ok'] == true;
      final warnings = (quality['warnings'] as List).map((e) => '$e').toList();
      if (!ok) {
        setState(() {
          error = 'Capture rejected for $key: ${warnings.join(', ')}';
        });
        return;
      }

      final lmRaw = (resp['landmarks'] as List).cast<List>();
      final lm = lmRaw.map((e) => e.map((n) => (n as num).toDouble()).toList()).toList();
      final landmarkMs = ((resp['timing']?['landmark_ms'] as num?) ?? 0).toDouble();
      setState(() {
        frames[key]!
          ..imagePath = file.path
          ..landmarks = lm
          ..warnings = warnings
          ..landmarkMs = landmarkMs;
        final vals = frames.values.where((f) => f.landmarkMs != null).map((f) => f.landmarkMs!).toList();
        avgLandmarkMs = vals.isEmpty ? 0 : vals.reduce((a, b) => a + b) / vals.length;
      });
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  Future<void> _analyze() async {
    if (frames.values.any((f) => !f.ready)) {
      setState(() => error = 'Capture Neutral, Smile and Anger first.');
      return;
    }

    final out = await client.analyzeSession(
      neutral: frames['Neutral']!.landmarks!,
      smile: frames['Smile']!.landmarks!,
      anger: frames['Anger']!.landmarks!,
    );
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultsScreen(result: SessionResult(out), frames: frames)));
  }

  void _reset() {
    setState(() {
      for (final k in frames.keys) {
        frames[k] = CaptureFrame(label: k);
      }
      error = null;
      avgLandmarkMs = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAST Face - Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Neutral may already show asymmetry. Relative analysis measures movement deficit. Absolute analysis measures structural asymmetry.'),
            const SizedBox(height: 8),
            Text('Average landmark latency: ${avgLandmarkMs.toStringAsFixed(1)} ms'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: frames.entries.map((entry) {
                  final f = entry.value;
                  return Card(
                    child: ListTile(
                      title: Text(entry.key),
                      subtitle: Text(f.ready
                          ? 'Captured (468 landmarks). extraction=${(f.landmarkMs ?? 0).toStringAsFixed(1)}ms'
                          : 'Not captured'),
                      trailing: FilledButton(
                        onPressed: () => _capture(entry.key),
                        child: const Text('Capture'),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(onPressed: _analyze, child: const Text('Analyze')),
                OutlinedButton(onPressed: _reset, child: const Text('Reset')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
