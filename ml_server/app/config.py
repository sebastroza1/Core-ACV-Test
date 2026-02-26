from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLUTTER_MODELS_DIR = ROOT / "flutter_app" / "assets" / "models"
WORK_DIR = ROOT / "ml_server" / "workdir"
DATA_DIR = WORK_DIR / "data"
REPORT_DIR = WORK_DIR / "reports"
MODEL_TMP_DIR = WORK_DIR / "models"

for p in [FLUTTER_MODELS_DIR, DATA_DIR, REPORT_DIR, MODEL_TMP_DIR]:
    p.mkdir(parents=True, exist_ok=True)

RANDOM_SEED = 42
DEFAULT_ALPHA = 0.65
DEFAULT_BETA = 1.0

DISCLAIMER = (
    "This is NOT a medical diagnosis. If you suspect stroke, seek emergency medical care."
)
