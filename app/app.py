"""Tiny lab app. The point of the lab is the platform, not the app."""
import json
import os
import socket

import boto3
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)


def get_db_credentials():
    """Read the database username and password from Secrets Manager at runtime.
    Nothing secret is stored in code, config files, or environment variables."""
    client = boto3.client("secretsmanager")
    secret = client.get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])
    return json.loads(secret["SecretString"])


def get_connection():
    creds = get_db_credentials()
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=creds["username"],
        password=creds["password"],
        sslmode="require",  # encrypt traffic to the database
        connect_timeout=5,
    )


def init_db():
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute(
            """CREATE TABLE IF NOT EXISTS visits (
                   id SERIAL PRIMARY KEY,
                   instance TEXT NOT NULL,
                   az TEXT NOT NULL,
                   visited_at TIMESTAMPTZ DEFAULT now()
               )"""
        )


@app.route("/")
def index():
    instance = socket.gethostname()
    az = os.environ.get("AZ", "unknown")
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO visits (instance, az) VALUES (%s, %s)", (instance, az))
        cur.execute("SELECT count(*) FROM visits")
        total = cur.fetchone()[0]
    return (
        "<h1>AWS Platform Lab</h1>"
        f"<p>Served by instance: <b>{instance}</b></p>"
        f"<p>Availability zone: <b>{az}</b></p>"
        f"<p>Total visits (stored in RDS): <b>{total}</b></p>"
    )


@app.route("/health")
def health():
    # Kept independent of the database on purpose: a database outage should not make
    # Auto Scaling replace every healthy app server.
    return jsonify(status="ok"), 200


@app.route("/db-health")
def db_health():
    try:
        with get_connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        return jsonify(database="ok"), 200
    except Exception as e:  # report the failure for troubleshooting
        return jsonify(database="error", detail=str(e)), 500


try:
    init_db()
except Exception as e:
    print(f"Database not ready at startup: {e}")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
