import argparse
import json
from pathlib import Path
import numpy as np
import tensorflow as tf


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', default='training/artifacts/keras_model.keras')
    parser.add_argument('--features', default='training/data/features.npz')
    parser.add_argument('--out_model', default='assets/models/palsy_landmarks_model.tflite')
    parser.add_argument('--out_spec', default='assets/models/feature_spec.json')
    args = parser.parse_args()

    model = tf.keras.models.load_model(args.model)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite = converter.convert()

    out_model = Path(args.out_model)
    out_model.parent.mkdir(parents=True, exist_ok=True)
    out_model.write_bytes(tflite)

    d = np.load(args.features)
    mean = d['mean'].tolist()
    std = d['std'].tolist()

    spec = {
        'feature_dim': len(mean),
        'landmark_count': 468,
        'ordering': 'mediapipe_face_mesh_468_xyz',
        'mean': mean,
        'std': std,
    }
    Path(args.out_spec).write_text(json.dumps(spec), encoding='utf-8')
    Path('assets/models/labels.txt').write_text('normal\npalsy\n', encoding='utf-8')
    print('exported tflite and spec')


if __name__ == '__main__':
    main()
