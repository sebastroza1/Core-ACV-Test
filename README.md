# Core ACV Test (Desktop)

Aplicación Flutter de escritorio con un menú simple de 3 opciones:

1. **Smart Watch (Huawei)**: simulación de conexión Bluetooth y lectura de giroscopio/acelerómetro.
2. **Cara**: evaluación de asimetrías faciales basada en métricas normalizadas.
3. **Habla**: evaluación de asimetrías del habla usando el trabalenguas _"tres tristes tigres"_.

## Requisitos

- Flutter SDK `>=3.19` (Dart 3.3+).
- Habilitar plataforma de escritorio:

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

## Ejecución

```bash
flutter pub get
flutter run -d windows # o macos/linux
```

## Nota de integración real

La clase `SimulatedBluetoothWatchService` está separada de la UI para facilitar reemplazo por una implementación Bluetooth real (Huawei) sin tocar pantallas.
