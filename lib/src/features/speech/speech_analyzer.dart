import '../../core/app_config.dart';

class SpeechAnalysisResult {
  const SpeechAnalysisResult({
    required this.pronouncedRatio,
    required this.asymmetryIndex,
    required this.isAboveThreshold,
  });

  final double pronouncedRatio;
  final double asymmetryIndex;
  final bool isAboveThreshold;
}

class SpeechAsymmetryAnalyzer {
  const SpeechAsymmetryAnalyzer({required this.config});

  final AppConfig config;

  SpeechAnalysisResult evaluate(String spokenText) {
    final List<String> targetWords = _normalize(config.targetTongueTwister).split(' ');
    final List<String> spokenWords = _normalize(spokenText).split(' ');

    int matched = 0;
    for (final String word in targetWords) {
      if (spokenWords.contains(word)) {
        matched++;
      }
    }

    final double ratio = matched / targetWords.length;
    final double asymmetryIndex = 1 - ratio;

    return SpeechAnalysisResult(
      pronouncedRatio: ratio,
      asymmetryIndex: asymmetryIndex,
      isAboveThreshold: asymmetryIndex > config.speechThreshold,
    );
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-záéíóúñü ]'), '').trim();
  }
}
