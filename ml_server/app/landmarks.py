from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List

import cv2
import mediapipe as mp
import numpy as np


@dataclass
class QualityResult:
    ok: bool
    warnings: List[str]
    pose: Dict[str, float]
    brightness: float
    confidence: float


class FaceMeshExtractor:
    def __init__(self):
        self._mp_face_mesh = mp.solutions.face_mesh
        self._mesh = self._mp_face_mesh.FaceMesh(
            static_image_mode=True,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.6,
            min_tracking_confidence=0.6,
        )

    def extract(self, image_bgr: np.ndarray) -> Dict[str, Any]:
        rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
        result = self._mesh.process(rgb)
        if not result.multi_face_landmarks:
            raise ValueError("No face landmarks detected")

        lms = result.multi_face_landmarks[0].landmark
        if len(lms) != 468:
            raise ValueError(f"Expected 468 landmarks, got {len(lms)}")
        arr = np.array([[lm.x, lm.y, lm.z] for lm in lms], dtype=np.float32)
        quality = self._quality_gate(arr, image_bgr)
        return {
            "landmarks": arr,
            "quality": quality,
            "landmark_count": int(arr.shape[0]),
        }

    def _quality_gate(self, landmarks_xyz: np.ndarray, image_bgr: np.ndarray) -> QualityResult:
        warnings = []
        xs = landmarks_xyz[:, 0]
        ys = landmarks_xyz[:, 1]
        width = max(float(xs.max() - xs.min()), 1e-6)
        height = max(float(ys.max() - ys.min()), 1e-6)
        area = width * height

        face_center = (float(xs.mean()), float(ys.mean()))
        center_penalty = abs(face_center[0] - 0.5) + abs(face_center[1] - 0.5)
        if abs(face_center[0] - 0.5) > 0.2 or abs(face_center[1] - 0.5) > 0.2:
            warnings.append("Face not centered")

        left = landmarks_xyz[33]
        right = landmarks_xyz[263]
        nose = landmarks_xyz[1]
        yaw = float((nose[0] - (left[0] + right[0]) / 2.0) * 100)
        pitch = float((nose[1] - landmarks_xyz[152][1]) * -100)
        roll = float((left[1] - right[1]) * 100)

        if abs(yaw) > 12:
            warnings.append("Yaw too high")
        if abs(pitch) > 15:
            warnings.append("Pitch too high")
        if abs(roll) > 15:
            warnings.append("Roll too high")

        brightness = float(cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY).mean())
        if brightness < 55:
            warnings.append("Brightness too low")

        if area < 0.06:
            warnings.append("Face too small in frame")

        # Proxy confidence from geometry sanity, centeredness and face size.
        confidence = float(np.clip((area / 0.20) * (1.0 - center_penalty), 0.0, 1.0))
        if confidence < 0.35:
            warnings.append("Low landmark confidence")

        return QualityResult(
            ok=len(warnings) == 0,
            warnings=warnings,
            pose={"yaw": yaw, "pitch": pitch, "roll": roll},
            brightness=brightness,
            confidence=confidence,
        )
