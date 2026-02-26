import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/validation_store.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.result, required this.frames});

  final SessionResult result;
  final Map<String, CaptureFrame> frames;

  @override
  Widget build(BuildContext context) {
    final absolute = result.raw['absolute'] as Map<String, dynamic>;
    final relative = result.raw['relative'] as Map<String, dynamic>;
    final finalSection = result.raw['final'] as Map<String, dynamic>;

    Widget absTile(String name) {
      final item = absolute[name] as Map<String, dynamic>;
      final zone = item['zone'] as Map<String, dynamic>;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('palsy_prob_abs: ${(item['palsy_prob_abs'] as num).toStringAsFixed(3)}'),
            Text('geom_abs_score: ${(item['geom_abs_score'] as num).toStringAsFixed(1)}'),
            Text('abs_score: ${(item['abs_score'] as num).toStringAsFixed(1)}'),
            Text('explanation: ${item['explanation']}'),
            _zoneBars(zone),
          ]),
        ),
      );
    }

    Widget relTile(String key, String title) {
      final item = relative[key] as Map<String, dynamic>;
      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text(
            'movement_deficit_score: ${(item['movement_deficit_score'] as num).toStringAsFixed(1)}\n'
            'metric_deltas: ${item['metric_deltas']}\n'
            'top_changed_landmarks: ${(item['top_changed_landmarks'] as List).take(10).toList()}\n'
            '${item['explanation']}',
          ),
        ),
      );
    }

    final neutral = frames['Neutral']?.landmarks;
    final smile = frames['Smile']?.landmarks;

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Final score: ${(finalSection['score'] as num).toStringAsFixed(1)} (${finalSection['status']})',
              style: Theme.of(context).textTheme.titleLarge),
          Text('Avg TFLite inference: ${((finalSection['latency_ms']?['avg_tflite_inference_ms'] as num?) ?? 0).toStringAsFixed(2)} ms'),
          const SizedBox(height: 12),
          const Text('ABSOLUTE analysis (Neutral can also be abnormal)'),
          absTile('neutral'),
          absTile('smile'),
          absTile('anger'),
          const SizedBox(height: 12),
          const Text('RELATIVE movement analysis'),
          relTile('smile_vs_neutral', 'Smile vs Neutral'),
          relTile('anger_vs_neutral', 'Anger vs Neutral'),
          if (neutral != null && smile != null) ...[
            const SizedBox(height: 12),
            const Text('Debug overlay (mesh + asymmetric landmarks)'),
            SizedBox(
              height: 250,
              child: Card(
                child: CustomPaint(
                  painter: _MeshPainter(
                    neutral: neutral,
                    expr: smile,
                    topChanged: (relative['smile_vs_neutral']['top_changed_landmarks'] as List)
                        .map((e) => (e['index'] as num).toInt())
                        .toSet(),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              ValidationStore.add(result);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session added to Validation Mode')));
            },
            child: const Text('Add to Validation Mode dataset'),
          ),
          const SizedBox(height: 12),
          const Text(
            'This is NOT a medical diagnosis. If you suspect stroke, seek emergency medical care.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _zoneBars(Map<String, dynamic> zone) {
    Widget bar(String label, num value) {
      final v = value.toDouble().clamp(0, 100);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ${v.toStringAsFixed(1)}'),
        LinearProgressIndicator(value: v / 100),
      ]);
    }

    return Column(
      children: [
        bar('mouth', zone['mouth_score'] as num),
        bar('eyes', zone['eyes_score'] as num),
        bar('brow', zone['brow_score'] as num),
        bar('midline', zone['midline_score'] as num),
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({required this.neutral, required this.expr, required this.topChanged});

  final List<List<double>> neutral;
  final List<List<double>> expr;
  final Set<int> topChanged;

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()..color = Colors.blue.withOpacity(0.35);
    final paintExpr = Paint()..color = Colors.green.withOpacity(0.4);
    final paintTop = Paint()..color = Colors.red;

    for (var i = 0; i < neutral.length; i++) {
      final nx = neutral[i][0] * size.width;
      final ny = neutral[i][1] * size.height;
      final ex = expr[i][0] * size.width;
      final ey = expr[i][1] * size.height;
      canvas.drawCircle(Offset(nx, ny), 1.0, paintBase);
      canvas.drawCircle(Offset(ex, ey), 1.0, paintExpr);
      if (topChanged.contains(i)) {
        canvas.drawCircle(Offset(ex, ey), 2.2, paintTop);
        canvas.drawLine(Offset(nx, ny), Offset(ex, ey), paintTop..strokeWidth = 0.8);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) => true;
}
