class FaceStrings {
  const FaceStrings._();

  static const String noCamera = 'No se detectó cámara.';
  static const String noCalculation = 'Sin cálculo aún.';
  static const String warningPrefix = '⚠️';
  static const String statusMessagePrefix = 'Mayor asimetría detectada en:';
  static const String reasonsLabel = 'Anomalías detectadas:';
  static const String noAnomalies = 'Sin anomalías relevantes.';
  static const String uncenteredFace = 'Rostro no centrado';
  static const String badPose = 'Yaw/Pitch/Roll fuera de rango';
  static const String lowBrightness = 'Brillo muy bajo';
  static const String lowConfidence = 'Landmarks insuficientes o baja confianza';
  static const String reasonMouth = 'Comisura derecha más baja';
  static const String reasonEye = 'Apertura ocular izquierda reducida';
  static const String reasonBrow = 'Desnivel de cejas evidente';
  static const String reasonMidline = 'Desviación del eje nariz-mentón';

  static const String cameraPluginMissing =
      'Plugin de cámara no registrado en Desktop (MissingPluginException).';
  static const String cameraFallback =
      'Continuarás en modo mock sin preview real de cámara.';
  static const String cameraHelp =
      'Sugerencia: ejecuta flutter clean, flutter pub get y vuelve a correr en Windows/macOS/Linux.';
  static const String previewUnavailable =
      'Preview de cámara no disponible en este entorno.';

  static const String expressionNeutral = 'NEUTRAL';
  static const String expressionSmile = 'SMILE';
  static const String expressionAnger = 'ANGER';

  static const String overallTitle = 'Resultado general (3 expresiones)';
  static const String overallPending =
      'Captura y calcula Neutral, Smile y Anger para obtener el resultado general.';
  static const String overallScoreLabel = 'Score general';
  static const String overallStatusLabel = 'Estado general';
  static const String overallSummaryLabel = 'Resumen';

  static const String healthHealthy = 'SANO';
  static const String healthAnomalies = 'CON ANOMALÍAS';
  static const String healthSevere = 'ANOMALÍAS IMPORTANTES';

  static const String geomScoreLabel = 'Asimetría geométrica';
  static const String classifierLabel = 'Clasificador palsy';
  static const String finalScoreLabel = 'Riesgo combinado';
  static const String zonesLabel = 'Zonas (0 a 100)';

  static const String metricMouthCorner =
      'Comisuras de la boca (diferencia izquierda/derecha)';
  static const String metricMouthWidth =
      'Amplitud de sonrisa (diferencia izquierda/derecha)';
  static const String metricEyeOpen =
      'Apertura de ojos (diferencia izquierda/derecha)';
  static const String metricBrow =
      'Altura de cejas (diferencia izquierda/derecha)';
  static const String metricMidline =
      'Desviación de línea media (nariz-mentón vs centro de boca)';

  static const String descHealthy =
      'Sin señales fuertes de asimetría clínica en esta expresión.';
  static const String descObs =
      'Se observan asimetrías leves/moderadas; conviene vigilar.';
  static const String descAlert =
      'Asimetría marcada en esta expresión; requiere atención.';
  static const String overallAllGood =
      'Las 3 expresiones están dentro de rango esperado.';

  static const String sourceLandmarks = 'Fuente landmarks';
  static const String sourceClassifier = 'Fuente clasificador';
  static const String debugLabel = 'Debug captura';
  static const String debugYawPitchRoll = 'yaw/pitch/roll';
  static const String debugBrightness = 'brillo';
  static const String debugLandmarksCount = 'landmarks';
  static const String debugConfidence = 'confianza';
  static const String linesExpressionNote =
      'Nota: no detectamos arrugas como tal; inferimos expresión por geometría facial y, si el modelo es por imagen, también por textura.';
}
