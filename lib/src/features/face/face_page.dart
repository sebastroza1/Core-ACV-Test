import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import 'face_analyzer.dart';

class FacePage extends StatefulWidget {
  const FacePage({super.key, required this.config});

  final AppConfig config;

  @override
  State<FacePage> createState() => _FacePageState();
}

class _FacePageState extends State<FacePage> {
  late final FaceAsymmetryAnalyzer _analyzer;

  double _leftEye = 0.5;
  double _rightEye = 0.5;
  double _leftMouth = 0.5;
  double _rightMouth = 0.5;

  @override
  void initState() {
    super.initState();
    _analyzer = FaceAsymmetryAnalyzer(config: widget.config);
  }

  @override
  Widget build(BuildContext context) {
    final FaceAnalysisResult result = _analyzer.evaluate(
      leftEye: _leftEye,
      rightEye: _rightEye,
      leftMouth: _leftMouth,
      rightMouth: _rightMouth,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Asimetría facial')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Umbral clínico: ${widget.config.faceThreshold.toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            _MetricSlider(
              label: 'Apertura ojo izquierdo',
              value: _leftEye,
              onChanged: (double value) => setState(() => _leftEye = value),
            ),
            _MetricSlider(
              label: 'Apertura ojo derecho',
              value: _rightEye,
              onChanged: (double value) => setState(() => _rightEye = value),
            ),
            _MetricSlider(
              label: 'Comisura izquierda',
              value: _leftMouth,
              onChanged: (double value) => setState(() => _leftMouth = value),
            ),
            _MetricSlider(
              label: 'Comisura derecha',
              value: _rightMouth,
              onChanged: (double value) => setState(() => _rightMouth = value),
            ),
            const SizedBox(height: 16),
            Text('Score: ${result.asymmetryScore.toStringAsFixed(3)}'),
            const SizedBox(height: 8),
            Text(
              result.isAboveThreshold
                  ? '⚠️ Posible asimetría detectada'
                  : '✅ Simetría dentro de rango',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricSlider extends StatelessWidget {
  const _MetricSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label),
        Slider(value: value, onChanged: onChanged),
      ],
    );
  }
}
