from typing import Tuple
from datetime import datetime, timezone

import os

from db import get_db
from security import (
    generate_salt,
    hash_password,
    verify_password,
    generate_otp,
    generate_otp_salt,
    hash_otp,
    otp_expiry,
)
from jwt_utils import issue_otp_token, verify_otp_token, issue_access_token
from mailer import send_otp_email


# -----------------------------
# Helpers
# -----------------------------
def _is_dev() -> bool:
    return os.getenv("APP_ENV", "prod").lower() == "dev"


def _ensure_utc_aware(dt):
    """
    MySQL DATETIME often comes back naive (no tzinfo).
    We treat DB times as UTC.
    """
    if dt is None:
        return None
    if getattr(dt, "tzinfo", None) is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _maybe_decode(value):
    if isinstance(value, (bytes, bytearray)):
        try:
            return value.decode("utf-8")
        except Exception:
            return value.decode("latin-1", errors="ignore")
    return value


# -----------------------------
# Register
# -----------------------------
def register_user(email: str, password: str) -> Tuple[bool, str]:
    normalized_email = (email or "").strip().lower()
    raw_password = password or ""

    if not normalized_email or "@" not in normalized_email:
        return False, "Invalid email."
    if len(raw_password) < 8:
        return False, "Password must be at least 8 characters."

    password_salt = generate_salt()
    password_hash = hash_password(raw_password, password_salt)

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            "INSERT INTO users (email, password_hash, salt) VALUES (%s, %s, %s)",
            (normalized_email, password_hash, password_salt),
        )
        conn.commit()
        return True, "Registered."

    except Exception as e:
        msg = str(e).lower()
        # MySQL duplicates often contain "1062"
        if "duplicate" in msg or "1062" in msg:
            return False, "Email already registered."
        return False, f"Registration failed: {type(e).__name__}"

    finally:
        try:
            if cur:
                cur.close()
        except Exception:
            pass
        try:
            if conn:
                conn.close()
        except Exception:
            pass


# -----------------------------
# Login (password check + create OTP challenge + send email)
# -----------------------------
def login_user(email: str, password: str):
    normalized_email = (email or "").strip().lower()
    raw_password = password or ""

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute(
            "SELECT id, password_hash, salt FROM users WHERE email=%s",
            (normalized_email,),
        )
        user_record = cur.fetchone()

        if not user_record:
            return False, "Invalid credentials.", None

        if not verify_password(raw_password, user_record["salt"], user_record["password_hash"]):
            return False, "Invalid credentials.", None

        user_id = int(user_record["id"])

        # Invalidate previous unused OTPs (keep only one valid)
        cur.execute(
            "UPDATE otp_verifications SET used=1 WHERE user_id=%s AND used=0",
            (user_id,),
        )
        conn.commit()

        # Create NEW OTP challenge
        otp_plain = generate_otp()
        otp_salt = generate_otp_salt()
        otp_hash = hash_otp(otp_plain, otp_salt)
        expires_at = otp_expiry(300)  # 5 minutes

        cur.execute(
            """
            INSERT INTO otp_verifications (user_id, otp_hash, otp_salt, expires_at, used)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (user_id, otp_hash, otp_salt, expires_at, 0),
        )
        conn.commit()

        challenge_id = cur.lastrowid

        # Send OTP email
        try:
            send_otp_email(normalized_email, otp_plain, ttl_seconds=300)
        except Exception as e:
            # cleanup: invalidate created OTP to avoid dead challenge
            try:
                cur.execute("UPDATE otp_verifications SET used=1 WHERE id=%s", (challenge_id,))
                conn.commit()
            except Exception:
                pass
            return False, f"Failed to send OTP email: {e}", None

        payload = {"challenge_id": challenge_id}
        if _is_dev():
            payload["otp_debug"] = otp_plain

        return True, "OTP sent to your email.", payload

    except Exception as e:
        return False, f"Login error: {type(e).__name__}: {e}", None

    finally:
        try:
            if cur:
                cur.close()
        except Exception:
            pass
        try:
            if conn:
                conn.close()
        except Exception:
            pass


# -----------------------------
# Verify OTP -> issues otp_token
# -----------------------------
def verify_otp(challenge_id: int, otp: str):
    otp_input = (otp or "").strip()
    print(f"[DEBUG] Verifying OTP for challenge {challenge_id}")

    if not otp_input:
        return False, "Invalid OTP.", None

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute(
            """
            SELECT id, user_id, otp_hash, otp_salt, expires_at, used
            FROM otp_verifications
            WHERE id=%s
            """,
            (challenge_id,),
        )
        otp_record = cur.fetchone()

        if not otp_record:
            print("[DEBUG] Challenge ID not found in DB")
            return False, "Invalid challenge.", None

        if int(otp_record.get("used") or 0) == 1:
            print("[DEBUG] OTP was already used")
            return False, "OTP already used.", None

        now = datetime.now(timezone.utc)
        expires_at = _ensure_utc_aware(otp_record.get("expires_at"))

        if not expires_at:
            print("[DEBUG] Missing expires_at in DB record")
            return False, "Invalid challenge.", None

        print(f"[DEBUG] Now: {now} | Expires: {expires_at}")

        if now > expires_at:
            print("[DEBUG] OTP has expired")
            return False, "OTP expired. Please resend.", None

        db_salt = _maybe_decode(otp_record.get("otp_salt"))
        db_hash = _maybe_decode(otp_record.get("otp_hash"))

        candidate_hash = hash_otp(otp_input, db_salt)

        if candidate_hash != db_hash:
            print("[DEBUG] Hash mismatch")
            return False, "Invalid OTP.", None

        # SUCCESS: Mark as used
        cur.execute("UPDATE otp_verifications SET used=1 WHERE id=%s", (challenge_id,))
        conn.commit()

        otp_token = issue_otp_token(int(otp_record["user_id"]), minutes=5)
        print("[DEBUG] OTP Verified Successfully")
        return True, "OTP verified.", {"otp_token": otp_token}

    except Exception as e:
        print("[DEBUG] ERROR during verify:", repr(e))
        return False, f"OTP verify error: {type(e).__name__}: {e}", None

    finally:
        try:
            if cur:
                cur.close()
        except Exception:
            pass
        try:
            if conn:
                conn.close()
        except Exception:
            pass


# -----------------------------
# Resend OTP (create new challenge + send email)
# -----------------------------
def resend_otp(challenge_id: int):
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        # Find original challenge -> user_id
        cur.execute(
            "SELECT id, user_id FROM otp_verifications WHERE id=%s",
            (challenge_id,),
        )
        row = cur.fetchone()
        if not row:
            return False, "Challenge not found.", None

        user_id = int(row["user_id"])

        # Get user email
        cur.execute("SELECT email FROM users WHERE id=%s", (user_id,))
        user_row = cur.fetchone()
        if not user_row:
            return False, "User not found.", None

        email = (user_row["email"] or "").strip().lower()

        # Invalidate any previous unused OTPs for this user
        cur.execute(
            "UPDATE otp_verifications SET used=1 WHERE user_id=%s AND used=0",
            (user_id,),
        )
        conn.commit()

        # Create new OTP
        otp_plain = generate_otp()
        otp_salt = generate_otp_salt()
        otp_hash = hash_otp(otp_plain, otp_salt)
        expires_at = otp_expiry(300)

        cur.execute(
            """
            INSERT INTO otp_verifications (user_id, otp_hash, otp_salt, expires_at, used)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (user_id, otp_hash, otp_salt, expires_at, 0),
        )
        conn.commit()

        new_id = cur.lastrowid

        # Send email
        try:
            send_otp_email(email, otp_plain, ttl_seconds=300)
        except Exception as e:
            # cleanup invalidate
            try:
                cur.execute("UPDATE otp_verifications SET used=1 WHERE id=%s", (new_id,))
                conn.commit()
            except Exception:
                pass
            return False, f"Failed to send OTP email: {e}", None

        payload = {"challenge_id": new_id}
        if _is_dev():
            payload["otp_debug"] = otp_plain

        return True, "OTP resent.", payload

    except Exception as e:
        return False, f"Resend OTP error: {type(e).__name__}: {e}", None

    finally:
        try:
            if cur:
                cur.close()
        except Exception:
            pass
        try:
            if conn:
                conn.close()
        except Exception:
            pass


# -----------------------------
# Complete auth (otp_token -> access_token)
# -----------------------------
def complete_auth(otp_token: str):
    otp_token = (otp_token or "").strip()
    if not otp_token:
        return False, "Missing otp_token.", None

    try:
        payload = verify_otp_token(otp_token)
        user_id = int(payload["sub"])
    except Exception as e:
        return False, f"otp_token error: {type(e).__name__}: {e}", None

    access_token = issue_access_token(user_id, minutes=1440)
    return True, "Authenticated.", {"access_token": access_token}