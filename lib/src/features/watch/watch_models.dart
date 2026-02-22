class MotionVector {
  const MotionVector({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;
}

class WatchSensorSample {
  const WatchSensorSample({
    required this.timestamp,
    required this.gyroscope,
    required this.accelerometer,
  });

  final DateTime timestamp;
  final MotionVector gyroscope;
  final MotionVector accelerometer;
}

class WatchDevice {
  const WatchDevice({required this.name, required this.macAddress});

  final String name;
  final String macAddress;
}
