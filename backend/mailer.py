import os
import smtplib
from email.message import EmailMessage

def send_otp_email(to_email: str, otp_code: str, ttl_seconds: int = 300) -> None:
    host = os.getenv("MAIL_HOST", "smtp.gmail.com")
    port = int(os.getenv("MAIL_PORT", "587"))
    use_tls = os.getenv("MAIL_USE_TLS", "1") == "1"

    username = os.getenv("MAIL_USERNAME", "")
    password = os.getenv("MAIL_PASSWORD", "")
    sender = os.getenv("MAIL_FROM", username)

    if not username or not password:
        raise RuntimeError("Missing MAIL_USERNAME / MAIL_PASSWORD in environment.")

    msg = EmailMessage()
    msg["Subject"] = "Your TFA Social OTP Code"
    msg["From"] = sender
    msg["To"] = to_email

    msg.set_content(
        f"Your OTP code is: {otp_code}\n\n"
        f"This code expires in {ttl_seconds // 60} minutes.\n"
        "If you didn’t request this, you can ignore this email."
    )

    with smtplib.SMTP(host, port, timeout=10) as smtp:
        smtp.ehlo()
        if use_tls:
            smtp.starttls()
            smtp.ehlo()
        smtp.login(username, password)
        smtp.send_message(msg)