import sqlite3
import time

class Curiosity:
    """Handles incremental learning by logging interactions."""

    def __init__(self, path: str = "memory.db"):
        self.conn = sqlite3.connect(path)
        self._ensure()

    def _ensure(self):
        cur = self.conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS log (
                ts REAL,
                user_message TEXT,
                context TEXT,
                response TEXT,
                perplexity REAL,
                entropy REAL,
                resonance REAL
            )
            """
        )
        self.conn.commit()

    def remember(self, user: str, context: str, response: str, metrics: dict):
        cur = self.conn.cursor()
        cur.execute(
            "INSERT INTO log VALUES (?,?,?,?,?,?,?)",
            (
                time.time(),
                user,
                context,
                response,
                metrics["perplexity"],
                metrics["entropy"],
                metrics["resonance"],
            ),
        )
        self.conn.commit()
