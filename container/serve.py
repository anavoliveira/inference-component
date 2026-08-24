import os

import joblib
import numpy as np
from flask import Flask, jsonify, request

MODEL_DIR = os.environ.get("MODEL_PATH", "/opt/ml/model")
_model = None


def get_model():
    global _model
    if _model is None:
        _model = joblib.load(os.path.join(MODEL_DIR, "model.joblib"))
    return _model


app = Flask(__name__)


@app.get("/ping")
def ping():
    try:
        get_model()
        return "", 200
    except Exception:
        return "", 500


@app.post("/invocations")
def invocations():
    data = request.get_json(force=True)
    instances = np.array(data["instances"])
    predictions = get_model().predict(instances).tolist()
    return jsonify({"predictions": predictions})
