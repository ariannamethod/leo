import collections
import re
import sqlite3

class Connections:
    """Explores relations between memory and current context."""

    def __init__(self, path: str = "memory.db"):
        self.conn = sqlite3.connect(path)

    def related_tokens(self, context: str):
        try:
            cur = self.conn.cursor()
            cur.execute("SELECT context || ' ' || response FROM log")
            text = " ".join(row[0] for row in cur.fetchall())
        except sqlite3.OperationalError:
            # log table may not exist yet
            return []
        words = re.findall(r"\w+", text.lower())
        counts = collections.Counter(words)
        tokens = re.findall(r"\w+", context.lower())
        return [t for t in tokens if counts.get(t, 0) > 1]
