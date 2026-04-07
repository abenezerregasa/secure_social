import os
import mysql.connector
from mysql.connector import pooling

# -----------------------------
# Create the pool ONCE
# -----------------------------
db_pool = pooling.MySQLConnectionPool(
    pool_name="mypool",
    pool_size=10,
    pool_reset_session=True,

    host=os.getenv("DB_HOST"),
    port=int(os.getenv("DB_PORT", "3309")),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    database=os.getenv("DB_NAME"),

    autocommit=True,
    raise_on_warnings=True
)

# -----------------------------
# Get connection safely
# -----------------------------
def get_db():
    try:
        conn = db_pool.get_connection()

        # VERY IMPORTANT: ensure connection is alive
        conn.ping(reconnect=True, attempts=3, delay=1)

        return conn

    except mysql.connector.Error as e:
        print(" DB connection error:", repr(e))
        raise


# -----------------------------
# Optional helper (DEBUGGING)
# -----------------------------
def test_connection():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT 1;")
        result = cur.fetchone()
        cur.close()
        conn.close()
        print(" DB test OK:", result)
        return True
    except Exception as e:
        print(" DB test failed:", repr(e))
        return False