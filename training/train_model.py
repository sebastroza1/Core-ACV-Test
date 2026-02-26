import argparse
import numpy as np
import tensorflow as tf
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--features', default='training/data/features.npz')
    parser.add_argument('--out', default='training/artifacts/keras_model.keras')
    args = parser.parse_args()

    data = np.load(args.features)
    X_train, y_train = data['X_train'], data['y_train']
    X_val, y_val = data['X_val'], data['y_val']

    tf.keras.utils.set_random_seed(42)

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(X_train.shape[1],)),
        tf.keras.layers.Dense(256, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])
    model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy', tf.keras.metrics.AUC(name='auc')])
    model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=25, batch_size=64)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    model.save(out)
    print('saved model to', out)


if __name__ == '__main__':
    main()
