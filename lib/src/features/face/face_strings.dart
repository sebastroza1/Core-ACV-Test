class FaceStrings {
  const FaceStrings._();

  static const String noCamera = 'No se detectó cámara.';
  static const String noCalculation = 'Sin cálculo aún.';
  static const String warningPrefix = '⚠️';
  static const String statusMessagePrefix = 'Mayor asimetría detectada en:';
  static const String reasonsLabel = 'Razones:';
  static const String uncenteredFace = 'Rostro no centrado';
  static const String badPose = 'Yaw/Pitch/Roll fuera de rango';
  static const String lowBrightness = 'Brillo muy bajo';
  static const String lowConfidence = 'Landmarks insuficientes o baja confianza';
  static const String reasonMouth = 'Comisura derecha más baja';
  static const String reasonEye = 'Apertura ocular izquierda reducida';
  static const String reasonBrow = 'Desnivel de cejas evidente';
  static const String reasonMidline = 'Desviación del eje nariz-mentón';
}
