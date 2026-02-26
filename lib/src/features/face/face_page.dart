import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _useMockLandmarks = false;
  bool _useMockClassifier = false;

  late final FacePipeline _pipeline;
  final Map<FaceExpression, CaptureSnapshot> _captures =
      <FaceExpression, CaptureSnapshot>{};
  final Map<FaceExpression, ExpressionResult> _results =
      <FaceExpression, ExpressionResult>{};
  final List<String> _warnings = <String>[];

  @override
  void initState() {
    super.initState();
    _pipeline = FacePipeline(widget.config.facePipeline);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final List<CameraDescription> cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _cameraError = FaceStrings.noCamera);
        return;
      }
      _cameraController = CameraController(
        cams.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } on MissingPluginException {
      setState(() {
        _cameraError =
            '${FaceStrings.cameraPluginMissing}\n${FaceStrings.cameraFallback}\n${FaceStrings.cameraHelp}';
      });
    } catch (e) {
      setState(() => _cameraError = 'Error de cámara: $e');
    }
  }

  Future<void> _capture(FaceExpression expression) async {
    final LandmarksDetector detector = _useMockLandmarks
        ? MockLandmarksDetector()
        : RealLandmarksDetector(widget.config.facePipeline);
    final Uint8List? frameBytes = await _captureFrameBytes();

    final FacialLandmarks landmarks = await detector.detect(
      expression: expression,
      frameBytes: frameBytes,
    );

    final List<String> warnings = _pipeline.qualityWarnings(landmarks);

    setState(() {
      _warnings
        ..clear()
        ..addAll(warnings);
    });

    if (warnings.isNotEmpty) return;

    setState(() {
      _captures[expression] = CaptureSnapshot(
        expression: expression,
        landmarks: landmarks,
        frameBytes: frameBytes,
        capturedAt: DateTime.now(),
      );
    });
  }

  Future<Uint8List?> _captureFrameBytes() async {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        return null;
      }
      final XFile frame = await _cameraController!.takePicture();
      return frame.readAsBytes();
    } catch (_) {
      return null;
    }
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

    final CaptureSnapshot baselineCapture = _captures[FaceExpression.neutral]!;
    final PalsyClassifier classifier = _useMockClassifier
        ? MockPalsyClassifier()
        : TFLitePalsyClassifier(widget.config.facePipeline);

    _results.clear();

    for (final FaceExpression expression in FaceExpression.values) {
      final CaptureSnapshot? sample = _captures[expression];
      if (sample == null) continue;
      final GeometricMetrics metrics = _pipeline.computeMetrics(
        sample.landmarks,
        baseline:
            expression == FaceExpression.neutral ? null : baselineCapture.landmarks,
      );
      final ClassifierResult cls = await classifier.classify(
        landmarks: sample.landmarks,
        metrics: metrics,
        frameBytes: sample.frameBytes,
      );
      _results[expression] =
          _pipeline.fuse(metrics, cls, sample.landmarks, expression);
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
                      ElevatedButton(
                        onPressed: () => _capture(FaceExpression.neutral),
                        child: const Text(AppStrings.captureNeutral),
                      ),
                      ElevatedButton(
                        onPressed: () => _capture(FaceExpression.smile),
                        child: const Text(AppStrings.captureSmile),
                      ),
                      ElevatedButton(
                        onPressed: () => _capture(FaceExpression.anger),
                        child: const Text(AppStrings.captureAnger),
                      ),
                      FilledButton(
                        onPressed: _calculate,
                        child: const Text(AppStrings.calculate),
                      ),
                      OutlinedButton(
                        onPressed: _reset,
                        child: const Text(AppStrings.reset),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    value: _useMockLandmarks,
                    title: const Text(AppStrings.mockLandmarks),
                    onChanged: (bool value) {
                      setState(() {
                        _useMockLandmarks = value;
                        _warnings.add(
                          value
                              ? 'Landmarks en modo MOCK.'
                              : 'Landmarks en modo REAL (HTTP local con fallback heurístico).',
                        );
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _useMockClassifier,
                    title: const Text(AppStrings.mockClassifier),
                    onChanged: (bool value) {
                      setState(() {
                        _useMockClassifier = value;
                        _warnings.add(
                          value
                              ? 'Clasificador en modo MOCK.'
                              : 'Clasificador en modo REAL (TFLite con fallback mock).',
                        );
                      });
                    },
                  ),
                  Text(
                    AppStrings.disclaimer,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 4),
                  const Text(FaceStrings.linesExpressionNote),
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
    if (_cameraError != null) {
      return Container(
        width: double.infinity,
        color: Colors.black12,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(_cameraError!, textAlign: TextAlign.center),
      );
    }
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    try {
      return CameraPreview(_cameraController!);
    } on MissingPluginException {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text(FaceStrings.previewUnavailable),
      );
    }
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
                  children: _warnings
                      .map((String e) => Text('${FaceStrings.warningPrefix} $e'))
                      .toList(),
                ),
              ),
            ),
          _buildOverallCard(),
          ...FaceExpression.values.map(_buildExpressionCard),
        ],
      ),
    );
  }

  Widget _buildOverallCard() {
    final bool hasAll = FaceExpression.values
        .every((FaceExpression expression) => _results[expression] != null);

    return Card(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              FaceStrings.overallTitle,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (!hasAll) const Text(FaceStrings.overallPending),
            if (hasAll) ...<Widget>[
              Text(
                '${FaceStrings.overallScoreLabel}: ${_overallScore().toStringAsFixed(1)}',
              ),
              Text(
                '${FaceStrings.overallStatusLabel}: ${_overallStateLabel()}',
                style: TextStyle(
                  color: _overallStateColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text('${FaceStrings.overallSummaryLabel}: ${_overallSummary()}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpressionCard(FaceExpression expression) {
    final ExpressionResult? result = _results[expression];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _expressionTitle(expression),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (result == null) const Text(FaceStrings.noCalculation),
            if (result != null) ...<Widget>[
              Text('Estado: ${_expressionStateLabel(result.status)}'),
              Text(
                'Interpretación: ${_expressionStateDescription(result.status)}',
              ),
              const SizedBox(height: 4),
              Text(
                '${FaceStrings.sourceLandmarks}: ${_sourceLabel(result.landmarks.source)}',
              ),
              Text(
                '${FaceStrings.sourceClassifier}: ${_sourceLabel(result.classifier.source)} (${result.classifier.modelType})',
              ),
              const SizedBox(height: 4),
              Text(
                '${FaceStrings.finalScoreLabel}: ${result.scoreFinal.toStringAsFixed(1)} / 100',
              ),
              Text(
                '${FaceStrings.geomScoreLabel}: ${result.scoreGeom.toStringAsFixed(1)} / 100',
              ),
              Text(
                '${FaceStrings.classifierLabel}: ${(result.classifier.palsyProb * 100).toStringAsFixed(1)}% (${result.classifier.label})',
              ),
              const SizedBox(height: 6),
              Text(
                '${FaceStrings.zonesLabel}: boca ${result.mouthScore.toStringAsFixed(1)}, ojos ${result.eyesScore.toStringAsFixed(1)}, cejas ${result.browScore.toStringAsFixed(1)}, línea media ${result.midlineScore.toStringAsFixed(1)}',
              ),
              const SizedBox(height: 6),
              Text(
                '${FaceStrings.metricMouthCorner}: ${result.metrics.mouthCornerDelta.toStringAsFixed(3)}',
              ),
              Text(
                '${FaceStrings.metricMouthWidth}: ${result.metrics.mouthWidthDelta.toStringAsFixed(3)}',
              ),
              Text(
                '${FaceStrings.metricEyeOpen}: ${result.metrics.eyeOpenDelta.toStringAsFixed(3)}',
              ),
              Text(
                '${FaceStrings.metricBrow}: ${result.metrics.browDelta.toStringAsFixed(3)}',
              ),
              Text(
                '${FaceStrings.metricMidline}: ${result.metrics.midlineDeviation.toStringAsFixed(3)}',
              ),
              const SizedBox(height: 6),
              Text(
                '${FaceStrings.debugLabel}: ${FaceStrings.debugYawPitchRoll} ${result.landmarks.yaw.toStringAsFixed(1)}/${result.landmarks.pitch.toStringAsFixed(1)}/${result.landmarks.roll.toStringAsFixed(1)}, ${FaceStrings.debugBrightness} ${result.landmarks.brightness.toStringAsFixed(1)}, ${FaceStrings.debugLandmarksCount} ${result.landmarks.landmarkCount}, ${FaceStrings.debugConfidence} ${result.landmarks.confidence.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 6),
              Text('${FaceStrings.statusMessagePrefix} ${result.primaryZone}.'),
              Text('${FaceStrings.reasonsLabel} ${_anomaliesText(result)}'),
            ],
          ],
        ),
      ),
    );
  }

  String _sourceLabel(DataSource source) {
    switch (source) {
      case DataSource.mock:
        return 'MOCK';
      case DataSource.real:
        return 'REAL';
      case DataSource.fallback:
        return 'FALLBACK';
    }
  }

  String _expressionTitle(FaceExpression expression) {
    switch (expression) {
      case FaceExpression.neutral:
        return FaceStrings.expressionNeutral;
      case FaceExpression.smile:
        return FaceStrings.expressionSmile;
      case FaceExpression.anger:
        return FaceStrings.expressionAnger;
    }
  }

  String _expressionStateLabel(FaceStatus status) {
    switch (status) {
      case FaceStatus.ok:
        return FaceStrings.healthHealthy;
      case FaceStatus.obs:
        return FaceStrings.healthAnomalies;
      case FaceStatus.alert:
        return FaceStrings.healthSevere;
    }
  }

  String _expressionStateDescription(FaceStatus status) {
    switch (status) {
      case FaceStatus.ok:
        return FaceStrings.descHealthy;
      case FaceStatus.obs:
        return FaceStrings.descObs;
      case FaceStatus.alert:
        return FaceStrings.descAlert;
    }
  }

  String _anomaliesText(ExpressionResult result) {
    if (result.reasons.isEmpty) {
      return FaceStrings.noAnomalies;
    }
    return result.reasons.join(', ');
  }

  double _overallScore() {
    final Iterable<double> scores =
        FaceExpression.values.map((FaceExpression e) => _results[e]!.scoreFinal);
    return scores.reduce((double a, double b) => a + b) / 3;
  }

  String _overallStateLabel() {
    final int alertCount = _results.values
        .where((ExpressionResult r) => r.status == FaceStatus.alert)
        .length;
    final int obsCount = _results.values
        .where((ExpressionResult r) => r.status == FaceStatus.obs)
        .length;

    if (alertCount > 0) return FaceStrings.healthSevere;
    if (obsCount > 0) return FaceStrings.healthAnomalies;
    return FaceStrings.healthHealthy;
  }

  Color _overallStateColor() {
    final String label = _overallStateLabel();
    if (label == FaceStrings.healthSevere) return Colors.red.shade700;
    if (label == FaceStrings.healthAnomalies) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  String _overallSummary() {
    final List<String> keyFindings = <String>[];
    for (final FaceExpression expression in FaceExpression.values) {
      final ExpressionResult result = _results[expression]!;
      if (result.status != FaceStatus.ok) {
        keyFindings.add(
          '${_expressionTitle(expression)}: ${result.primaryZone} (${_anomaliesText(result)})',
        );
      }
    }
    if (keyFindings.isEmpty) {
      return FaceStrings.overallAllGood;
    }
    return keyFindings.join(' | ');
  }
}
