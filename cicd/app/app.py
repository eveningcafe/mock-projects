import os
import psycopg2
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__, static_folder="static")

DB = dict(
    host=os.environ["DB_HOST"],
    port=os.environ.get("DB_PORT", 5432),
    dbname=os.environ["DB_NAME"],
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASSWORD"],
)


def db():
    conn = psycopg2.connect(**DB)
    with conn, conn.cursor() as cur:
        cur.execute("CREATE TABLE IF NOT EXISTS items (id SERIAL PRIMARY KEY, text TEXT)")
    return conn


@app.get("/")
def index():
    return send_from_directory("static", "index.html")


@app.get("/health")
def health():
    return "ok"


@app.get("/api/items")
def list_items():
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, text FROM items ORDER BY id DESC")
        rows = cur.fetchall()
    return jsonify([{"id": r[0], "text": r[1]} for r in rows])


@app.post("/api/items")
def add_item():
    text = request.json.get("text", "").strip()
    if not text:
        return jsonify(error="text required"), 400
    with db() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO items (text) VALUES (%s) RETURNING id", (text,))
        item_id = cur.fetchone()[0]
    return jsonify(id=item_id, text=text), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
