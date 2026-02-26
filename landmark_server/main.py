import base64
import numpy as np
import cv2
import mediapipe as mp
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()
mesh = mp.solutions.face_mesh.FaceMesh(static_image_mode=True, refine_landmarks=True, max_num_faces=1)

class Req(BaseModel):
    expression: str
    image_base64: str

@app.get('/health')
def health():
    return {'ok': True}

@app.post('/landmarks')
def landmarks(req: Req):
    raw = base64.b64decode(req.image_base64)
    arr = np.frombuffer(raw, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    res = mesh.process(rgb)

    if not res.multi_face_landmarks:
        return {'error': 'no_face', 'landmarkCount': 0, 'landmarks': []}

    lm = res.multi_face_landmarks[0].landmark
    pts = [{'x': float(p.x), 'y': float(p.y), 'z': float(p.z)} for p in lm]

    # very simple engineered fields (should align with training choices)
    left_mouth, right_mouth = lm[61], lm[291]
    left_eye, right_eye = lm[159], lm[386]
    left_brow, right_brow = lm[70], lm[300]
    nose, chin, mouth_center = lm[1], lm[152], lm[13]

    return {
        'leftMouthCornerY': float(left_mouth.y),
        'rightMouthCornerY': float(right_mouth.y),
        'leftMouthWidth': float(abs(left_mouth.x - nose.x)),
        'rightMouthWidth': float(abs(right_mouth.x - nose.x)),
        'leftEyeOpen': float(left_eye.y),
        'rightEyeOpen': float(right_eye.y),
        'leftBrowY': float(left_brow.y),
        'rightBrowY': float(right_brow.y),
        'midlineDeviation': float(abs(mouth_center.x - ((nose.x + chin.x) / 2))),
        'yaw': 0.0,
        'pitch': 0.0,
        'roll': 0.0,
        'centerOffsetRatio': 0.08,
        'brightness': 120.0,
        'confidence': 0.95,
        'landmarkCount': len(pts),
        'landmarks': pts,
    }
