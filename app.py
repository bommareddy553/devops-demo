import os
import time
from flask import Flask, jsonify

app = Flask(__name__)

START_TIME = time.monotonic()
APP_VERSION = os.getenv("APP_VERSION", "v1")
READY_DELAY_SECONDS = int(os.getenv("READY_DELAY_SECONDS", "0"))
NEVER_READY = os.getenv("NEVER_READY", "false").lower() == "true"
INSTANCE = os.getenv("HOSTNAME", "local")

def is_ready():
    if NEVER_READY:
        return False
    return time.monotonic() - START_TIME >= READY_DELAY_SECONDS

@app.get("/health")
def health():
    return jsonify(status="alive", version=APP_VERSION, instance=INSTANCE), 200

@app.get("/ready")
def ready():
    if not is_ready():
        return jsonify(status="not-ready", version=APP_VERSION, instance=INSTANCE), 503
    return jsonify(status="ready", version=APP_VERSION, instance=INSTANCE), 200

@app.get("/version")
def version():
    if not is_ready():
        return jsonify(status="not-ready", version=APP_VERSION, instance=INSTANCE), 503
    return jsonify(status="ready", version=APP_VERSION, instance=INSTANCE), 200

if __name__ == "__main__":
    # Bind immediately; readiness is controlled independently.
    app.run(host="0.0.0.0", port=8080, threaded=True)
