from __future__ import annotations

import json
import logging
import time
from typing import Dict

import numpy as np
import tensorflow as tf

from .config import FLUTTER_MODELS_DIR
from .features import build_feature_vector, engineered_metrics, landmark_zone, metrics_to_zone_scores, top_changed_landmarks

logger = logging.getLogger("fast_face.inference")


class HybridAnalyzer:
    def __init__(self):
        self.spec_path = FLUTTER_MODELS_DIR / "feature_spec.json"
        self.model_path = FLUTTER_MODELS_DIR / "palsy_landmarks_model.tflite"
        self._perf = {"landmark_ms": [], "inference_ms": []}

    def _load_assets(self):
        if not self.spec_path.exists() or not self.model_path.exists():
            raise RuntimeError("Model artifacts missing. Run /train first. No fallback is allowed.")
        spec = json.loads(self.spec_path.read_text())
        logger.info("Loading TFLite model: %s", self.model_path)
        interpreter = tf.lite.Interpreter(model_path=str(self.model_path))
        interpreter.allocate_tensors()
        logger.info("TFLite input tensor details: %s", interpreter.get_input_details())
        return spec, interpreter

    def analyze_single(self, landmarks: np.ndarray) -> Dict:
        spec, interpreter = self._load_assets()
        vec = build_feature_vector(landmarks)
        mean = np.array(spec["normalization"]["mean"], dtype=np.float32)
        std = np.array(spec["normalization"]["std"], dtype=np.float32)
        norm = ((vec - mean) / std).astype(np.float32)[None, :]
        logger.info("Normalized feature vector size: %s", norm.shape)

        inp = interpreter.get_input_details()[0]
        out = interpreter.get_output_details()[0]
        logger.info("Input first 5 values: %s", norm.reshape(-1)[:5].tolist())

        t0 = time.perf_counter()
        interpreter.set_tensor(inp["index"], norm)
        interpreter.invoke()
        inf_ms = (time.perf_counter() - t0) * 1000.0
        self._perf["inference_ms"].append(inf_ms)

        prob = float(interpreter.get_tensor(out["index"])[0][0])
        logger.info("Raw model output: %.6f | inference_ms=%.2f", prob, inf_ms)

        metrics = engineered_metrics(landmarks)
        zone = metrics_to_zone_scores(metrics, spec["metric_thresholds"])
        geom = zone.total
        alpha = spec.get("alpha", 0.65)
        abs_score = alpha * geom + (1 - alpha) * (prob * 100)

        return {
            "palsy_prob_abs": prob,
            "geom_abs_score": geom,
            "zone": {
                "mouth_score": zone.mouth_score,
                "eyes_score": zone.eyes_score,
                "brow_score": zone.brow_score,
                "midline_score": zone.midline_score,
            },
            "metrics": metrics,
            "abs_score": float(abs_score),
            "explanation": f"Absolute asymmetry is highest in zone {max(['mouth','eyes','brow','midline'], key=lambda z: {'mouth': zone.mouth_score, 'eyes': zone.eyes_score, 'brow': zone.brow_score, 'midline': zone.midline_score}[z])}.",
        }

    def _movement_deficit(self, base: Dict, expr: Dict) -> Dict:
        keys = ["mouthCornerDelta", "eyeOpenDelta", "browDelta", "midlineDeviation"]
        deltas = {k: float(expr["metrics"][k] - base["metrics"][k]) for k in keys}
        asym = sum(max(0.0, v) for v in deltas.values())
        score = float(np.clip(asym * 1000, 0, 100))
        return {"score": score, "deltas": deltas}

    def analyze_session(self, neutral: np.ndarray, smile: np.ndarray, anger: np.ndarray):
        spec, _ = self._load_assets()
        n = self.analyze_single(neutral)
        s = self.analyze_single(smile)
        a = self.analyze_single(anger)

        smile_mv = self._movement_deficit(n, s)
        anger_mv = self._movement_deficit(n, a)

        smile_top = top_changed_landmarks(neutral, smile, 10)
        anger_top = top_changed_landmarks(neutral, anger, 10)

        abs_session = max(n["abs_score"], s["abs_score"], a["abs_score"])
        final = max(abs_session, spec.get("beta", 1.0) * max(smile_mv["score"], anger_mv["score"]))
        status = "OK" if final < 30 else "OBS" if final <= 60 else "ALERT"

        avg_inf = float(np.mean(self._perf["inference_ms"])) if self._perf["inference_ms"] else 0.0
        logger.info("Average TFLite inference latency (ms): %.2f", avg_inf)

        def _top_explain(items):
            return [
                {**it, "zone": landmark_zone(it["index"])}
                for it in items
            ]

        return {
            "absolute": {"neutral": n, "smile": s, "anger": a},
            "relative": {
                "smile_vs_neutral": {
                    "movement_deficit_score": smile_mv["score"],
                    "metric_deltas": smile_mv["deltas"],
                    "top_changed_landmarks": _top_explain(smile_top),
                    "explanation": "Relative movement deficit compares Smile against Neutral and can reveal unilateral weakness.",
                },
                "anger_vs_neutral": {
                    "movement_deficit_score": anger_mv["score"],
                    "metric_deltas": anger_mv["deltas"],
                    "top_changed_landmarks": _top_explain(anger_top),
                    "explanation": "Relative movement deficit compares Anger against Neutral and can reveal reduced brow/eye activation.",
                },
            },
            "final": {"score": float(final), "status": status, "latency_ms": {"avg_tflite_inference_ms": avg_inf}},
            "neutral_reference_note": "Neutral may already show asymmetry. Relative analysis measures movement deficit. Absolute analysis measures structural asymmetry.",
        }
