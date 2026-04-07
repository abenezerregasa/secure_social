import os
from datetime import datetime, timedelta, timezone
import jwt

JWT_SECRET = os.getenv("JWT_SECRET", "dev_secret_change_me")
JWT_ALG = os.getenv("JWT_ALG", "HS256")

# Helps when server/client/container clocks differ slightly
JWT_LEEWAY_SECONDS = int(os.getenv("JWT_LEEWAY_SECONDS", "10"))


def _now():
    return datetime.now(timezone.utc)


def issue_otp_token(user_id: int, minutes: int = 5) -> str:
    now = _now()
    exp = now + timedelta(minutes=minutes)
    payload = {
        "sub": str(user_id),
        "type": "otp",
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)


def issue_access_token(user_id: int, minutes: int = 1440) -> str:
    now = _now()
    exp = now + timedelta(minutes=minutes)
    payload = {
        "sub": str(user_id),
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)


def verify_otp_token(token: str) -> dict:
    payload = jwt.decode(
        token,
        JWT_SECRET,
        algorithms=[JWT_ALG],
        options={"require": ["exp", "sub"]},
        leeway=JWT_LEEWAY_SECONDS,
    )
    if payload.get("type") != "otp":
        raise Exception("Wrong token type")
    if not payload.get("sub"):
        raise Exception("Missing sub")
    return payload


def verify_access_token(token: str) -> dict:
    payload = jwt.decode(
        token,
        JWT_SECRET,
        algorithms=[JWT_ALG],
        options={"require": ["exp", "sub"]},
        leeway=JWT_LEEWAY_SECONDS,
    )
    if payload.get("type") != "access":
        raise Exception("Wrong token type")
    if not payload.get("sub"):
        raise Exception("Missing sub")
    return payload