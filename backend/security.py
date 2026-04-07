import secrets
import hashlib
import bcrypt

def generate_salt(length: int = 16) -> str:
    return secrets.token_hex(length)  # 16 bytes -> 32 hex chars

def _prehash_bytes(password: str, salt: str) -> bytes:
    # Fixed 32-byte digest -> always safe for bcrypt
    return hashlib.sha256((password + salt).encode("utf-8")).digest()

def hash_password(password: str, salt: str) -> str:
    pre = _prehash_bytes(password, salt)
    hashed = bcrypt.hashpw(pre, bcrypt.gensalt(rounds=12))
    return hashed.decode("utf-8")  # store as text in DB

def verify_password(password: str, salt: str, stored_hash: str) -> bool:
    pre = _prehash_bytes(password, salt)
    return bcrypt.checkpw(pre, stored_hash.encode("utf-8"))



import random
from datetime import datetime, timedelta

def generate_otp() -> str:
    # 6-digit OTP, leading zeros allowed
    return f"{random.randint(0, 999999):06d}"

def generate_otp_salt(length: int = 8) -> str:
    return secrets.token_hex(length)  # 8 bytes -> 16 hex chars

def hash_otp(otp: str, otp_salt: str) -> str:
    # sha256(otp_salt + otp) -> hex string
    return hashlib.sha256((otp_salt + otp).encode("utf-8")).hexdigest()

def otp_expiry(seconds: int = 90) -> datetime:
    return datetime.utcnow() + timedelta(seconds=seconds)

