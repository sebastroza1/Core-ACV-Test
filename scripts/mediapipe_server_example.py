"""Example local HTTP landmarks service for desktop fallback.
Run: python scripts/mediapipe_server_example.py
Expected endpoint: POST /detect with JSON {expression, image_base64}
Return JSON with normalized fields used by Flutter.
"""
from flask import Flask, request, jsonify
import base64

app = Flask(__name__)

@app.post('/detect')
def detect():
    payload = request.get_json(force=True)
    _ = payload.get('expression')
    _img_b64 = payload.get('image_base64', '')
    # TODO: decode image and run mediapipe face mesh here.
    # This returns dummy structure expected by Flutter real detector.
    return jsonify({
        'leftMouthCornerY': 0.49,
        'rightMouthCornerY': 0.45,
        'leftMouthWidth': 0.29,
        'rightMouthWidth': 0.24,
        'leftEyeOpen': 0.28,
        'rightEyeOpen': 0.30,
        'leftBrowY': 0.36,
        'rightBrowY': 0.34,
        'midlineDeviation': 0.06,
        'yaw': 2.0,
        'pitch': 1.0,
        'roll': 0.5,
        'centerOffsetRatio': 0.07,
        'brightness': 120.0,
        'confidence': 0.85,
        'landmarkCount': 48,
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8765, debug=True)
