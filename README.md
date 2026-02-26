# Core ACV Test (Desktop)

Prototipo Flutter Desktop con pipeline híbrido para Face FAST:
- Landmarks/Face Mesh (mock hoy, interfaz lista para integración real).
- Clasificador on-device TFLite palsy vs normal (mock hoy, interfaz lista para modelo real).
- Score clínico interpretable por zonas + score fusionado final.

## Ejecutar en Desktop

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
flutter pub get
flutter run -d windows # o macos/linux
```

## Modo de uso (Face)
1. Abrir módulo **Cara** desde el menú.
2. Verificar cámara y warnings de quality gate.
3. Capturar **Neutral** (baseline obligatorio).
4. Capturar **Smile** y **Anger**.
5. Presionar **Calcular** para obtener métricas por expresión y score final.

Si falta Neutral, el cálculo final se bloquea.

## Configuración de fusión y umbrales

Ajustar en `lib/src/core/app_config.dart`, clase `FacePipelineConfig`:
- `alpha` (default `0.65`):
  - `score_final = alpha * score_geom + (1 - alpha) * (palsy_prob * 100)`
- Umbrales estado:
  - `okMax` (<30), `obsMax` (30–60), `alert` (>60)
- Umbrales quality gate:
  - centrado, yaw/pitch/roll, brillo, confianza y cantidad de landmarks
- Umbrales por métrica (`metricThresholds`)

## Integración real pendiente (preparada)

### Landmarks reales
Implementar `LandmarksDetector` en `lib/src/features/face/face_pipeline.dart` usando MLKit/MediaPipe (o equivalente) y activar toggle “Real”.

### Modelo `.tflite` + labels
Implementar `PalsyClassifier` real en el mismo archivo o en un servicio dedicado.
Ubicación sugerida:
- `assets/models/palsy_classifier.tflite`
- `assets/models/labels.txt`

Agregar assets a `pubspec.yaml` cuando el modelo exista.

## Disclaimer

**Esto NO es diagnóstico médico. Si sospecha ACV, contacte emergencias.**


## Troubleshooting cámara Desktop

Si aparece: `MissingPluginException(No implementation found for method availableCameras...)`

1. Limpia e instala dependencias nuevamente:
   ```bash
   flutter clean
   flutter pub get
   ```
2. Verifica que corres en Desktop soportado:
   ```bash
   flutter devices
   flutter run -d windows # o macos/linux
   ```
3. Este prototipo incluye fallback: si falla el plugin de cámara, el pipeline mock sigue funcionando sin preview real.


## Nota para Windows

Este repo fija dependencia explícita de `camera_windows` para evitar errores de resolución en `flutter pub get` en entornos Windows.
