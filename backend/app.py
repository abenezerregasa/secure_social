import os
import time
import traceback

from flask import Flask, jsonify, request, make_response
from dotenv import load_dotenv

load_dotenv()

from db import get_db
from auth_service import register_user, login_user, verify_otp, complete_auth, resend_otp
from auth_middleware import require_auth
from posts_service import (
    list_posts, create_post, delete_post,
    like_post, unlike_post,
    list_comments, add_comment
)

app = Flask(__name__)

# -----------------------------
# CORS + Preflight (IMPORTANT for browser/Flutter web)
# -----------------------------
# Set env like:
# CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173
ALLOWED_ORIGINS = os.getenv("CORS_ORIGINS", "*")

def _set_cors_headers(resp):
    origin = request.headers.get("Origin", "")

    if ALLOWED_ORIGINS == "*":
        resp.headers["Access-Control-Allow-Origin"] = "*"
    else:
        allowed = [o.strip() for o in ALLOWED_ORIGINS.split(",") if o.strip()]
        if origin in allowed:
            resp.headers["Access-Control-Allow-Origin"] = origin

    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS"
    resp.headers["Access-Control-Max-Age"] = "86400"
    return resp


 


import time
from flask import g

@app.before_request
def _start_timer():
    g.t0 = time.time()
    print(f"[REQ] {request.method} {request.path}")

@app.after_request
def _end_timer(resp):
    ms = int((time.time() - g.t0) * 1000)
    print(f"[DONE] {request.method} {request.path} -> {resp.status_code} in {ms}ms")
    return resp

# Always return JSON even on server crashes (prevents "Non-JSON response")
@app.errorhandler(Exception)
def handle_exception(e):
    traceback.print_exc()
    return jsonify({
        "ok": False,
        "message": f"Server error: {type(e).__name__}: {e}"
    }), 500


# -----------------------------
# Routes
# -----------------------------

@app.get("/health")
def health():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT 1;")
        cur.fetchone()
        cur.close()
        conn.close()
        return jsonify({"ok": True, "db": "connected"}), 200
    except Exception as e:
        return jsonify({"ok": False, "db": "error", "detail": str(e)}), 500


@app.post("/auth/register")
def auth_register():
    data = request.get_json(silent=True) or {}
    ok, msg = register_user(data.get("email"), data.get("password"))
    if ok:
        return jsonify({"ok": True, "message": msg}), 201
    return jsonify({"ok": False, "message": msg}), 400


@app.post("/auth/login")
def auth_login():
    data = request.get_json(silent=True) or {}
    ok, msg, payload = login_user(data.get("email"), data.get("password"))
    if ok:
        return jsonify({"ok": True, "message": msg, **payload}), 200
    return jsonify({"ok": False, "message": msg}), 401


@app.post("/auth/verify-otp")
def auth_verify_otp():
    data = request.get_json(silent=True) or {}
    challenge_id = data.get("challenge_id")
    otp = (data.get("otp") or "").strip()

    try:
        challenge_id = int(challenge_id)
    except Exception:
        return jsonify({"ok": False, "message": "Invalid challenge_id."}), 400

    ok, msg, payload = verify_otp(challenge_id, otp)
    if ok:
        return jsonify({"ok": True, "message": msg, **payload}), 200
    return jsonify({"ok": False, "message": msg}), 401


@app.post("/auth/resend-otp")
def auth_resend_otp():
    data = request.get_json(silent=True) or {}
    challenge_id = data.get("challenge_id")

    try:
        challenge_id = int(challenge_id)
    except Exception:
        return jsonify({"ok": False, "message": "Invalid challenge_id."}), 400

    ok, msg, payload = resend_otp(challenge_id)
    if ok:
        return jsonify({"ok": True, "message": msg, **payload}), 200
    return jsonify({"ok": False, "message": msg}), 400


@app.post("/auth/complete")
def auth_complete():
    t0 = time.time()
    try:
        data = request.get_json(silent=True) or {}
        print(" /auth/complete JSON keys:", list(data.keys()))

        otp_token = (data.get("otp_token") or "").strip()
        print(" otp_token length:", len(otp_token))

        print(" calling complete_auth() ...")
        ok, msg, payload = complete_auth(otp_token)
        print(" complete_auth() returned:", ok)

        print(f"⏱ /auth/complete finished in {round((time.time()-t0)*1000)}ms")

        if ok:
            return jsonify({"ok": True, "message": msg, **payload}), 200
        return jsonify({"ok": False, "message": msg}), 401

    except Exception as e:
        print(" /auth/complete crashed:", repr(e))
        traceback.print_exc()
        return jsonify({"ok": False, "message": f"Server error: {type(e).__name__}: {e}"}), 500


@app.get("/posts")
@require_auth
def get_posts():
    posts = list_posts(request.user_id)
    return jsonify({"ok": True, "posts": posts}), 200


@app.post("/posts")
@require_auth
def new_post():
    data = request.get_json(silent=True) or {}
    ok, msg, payload = create_post(request.user_id, data.get("content"))
    if ok:
        return jsonify({"ok": True, "message": msg, **payload}), 201
    return jsonify({"ok": False, "message": msg}), 400


@app.delete("/posts/<int:post_id>")
@require_auth
def remove_post(post_id: int):
    ok, msg, status = delete_post(request.user_id, post_id)
    if ok:
        return jsonify({"ok": True, "message": msg}), status
    return jsonify({"ok": False, "message": msg}), status


@app.post("/posts/<int:post_id>/like")
@require_auth
def like(post_id: int):
    ok, msg, status, payload = like_post(request.user_id, post_id)
    if ok:
        return jsonify({"ok": True, "message": msg, **payload}), status
    return jsonify({"ok": False, "message": msg}), status


@app.delete("/posts/<int:post_id>/like")
@require_auth
def unlike(post_id: int):
    ok, msg, status, payload = unlike_post(request.user_id, post_id)
    if ok:
        return jsonify({"ok": True, "message": msg, **payload}), status
    return jsonify({"ok": False, "message": msg}), status


@app.get("/posts/<int:post_id>/comments")
@require_auth
def get_comments(post_id: int):
    comments = list_comments(post_id)
    return jsonify({"ok": True, "comments": comments}), 200


@app.post("/posts/<int:post_id>/comments")
@require_auth
def new_comment(post_id: int):
    data = request.get_json(silent=True) or {}
    ok, msg, status, payload = add_comment(request.user_id, post_id, data.get("content"))
    if ok:
        return jsonify({"ok": True, "message": msg, **payload}), status
    return jsonify({"ok": False, "message": msg}), status


# -----------------------------
# RUN
# -----------------------------
if __name__ == "__main__":
    #  Optional DB warmup (prevents first-request cold issues)
    try:
        c = get_db()
        cur = c.cursor()
        cur.execute("SELECT 1;")
        cur.fetchone()
        cur.close()
        c.close()
        print(" DB warmup OK")
    except Exception as e:
        print(" DB warmup failed:", e)

    host = os.getenv("APP_HOST", "0.0.0.0")
    port = int(os.getenv("APP_PORT", "8000"))

    app.run(
        host=host,
        port=port,
        debug=True,
        use_reloader=False,
        threaded=True,
    )