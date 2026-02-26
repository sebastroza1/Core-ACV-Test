# FAST Face Desktop + ML Server (Facial Droop / Facial Weakness Prototype)

Academic prototype that detects **facial asymmetry patterns** (healthy vs palsy-like droop proxy) using:

1. **High-density MediaPipe FaceMesh (468 landmarks)**
2. **ML classifier (TensorFlow -> TFLite)**
3. **Interpretable geometry + movement-deficit scoring**

> **Clinical disclaimer**: This is NOT a medical diagnosis. If you suspect stroke, seek emergency medical care.

## Repository layout

- `flutter_app/`: Desktop Flutter app (Home, Test, Results, Validation Mode)
- `ml_server/`: FastAPI backend for training + landmarks + session analysis

## 1) Run ML server

```bash
cd ml_server
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Endpoints:
- `GET /status`
- `POST /train`
- `POST /landmarks`
- `POST /analyze_session`

### Training hardening (`POST /train`)
- Downloads **Hugging Face dataset** `jasir/palsynet-data`.
- Extracts **468 x,y,z landmarks** via MediaPipe FaceMesh.
- Rejects low-quality samples (pose/brightness/size/confidence gate).
- Logs integrity and rejection statistics:
  - total images
  - skipped images
  - rejected by quality
  - class distribution and imbalance warning
- Trains MLP with train-only normalization mean/std.
- Computes metrics:
  - accuracy/precision/recall/F1/ROC-AUC
  - confusion matrix
  - sensitivity/specificity
- Chooses threshold prioritizing sensitivity (screening context).
- Saves ROC curve image to `ml_server/workdir/reports/roc_curve.png`.
- Exports to `flutter_app/assets/models/`:
  - `palsy_landmarks_model.tflite`
  - `labels.txt`
  - `feature_spec.json`

## 2) Run Flutter desktop app

```bash
cd flutter_app
flutter pub get
flutter run -d linux   # or windows / macos
```

## Runtime verification guarantees
- No mock classifier or mock landmarks in production path.
- If TFLite cannot be loaded, backend fails clearly (no fallback).
- Backend logs include:
  - model load event
  - input tensor details
  - normalized vector size
  - first 5 input values
  - inference latency and output value
- Landmark endpoint validates `landmark_count == 468`.

## App workflow
1. **Home**: click **Train Model**.
2. **Test**: capture Neutral / Smile / Anger (quality gate rejects bad captures).
3. **Results**:
   - absolute analysis for Neutral/Smile/Anger
   - relative movement deficits Smile-vs-Neutral / Anger-vs-Neutral
   - top changed landmarks and zone contributions
   - debug overlay with highlighted asymmetric landmarks
4. **Validation Mode**:
   - aggregate sessions
   - export CSV for thesis reporting

## Neutral can be abnormal (important)
Neutral is within-session reference posture and may be abnormal.
Final decision combines:
- absolute abnormality in all photos (including Neutral)
- relative movement deficit in Smile/Anger vs Neutral

## Fusion scoring (configurable in `feature_spec.json`)
- `abs_score_expr = alpha * geom_abs + (1-alpha) * (palsy_prob_abs*100)`
- `abs_score_session = max(neutral, smile, anger)`
- `final_score = max(abs_score_session, beta * max(smile_deficit, anger_deficit))`

Thresholds:
- `OK < 30`
- `OBS 30-60`
- `ALERT > 60`
