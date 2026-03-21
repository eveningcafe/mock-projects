import os
import time
from flask import Flask, jsonify, render_template

import pymysql
import pymongo
import redis
from minio import Minio
from minio.error import S3Error

app = Flask(__name__)

# ── Config from environment variables ─────────────────────────────────────────

MARIADB_HOST     = os.getenv("MARIADB_HOST", "localhost")
MARIADB_PORT     = int(os.getenv("MARIADB_PORT", 3306))
MARIADB_USER     = os.getenv("MARIADB_USER", "root")
MARIADB_PASSWORD = os.getenv("MARIADB_PASSWORD", "")
MARIADB_DB       = os.getenv("MARIADB_DB", "healthdb")

MONGO_HOST = os.getenv("MONGO_HOST", "localhost")
MONGO_PORT = int(os.getenv("MONGO_PORT", 27017))

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))

MINIO_HOST       = os.getenv("MINIO_HOST", "localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin")
MINIO_BUCKET     = os.getenv("MINIO_BUCKET", "healthcheck")

# ── Health check functions ─────────────────────────────────────────────────────

def check_mariadb():
    start = time.time()
    try:
        conn = pymysql.connect(
            host=MARIADB_HOST, port=MARIADB_PORT,
            user=MARIADB_USER, password=MARIADB_PASSWORD,
            db=MARIADB_DB, connect_timeout=3
        )
        conn.cursor().execute("SELECT 1")
        conn.close()
        return {"status": "ok", "latency_ms": round((time.time() - start) * 1000)}
    except Exception as e:
        return {"status": "error", "error": str(e)}

def check_mongodb():
    start = time.time()
    try:
        client = pymongo.MongoClient(
            MONGO_HOST, MONGO_PORT,
            serverSelectionTimeoutMS=3000
        )
        client.admin.command("ping")
        client.close()
        return {"status": "ok", "latency_ms": round((time.time() - start) * 1000)}
    except Exception as e:
        return {"status": "error", "error": str(e)}

def check_redis():
    start = time.time()
    try:
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, socket_connect_timeout=3)
        r.ping()
        return {"status": "ok", "latency_ms": round((time.time() - start) * 1000)}
    except Exception as e:
        return {"status": "error", "error": str(e)}

def check_minio():
    start = time.time()
    try:
        client = Minio(MINIO_HOST, access_key=MINIO_ACCESS_KEY,
                       secret_key=MINIO_SECRET_KEY, secure=False)
        client.bucket_exists(MINIO_BUCKET)
        return {"status": "ok", "latency_ms": round((time.time() - start) * 1000)}
    except Exception as e:
        return {"status": "error", "error": str(e)}

# ── Routes ─────────────────────────────────────────────────────────────────────

@app.route("/health")
def health():
    results = {
        "mariadb": check_mariadb(),
        "mongodb": check_mongodb(),
        "redis":   check_redis(),
        "minio":   check_minio(),
    }
    overall = all(v["status"] == "ok" for v in results.values())
    return jsonify({"overall": "ok" if overall else "degraded", "services": results}), \
           200 if overall else 503

@app.route("/")
def index():
    results = {
        "mariadb": check_mariadb(),
        "mongodb": check_mongodb(),
        "redis":   check_redis(),
        "minio":   check_minio(),
    }
    return render_template("index.html", services=results)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
