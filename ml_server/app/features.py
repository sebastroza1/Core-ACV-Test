from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List

import numpy as np


@dataclass
class GeometryScores:
    mouth_score: float
    eyes_score: float
    brow_score: float
    midline_score: float

    @property
    def total(self) -> float:
        return float(np.clip((self.mouth_score + self.eyes_score + self.brow_score + self.midline_score) / 4.0, 0, 100))


def _dist(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.linalg.norm(a - b))


def flatten_landmarks(landmarks_xyz: np.ndarray) -> np.ndarray:
    return landmarks_xyz.reshape(-1).astype(np.float32)


def engineered_metrics(landmarks_xyz: np.ndarray) -> Dict[str, float]:
    lm = landmarks_xyz
    mouth_left = lm[61]
    mouth_right = lm[291]
    left_eye_top = lm[159]
    left_eye_bottom = lm[145]
    right_eye_top = lm[386]
    right_eye_bottom = lm[374]
    left_brow = lm[70]
    right_brow = lm[300]
    nose_tip = lm[1]
    chin = lm[152]
    forehead = lm[10]

    mouth_corner_delta = abs(mouth_left[1] - mouth_right[1])
    mouth_width_delta = abs(_dist(mouth_left, nose_tip) - _dist(mouth_right, nose_tip))
    eye_open_left = _dist(left_eye_top, left_eye_bottom)
    eye_open_right = _dist(right_eye_top, right_eye_bottom)
    eye_open_delta = abs(eye_open_left - eye_open_right)
    brow_delta = abs(left_brow[1] - right_brow[1])
    face_mid = (forehead + chin) / 2.0
    midline_deviation = abs(nose_tip[0] - face_mid[0])

    return {
        "mouthCornerDelta": float(mouth_corner_delta),
        "mouthWidthDelta": float(mouth_width_delta),
        "eyeOpenDelta": float(eye_open_delta),
        "browDelta": float(brow_delta),
        "midlineDeviation": float(midline_deviation),
        "eyeOpenLeft": float(eye_open_left),
        "eyeOpenRight": float(eye_open_right),
    }


def metrics_to_zone_scores(metrics: Dict[str, float], spec_thresholds: Dict[str, float]) -> GeometryScores:
    mouth = 100.0 * np.clip(
        (metrics["mouthCornerDelta"] + metrics["mouthWidthDelta"]) / (spec_thresholds["mouth"] + 1e-6),
        0,
        1,
    )
    eyes = 100.0 * np.clip(metrics["eyeOpenDelta"] / (spec_thresholds["eyes"] + 1e-6), 0, 1)
    brow = 100.0 * np.clip(metrics["browDelta"] / (spec_thresholds["brow"] + 1e-6), 0, 1)
    midline = 100.0 * np.clip(metrics["midlineDeviation"] / (spec_thresholds["midline"] + 1e-6), 0, 1)
    return GeometryScores(float(mouth), float(eyes), float(brow), float(midline))


def build_feature_vector(landmarks_xyz: np.ndarray) -> np.ndarray:
    raw = flatten_landmarks(landmarks_xyz)
    metrics = engineered_metrics(landmarks_xyz)
    engineered = np.array([
        metrics["mouthCornerDelta"],
        metrics["mouthWidthDelta"],
        metrics["eyeOpenDelta"],
        metrics["browDelta"],
        metrics["midlineDeviation"],
    ], dtype=np.float32)
    return np.concatenate([raw, engineered], axis=0)


def top_changed_landmarks(neutral: np.ndarray, expr: np.ndarray, k: int = 10) -> List[Dict[str, float]]:
    delta = np.linalg.norm(expr - neutral, axis=1)
    idx = np.argsort(delta)[::-1][:k]
    return [{"index": int(i), "delta": float(delta[i])} for i in idx]


def landmark_zone(index: int) -> str:
    if index in {61, 291, 13, 14, 78, 308}:
        return "mouth"
    if index in {159, 145, 386, 374, 33, 263}:
        return "eyes"
    if index in {70, 300, 65, 295}:
        return "brow"
    return "midline"
