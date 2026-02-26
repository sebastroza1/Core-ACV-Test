class AppStrings {
  const AppStrings._();

  static const String appTitle = 'Core ACV Test';
  static const String faceTitle = 'Face FAST (Pipeline híbrido)';
  static const String disclaimer =
      'This detects facial asymmetry patterns; it does not diagnose stroke. If you suspect stroke, seek emergency care.';
  static const String captureNeutral = 'Capturar Neutral';
  static const String captureSmile = 'Capturar Smile';
  static const String captureAnger = 'Capturar Anger';
  static const String calculate = 'Calcular';
  static const String reset = 'Reset';
  static const String mockLandmarks = 'Usar Mock Landmarks';
  static const String mockClassifier = 'Usar Mock Classifier';
  static const String needsNeutral =
      'Debe capturar Neutral antes de calcular Smile/Anger.';
}
