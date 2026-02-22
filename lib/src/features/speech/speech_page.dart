import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import 'speech_analyzer.dart';

class SpeechPage extends StatefulWidget {
  const SpeechPage({super.key, required this.config});

  final AppConfig config;

  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
  late final TextEditingController _controller;
  late final SpeechAsymmetryAnalyzer _analyzer;

  SpeechAnalysisResult? _result;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _analyzer = SpeechAsymmetryAnalyzer(config: widget.config);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analyze() {
    setState(() {
      _result = _analyzer.evaluate(_controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asimetría del habla')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Frase objetivo: "${widget.config.targetTongueTwister}"'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Transcripción de voz',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _analyze,
              child: const Text('Evaluar trabalenguas'),
            ),
            if (_result != null) ...<Widget>[
              const SizedBox(height: 16),
              Text('Pronunciación correcta: ${(_result!.pronouncedRatio * 100).toStringAsFixed(1)}%'),
              Text('Índice de asimetría: ${_result!.asymmetryIndex.toStringAsFixed(3)}'),
              const SizedBox(height: 8),
              Text(
                _result!.isAboveThreshold
                    ? '⚠️ Probable asimetría en el habla'
                    : '✅ Habla dentro de rango',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
