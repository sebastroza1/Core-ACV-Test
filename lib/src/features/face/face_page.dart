import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/app_strings.dart';
import 'face_models.dart';
import 'face_pipeline.dart';
import 'face_strings.dart';

class FacePage extends StatefulWidget {
  const FacePage({super.key, required this.config});

  final AppConfig config;

  @override
  State<FacePage> createState() => _FacePageState();
}

class _FacePageState extends State<FacePage> {
  CameraController? _cameraController;
  String? _cameraError;
  bool _useMockLandmarks = true;
  bool _useMockClassifier = true;

  final FacePipeline _pipeline = FacePipeline(AppConfig.desktopDefault.facePipeline);
  final Map<FaceExpression, FacialLandmarks> _captures = <FaceExpression, FacialLandmarks>{};
  final Map<FaceExpression, ExpressionResult> _results = <FaceExpression, ExpressionResult>{};
  final List<String> _warnings = <String>[];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final List<CameraDescription> cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _cameraError = FaceStrings.noCamera);
        return;
      }
      _cameraController = CameraController(cams.first, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _cameraError = 'Error de cámara: $e');
    }
  }

  Future<void> _capture(FaceExpression expression) async {
    final LandmarksDetector detector = MockLandmarksDetector(expression);
    if (!_useMockLandmarks) {
      _warnings.add('Modo Real Landmarks pendiente; usando mock.');
    }
    final FacialLandmarks landmarks = await detector.detect();
    final List<String> warnings = _pipeline.qualityWarnings(landmarks);
    setState(() {
      _warnings
        ..clear()
        ..addAll(warnings);
    });
    if (warnings.isNotEmpty) return;
    setState(() => _captures[expression] = landmarks);
  }

  Future<void> _calculate() async {
    if (!_captures.containsKey(FaceExpression.neutral)) {
      setState(() {
        _warnings
          ..clear()
          ..add(AppStrings.needsNeutral);
      });
      return;
    }

    final FacialLandmarks baseline = _captures[FaceExpression.neutral]!;
    final PalsyClassifier classifier = MockPalsyClassifier();
    if (!_useMockClassifier) {
      _warnings.add('Modo Real Classifier pendiente; usando mock.');
    }
    for (final FaceExpression expression in FaceExpression.values) {
      final FacialLandmarks? sample = _captures[expression];
      if (sample == null) continue;
      final GeometricMetrics metrics = _pipeline.computeMetrics(
        sample,
        baseline: expression == FaceExpression.neutral ? null : baseline,
      );
      final ClassifierResult c = await classifier.classify(sample);
      _results[expression] = _pipeline.fuse(metrics, c);
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _captures.clear();
      _results.clear();
      _warnings.clear();
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.faceTitle)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: _buildPreview()),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ElevatedButton(onPressed: () => _capture(FaceExpression.neutral), child: const Text(AppStrings.captureNeutral)),
                      ElevatedButton(onPressed: () => _capture(FaceExpression.smile), child: const Text(AppStrings.captureSmile)),
                      ElevatedButton(onPressed: () => _capture(FaceExpression.anger), child: const Text(AppStrings.captureAnger)),
                      FilledButton(onPressed: _calculate, child: const Text(AppStrings.calculate)),
                      OutlinedButton(onPressed: _reset, child: const Text(AppStrings.reset)),
                    ],
                  ),
                  SwitchListTile(
                    value: _useMockLandmarks,
                    title: const Text(AppStrings.mockLandmarks),
                    onChanged: (bool value) => setState(() => _useMockLandmarks = value),
                  ),
                  SwitchListTile(
                    value: _useMockClassifier,
                    title: const Text(AppStrings.mockClassifier),
                    onChanged: (bool value) => setState(() => _useMockClassifier = value),
                  ),
                  Text(AppStrings.disclaimer, style: const TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_cameraError != null) return Center(child: Text(_cameraError!));
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return CameraPreview(_cameraController!);
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_warnings.isNotEmpty)
            Card(
              color: Colors.amber.shade100,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _warnings.map((String e) => Text('${FaceStrings.warningPrefix} $e')).toList(),
                ),
              ),
            ),
          ...FaceExpression.values.map(_buildExpressionCard),
        ],
      ),
    );
  }

  Widget _buildExpressionCard(FaceExpression expression) {
    final ExpressionResult? result = _results[expression];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(expression.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
          if (result == null) const Text(FaceStrings.noCalculation),
          if (result != null) ...<Widget>[
            Text('mouthCornerDelta: ${result.metrics.mouthCornerDelta.toStringAsFixed(3)}'),
            Text('mouthWidthDelta: ${result.metrics.mouthWidthDelta.toStringAsFixed(3)}'),
            Text('eyeOpenDelta: ${result.metrics.eyeOpenDelta.toStringAsFixed(3)}'),
            Text('browDelta: ${result.metrics.browDelta.toStringAsFixed(3)}'),
            Text('midlineDeviation: ${result.metrics.midlineDeviation.toStringAsFixed(3)}'),
            Text('mouth_score: ${result.mouthScore.toStringAsFixed(1)} | eyes_score: ${result.eyesScore.toStringAsFixed(1)}'),
            Text('brow_score: ${result.browScore.toStringAsFixed(1)} | midline_score: ${result.midlineScore.toStringAsFixed(1)}'),
            Text('score_geom: ${result.scoreGeom.toStringAsFixed(1)}'),
            Text('palsy_prob: ${result.classifier.palsyProb.toStringAsFixed(2)} (${result.classifier.label})'),
            Text('score_final: ${result.scoreFinal.toStringAsFixed(1)} | estado: ${result.status.name.toUpperCase()}'),
            Text('${FaceStrings.statusMessagePrefix} ${result.primaryZone}.'),
            Text('${FaceStrings.reasonsLabel} ${result.reasons.join(', ')}'),
          ],
        ]),
      ),
    );
  }
}
