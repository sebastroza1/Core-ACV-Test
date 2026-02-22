import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import 'watch_models.dart';
import 'watch_service.dart';

class WatchPage extends StatefulWidget {
  const WatchPage({super.key, required this.config});

  final AppConfig config;

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  late final WatchSensorService _service;
  StreamSubscription<WatchSensorSample>? _subscription;

  WatchDevice? _device;
  WatchSensorSample? _lastSample;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _service = buildWatchService(widget.config);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    final WatchDevice device = await _service.connect(
      brand: widget.config.supportedWatchBrand,
    );

    _subscription = _service.sensorStream().listen((WatchSensorSample sample) {
      if (!mounted) {
        return;
      }
      setState(() => _lastSample = sample);
    });

    setState(() {
      _device = device;
      _connecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Watch')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Marca objetivo: ${widget.config.supportedWatchBrand}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _connecting || _device != null ? null : _connect,
              child: Text(_connecting ? 'Conectando...' : 'Conectar por Bluetooth'),
            ),
            const SizedBox(height: 20),
            if (_device != null) ...<Widget>[
              Text('Dispositivo: ${_device!.name} (${_device!.macAddress})'),
              const SizedBox(height: 12),
            ],
            if (_lastSample != null) _SensorView(sample: _lastSample!),
          ],
        ),
      ),
    );
  }
}

class _SensorView extends StatelessWidget {
  const _SensorView({required this.sample});

  final WatchSensorSample sample;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Última lectura: ${sample.timestamp.toIso8601String()}'),
            const SizedBox(height: 10),
            Text(
              'Giroscopio -> x:${sample.gyroscope.x.toStringAsFixed(2)}, '
              'y:${sample.gyroscope.y.toStringAsFixed(2)}, '
              'z:${sample.gyroscope.z.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Acelerómetro -> x:${sample.accelerometer.x.toStringAsFixed(2)}, '
              'y:${sample.accelerometer.y.toStringAsFixed(2)}, '
              'z:${sample.accelerometer.z.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }
}
