class FacePipelineConfig {
  const FacePipelineConfig({
    this.alpha = 0.65,
    this.okMax = 25,
    this.obsMax = 50,
    this.minBrightness = 40,
    this.maxYawPitchRoll = 20,
    this.minLandmarkConfidence = 0.6,
    this.minLandmarks = 20,
    this.maxCenterOffsetRatio = 0.20,
    this.realLandmarksEndpoint = 'http://127.0.0.1:8765/landmarks',
    this.realtimeRequestTimeoutMs = 1200,
    this.tfliteModelAssetPath = 'assets/models/palsy_landmarks_model.tflite',
    this.tfliteLabelsAssetPath = 'assets/models/labels.txt',
    this.tfliteFeatureSpecAssetPath = 'assets/models/feature_spec.json',
    this.metricThresholds = const <String, double>{
      'mouthCornerDelta': 0.08,
      'mouthWidthDelta': 0.10,
      'eyeOpenDelta': 0.08,
      'browDelta': 0.08,
      'midlineDeviation': 0.07,
    },
  });

  final double alpha;
  final double okMax;
  final double obsMax;
  final double minBrightness;
  final double maxYawPitchRoll;
  final double minLandmarkConfidence;
  final int minLandmarks;
  final double maxCenterOffsetRatio;
  final String realLandmarksEndpoint;
  final int realtimeRequestTimeoutMs;
  final String tfliteModelAssetPath;
  final String tfliteLabelsAssetPath;
  final String tfliteFeatureSpecAssetPath;
  final Map<String, double> metricThresholds;
}

class AppConfig {
  const AppConfig({
    required this.supportedWatchBrand,
    required this.targetTongueTwister,
    required this.faceThreshold,
    required this.speechThreshold,
    this.facePipeline = const FacePipelineConfig(),
  });

  final String supportedWatchBrand;
  final String targetTongueTwister;
  final double faceThreshold;
  final double speechThreshold;
  final FacePipelineConfig facePipeline;

  static const AppConfig desktopDefault = AppConfig(
    supportedWatchBrand: 'Huawei',
    targetTongueTwister: 'tres tristes tigres',
    faceThreshold: 0.35,
    speechThreshold: 0.40,
  );
}
