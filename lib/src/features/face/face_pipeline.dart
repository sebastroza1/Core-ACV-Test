import 'dart:math';

import '../../core/app_config.dart';
import 'face_models.dart';
import 'face_strings.dart';

abstract class LandmarksDetector {
  Future<FacialLandmarks> detect();
}

class MockLandmarksDetector implements LandmarksDetector {
  MockLandmarksDetector(this.expression);

  final FaceExpression expression;

  @override
  Future<FacialLandmarks> detect() async {
    final double boost = expression == FaceExpression.smile
        ? 0.07
        : expression == FaceExpression.anger
            ? 0.06
            : 0.03;
    return FacialLandmarks(
      leftMouthCornerY: 0.48 + boost,
      rightMouthCornerY: 0.44,
      leftMouthWidth: 0.28,
      rightMouthWidth: 0.22 + boost,
      leftEyeOpen: 0.27,
      rightEyeOpen: 0.31,
      leftBrowY: 0.38,
      rightBrowY: 0.33 + (expression == FaceExpression.anger ? 0.03 : 0),
      midlineDeviation: 0.08 + boost / 4,
      yaw: 4,
      pitch: 3,
      roll: 5,
      centerOffsetRatio: 0.08,
      brightness: 110,
      confidence: 0.91,
      landmarkCount: 42,
    );
  }
}

abstract class PalsyClassifier {
  Future<ClassifierResult> classify(FacialLandmarks landmarks);
}

class MockPalsyClassifier implements PalsyClassifier {
  @override
  Future<ClassifierResult> classify(FacialLandmarks landmarks) async {
    final double asymmetry = ((landmarks.leftMouthCornerY - landmarks.rightMouthCornerY).abs() +
            (landmarks.leftEyeOpen - landmarks.rightEyeOpen).abs() +
            landmarks.midlineDeviation) /
        3;
    final double prob = asymmetry.clamp(0, 1);
    return ClassifierResult(palsyProb: prob, label: prob > 0.5 ? 'palsy' : 'normal');
  }
}

class FacePipeline {
  const FacePipeline(this.config);

  final FacePipelineConfig config;

  List<String> qualityWarnings(FacialLandmarks l) {
    final List<String> warnings = <String>[];
    if (l.centerOffsetRatio > config.maxCenterOffsetRatio) warnings.add(FaceStrings.uncenteredFace);
    if (max(l.yaw.abs(), max(l.pitch.abs(), l.roll.abs())) > config.maxYawPitchRoll) {
      warnings.add(FaceStrings.badPose);
    }
    if (l.brightness < config.minBrightness) warnings.add(FaceStrings.lowBrightness);
    if (l.confidence < config.minLandmarkConfidence || l.landmarkCount < config.minLandmarks) {
      warnings.add(FaceStrings.lowConfidence);
    }
    return warnings;
  }

  GeometricMetrics computeMetrics(FacialLandmarks current, {FacialLandmarks? baseline}) {
    double delta(double a, double b, [double ba = 0, double bb = 0]) => ((a - b) - (ba - bb)).abs();

    return GeometricMetrics(
      mouthCornerDelta: delta(current.leftMouthCornerY, current.rightMouthCornerY,
          baseline?.leftMouthCornerY ?? 0, baseline?.rightMouthCornerY ?? 0),
      mouthWidthDelta: delta(current.leftMouthWidth, current.rightMouthWidth,
          baseline?.leftMouthWidth ?? 0, baseline?.rightMouthWidth ?? 0),
      eyeOpenDelta: delta(current.leftEyeOpen, current.rightEyeOpen, baseline?.leftEyeOpen ?? 0,
          baseline?.rightEyeOpen ?? 0),
      browDelta: delta(
          current.leftBrowY, current.rightBrowY, baseline?.leftBrowY ?? 0, baseline?.rightBrowY ?? 0),
      midlineDeviation: (current.midlineDeviation - (baseline?.midlineDeviation ?? 0)).abs(),
    );
  }

  ExpressionResult fuse(GeometricMetrics m, ClassifierResult c) {
    double normalized(String key, double value) => (value / (config.metricThresholds[key] ?? 0.1)).clamp(0, 2);

    final double mouthScore = ((normalized('mouthCornerDelta', m.mouthCornerDelta) +
                normalized('mouthWidthDelta', m.mouthWidthDelta)) /
            2) *
        50;
    final double eyesScore = normalized('eyeOpenDelta', m.eyeOpenDelta) * 50;
    final double browScore = normalized('browDelta', m.browDelta) * 50;
    final double midlineScore = normalized('midlineDeviation', m.midlineDeviation) * 50;
    final double geom = ((mouthScore + eyesScore + browScore + midlineScore) / 4).clamp(0, 100);
    final double finalScore =
        (config.alpha * geom + (1 - config.alpha) * (c.palsyProb * 100)).clamp(0, 100);
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
    final String primary = zones.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final List<String> reasons = <String>[];
    if (m.mouthCornerDelta > (config.metricThresholds['mouthCornerDelta'] ?? 0)) {
      reasons.add(FaceStrings.reasonMouth);
    }
    if (m.eyeOpenDelta > (config.metricThresholds['eyeOpenDelta'] ?? 0)) {
      reasons.add(FaceStrings.reasonEye);
    }
    if (m.browDelta > (config.metricThresholds['browDelta'] ?? 0)) {
      reasons.add(FaceStrings.reasonBrow);
    }
    if (m.midlineDeviation > (config.metricThresholds['midlineDeviation'] ?? 0)) {
      reasons.add(FaceStrings.reasonMidline);
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
    );
  }
}
