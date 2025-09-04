import sqlite3

class Infinity:
    """Simple RAG-style memory using SQLite FTS."""

    def __init__(self, path: str = "memory.db"):
        self.conn = sqlite3.connect(path)
        self._ensure()

    def _ensure(self):
        cur = self.conn.cursor()
        cur.execute("CREATE VIRTUAL TABLE IF NOT EXISTS rag USING FTS5(text)")
        self.conn.commit()

    def add(self, text: str):
        cur = self.conn.cursor()
        cur.execute("INSERT INTO rag(text) VALUES (?)", (text,))
        self.conn.commit()

    def search(self, query: str):
        cur = self.conn.cursor()
        cur.execute("SELECT text FROM rag WHERE rag MATCH ?", (query,))
        return [row[0] for row in cur.fetchall()]
