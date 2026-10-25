"""Tiny lab app. The point of the lab is the platform, not the app."""
import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    # Shows which instance answered, so you can watch the load balancer spread traffic.
    return (
        "<h1>AWS Platform Lab</h1>"
        f"<p>Served by instance: <b>{socket.gethostname()}</b></p>"
        f"<p>Availability zone: <b>{os.environ.get('AZ', 'unknown')}</b></p>"
    )


@app.route("/health")
def health():
    # The load balancer calls this to decide if the instance is healthy.
    return jsonify(status="ok"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
