"""
Backend API - Flask
Talks to MySQL (local Docker container in dev, AWS RDS in prod).
All configuration comes from environment variables (see .env.example).
"""
import os
import time
import pymysql
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

DB_HOST = os.environ.get("DB_HOST", "mysql")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_USER = os.environ.get("DB_USER", "appuser")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "apppassword")
DB_NAME = os.environ.get("DB_NAME", "appdb")


def get_connection(retries=10, delay=3):
    """Connect to MySQL with retries (useful while RDS/container is booting)."""
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            return pymysql.connect(
                host=DB_HOST,
                port=DB_PORT,
                user=DB_USER,
                password=DB_PASSWORD,
                database=DB_NAME,
                cursorclass=pymysql.cursors.DictCursor,
                connect_timeout=5,
            )
        except pymysql.err.OperationalError as e:
            last_err = e
            app.logger.warning(f"DB connect attempt {attempt}/{retries} failed: {e}")
            time.sleep(delay)
    raise last_err


def init_db():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS tasks (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    done BOOLEAN NOT NULL DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
        conn.commit()
    finally:
        conn.close()


@app.route("/api/health", methods=["GET"])
def health():
    """Used by Docker healthcheck and the load balancer / nginx."""
    try:
        conn = get_connection(retries=1)
        conn.close()
        db_status = "up"
    except Exception as e:
        db_status = f"down: {e}"
    return jsonify({"status": "ok", "database": db_status}), 200


@app.route("/api/tasks", methods=["GET"])
def list_tasks():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, title, done, created_at FROM tasks ORDER BY id DESC")
            rows = cur.fetchall()
        return jsonify(rows)
    finally:
        conn.close()


@app.route("/api/tasks", methods=["POST"])
def create_task():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    if not title:
        return jsonify({"error": "title is required"}), 400

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO tasks (title) VALUES (%s)", (title,))
            new_id = cur.lastrowid
        conn.commit()
        return jsonify({"id": new_id, "title": title, "done": False}), 201
    finally:
        conn.close()


@app.route("/api/tasks/<int:task_id>", methods=["PATCH"])
def update_task(task_id):
    data = request.get_json(silent=True) or {}
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            if "done" in data:
                cur.execute("UPDATE tasks SET done=%s WHERE id=%s", (bool(data["done"]), task_id))
            if "title" in data:
                cur.execute("UPDATE tasks SET title=%s WHERE id=%s", (data["title"], task_id))
        conn.commit()
        return jsonify({"status": "updated"})
    finally:
        conn.close()


@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM tasks WHERE id=%s", (task_id,))
        conn.commit()
        return jsonify({"status": "deleted"})
    finally:
        conn.close()


# Initialize schema on import so it works under gunicorn too.
try:
    init_db()
except Exception as e:
    app.logger.error(f"Could not initialize database on startup: {e}")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
