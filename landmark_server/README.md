# Local landmark server (FastAPI)

```bash
pip install fastapi uvicorn mediapipe opencv-python numpy
uvicorn landmark_server.main:app --host 127.0.0.1 --port 8765 --reload
```

Endpoints:
- `GET /health`
- `POST /landmarks`

If using Flutter app, set:
- `realLandmarksEndpoint = http://127.0.0.1:8765/landmarks`
