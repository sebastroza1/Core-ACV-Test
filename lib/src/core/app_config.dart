class AppConfig {
  const AppConfig({
    required this.supportedWatchBrand,
    required this.targetTongueTwister,
    required this.faceThreshold,
    required this.speechThreshold,
  });

  final String supportedWatchBrand;
  final String targetTongueTwister;
  final double faceThreshold;
  final double speechThreshold;

  static const AppConfig desktopDefault = AppConfig(
    supportedWatchBrand: 'Huawei',
    targetTongueTwister: 'tres tristes tigres',
    faceThreshold: 0.35,
    speechThreshold: 0.40,
  );
}
