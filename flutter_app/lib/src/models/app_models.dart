class CaptureFrame {
  CaptureFrame({required this.label, this.imagePath, this.landmarks, this.warnings = const [], this.landmarkMs});

  final String label;
  String? imagePath;
  List<List<double>>? landmarks;
  List<String> warnings;
  double? landmarkMs;

  bool get ready => landmarks != null;
}

class SessionResult {
  SessionResult(this.raw);
  final Map<String, dynamic> raw;
}

class ValidationRecord {
  ValidationRecord({required this.id, required this.timestampIso, required this.geom, required this.prob, required this.finalScore, required this.status});
  final String id;
  final String timestampIso;
  final double geom;
  final double prob;
  final double finalScore;
  final String status;

  String toCsv() => '$id,$timestampIso,${geom.toStringAsFixed(3)},${prob.toStringAsFixed(4)},${finalScore.toStringAsFixed(3)},$status';
}
