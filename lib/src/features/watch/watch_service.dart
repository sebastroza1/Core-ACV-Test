import 'dart:async';
import 'dart:math';

import '../../core/app_config.dart';
import 'watch_models.dart';

abstract class WatchSensorService {
  Future<WatchDevice> connect({required String brand});
  Stream<WatchSensorSample> sensorStream();
  Future<void> disconnect();
}

class SimulatedBluetoothWatchService implements WatchSensorService {
  SimulatedBluetoothWatchService({this.interval = const Duration(seconds: 1)});

  final Duration interval;
  final Random _random = Random();
  StreamController<WatchSensorSample>? _controller;
  Timer? _timer;

  @override
  Future<WatchDevice> connect({required String brand}) async {
    _controller = StreamController<WatchSensorSample>.broadcast();
    _timer = Timer.periodic(interval, (_) {
      _controller?.add(
        WatchSensorSample(
          timestamp: DateTime.now(),
          gyroscope: _nextVector(scale: 1.8),
          accelerometer: _nextVector(scale: 9.81),
        ),
      );
    });

    return WatchDevice(name: '$brand Watch GT', macAddress: '00:11:22:33:44:55');
  }

  @override
  Stream<WatchSensorSample> sensorStream() {
    return _controller?.stream ?? const Stream<WatchSensorSample>.empty();
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    await _controller?.close();
  }

  MotionVector _nextVector({required double scale}) {
    return MotionVector(
      x: (2 * _random.nextDouble() - 1) * scale,
      y: (2 * _random.nextDouble() - 1) * scale,
      z: (2 * _random.nextDouble() - 1) * scale,
    );
  }
}

WatchSensorService buildWatchService(AppConfig config) {
  // Punto de extensión para reemplazar por implementación Bluetooth real.
  return SimulatedBluetoothWatchService();
}
