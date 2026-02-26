import argparse
import json
from pathlib import Path
import numpy as np
from sklearn.model_selection import train_test_split

SEED = 42


def engineered(lm):
    arr = np.array(lm, dtype=np.float32)
    # simple pseudo-index mapping (replace with precise mesh indices)
    left_mouth, right_mouth = arr[61], arr[291]
    left_eye, right_eye = arr[159], arr[386]
    left_brow, right_brow = arr[70], arr[300]
    nose, chin, mouth_center = arr[1], arr[152], arr[13]

    mouth_corner_delta = abs(left_mouth[1] - right_mouth[1])
    mouth_width_delta = abs(left_mouth[0] - nose[0]) - abs(right_mouth[0] - nose[0])
    eye_open_delta = abs(left_eye[1] - right_eye[1])
    brow_delta = abs(left_brow[1] - right_brow[1])
    midline_deviation = abs(mouth_center[0] - ((nose[0] + chin[0]) / 2))
    return np.array([
        mouth_corner_delta,
        mouth_width_delta,
        eye_open_delta,
        brow_delta,
        midline_deviation,
    ], dtype=np.float32)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--infile', default='training/data/landmarks.jsonl')
    parser.add_argument('--out', default='training/data/features.npz')
    args = parser.parse_args()

    X, y = [], []
    for line in Path(args.infile).read_text(encoding='utf-8').splitlines():
        row = json.loads(line)
        lm = np.array(row['landmarks'], dtype=np.float32)
        dense = lm.reshape(-1)
        feats = np.concatenate([dense, engineered(lm)], axis=0)
        X.append(feats)
        y.append(int(row['label']))

    X = np.stack(X)
    y = np.array(y)

    X_train, X_tmp, y_train, y_tmp = train_test_split(X, y, test_size=0.3, random_state=SEED, stratify=y)
    X_val, X_test, y_val, y_test = train_test_split(X_tmp, y_tmp, test_size=0.5, random_state=SEED, stratify=y_tmp)

    mean = X_train.mean(axis=0)
    std = X_train.std(axis=0) + 1e-6

    np.savez(args.out,
             X_train=(X_train-mean)/std,
             y_train=y_train,
             X_val=(X_val-mean)/std,
             y_val=y_val,
             X_test=(X_test-mean)/std,
             y_test=y_test,
             mean=mean,
             std=std)
    print('saved', args.out)


if __name__ == '__main__':
    main()
