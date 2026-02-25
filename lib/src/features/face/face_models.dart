enum FaceExpression { neutral, smile, anger }

enum FaceStatus { ok, obs, alert }

class FacialLandmarks {
  const FacialLandmarks({
    required this.leftMouthCornerY,
    required this.rightMouthCornerY,
    required this.leftMouthWidth,
    required this.rightMouthWidth,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.leftBrowY,
    required this.rightBrowY,
    required this.midlineDeviation,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.centerOffsetRatio,
    required this.brightness,
    required this.confidence,
    required this.landmarkCount,
  });

  final double leftMouthCornerY;
  final double rightMouthCornerY;
  final double leftMouthWidth;
  final double rightMouthWidth;
  final double leftEyeOpen;
  final double rightEyeOpen;
  final double leftBrowY;
  final double rightBrowY;
  final double midlineDeviation;
  final double yaw;
  final double pitch;
  final double roll;
  final double centerOffsetRatio;
  final double brightness;
  final double confidence;
  final int landmarkCount;
}

class GeometricMetrics {
  const GeometricMetrics({
    required this.mouthCornerDelta,
    required this.mouthWidthDelta,
    required this.eyeOpenDelta,
    required this.browDelta,
    required this.midlineDeviation,
  });

  final double mouthCornerDelta;
  final double mouthWidthDelta;
  final double eyeOpenDelta;
  final double browDelta;
  final double midlineDeviation;
}

class ClassifierResult {
  const ClassifierResult({required this.palsyProb, required this.label});

  final double palsyProb;
  final String label;
}

class ExpressionResult {
  const ExpressionResult({
    required this.metrics,
    required this.mouthScore,
    required this.eyesScore,
    required this.browScore,
    required this.midlineScore,
    required this.scoreGeom,
    required this.classifier,
    required this.scoreFinal,
    required this.status,
    required this.primaryZone,
    required this.reasons,
  });

  final GeometricMetrics metrics;
  final double mouthScore;
  final double eyesScore;
  final double browScore;
  final double midlineScore;
  final double scoreGeom;
  final ClassifierResult classifier;
  final double scoreFinal;
  final FaceStatus status;
  final String primaryZone;
  final List<String> reasons;
}
