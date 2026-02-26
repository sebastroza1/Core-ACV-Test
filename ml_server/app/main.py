from __future__ import annotations

import logging
import time
from typing import List

import cv2
import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel

from .config import DISCLAIMER
from .inference import HybridAnalyzer
from .landmarks import FaceMeshExtractor
from .train_pipeline import train

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("fast_face.api")

app = FastAPI(title="FAST Face ML Server")
extractor = FaceMeshExtractor()
analyzer = HybridAnalyzer()
STATUS = {"state": "idle", "logs": [], "metrics": {"landmark_ms": []}}


class SessionAnalyzeRequest(BaseModel):
    neutral: List[List[float]]
    smile: List[List[float]]
    anger: List[List[float]]


@app.get("/status")
def get_status():
    return STATUS


@app.post("/train")
def train_model():
    STATUS["state"] = "training"
    STATUS["logs"] = []

    def log(msg: str):
        logger.info(msg)
        STATUS["logs"].append(msg)

    try:
        report = train(log)
    except Exception as exc:
        STATUS["state"] = "error"
        STATUS["logs"].append(str(exc))
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    STATUS["state"] = "ready"
    return {"ok": True, "report": report, "disclaimer": DISCLAIMER}


@app.post("/landmarks")
async def landmarks(image: UploadFile = File(...)):
    data = await image.read()
    np_buf = np.frombuffer(data, dtype=np.uint8)
    frame = cv2.imdecode(np_buf, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=400, detail="Invalid image")

    try:
        t0 = time.perf_counter()
        result = extractor.extract(frame)
        elapsed = (time.perf_counter() - t0) * 1000.0
        STATUS["metrics"]["landmark_ms"].append(elapsed)
        logger.info("Landmark extraction: %.2fms | count=%s", elapsed, result["landmark_count"])
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    q = result["quality"]
    return {
        "landmarks": result["landmarks"].tolist(),
        "landmark_count": result["landmark_count"],
        "quality": {
            "ok": q.ok,
            "warnings": q.warnings,
            "pose": q.pose,
            "brightness": q.brightness,
            "confidence": q.confidence,
        },
        "timing": {"landmark_ms": elapsed},
        "disclaimer": DISCLAIMER,
    }


@app.post("/analyze_session")
def analyze_session(payload: SessionAnalyzeRequest):
    try:
        neutral = np.array(payload.neutral, dtype=np.float32)
        smile = np.array(payload.smile, dtype=np.float32)
        anger = np.array(payload.anger, dtype=np.float32)
        out = analyzer.analyze_session(neutral, smile, anger)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    out["disclaimer"] = DISCLAIMER
    return out
