import argparse
import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, precision_recall_fscore_support, roc_auc_score, confusion_matrix


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--features', default='training/data/features.npz')
    parser.add_argument('--model', default='training/artifacts/keras_model.keras')
    args = parser.parse_args()

    data = np.load(args.features)
    X_test, y_test = data['X_test'], data['y_test']
    model = tf.keras.models.load_model(args.model)

    probs = model.predict(X_test, verbose=0).reshape(-1)
    threshold = 0.35  # sensitivity-prioritized
    preds = (probs >= threshold).astype(int)

    acc = accuracy_score(y_test, preds)
    prec, rec, f1, _ = precision_recall_fscore_support(y_test, preds, average='binary')
    auc = roc_auc_score(y_test, probs)
    cm = confusion_matrix(y_test, preds)

    print({'accuracy': acc, 'precision': prec, 'recall': rec, 'f1': f1, 'roc_auc': auc})
    print('confusion_matrix:\n', cm)


if __name__ == '__main__':
    main()
