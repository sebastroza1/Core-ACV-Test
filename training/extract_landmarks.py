import argparse
import json
from pathlib import Path
import cv2
import mediapipe as mp


def extract_one(img_path: Path, mesh):
    image = cv2.imread(str(img_path))
    if image is None:
        return None
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    res = mesh.process(rgb)
    if not res.multi_face_landmarks:
        return None
    lm = res.multi_face_landmarks[0].landmark
    return [[p.x, p.y, p.z] for p in lm]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--images', default='training/data/raw')
    parser.add_argument('--out', default='training/data/landmarks.jsonl')
    args = parser.parse_args()

    mp_mesh = mp.solutions.face_mesh
    mesh = mp_mesh.FaceMesh(static_image_mode=True, refine_landmarks=True, max_num_faces=1)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    skipped = 0
    total = 0

    with out_path.open('w', encoding='utf-8') as f:
        for img_path in Path(args.images).rglob('*.jpg'):
            total += 1
            lms = extract_one(img_path, mesh)
            if lms is None:
                skipped += 1
                continue
            label = 1 if 'palsy' in img_path.name.lower() else 0
            row = {'image_path': str(img_path), 'label': label, 'landmarks': lms}
            f.write(json.dumps(row) + '\n')

    print({'total': total, 'skipped': skipped, 'saved': total - skipped})


if __name__ == '__main__':
    main()
