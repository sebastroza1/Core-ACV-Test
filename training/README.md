# Training pipeline (real model)

## Install
```bash
pip install datasets mediapipe opencv-python scikit-learn tensorflow numpy
```

## End-to-end
```bash
python training/download_dataset.py --dataset jasir/palsynet-data
python training/extract_landmarks.py
python training/build_features.py
python training/train_model.py
python training/evaluate.py
python training/export_tflite.py
```

Outputs:
- `assets/models/palsy_landmarks_model.tflite`
- `assets/models/labels.txt`
- `assets/models/feature_spec.json`

Notes:
- Uses high-density MediaPipe FaceMesh (468 landmarks, xyz).
- Deterministic splits with fixed seed.
- Skipped images are logged in extraction summary.
