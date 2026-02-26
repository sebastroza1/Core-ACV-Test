# Core ACV Test (Desktop) - Face FAST híbrido real

> **This detects facial asymmetry patterns; it does not diagnose stroke. If you suspect stroke, seek emergency care.**

## Estructura entregada

- `training/`: pipeline real de entrenamiento (dataset -> landmarks 468 -> features -> train -> eval -> export tflite).
- `landmark_server/`: servicio FastAPI local para extraer FaceMesh 468 en desktop.
- `flutter_app/`: guía (la app Flutter está en la raíz de este repo).
- `assets/models/`: `palsy_landmarks_model.tflite`, `labels.txt`, `feature_spec.json`.

## 1) Entrenar modelo real (Python)

```bash
python training/download_dataset.py --dataset jasir/palsynet-data
python training/extract_landmarks.py
python training/build_features.py
python training/train_model.py
python training/evaluate.py
python training/export_tflite.py
```

Métricas reportadas: Accuracy, Precision, Recall, F1, ROC-AUC, matriz de confusión.
Umbral sugerido de screening sensible: `0.35`.

## 2) Levantar servidor local de landmarks (desktop)

```bash
uvicorn landmark_server.main:app --host 127.0.0.1 --port 8765 --reload
```

Endpoints:
- `GET /health`
- `POST /landmarks`

## 3) Ejecutar app Flutter desktop

```bash
flutter pub get
flutter run -d windows  # o macos/linux
```

En la pantalla Face:
- Captura `Neutral` (baseline), `Smile`, `Anger`.
- `Analyze` calcula comparación `Neutral vs Smile/Anger`.
- Default recomendado: **REAL landmarks + REAL classifier**.

## Lógica clínica implementada

- Landmarks densos: **MediaPipe FaceMesh 468 (xyz)**.
- Features del modelo:
  - 468*3 = 1404 valores de landmarks
  - + features de simetría (mouth/eyes/brows/midline)
- Baseline obligatorio: `Neutral`.
- Fusión:
  - `final_score_expr = alpha * geom_score_expr + (1-alpha) * (palsy_prob_expr*100)`
  - `final_score_session = max(score_smile, score_anger)`
- Estados:
  - `OK < 30`
  - `OBS 30–60`
  - `ALERT > 60`

## “Líneas de expresión”

No se detectan arrugas de forma aislada por regla fija.
Se usa geometría facial (landmarks) y, si el modelo fuese por imagen, también textura.

## Si no detecta bien

1. Verifica que usas fuente **REAL** (no mock/fallback).
2. Verifica servidor `/landmarks` respondiendo y retornando `landmarkCount=468`.
3. Verifica que cargó `assets/models/palsy_landmarks_model.tflite`.
4. Recalibra umbrales en `lib/src/core/app_config.dart`.

## Seguridad

> **This detects facial asymmetry patterns; it does not diagnose stroke. If you suspect stroke, seek emergency care.**
