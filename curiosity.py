import sqlite3

class Infinity:
    """Simple RAG-style memory using SQLite with FTS5 or fallback."""

    def __init__(self, path: str = "memory.db"):
        self.conn = sqlite3.connect(path)
        self._fts = False
        self._ensure()

    def _ensure(self):
        cur = self.conn.cursor()
        try:
            cur.execute("CREATE VIRTUAL TABLE IF NOT EXISTS rag USING FTS5(text)")
            self._fts = True
        except sqlite3.OperationalError:
            # FTS5 not available: fallback to a normal table
            cur.execute("CREATE TABLE IF NOT EXISTS rag (text TEXT)")
            self._fts = False
        self.conn.commit()

    def add(self, text: str):
        cur = self.conn.cursor()
        cur.execute("INSERT INTO rag(text) VALUES (?)", (text,))
        self.conn.commit()

    def search(self, query: str):
        cur = self.conn.cursor()
        if self._fts:
            cur.execute("SELECT text FROM rag WHERE rag MATCH ?", (query,))
        else:
            cur.execute("SELECT text FROM rag WHERE text LIKE ?", (f"%{query}%",))
        return [row[0] for row in cur.fetchall()]
