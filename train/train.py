import argparse
import os

import joblib
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split


def model_fn(model_dir):
    return joblib.load(os.path.join(model_dir, "model.joblib"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-estimators", type=int, default=100)
    parser.add_argument("--max-depth", type=int, default=4)
    parser.add_argument("--random-state", type=int, default=42)
    parser.add_argument("--model-dir", type=str, default=os.environ.get("SM_MODEL_DIR", "."))
    args = parser.parse_args()

    X, y = load_iris(return_X_y=True)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=args.random_state, stratify=y
    )

    clf = RandomForestClassifier(
        n_estimators=args.n_estimators,
        max_depth=args.max_depth,
        random_state=args.random_state,
    )
    clf.fit(X_train, y_train)

    accuracy = clf.score(X_test, y_test)
    print(f"test_accuracy={accuracy:.4f}")

    os.makedirs(args.model_dir, exist_ok=True)
    joblib.dump(clf, os.path.join(args.model_dir, "model.joblib"))
