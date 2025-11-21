#!/usr/bin/env python3
"""Tests for santaclaus.py — resonant recall layer."""

import sqlite3
import tempfile
import unittest
from pathlib import Path

from santaclaus import SantaKlaus, SantaContext


class TestSantaKlaus(unittest.TestCase):
    """Test Santa Klaus resonant recall."""
    
    def setUp(self):
        """Create temporary DB for each test."""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.sqlite3')
        self.temp_db.close()
        self.db_path = Path(self.temp_db.name)
        
        # Initialize DB with snapshots table
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                text TEXT NOT NULL,
                origin TEXT,
                quality REAL,
                emotional REAL,
                created_at INTEGER,
                last_used_at INTEGER,
                use_count INTEGER DEFAULT 0,
                cluster_id INTEGER
            )
        """)
        conn.commit()
        conn.close()
        
    def tearDown(self):
        """Clean up temp DB."""
        if self.db_path.exists():
            self.db_path.unlink()
            
    def test_no_snapshots_returns_none(self):
        """Test that recall returns None when no snapshots exist."""
        santa = SantaKlaus(db_path=self.db_path)
        result = santa.recall(
            field=None,
            prompt_text="test prompt",
            pulse={"novelty": 0.5, "arousal": 0.5, "entropy": 0.5},
        )
        self.assertIsNone(result)
        
    def test_single_obvious_snapshot(self):
        """Test that a snapshot with matching tokens is recalled."""
        # Insert a snapshot
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO snapshots (text, quality, emotional, created_at)
            VALUES (?, ?, ?, ?)
        """, ("test prompt with matching words", 0.8, 0.6, 1234567890))
        conn.commit()
        conn.close()
        
        santa = SantaKlaus(db_path=self.db_path)
        result = santa.recall(
            field=None,
            prompt_text="test prompt",
            pulse={"novelty": 0.5, "arousal": 0.6, "entropy": 0.5},
        )
        
        self.assertIsNotNone(result)
        self.assertIsInstance(result, SantaContext)
        self.assertEqual(len(result.recalled_texts), 1)
        self.assertIn("test", result.token_boosts)
        self.assertIn("prompt", result.token_boosts)
        
    def test_quality_and_arousal_influence(self):
        """Test that high quality + similar arousal gets higher score."""
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()
        # High quality, similar arousal
        cur.execute("""
            INSERT INTO snapshots (text, quality, emotional, created_at)
            VALUES (?, ?, ?, ?)
        """, ("good snapshot with test words", 0.9, 0.6, 1234567890))
        # Low quality, far arousal
        cur.execute("""
            INSERT INTO snapshots (text, quality, emotional, created_at)
            VALUES (?, ?, ?, ?)
        """, ("bad snapshot with test words", 0.3, 0.1, 1234567891))
        conn.commit()
        conn.close()
        
        santa = SantaKlaus(db_path=self.db_path, max_memories=1)
        result = santa.recall(
            field=None,
            prompt_text="test words",
            pulse={"novelty": 0.5, "arousal": 0.6, "entropy": 0.5},
        )
        
        self.assertIsNotNone(result)
        # Should prefer high quality one
        self.assertIn("good", result.recalled_texts[0])
        
    def test_graceful_failure_on_corrupt_db(self):
        """Test that corrupt DB path returns None without raising."""
        santa = SantaKlaus(db_path=Path("/nonexistent/path/db.sqlite3"))
        result = santa.recall(
            field=None,
            prompt_text="test",
            pulse={"novelty": 0.5, "arousal": 0.5, "entropy": 0.5},
        )
        self.assertIsNone(result)
        
    def test_empty_prompt_returns_none(self):
        """Test that empty prompt returns None."""
        santa = SantaKlaus(db_path=self.db_path)
        result = santa.recall(
            field=None,
            prompt_text="",
            pulse={"novelty": 0.5, "arousal": 0.5, "entropy": 0.5},
        )
        self.assertIsNone(result)
        
    def test_token_boosts_are_normalized(self):
        """Test that token boosts are in reasonable range."""
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO snapshots (text, quality, emotional, created_at)
            VALUES (?, ?, ?, ?)
        """, ("test test test repeated words", 0.8, 0.6, 1234567890))
        conn.commit()
        conn.close()
        
        santa = SantaKlaus(db_path=self.db_path, alpha=0.3)
        result = santa.recall(
            field=None,
            prompt_text="test",
            pulse={"novelty": 0.5, "arousal": 0.6, "entropy": 0.5},
        )
        
        self.assertIsNotNone(result)
        # All boosts should be <= alpha (0.3)
        for boost in result.token_boosts.values():
            self.assertLessEqual(boost, 0.3)
            self.assertGreaterEqual(boost, 0.0)


if __name__ == "__main__":
    unittest.main()

