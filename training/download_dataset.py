import argparse
from pathlib import Path
from datasets import load_dataset


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default='training/data/raw')
    parser.add_argument('--dataset', default='jasir/palsynet-data')
    args = parser.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    ds = load_dataset(args.dataset)
    for split_name, split in ds.items():
      split_dir = out / split_name
      split_dir.mkdir(parents=True, exist_ok=True)
      for i, row in enumerate(split):
        img = row['image']
        label = row.get('label', row.get('class', 'unknown'))
        fname = split_dir / f"{i:06d}_{label}.jpg"
        img.save(fname)
    print('dataset downloaded to', out)


if __name__ == '__main__':
    main()
