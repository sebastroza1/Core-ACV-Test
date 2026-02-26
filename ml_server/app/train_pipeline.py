from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Callable, Dict, List

import cv2
import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf
from huggingface_hub import snapshot_download
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_recall_curve,
    precision_score,
    recall_score,
    roc_auc_score,
    roc_curve,
)
from sklearn.model_selection import train_test_split

from .config import DATA_DIR, DEFAULT_ALPHA, DEFAULT_BETA, FLUTTER_MODELS_DIR, RANDOM_SEED, REPORT_DIR
from .features import build_feature_vector, engineered_metrics
from .landmarks import FaceMeshExtractor


def _set_seed(seed: int = RANDOM_SEED):
    random.seed(seed)
    np.random.seed(seed)
    tf.random.set_seed(seed)


def _label_from_path(path: Path) -> int:
    low = str(path).lower()
    if any(x in low for x in ["palsy", "droop", "patient", "affected", "abnormal"]):
        return 1
    return 0


def _collect_images(dataset_root: Path) -> List[Path]:
    exts = {".jpg", ".jpeg", ".png", ".bmp"}
    return [p for p in dataset_root.rglob("*") if p.suffix.lower() in exts]


def _choose_threshold_sensitivity(y_true: np.ndarray, probs: np.ndarray, min_sens: float = 0.9) -> float:
    thresholds = np.linspace(0.05, 0.95, 91)
    best = (0.35, -1.0)
    for t in thresholds:
        pred = (probs >= t).astype(int)
        sens = recall_score(y_true, pred, zero_division=0)
        spec = recall_score(1 - y_true, 1 - pred, zero_division=0)
        if sens >= min_sens and spec > best[1]:
            best = (float(t), float(spec))
    if best[1] >= 0:
        return best[0]
    # fallback: maximize recall if min_sens impossible
    recalls = [(float(t), recall_score(y_true, (probs >= t).astype(int), zero_division=0)) for t in thresholds]
    return max(recalls, key=lambda x: x[1])[0]


def train(log: Callable[[str], None]) -> Dict:
    _set_seed()
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    log("Downloading dataset jasir/palsynet-data from Hugging Face...")
    ds_path = Path(snapshot_download(repo_id="jasir/palsynet-data", repo_type="dataset", local_dir=str(DATA_DIR / "palsynet")))
    imgs = _collect_images(ds_path)
    total_images = len(imgs)
    log(f"Total discovered images: {total_images}")
    if total_images < 20:
        raise RuntimeError("Dataset seems empty. Consider fallback dataset YFP.")

    extractor = FaceMeshExtractor()
    X, y = [], []
    metrics_list = []
    skipped_no_face = 0
    rejected_quality = 0

    for i, img_path in enumerate(imgs):
        image = cv2.imread(str(img_path))
        if image is None:
            skipped_no_face += 1
            continue
        try:
            out = extractor.extract(image)
            if not out["quality"].ok:
                rejected_quality += 1
                continue
            lms = out["landmarks"]
            X.append(build_feature_vector(lms))
            y.append(_label_from_path(img_path))
            metrics_list.append(engineered_metrics(lms))
        except Exception:
            skipped_no_face += 1
            continue
        if i % 200 == 0:
            log(f"Processed {i}/{len(imgs)} images")

    X = np.array(X, dtype=np.float32)
    y = np.array(y, dtype=np.float32)
    if len(X) < 30 or len(np.unique(y)) < 2:
        raise RuntimeError("Not enough labeled samples after filtering.")

    class_dist = {"normal": int((y == 0).sum()), "palsy": int((y == 1).sum())}
    imbalance_ratio = max(class_dist.values()) / max(1, min(class_dist.values()))
    log(f"Class distribution: {class_dist}")
    if imbalance_ratio > 3.0:
        log("WARNING: dataset is highly imbalanced (>3:1).")

    log(f"Skipped images (decode/face fail): {skipped_no_face}")
    log(f"Rejected by quality gate: {rejected_quality}")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_SEED, stratify=y
    )

    mean = X_train.mean(axis=0)
    std = X_train.std(axis=0) + 1e-6
    X_train_n = (X_train - mean) / std
    X_test_n = (X_test - mean) / std

    tf.keras.backend.clear_session()
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(X.shape[1],)),
        tf.keras.layers.Dense(512, activation="relu"),
        tf.keras.layers.Dropout(0.35),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy", tf.keras.metrics.AUC(name="auc")])
    log("Training MLP model...")
    model.fit(X_train_n, y_train, validation_split=0.1, epochs=25, batch_size=32, verbose=0)

    probs = model.predict(X_test_n, verbose=0).reshape(-1)
    threshold = _choose_threshold_sensitivity(y_test.astype(int), probs, min_sens=0.9)
    preds = (probs >= threshold).astype(np.int32)

    tn, fp, fn, tp = confusion_matrix(y_test, preds).ravel()
    sensitivity = tp / max(1, tp + fn)
    specificity = tn / max(1, tn + fp)

    fpr, tpr, _ = roc_curve(y_test, probs)
    plt.figure(figsize=(6, 5))
    plt.plot(fpr, tpr, label=f"ROC AUC={roc_auc_score(y_test, probs):.3f}")
    plt.plot([0, 1], [0, 1], "k--")
    plt.xlabel("False Positive Rate")
    plt.ylabel("True Positive Rate")
    plt.title("ROC Curve - FAST Face")
    plt.legend(loc="lower right")
    plt.tight_layout()
    roc_path = REPORT_DIR / "roc_curve.png"
    plt.savefig(roc_path)
    plt.close()

    report = {
        "accuracy": float(accuracy_score(y_test, preds)),
        "precision": float(precision_score(y_test, preds, zero_division=0)),
        "recall": float(recall_score(y_test, preds, zero_division=0)),
        "f1": float(f1_score(y_test, preds, zero_division=0)),
        "roc_auc": float(roc_auc_score(y_test, probs)),
        "sensitivity": float(sensitivity),
        "specificity": float(specificity),
        "confusion_matrix": [[int(tn), int(fp)], [int(fn), int(tp)]],
        "threshold": float(threshold),
        "samples": int(len(X)),
        "integrity": {
            "total_images": total_images,
            "used_samples": int(len(X)),
            "skipped_images": int(skipped_no_face),
            "rejected_quality": int(rejected_quality),
            "class_distribution": class_dist,
            "imbalance_ratio": float(imbalance_ratio),
        },
        "roc_curve": str(roc_path),
    }
    log(f"Confusion matrix: {report['confusion_matrix']}")

    (REPORT_DIR / "metrics.json").write_text(json.dumps(report, indent=2))

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_bytes = converter.convert()
    (FLUTTER_MODELS_DIR / "palsy_landmarks_model.tflite").write_bytes(tflite_bytes)
    (FLUTTER_MODELS_DIR / "labels.txt").write_text("normal\npalsy\n")

    metric_keys = ["mouthCornerDelta", "mouthWidthDelta", "eyeOpenDelta", "browDelta", "midlineDeviation"]
    m = {k: np.array([it[k] for it in metrics_list], dtype=np.float32) for k in metric_keys}
    thresholds = {
        "mouth": float(m["mouthCornerDelta"].mean() + 2 * m["mouthCornerDelta"].std()),
        "eyes": float(m["eyeOpenDelta"].mean() + 2 * m["eyeOpenDelta"].std()),
        "brow": float(m["browDelta"].mean() + 2 * m["browDelta"].std()),
        "midline": float(m["midlineDeviation"].mean() + 2 * m["midlineDeviation"].std()),
    }

    feature_spec = {
        "landmark_count": 468,
        "landmark_order": "mediapipe_face_mesh",
        "normalization": {"mean": mean.tolist(), "std": std.tolist()},
        "metric_thresholds": thresholds,
        "classifier_threshold": float(threshold),
        "alpha": DEFAULT_ALPHA,
        "beta": DEFAULT_BETA,
        "engineered_features": metric_keys,
    }
    (FLUTTER_MODELS_DIR / "feature_spec.json").write_text(json.dumps(feature_spec, indent=2))
    log("Exported TFLite + feature_spec with sensitivity-optimized threshold.")
    return report
