import '../models/app_models.dart';

class ValidationStore {
  static final List<ValidationRecord> records = [];

  static void add(SessionResult result) {
    final absNeutral = (result.raw['absolute']['neutral'] as Map<String, dynamic>);
    records.add(
      ValidationRecord(
        id: 'sess_${records.length + 1}',
        timestampIso: DateTime.now().toIso8601String(),
        geom: ((absNeutral['geom_abs_score'] as num?) ?? 0).toDouble(),
        prob: ((absNeutral['palsy_prob_abs'] as num?) ?? 0).toDouble(),
        finalScore: ((result.raw['final']['score'] as num?) ?? 0).toDouble(),
        status: '${result.raw['final']['status']}',
      ),
    );
  }
}
