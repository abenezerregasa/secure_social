from db import get_db


# -----------------------------
# Posts
# -----------------------------
def list_posts(viewer_user_id: int):
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute(
            """
            SELECT 
              p.id,
              p.user_id,
              u.email AS author_email,
              p.content,
              p.created_at,

              (SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id) AS like_count,
              EXISTS(
                SELECT 1 FROM post_likes pl2
                WHERE pl2.post_id = p.id AND pl2.user_id = %s
              ) AS liked_by_me,

              (SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id) AS comment_count

            FROM user_posts p
            JOIN users u ON u.id = p.user_id
            ORDER BY p.created_at DESC
            """,
            (viewer_user_id,),
        )

        rows = cur.fetchall() or []

        for r in rows:
            r["liked_by_me"] = bool(r.get("liked_by_me"))
            r["like_count"] = int(r.get("like_count") or 0)
            r["comment_count"] = int(r.get("comment_count") or 0)

        return rows

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


def create_post(user_id: int, content: str):
    post_content = (content or "").strip()

    if not post_content:
        return False, "Content cannot be empty.", None
    if len(post_content) > 50000:
        return False, "Content too long (max 50000 characters).", None

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            "INSERT INTO user_posts (user_id, content) VALUES (%s, %s)",
            (user_id, post_content),
        )

        # Even if autocommit=True, commit() is safe and makes behavior consistent.
        conn.commit()

        post_id = cur.lastrowid
        return True, "Post created.", {"post_id": post_id}

    except Exception as e:
        return False, f"Create post error: {type(e).__name__}: {e}", None

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


def delete_post(user_id: int, post_id: int):
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute("SELECT id, user_id FROM user_posts WHERE id=%s", (post_id,))
        post_row = cur.fetchone()

        if not post_row:
            return False, "Post not found.", 404

        if int(post_row["user_id"]) != int(user_id):
            return False, "You can only delete your own posts.", 403

        # Delete post (FK constraints should remove likes/comments if you set ON DELETE CASCADE)
        # If you didn't set CASCADE, then delete children first in schema or here.
        cur2 = conn.cursor()
        try:
            # Safe cleanup (won't error if tables exist)
            cur2.execute("DELETE FROM post_likes WHERE post_id=%s", (post_id,))
            cur2.execute("DELETE FROM post_comments WHERE post_id=%s", (post_id,))
            cur2.execute("DELETE FROM user_posts WHERE id=%s", (post_id,))
            conn.commit()
        finally:
            try:
                cur2.close()
            except Exception:
                pass

        return True, "Post deleted.", 200

    except Exception as e:
        return False, f"Delete post error: {type(e).__name__}: {e}", 500

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
# Likes
# -----------------------------
def like_post(user_id: int, post_id: int):
    conn = None
    cur = None
    cur2 = None
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        # check post exists
        cur.execute("SELECT id FROM user_posts WHERE id=%s", (post_id,))
        if not cur.fetchone():
            return False, "Post not found.", 404, None

        # insert like (unique constraint recommended on (post_id, user_id))
        try:
            cur2 = conn.cursor()
            cur2.execute(
                "INSERT INTO post_likes (post_id, user_id) VALUES (%s, %s)",
                (post_id, user_id),
            )
            conn.commit()
        except Exception as e:
            # If already liked, treat as success (idempotent)
            msg = str(e).lower()
            # MySQL duplicate messages often contain "duplicate" and/or "1062"
            if ("duplicate" not in msg) and ("1062" not in msg):
                return False, f"Like failed: {type(e).__name__}: {e}", 400, None

        # return updated like_count
        cur.execute("SELECT COUNT(*) AS c FROM post_likes WHERE post_id=%s", (post_id,))
        like_count = int(cur.fetchone()["c"])

        return True, "Liked.", 200, {"like_count": like_count, "liked_by_me": True}

    finally:
        try:
            if cur2:
                cur2.close()
        except Exception:
            pass
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


def unlike_post(user_id: int, post_id: int):
    conn = None
    cur = None
    cur2 = None
    try:
        conn = get_db()
        cur = conn.cursor()

        cur.execute(
            "DELETE FROM post_likes WHERE post_id=%s AND user_id=%s",
            (post_id, user_id),
        )
        conn.commit()

        cur2 = conn.cursor(dictionary=True)
        cur2.execute("SELECT COUNT(*) AS c FROM post_likes WHERE post_id=%s", (post_id,))
        like_count = int(cur2.fetchone()["c"])

        return True, "Unliked.", 200, {"like_count": like_count, "liked_by_me": False}

    finally:
        try:
            if cur2:
                cur2.close()
        except Exception:
            pass
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
# Comments
# -----------------------------
def list_comments(post_id: int):
    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute(
            """
            SELECT 
              c.id,
              c.post_id,
              c.user_id,
              u.email AS author_email,
              c.content,
              c.created_at
            FROM post_comments c
            JOIN users u ON u.id = c.user_id
            WHERE c.post_id = %s
            ORDER BY c.created_at ASC
            """,
            (post_id,),
        )

        return cur.fetchall() or []

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


def add_comment(user_id: int, post_id: int, content: str):
    text = (content or "").strip()
    if not text:
        return False, "Comment cannot be empty.", 400, None
    if len(text) > 50000:
        return False, "Comment too long (max 50000 characters).", 400, None

    conn = None
    cur = None
    try:
        conn = get_db()
        cur = conn.cursor()

        # Check post exists
        cur.execute("SELECT id FROM user_posts WHERE id=%s", (post_id,))
        if not cur.fetchone():
            return False, "Post not found.", 404, None

        # Insert comment
        cur.execute(
            "INSERT INTO post_comments (post_id, user_id, content, created_at) VALUES (%s, %s, %s, NOW())",
            (post_id, user_id, text),
        )
        conn.commit()
        comment_id = cur.lastrowid

        # Get count
        cur.execute("SELECT COUNT(*) FROM post_comments WHERE post_id=%s", (post_id,))
        res = cur.fetchone()
        comment_count = int(res[0]) if res else 0

        return True, "Comment added.", 201, {
            "comment_id": comment_id,
            "comment_count": comment_count
        }

    except Exception as e:
        print("CRITICAL ERROR in add_comment:", repr(e))
        return False, f"Database error: {type(e).__name__}: {e}", 500, None

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