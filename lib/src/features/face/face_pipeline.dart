import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/app_config.dart';
import 'face_models.dart';
import 'face_strings.dart';

abstract class LandmarksDetector {
  Future<FacialLandmarks> detect({
    required FaceExpression expression,
    Uint8List? frameBytes,
  });
}

class MockLandmarksDetector implements LandmarksDetector {
  @override
  Future<FacialLandmarks> detect({
    required FaceExpression expression,
    Uint8List? frameBytes,
  }) async {
    final int tick = DateTime.now().microsecondsSinceEpoch % 1000;
    final double noise = (tick / 1000) * 0.02;
    final double boost = expression == FaceExpression.smile
        ? 0.07
        : expression == FaceExpression.anger
            ? 0.06
            : 0.03;
    return FacialLandmarks(
      leftMouthCornerY: 0.48 + boost + noise,
      rightMouthCornerY: 0.44 + noise / 2,
      leftMouthWidth: 0.28 + noise,
      rightMouthWidth: 0.22 + boost,
      leftEyeOpen: 0.27 - noise / 2,
      rightEyeOpen: 0.31 + noise / 2,
      leftBrowY: 0.38,
      rightBrowY: 0.33 + (expression == FaceExpression.anger ? 0.03 : 0),
      midlineDeviation: 0.08 + boost / 4 + noise,
      yaw: 4 + noise * 20,
      pitch: 3 + noise * 15,
      roll: 5 + noise * 10,
      centerOffsetRatio: 0.08 + noise,
      brightness: 110,
      confidence: 0.91,
      landmarkCount: 42,
      source: DataSource.mock,
    );
  }
}

class RealLandmarksDetector implements LandmarksDetector {
  const RealLandmarksDetector(this.config);

  final FacePipelineConfig config;

  @override
  Future<FacialLandmarks> detect({
    required FaceExpression expression,
    Uint8List? frameBytes,
  }) async {
    if (frameBytes == null || frameBytes.isEmpty) {
      return _fallbackHeuristic(expression, null);
    }

    try {
      final Uri uri = Uri.parse(config.realLandmarksEndpoint);
      final http.Response response = await http
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, Object>{
              'expression': expression.name,
              'image_base64': base64Encode(frameBytes),
            }),
          )
          .timeout(Duration(milliseconds: config.realtimeRequestTimeoutMs));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackHeuristic(expression, frameBytes);
      }

      final Map<String, dynamic> payload =
          jsonDecode(response.body) as Map<String, dynamic>;

      return FacialLandmarks(
        leftMouthCornerY: _d(payload, 'leftMouthCornerY', 0.48),
        rightMouthCornerY: _d(payload, 'rightMouthCornerY', 0.44),
        leftMouthWidth: _d(payload, 'leftMouthWidth', 0.28),
        rightMouthWidth: _d(payload, 'rightMouthWidth', 0.24),
        leftEyeOpen: _d(payload, 'leftEyeOpen', 0.28),
        rightEyeOpen: _d(payload, 'rightEyeOpen', 0.30),
        leftBrowY: _d(payload, 'leftBrowY', 0.36),
        rightBrowY: _d(payload, 'rightBrowY', 0.35),
        midlineDeviation: _d(payload, 'midlineDeviation', 0.08),
        yaw: _d(payload, 'yaw', 0),
        pitch: _d(payload, 'pitch', 0),
        roll: _d(payload, 'roll', 0),
        centerOffsetRatio: _d(payload, 'centerOffsetRatio', 0.08),
        brightness: _d(payload, 'brightness', 100),
        confidence: _d(payload, 'confidence', 0.7),
        landmarkCount: (payload['landmarkCount'] as num?)?.toInt() ?? 24,
        source: DataSource.real,
      );
    } on TimeoutException {
      return _fallbackHeuristic(expression, frameBytes);
    } catch (_) {
      return _fallbackHeuristic(expression, frameBytes);
    }
  }

  double _d(Map<String, dynamic> map, String key, double fallback) {
    return (map[key] as num?)?.toDouble() ?? fallback;
  }

  FacialLandmarks _fallbackHeuristic(
    FaceExpression expression,
    Uint8List? frameBytes,
  ) {
    final img.Image? image =
        frameBytes == null ? null : img.decodeImage(frameBytes);
    if (image == null) {
      return FacialLandmarks(
        leftMouthCornerY: 0.49,
        rightMouthCornerY: 0.45,
        leftMouthWidth: 0.28,
        rightMouthWidth: 0.23,
        leftEyeOpen: 0.29,
        rightEyeOpen: 0.30,
        leftBrowY: 0.37,
        rightBrowY: 0.35,
        midlineDeviation: 0.08,
        yaw: 0,
        pitch: 0,
        roll: 0,
        centerOffsetRatio: 0.12,
        brightness: 70,
        confidence: 0.60,
        landmarkCount: 20,
        source: DataSource.fallback,
      );
    }

    final int width = image.width;
    final int height = image.height;

    double roiMean(double x0, double x1, double y0, double y1) {
      final int sx = (width * x0).toInt().clamp(0, width - 1);
      final int ex = (width * x1).toInt().clamp(1, width);
      final int sy = (height * y0).toInt().clamp(0, height - 1);
      final int ey = (height * y1).toInt().clamp(1, height);
      double sum = 0;
      int count = 0;
      for (int y = sy; y < ey; y += 4) {
        for (int x = sx; x < ex; x += 4) {
          final img.Pixel pixel = image.getPixel(x, y);
          final double lum =
              (pixel.r.toDouble() + pixel.g.toDouble() + pixel.b.toDouble()) /
                  3;
          sum += lum;
          count++;
        }
      }
      return sum / max(1, count);
    }

    final double leftFace = roiMean(0.15, 0.48, 0.10, 0.90);
    final double rightFace = roiMean(0.52, 0.85, 0.10, 0.90);
    final double upperFace = roiMean(0.15, 0.85, 0.10, 0.45);
    final double lowerFace = roiMean(0.15, 0.85, 0.55, 0.90);

    final double leftEyeRoi = roiMean(0.22, 0.40, 0.24, 0.40);
    final double rightEyeRoi = roiMean(0.60, 0.78, 0.24, 0.40);
    final double leftBrowRoi = roiMean(0.22, 0.40, 0.16, 0.24);
    final double rightBrowRoi = roiMean(0.60, 0.78, 0.16, 0.24);
    final double leftMouthRoi = roiMean(0.25, 0.45, 0.62, 0.80);
    final double rightMouthRoi = roiMean(0.55, 0.75, 0.62, 0.80);
    final double centerMouthRoi = roiMean(0.45, 0.55, 0.62, 0.80);

    final double globalBrightness = ((leftFace + rightFace + upperFace + lowerFace) / 4).clamp(0, 255);

    final double faceBias = (leftFace - rightFace) / max(1, leftFace + rightFace);
    final double verticalBias = (upperFace - lowerFace) / max(1, upperFace + lowerFace);

    final double eyeAsym = (leftEyeRoi - rightEyeRoi) / max(1, leftEyeRoi + rightEyeRoi);
    final double browAsym = (leftBrowRoi - rightBrowRoi) / max(1, leftBrowRoi + rightBrowRoi);
    final double mouthAsym = (leftMouthRoi - rightMouthRoi) / max(1, leftMouthRoi + rightMouthRoi);
    final double mouthCenterOffset =
        ((centerMouthRoi - ((leftMouthRoi + rightMouthRoi) / 2)).abs() / 255)
            .clamp(0, 1);

    final double expBoost = switch (expression) {
      FaceExpression.neutral => 0.00,
      FaceExpression.smile => 0.02,
      FaceExpression.anger => 0.02,
    };

    return FacialLandmarks(
      leftMouthCornerY: (0.46 + mouthAsym * 0.12 + expBoost).clamp(0, 1),
      rightMouthCornerY: (0.46 - mouthAsym * 0.12).clamp(0, 1),
      leftMouthWidth: (0.25 + expBoost + mouthAsym.abs() * 0.10).clamp(0, 1),
      rightMouthWidth: (0.25 + expBoost / 2 - mouthAsym * 0.06).clamp(0, 1),
      leftEyeOpen: (0.29 - eyeAsym * 0.15 - verticalBias.abs() * 0.03).clamp(0, 1),
      rightEyeOpen: (0.29 + eyeAsym * 0.15 - verticalBias.abs() * 0.03).clamp(0, 1),
      leftBrowY: (0.36 - browAsym * 0.12).clamp(0, 1),
      rightBrowY: (0.36 + browAsym * 0.12).clamp(0, 1),
      midlineDeviation: (faceBias.abs() * 0.20 + mouthCenterOffset * 0.60).clamp(0, 1),
      yaw: (faceBias * 40).clamp(-30, 30),
      pitch: (verticalBias * 28).clamp(-20, 20),
      roll: ((eyeAsym + browAsym) * 18).clamp(-15, 15),
      centerOffsetRatio: faceBias.abs().clamp(0, 1),
      brightness: globalBrightness,
      confidence: 0.75,
      landmarkCount: 28,
      source: DataSource.fallback,
    );
  }
}

abstract class PalsyClassifier {
  Future<ClassifierResult> classify({
    required FacialLandmarks landmarks,
    required GeometricMetrics metrics,
    Uint8List? frameBytes,
  });
}

class MockPalsyClassifier implements PalsyClassifier {
  @override
  Future<ClassifierResult> classify({
    required FacialLandmarks landmarks,
    required GeometricMetrics metrics,
    Uint8List? frameBytes,
  }) async {
    final double asymmetry = (metrics.mouthCornerDelta +
            metrics.eyeOpenDelta +
            metrics.midlineDeviation +
            metrics.browDelta) /
        4;
    final double prob = asymmetry.clamp(0, 1);
    return ClassifierResult(
      palsyProb: prob,
      label: prob > 0.5 ? 'palsy' : 'normal',
      source: DataSource.mock,
      modelType: 'mock-features',
    );
  }
}

class TFLitePalsyClassifier implements PalsyClassifier {
  TFLitePalsyClassifier(this.config);

  final FacePipelineConfig config;

  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset(config.tfliteModelAssetPath);
      final String labelsRaw =
          await rootBundle.loadString(config.tfliteLabelsAssetPath);
      _labels = labelsRaw
          .split('\n')
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      _interpreter = null;
      _labels = const <String>['normal', 'palsy'];
    }
  }

  @override
  Future<ClassifierResult> classify({
    required FacialLandmarks landmarks,
    required GeometricMetrics metrics,
    Uint8List? frameBytes,
  }) async {
    await _ensureLoaded();

    if (_interpreter == null) {
      final MockPalsyClassifier fallback = MockPalsyClassifier();
      final ClassifierResult result = await fallback.classify(
        landmarks: landmarks,
        metrics: metrics,
        frameBytes: frameBytes,
      );
      return ClassifierResult(
        palsyProb: result.palsyProb,
        label: result.label,
        source: DataSource.fallback,
        modelType: 'fallback-mock',
      );
    }

    final List<int> inputShape = _interpreter!.getInputTensor(0).shape;
    final List<int> outputShape = _interpreter!.getOutputTensor(0).shape;
    final bool isFeatureModel = inputShape.length == 2 && inputShape[1] <= 128;

    final dynamic input = isFeatureModel
        ? _buildFeaturesInput(inputShape, metrics, landmarks)
        : _buildImageInput(inputShape, frameBytes);

    final List<List<double>> output = List<List<double>>.generate(
      outputShape.first,
      (_) => List<double>.filled(outputShape.length > 1 ? outputShape[1] : 1, 0),
    );

    _interpreter!.run(input, output);

    final List<double> probs = output.first;
    final double palsyProb = _resolvePalsyProb(probs, _labels ?? <String>[]);
    final String label = palsyProb >= 0.5 ? 'palsy' : 'normal';

    return ClassifierResult(
      palsyProb: palsyProb.clamp(0, 1),
      label: label,
      source: DataSource.real,
      modelType: isFeatureModel ? 'tflite-features' : 'tflite-image',
    );
  }

  List<List<double>> _buildFeaturesInput(
    List<int> inputShape,
    GeometricMetrics metrics,
    FacialLandmarks landmarks,
  ) {
    final int featureCount = inputShape[1];
    final List<double> features = <double>[
      ...metrics.toFeatureVector(),
      landmarks.yaw / 30,
      landmarks.pitch / 30,
      landmarks.roll / 30,
      landmarks.brightness / 255,
      landmarks.confidence,
    ];

    final List<double> padded = List<double>.filled(featureCount, 0);
    for (int i = 0; i < min(featureCount, features.length); i++) {
      padded[i] = features[i];
    }
    return <List<double>>[padded];
  }

  List<List<List<List<double>>>> _buildImageInput(
    List<int> inputShape,
    Uint8List? frameBytes,
  ) {
    final int h = inputShape[1];
    final int w = inputShape[2];
    final img.Image? decoded =
        frameBytes == null ? null : img.decodeImage(frameBytes);
    final img.Image normalized = decoded == null
        ? img.Image(width: w, height: h)
        : img.copyResize(decoded, width: w, height: h);

    final List<List<List<double>>> one = List<List<List<double>>>.generate(
      h,
      (int y) => List<List<double>>.generate(
        w,
        (int x) {
          final img.Pixel p = normalized.getPixel(x, y);
          return <double>[p.r / 255, p.g / 255, p.b / 255];
        },
      ),
    );
    return <List<List<List<double>>>>[one];
  }

  double _resolvePalsyProb(List<double> probs, List<String> labels) {
    if (probs.isEmpty) return 0;
    if (probs.length == 1) return probs.first;

    int palsyIndex = labels.indexWhere(
      (String e) => e.toLowerCase().contains('palsy'),
    );
    if (palsyIndex < 0) palsyIndex = min(1, probs.length - 1);
    return probs[palsyIndex];
  }
}

class FacePipeline {
  const FacePipeline(this.config);

  final FacePipelineConfig config;

  List<String> qualityWarnings(FacialLandmarks l) {
    final List<String> warnings = <String>[];
    if (l.centerOffsetRatio > config.maxCenterOffsetRatio) {
      warnings.add(FaceStrings.uncenteredFace);
    }
    if (max(l.yaw.abs(), max(l.pitch.abs(), l.roll.abs())) >
        config.maxYawPitchRoll) {
      warnings.add(FaceStrings.badPose);
    }
    if (l.brightness < config.minBrightness) {
      warnings.add(FaceStrings.lowBrightness);
    }
    if (l.confidence < config.minLandmarkConfidence ||
        l.landmarkCount < config.minLandmarks) {
      warnings.add(FaceStrings.lowConfidence);
    }
    return warnings;
  }

  GeometricMetrics computeMetrics(
    FacialLandmarks current, {
    FacialLandmarks? baseline,
  }) {
    double signed(double a, double b, [double ba = 0, double bb = 0]) =>
        ((a - b) - (ba - bb));

    final double mouthCornerSigned = signed(
      current.leftMouthCornerY,
      current.rightMouthCornerY,
      baseline?.leftMouthCornerY ?? 0,
      baseline?.rightMouthCornerY ?? 0,
    );
    final double mouthWidthSigned = signed(
      current.leftMouthWidth,
      current.rightMouthWidth,
      baseline?.leftMouthWidth ?? 0,
      baseline?.rightMouthWidth ?? 0,
    );
    final double eyeOpenSigned = signed(
      current.leftEyeOpen,
      current.rightEyeOpen,
      baseline?.leftEyeOpen ?? 0,
      baseline?.rightEyeOpen ?? 0,
    );
    final double browSigned = signed(
      current.leftBrowY,
      current.rightBrowY,
      baseline?.leftBrowY ?? 0,
      baseline?.rightBrowY ?? 0,
    );
    final double midlineSigned =
        current.midlineDeviation - (baseline?.midlineDeviation ?? 0);

    return GeometricMetrics(
      mouthCornerDelta: mouthCornerSigned.abs(),
      mouthWidthDelta: mouthWidthSigned.abs(),
      eyeOpenDelta: eyeOpenSigned.abs(),
      browDelta: browSigned.abs(),
      midlineDeviation: midlineSigned.abs(),
      mouthCornerSigned: mouthCornerSigned,
      mouthWidthSigned: mouthWidthSigned,
      eyeOpenSigned: eyeOpenSigned,
      browSigned: browSigned,
      midlineSigned: midlineSigned,
    );
  }

  ExpressionResult fuse(
    GeometricMetrics m,
    ClassifierResult c,
    FacialLandmarks landmarks,
    FaceExpression expression,
  ) {
    double normalized(String key, double value) =>
        (value / (config.metricThresholds[key] ?? 0.1)).clamp(0, 2);

    final double mouthScore = ((normalized('mouthCornerDelta', m.mouthCornerDelta) +
                normalized('mouthWidthDelta', m.mouthWidthDelta)) /
            2) *
        50;
    final double eyesScore = normalized('eyeOpenDelta', m.eyeOpenDelta) * 50;
    final double browScore = normalized('browDelta', m.browDelta) * 50;
    final double midlineScore =
        normalized('midlineDeviation', m.midlineDeviation) * 50;

    final Map<String, double> weights = switch (expression) {
      FaceExpression.neutral => <String, double>{
          'mouth': 0.25,
          'eyes': 0.30,
          'brow': 0.20,
          'midline': 0.25,
        },
      FaceExpression.smile => <String, double>{
          'mouth': 0.45,
          'eyes': 0.20,
          'brow': 0.10,
          'midline': 0.25,
        },
      FaceExpression.anger => <String, double>{
          'mouth': 0.20,
          'eyes': 0.20,
          'brow': 0.35,
          'midline': 0.25,
        },
    };

    final double geom = (mouthScore * weights['mouth']! +
            eyesScore * weights['eyes']! +
            browScore * weights['brow']! +
            midlineScore * weights['midline']!)
        .clamp(0, 100);
    final double finalScore =
        (config.alpha * geom + (1 - config.alpha) * (c.palsyProb * 100))
            .clamp(0, 100);
    final FaceStatus status = finalScore < config.okMax
        ? FaceStatus.ok
        : finalScore <= config.obsMax
            ? FaceStatus.obs
            : FaceStatus.alert;

    final Map<String, double> zones = <String, double>{
      'boca': mouthScore,
      'ojos': eyesScore,
      'cejas': browScore,
      'línea media': midlineScore,
    };
    final String primary =
        zones.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final List<String> reasons = <String>[];
    if (m.mouthCornerDelta > (config.metricThresholds['mouthCornerDelta'] ?? 0)) {
      reasons.add(
        m.mouthCornerSigned >= 0
            ? 'Comisura izquierda más alta / derecha más baja'
            : 'Comisura derecha más alta / izquierda más baja',
      );
    }
    if (m.mouthWidthDelta > (config.metricThresholds['mouthWidthDelta'] ?? 0)) {
      reasons.add(
        m.mouthWidthSigned >= 0
            ? 'Sonrisa más amplia en lado izquierdo'
            : 'Sonrisa más amplia en lado derecho',
      );
    }
    if (m.eyeOpenDelta > (config.metricThresholds['eyeOpenDelta'] ?? 0)) {
      reasons.add(
        m.eyeOpenSigned >= 0
            ? 'Apertura ocular derecha reducida'
            : 'Apertura ocular izquierda reducida',
      );
    }
    if (m.browDelta > (config.metricThresholds['browDelta'] ?? 0)) {
      reasons.add(
        m.browSigned >= 0
            ? 'Ceja izquierda más alta que derecha'
            : 'Ceja derecha más alta que izquierda',
      );
    }
    if (m.midlineDeviation >
        (config.metricThresholds['midlineDeviation'] ?? 0)) {
      reasons.add(FaceStrings.reasonMidline);
    }

    if (landmarks.source != DataSource.real || c.source != DataSource.real) {
      reasons.add(
        FaceStrings.nonRealSourceWarning,
      );
    }

    return ExpressionResult(
      metrics: m,
      mouthScore: mouthScore,
      eyesScore: eyesScore,
      browScore: browScore,
      midlineScore: midlineScore,
      scoreGeom: geom,
      classifier: c,
      scoreFinal: finalScore,
      status: status,
      primaryZone: primary,
      reasons: reasons,
      landmarks: landmarks,
    );
  }
}
