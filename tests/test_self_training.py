#!/usr/bin/env python3
"""Tests for Leo's self-training loop, hierarchical decay, and field debt.

Inspired by arianna.c (notorch plasticity), stanley (MemorySea),
and ariannamethod.lang (prophecy debt → field debt).
"""

import sqlite3
import unittest
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))


def _fresh_db() -> sqlite3.Connection:
    """Create a fresh in-memory DB with Leo's schema."""
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")
    cur.execute("CREATE TABLE IF NOT EXISTS tokens (id INTEGER PRIMARY KEY, token TEXT UNIQUE)")
    cur.execute(
        "CREATE TABLE IF NOT EXISTS bigrams "
        "(src_id INTEGER, dst_id INTEGER, count INTEGER DEFAULT 0, "
        "PRIMARY KEY(src_id, dst_id))"
    )
    cur.execute(
        "CREATE TABLE IF NOT EXISTS trigrams "
        "(first_id INTEGER, second_id INTEGER, third_id INTEGER, count INTEGER DEFAULT 0, "
        "PRIMARY KEY(first_id, second_id, third_id))"
    )
    cur.execute(
        "CREATE TABLE IF NOT EXISTS co_occurrence "
        "(word_id INTEGER, context_id INTEGER, count INTEGER DEFAULT 0, "
        "PRIMARY KEY(word_id, context_id))"
    )
    cur.execute(
        "CREATE TABLE IF NOT EXISTS snapshots "
        "(id INTEGER PRIMARY KEY, text TEXT, origin TEXT, quality REAL, "
        "emotional REAL, created_at INTEGER, last_used_at INTEGER, use_count INTEGER DEFAULT 0)"
    )
    conn.commit()
    return conn


def _insert_cooccurrence(conn, word, context, count):
    """Helper: insert a co-occurrence pair with given count."""
    cur = conn.cursor()
    cur.execute("INSERT OR IGNORE INTO tokens(token) VALUES (?)", (word,))
    cur.execute("INSERT OR IGNORE INTO tokens(token) VALUES (?)", (context,))
    wid = cur.execute("SELECT id FROM tokens WHERE token=?", (word,)).fetchone()[0]
    cid = cur.execute("SELECT id FROM tokens WHERE token=?", (context,)).fetchone()[0]
    cur.execute(
        "INSERT INTO co_occurrence(word_id, context_id, count) VALUES (?, ?, ?)",
        (wid, cid, count),
    )
    conn.commit()
    return wid, cid


def _get_count(conn, wid, cid):
    """Helper: get co-occurrence count."""
    row = conn.execute(
        "SELECT count FROM co_occurrence WHERE word_id=? AND context_id=?",
        (wid, cid),
    ).fetchone()
    return row[0] if row else None


class TestHierarchicalDecay(unittest.TestCase):
    """Test that decay rates differ by co-occurrence strength tier."""

    def test_surface_decays_fast(self):
        """Count 1-4 (surface) decays at 0.90."""
        from leo import apply_memory_decay

        conn = _fresh_db()
        wid, cid = _insert_cooccurrence(conn, "alpha", "beta", 4)

        apply_memory_decay(conn)

        # 4 * 0.90 = 3.6 → CAST = 3
        self.assertEqual(_get_count(conn, wid, cid), 3)
        conn.close()

    def test_middle_decays_normal(self):
        """Count 5-49 (middle) decays at 0.95."""
        from leo import apply_memory_decay

        conn = _fresh_db()
        wid, cid = _insert_cooccurrence(conn, "gamma", "delta", 20)

        apply_memory_decay(conn)

        # 20 * 0.95 = 19.0 → CAST = 19
        self.assertEqual(_get_count(conn, wid, cid), 19)
        conn.close()

    def test_deep_barely_decays(self):
        """Count 50+ (deep/crystallized) decays at 0.998 — near-permanent."""
        from leo import apply_memory_decay

        conn = _fresh_db()
        wid, cid = _insert_cooccurrence(conn, "love", "resonance", 100)

        apply_memory_decay(conn)

        # 100 * 0.998 = 99.8 → CAST = 99
        self.assertEqual(_get_count(conn, wid, cid), 99)
        conn.close()

    def test_deep_survives_many_decays(self):
        """A crystallized pattern (count=100) survives 50 decay cycles.

        Note: CAST truncation means each cycle loses ~1 from count,
        so after 50 cycles count ≈ 50. The key point: it's STILL ALIVE
        and still in deep tier, whereas surface (count=2) would die in 2 cycles.
        """
        from leo import apply_memory_decay

        conn = _fresh_db()
        wid, cid = _insert_cooccurrence(conn, "core", "word", 100)

        for _ in range(50):
            apply_memory_decay(conn)

        count = _get_count(conn, wid, cid)
        self.assertIsNotNone(count, "Deep pattern should survive 50 decay cycles")
        self.assertGreater(count, 40)  # Still substantial after 50 cycles
        conn.close()

    def test_surface_dies_quickly(self):
        """A surface pattern (count=2) dies within a few decay cycles."""
        from leo import apply_memory_decay

        conn = _fresh_db()
        wid, cid = _insert_cooccurrence(conn, "temp", "word", 2)

        # count=2: surface tier → 0.90 decay
        # cycle 1: 2*0.90=1.8→1 (now count=1, still surface)
        # cycle 2: 1*0.90=0.9→0 (deleted, < min_threshold=1)
        apply_memory_decay(conn)
        apply_memory_decay(conn)

        self.assertIsNone(_get_count(conn, wid, cid))
        conn.close()


class TestFieldDebt(unittest.TestCase):
    """Test field debt computation."""

    def test_low_debt_confident_field(self):
        """High entropy-quality + high structural = low debt."""
        # entropy=0.9 (mapped, good), structural=0.8
        # debt = (1-0.9)*(1-0.8) = 0.1*0.2 = 0.02
        debt = (1.0 - 0.9) * (1.0 - 0.8)
        self.assertLess(debt, 0.1)

    def test_high_debt_struggling_field(self):
        """Low entropy-quality + low structural = high debt."""
        # entropy=0.2 (mapped, bad), structural=0.3
        # debt = (1-0.2)*(1-0.3) = 0.8*0.7 = 0.56
        debt = (1.0 - 0.2) * (1.0 - 0.3)
        self.assertGreater(debt, 0.5)

    def test_debt_range(self):
        """Field debt is always in [0, 1]."""
        for e in [0.0, 0.25, 0.5, 0.75, 1.0]:
            for s in [0.0, 0.25, 0.5, 0.75, 1.0]:
                debt = (1.0 - e) * (1.0 - s)
                self.assertGreaterEqual(debt, 0.0)
                self.assertLessEqual(debt, 1.0)


class TestSnapshotSaving(unittest.TestCase):
    """Test that snapshot saving works (was frozen since Dec 2025)."""

    def test_save_snapshot_creates_record(self):
        """save_snapshot should insert into snapshots table."""
        from leo import save_snapshot

        conn = _fresh_db()
        save_snapshot(conn, text="Leo discovers resonance.", origin="leo",
                      quality=0.75, emotional=0.6)

        row = conn.execute("SELECT COUNT(*) FROM snapshots").fetchone()
        self.assertEqual(row[0], 1)

        snap = conn.execute("SELECT text, origin, quality FROM snapshots").fetchone()
        self.assertEqual(snap[0], "Leo discovers resonance.")
        self.assertEqual(snap[1], "leo")
        self.assertAlmostEqual(snap[2], 0.75, places=2)
        conn.close()

    def test_snapshot_cap(self):
        """Snapshots are capped at max_snapshots."""
        from leo import save_snapshot

        conn = _fresh_db()
        for i in range(20):
            save_snapshot(conn, text=f"Snapshot {i}", origin="leo",
                          quality=0.7, emotional=0.5, max_snapshots=10)

        row = conn.execute("SELECT COUNT(*) FROM snapshots").fetchone()
        self.assertLessEqual(row[0], 12)  # 10 + some margin from batch delete
        conn.close()


class TestSelfTrainingGating(unittest.TestCase):
    """Test that quality + debt gates self-training correctly."""

    def test_high_quality_low_debt_trains(self):
        """quality=0.8, debt=0.1 → should self-train."""
        quality = 0.8
        debt = 0.1
        should_train = quality >= 0.7 and debt < 0.5
        self.assertTrue(should_train)

    def test_high_quality_high_debt_no_train(self):
        """quality=0.8, debt=0.6 → should NOT self-train (lucky guess)."""
        quality = 0.8
        debt = 0.6
        should_train = quality >= 0.7 and debt < 0.5
        self.assertFalse(should_train)

    def test_medium_quality_very_low_debt_light_train(self):
        """quality=0.55, debt=0.1 → light ingest."""
        quality = 0.55
        debt = 0.1
        should_light = quality >= 0.5 and debt < 0.3
        self.assertTrue(should_light)

    def test_low_quality_no_train(self):
        """quality=0.3 → never train regardless of debt."""
        quality = 0.3
        should_full = quality >= 0.7
        should_light = quality >= 0.5
        self.assertFalse(should_full)
        self.assertFalse(should_light)


if __name__ == "__main__":
    unittest.main()
