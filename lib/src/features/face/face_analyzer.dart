import '../../core/app_config.dart';

class FaceAnalysisResult {
  const FaceAnalysisResult({
    required this.asymmetryScore,
    required this.isAboveThreshold,
  });

  final double asymmetryScore;
  final bool isAboveThreshold;
}

class FaceAsymmetryAnalyzer {
  const FaceAsymmetryAnalyzer({required this.config});

  final AppConfig config;

  FaceAnalysisResult evaluate({
    required double leftEye,
    required double rightEye,
    required double leftMouth,
    required double rightMouth,
  }) {
    final double eyeDelta = (leftEye - rightEye).abs();
    final double mouthDelta = (leftMouth - rightMouth).abs();
    final double normalized = (eyeDelta + mouthDelta) / 2;

    return FaceAnalysisResult(
      asymmetryScore: normalized,
      isAboveThreshold: normalized > config.faceThreshold,
    );
  }
}
