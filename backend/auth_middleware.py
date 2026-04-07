import os
from functools import wraps
from flask import request, jsonify
from jwt_utils import verify_access_token


def require_auth(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        # Some proxies/clients can alter header casing; Flask usually normalizes,
        # but we support both to be safe.
        auth = request.headers.get("Authorization") or request.headers.get("authorization") or ""
        auth = (auth or "").strip()

        if not auth:
            return jsonify({"ok": False, "message": "Missing Authorization header."}), 401

        # Allow extra spaces: "Bearer    <token>"
        parts = auth.split()
        if len(parts) < 2 or parts[0].lower() != "bearer":
            return jsonify({
                "ok": False,
                "message": "Invalid Authorization header format. Use: Bearer <token>."
            }), 401

        token = parts[1].strip()
        if not token:
            return jsonify({"ok": False, "message": "Missing Bearer token."}), 401

        try:
            payload = verify_access_token(token)
            request.user_id = int(payload["sub"])
        except Exception as e:
            resp = {
                "ok": False,
                "message": "Invalid or expired access_token.",
            }
            if os.getenv("APP_ENV", "prod").lower() == "dev":
                resp["detail"] = f"{type(e).__name__}: {e}"
            return jsonify(resp), 401

        return fn(*args, **kwargs)

    return wrapper