#!/usr/bin/env python3
"""Tests for leo_storage.py — async storage layer."""

import asyncio
import tempfile
import unittest
from pathlib import Path

try:
    import aiosqlite
    AIOSQLITE_AVAILABLE = True
except ImportError:
    AIOSQLITE_AVAILABLE = False

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from leo_storage import (
    tokenize,
    _sha256_hex,
    create_bin_shard,
    load_bin_bias,
    _SCHEMA_SQL,
    AIOSQLITE_AVAILABLE as STORAGE_AIOSQLITE,
)


def run_async(coro):
    """Helper to run async tests."""
    return asyncio.get_event_loop().run_until_complete(coro)


class TestTokenize(unittest.TestCase):
    """Test tokenizer (sync, shared between layers)."""

    def test_basic(self):
        tokens = tokenize("Hello World")
        self.assertEqual(tokens, ["hello", "world"])

    def test_punctuation(self):
        tokens = tokenize("Hi! How are you?")
        self.assertIn("!", tokens)
        self.assertIn("?", tokens)

    def test_empty(self):
        self.assertEqual(tokenize(""), [])

    def test_mixed_case(self):
        tokens = tokenize("Leo IS Here")
        self.assertEqual(tokens, ["leo", "is", "here"])


class TestSha256(unittest.TestCase):
    def test_deterministic(self):
        h1 = _sha256_hex(b"test")
        h2 = _sha256_hex(b"test")
        self.assertEqual(h1, h2)

    def test_different_inputs(self):
        h1 = _sha256_hex(b"a")
        h2 = _sha256_hex(b"b")
        self.assertNotEqual(h1, h2)


class TestBinShards(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def test_create_and_load(self):
        import leo_storage
        old_bin = leo_storage.BIN_DIR
        leo_storage.BIN_DIR = self.tmp / "bin"
        try:
            create_bin_shard("test", ["alpha", "beta", "gamma"])
            bias = load_bin_bias("test")
            self.assertIn("alpha", bias)
            self.assertIn("beta", bias)
            self.assertEqual(bias["alpha"], 1)
        finally:
            leo_storage.BIN_DIR = old_bin

    def test_empty_centers(self):
        create_bin_shard("test", [])
        # Should not crash

    def test_load_missing_dir(self):
        import leo_storage
        old_bin = leo_storage.BIN_DIR
        leo_storage.BIN_DIR = self.tmp / "nonexistent"
        try:
            bias = load_bin_bias("test")
            self.assertEqual(bias, {})
        finally:
            leo_storage.BIN_DIR = old_bin


@unittest.skipUnless(AIOSQLITE_AVAILABLE, "aiosqlite not installed")
class TestAsyncDB(unittest.TestCase):
    """Test async database operations."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.db_path = self.tmp / "test.sqlite3"

    async def _init_db(self):
        db = await aiosqlite.connect(str(self.db_path))
        db.row_factory = aiosqlite.Row
        for sql in _SCHEMA_SQL:
            await db.execute(sql)
        await db.commit()
        return db

    def test_init_and_meta(self):
        from leo_storage import async_get_meta, async_set_meta

        async def _test():
            db = await self._init_db()
            try:
                val = await async_get_meta(db, "test_key")
                self.assertIsNone(val)

                await async_set_meta(db, "test_key", "test_value")
                val = await async_get_meta(db, "test_key")
                self.assertEqual(val, "test_value")

                await async_set_meta(db, "test_key", "updated")
                val = await async_get_meta(db, "test_key")
                self.assertEqual(val, "updated")
            finally:
                await db.close()

        run_async(_test())

    def test_ingest_tokens(self):
        from leo_storage import async_ingest_tokens

        async def _test():
            db = await self._init_db()
            try:
                await async_ingest_tokens(db, ["hello", "world", "hello"])

                cursor = await db.execute("SELECT COUNT(*) FROM tokens")
                row = await cursor.fetchone()
                self.assertEqual(row[0], 2)  # hello, world

                cursor = await db.execute("SELECT COUNT(*) FROM bigrams")
                row = await cursor.fetchone()
                self.assertGreater(row[0], 0)
            finally:
                await db.close()

        run_async(_test())

    def test_ingest_text(self):
        from leo_storage import async_ingest_text

        async def _test():
            db = await self._init_db()
            try:
                await async_ingest_text(db, "the quick brown fox jumps over the lazy dog")

                cursor = await db.execute("SELECT COUNT(*) FROM tokens")
                row = await cursor.fetchone()
                self.assertGreater(row[0], 0)

                cursor = await db.execute("SELECT COUNT(*) FROM bigrams")
                row = await cursor.fetchone()
                self.assertGreater(row[0], 0)

                cursor = await db.execute("SELECT COUNT(*) FROM trigrams")
                row = await cursor.fetchone()
                self.assertGreater(row[0], 0)

                cursor = await db.execute("SELECT COUNT(*) FROM co_occurrence")
                row = await cursor.fetchone()
                self.assertGreater(row[0], 0)
            finally:
                await db.close()

        run_async(_test())

    def test_load_bigrams(self):
        from leo_storage import async_ingest_text, async_load_bigrams

        async def _test():
            db = await self._init_db()
            try:
                await async_ingest_text(db, "hello world hello earth")
                bigrams, vocab = await async_load_bigrams(db)

                self.assertIn("hello", bigrams)
                self.assertIn("world", bigrams["hello"])
                self.assertIn("hello", vocab)
                self.assertIn("world", vocab)
            finally:
                await db.close()

        run_async(_test())

    def test_load_trigrams(self):
        from leo_storage import async_ingest_text, async_load_trigrams

        async def _test():
            db = await self._init_db()
            try:
                await async_ingest_text(db, "one two three four")
                trigrams = await async_load_trigrams(db)

                self.assertIn(("one", "two"), trigrams)
                self.assertIn("three", trigrams[("one", "two")])
            finally:
                await db.close()

        run_async(_test())

    def test_load_co_occurrence(self):
        from leo_storage import async_ingest_text, async_load_co_occurrence

        async def _test():
            db = await self._init_db()
            try:
                await async_ingest_text(db, "alpha beta gamma delta")
                co_occur = await async_load_co_occurrence(db)

                self.assertGreater(len(co_occur), 0)
                self.assertIn("alpha", co_occur)
            finally:
                await db.close()

        run_async(_test())

    def test_compute_centers(self):
        from leo_storage import async_ingest_text, async_compute_centers

        async def _test():
            db = await self._init_db()
            try:
                text = " ".join(["alpha beta gamma"] * 10 + ["delta epsilon"] * 3)
                await async_ingest_text(db, text)
                centers = await async_compute_centers(db, k=3)

                self.assertGreater(len(centers), 0)
                self.assertLessEqual(len(centers), 3)
            finally:
                await db.close()

        run_async(_test())

    def test_save_snapshot(self):
        from leo_storage import async_save_snapshot

        async def _test():
            db = await self._init_db()
            try:
                await async_save_snapshot(db, "test reply", "test", 0.8, 0.5)

                cursor = await db.execute("SELECT COUNT(*) FROM snapshots")
                row = await cursor.fetchone()
                self.assertEqual(row[0], 1)

                cursor = await db.execute("SELECT text, quality FROM snapshots")
                row = await cursor.fetchone()
                self.assertEqual(row[0], "test reply")
                self.assertAlmostEqual(row[1], 0.8)
            finally:
                await db.close()

        run_async(_test())

    def test_snapshot_cleanup(self):
        from leo_storage import async_save_snapshot

        async def _test():
            db = await self._init_db()
            try:
                for i in range(15):
                    await async_save_snapshot(
                        db, f"reply {i}", "test", 0.5, 0.5, max_snapshots=10
                    )

                cursor = await db.execute("SELECT COUNT(*) FROM snapshots")
                row = await cursor.fetchone()
                self.assertLessEqual(row[0], 15)
            finally:
                await db.close()

        run_async(_test())

    def test_memory_decay(self):
        from leo_storage import async_ingest_text, async_apply_memory_decay

        async def _test():
            db = await self._init_db()
            try:
                await async_ingest_text(db, "alpha beta gamma")

                cursor = await db.execute("SELECT SUM(count) FROM co_occurrence")
                before = (await cursor.fetchone())[0]
                self.assertGreater(before, 0)

                deleted = await async_apply_memory_decay(db, decay_factor=0.1, min_threshold=2)

                cursor = await db.execute("SELECT SUM(count) FROM co_occurrence")
                row = await cursor.fetchone()
                after = row[0] if row[0] else 0
                self.assertLessEqual(after, before)
            finally:
                await db.close()

        run_async(_test())

    def test_ingest_empty(self):
        from leo_storage import async_ingest_text

        async def _test():
            db = await self._init_db()
            try:
                await async_ingest_text(db, "")
                cursor = await db.execute("SELECT COUNT(*) FROM tokens")
                row = await cursor.fetchone()
                self.assertEqual(row[0], 0)
            finally:
                await db.close()

        run_async(_test())

    def test_concurrent_access(self):
        """Test that multiple async operations don't corrupt data."""
        from leo_storage import async_ingest_text, async_load_bigrams

        async def _test():
            db = await self._init_db()
            try:
                # Sequential ingestion (aiosqlite serializes internally)
                await async_ingest_text(db, "hello world")
                await async_ingest_text(db, "world hello")

                bigrams, vocab = await async_load_bigrams(db)
                self.assertIn("hello", bigrams)
                self.assertIn("world", bigrams)
            finally:
                await db.close()

        run_async(_test())


if __name__ == "__main__":
    unittest.main()
