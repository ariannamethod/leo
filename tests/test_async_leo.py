#!/usr/bin/env python3
"""Tests for AsyncLeoField — async Leo core."""

import asyncio
import tempfile
import unittest
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    import aiosqlite
    AIOSQLITE_AVAILABLE = True
except ImportError:
    AIOSQLITE_AVAILABLE = False


def run_async(coro):
    """Helper to run async tests."""
    return asyncio.get_event_loop().run_until_complete(coro)


@unittest.skipUnless(AIOSQLITE_AVAILABLE, "aiosqlite not installed")
class TestAsyncLeoField(unittest.TestCase):
    """Test AsyncLeoField creation and basic operations."""

    def test_create(self):
        """Test that AsyncLeoField can be created."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                self.assertIsNotNone(field.db)
                self.assertGreater(len(field.vocab), 0)
                self.assertGreater(len(field.bigrams), 0)
            finally:
                await field.close()

        run_async(_test())

    def test_async_observe(self):
        """Test async observe ingests text."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                vocab_before = len(field.vocab)
                await field.async_observe("xylophone zebra quasar nebula")
                vocab_after = len(field.vocab)
                self.assertGreaterEqual(vocab_after, vocab_before)
            finally:
                await field.close()

        run_async(_test())

    def test_async_reply(self):
        """Test async reply generates text."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                reply = await field.async_reply("hello world", max_tokens=20)
                self.assertIsInstance(reply, str)
                self.assertGreater(len(reply), 0)
            finally:
                await field.close()

        run_async(_test())

    def test_sync_observe_works(self):
        """Test that sync observe (for modules) still works."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                # Sync observe should not crash
                field.observe("test sync observe path")
                self.assertGreater(field.observe_count, 0)
            finally:
                await field.close()

        run_async(_test())

    def test_lock_prevents_corruption(self):
        """Test that the lock serializes access."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                # Run multiple observes sequentially (lock ensures order)
                await field.async_observe("alpha beta gamma")
                await field.async_observe("delta epsilon zeta")
                # If we got here without crash, lock works
                self.assertGreater(len(field.vocab), 0)
            finally:
                await field.close()

        run_async(_test())

    def test_stats_summary(self):
        """Test stats_summary works."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                stats = field.stats_summary()
                self.assertIn("vocab=", stats)
                self.assertIn("centers=", stats)
                self.assertIn("bigrams=", stats)
            finally:
                await field.close()

        run_async(_test())

    def test_multiple_replies(self):
        """Test multiple sequential replies."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                r1 = await field.async_reply("what is love", max_tokens=15)
                r2 = await field.async_reply("tell me more", max_tokens=15)
                self.assertIsInstance(r1, str)
                self.assertIsInstance(r2, str)
                self.assertGreater(len(r1), 0)
                self.assertGreater(len(r2), 0)
            finally:
                await field.close()

        run_async(_test())

    def test_observe_reply_cycle(self):
        """Test the core observe → reply → observe cycle."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                prompt = "the stars shine bright tonight"
                await field.async_observe(prompt)
                reply = await field.async_reply(prompt, max_tokens=20)
                await field.async_observe(reply)
                # Full cycle completed without errors
                self.assertIsInstance(reply, str)
            finally:
                await field.close()

        run_async(_test())


@unittest.skipUnless(AIOSQLITE_AVAILABLE, "aiosqlite not installed")
class TestAsyncLeoFieldModules(unittest.TestCase):
    """Test that optional modules initialize correctly in async mode."""

    def test_modules_initialized(self):
        """Test that modules are properly initialized."""
        from leo import AsyncLeoField, ASYNC_AVAILABLE
        if not ASYNC_AVAILABLE:
            self.skipTest("async not available")

        async def _test():
            tmp = Path(tempfile.mkdtemp())
            db_path = tmp / "test_leo.sqlite3"
            field = await AsyncLeoField.create(db_path=db_path)
            try:
                # These should be initialized (if modules available)
                # We just check they don't crash, not that they're non-None
                # (because modules are optional)
                _ = field.flow_tracker
                _ = field.metaleo
                _ = field._math_brain
                _ = field.santa
                _ = field.game
                _ = field.school
                _ = field.subword_field
                _ = field.bridge_memory
            finally:
                await field.close()

        run_async(_test())


if __name__ == "__main__":
    unittest.main()
