# Core ACV Test (Desktop)

Prototipo Flutter Desktop con pipeline híbrido para Face FAST:
- Landmarks/Face Mesh (mock + real vía endpoint HTTP local).
- Clasificador on-device TFLite palsy vs normal (mock + real con `.tflite`).
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
2. Capturar **Neutral** (baseline obligatorio).
3. Capturar **Smile** y **Anger**.
4. Presionar **Calcular** para obtener métricas por expresión y score final.
5. Revisar en cada tarjeta: estado, anomalías, fuentes (MOCK/REAL/FALLBACK), y debug.

Si falta Neutral, el cálculo final se bloquea.

## Toggles reales (sin reiniciar app)

- **Usar Mock Landmarks**
  - `ON`: usa `MockLandmarksDetector`
  - `OFF`: usa `RealLandmarksDetector` (endpoint HTTP local `http://127.0.0.1:8765/detect`; si falla, fallback heurístico en desktop)
- **Usar Mock Classifier**
  - `ON`: usa `MockPalsyClassifier`
  - `OFF`: usa `TFLitePalsyClassifier` (si no encuentra/carga modelo, fallback a mock)

## Configuración de fusión y umbrales

Ajustar en `lib/src/core/app_config.dart`, clase `FacePipelineConfig`:
- `alpha` (default `0.65`):
  - `score_final = alpha * score_geom + (1 - alpha) * (palsy_prob * 100)`
- Umbrales estado:
  - `okMax` (<30), `obsMax` (30–60), `alert` (>60)
- Umbrales quality gate:
  - centrado, yaw/pitch/roll, brillo, confianza y cantidad de landmarks
- Umbrales por métrica (`metricThresholds`)
- Endpoint real de landmarks (`realLandmarksEndpoint`)
- Assets TFLite (`tfliteModelAssetPath`, `tfliteLabelsAssetPath`)

## Landmarks reales en Desktop

En desktop no hay MLKit oficial para este caso en Flutter puro. Este prototipo usa:
1. **Endpoint HTTP local opcional** para detector real (MediaPipe en Python u otro servicio).
2. Si el endpoint no responde, usa fallback heurístico para mantener el flujo sin romper app.

Ejemplo de servidor base: `scripts/mediapipe_server_example.py`.

## Modelo `.tflite` real

Coloca:
- `assets/models/palsy_model.tflite`
- `assets/models/labels.txt`

Ya está declarado en `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/models/
```

### Tipo de modelo soportado

`TFLitePalsyClassifier` detecta automáticamente el tipo por forma de tensor de entrada:
- **Modelo por features** (`[1, N]`): usa vector geométrico + pose/brillo/confianza.
- **Modelo por imagen** (`[1, H, W, 3]`): resize/normalización de frame y predicción por imagen.


## Proceso de análisis (paso a paso)

1. **Captura por expresión**: se toma un snapshot por cada fase (`Neutral`, `Smile`, `Anger`) con `frame` + landmarks.
2. **Detección de landmarks**:
   - Si toggle está en Mock: usa datos simulados.
   - Si toggle está en Real: intenta endpoint HTTP local (`/detect`) y si falla usa fallback heurístico sobre la imagen.
3. **Quality gate**: valida centrado, yaw/pitch/roll, brillo, confianza y cantidad de landmarks antes de aceptar la toma.
4. **Baseline**: `Neutral` se usa como referencia obligatoria para comparar `Smile` y `Anger`.
5. **Métricas geométricas**: calcula deltas absolutos y también deltas con signo (para saber qué lado está más afectado).
6. **Clasificador**:
   - Mock, o
   - TFLite real. Detecta automáticamente si el modelo es por **features** o por **imagen** según shape del input tensor.
7. **Fusión final**: `score_final = alpha * score_geom + (1 - alpha) * (palsy_prob * 100)`.
8. **Interpretación clínica**:
   - estado por expresión (`SANO` / `CON ANOMALÍAS` / `ANOMALÍAS IMPORTANTES`),
   - anomalías explicadas con dirección (izquierda/derecha),
   - resultado general de las 3 expresiones.

## “Líneas de expresión”

Este sistema **no mide arrugas** como textura de forma explícita. Evalúa expresión por:
- geometría de landmarks (asimetrías de boca/ojos/cejas/línea media), y
- opcionalmente por textura/rasgos si tu `.tflite` es de imagen.

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

## Disclaimer

**Esto NO es diagnóstico médico. Si sospecha ACV, contacte emergencias.**


## Si una imagen con ACV no se detecta bien

Para casos reales, la precisión depende de usar **fuentes reales**:
1. Toggle landmarks en REAL con endpoint `/detect` funcionando.
2. Toggle classifier en REAL con `palsy_model.tflite` válido cargado.
3. Buena captura: rostro centrado, luz suficiente y poca rotación.

Con fuentes `MOCK/FALLBACK`, la salida sirve para prototipo y puede sub-detectar anomalías clínicas.
Además, los umbrales base (`metricThresholds`, `okMax`, `obsMax`) son calibrables por población/estudio.
