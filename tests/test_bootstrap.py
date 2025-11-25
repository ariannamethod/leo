#!/usr/bin/env python3
"""Tests for Leo 1.1 - Sonar-Child bootstrap functionality."""

import sys
import tempfile
import unittest
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import leo


class TestModuleBootstraps(unittest.TestCase):
    """Test that modules have BOOTSTRAP_TEXT and bootstrap() functions."""

    def test_metaleo_has_bootstrap(self):
        """Test that metaleo has BOOTSTRAP_TEXT and bootstrap()."""
        try:
            import metaleo
            self.assertTrue(hasattr(metaleo, 'BOOTSTRAP_TEXT'))
            self.assertTrue(hasattr(metaleo, 'bootstrap'))
            self.assertTrue(callable(metaleo.bootstrap))
            self.assertIn("inner voice", metaleo.BOOTSTRAP_TEXT.lower())
        except ImportError:
            self.skipTest("metaleo not available")

    def test_mathbrain_has_bootstrap(self):
        """Test that mathbrain has BOOTSTRAP_TEXT and bootstrap()."""
        try:
            import mathbrain
            self.assertTrue(hasattr(mathbrain, 'BOOTSTRAP_TEXT'))
            self.assertTrue(hasattr(mathbrain, 'bootstrap'))
            self.assertTrue(callable(mathbrain.bootstrap))
            self.assertIn("body awareness", mathbrain.BOOTSTRAP_TEXT.lower())
        except ImportError:
            self.skipTest("mathbrain not available")

    def test_school_has_bootstrap(self):
        """Test that school has BOOTSTRAP_TEXT and bootstrap()."""
        try:
            import school
            self.assertTrue(hasattr(school, 'BOOTSTRAP_TEXT'))
            self.assertTrue(hasattr(school, 'bootstrap'))
            self.assertTrue(callable(school.bootstrap))
            self.assertIn("school of forms", school.BOOTSTRAP_TEXT.lower())
        except ImportError:
            self.skipTest("school not available")

    def test_dream_has_bootstrap(self):
        """Test that dream has BOOTSTRAP_TEXT and bootstrap()."""
        try:
            import dream
            self.assertTrue(hasattr(dream, 'BOOTSTRAP_TEXT'))
            self.assertTrue(hasattr(dream, 'bootstrap'))
            self.assertTrue(callable(dream.bootstrap))
            self.assertIn("dream space", dream.BOOTSTRAP_TEXT.lower())
        except ImportError:
            self.skipTest("dream not available")

    def test_game_has_bootstrap(self):
        """Test that game has BOOTSTRAP_TEXT and bootstrap()."""
        try:
            import game
            self.assertTrue(hasattr(game, 'BOOTSTRAP_TEXT'))
            self.assertTrue(hasattr(game, 'bootstrap'))
            self.assertTrue(callable(game.bootstrap))
            self.assertIn("playground", game.BOOTSTRAP_TEXT.lower())
        except ImportError:
            self.skipTest("game not available")


class TestBootstrapFeeding(unittest.TestCase):
    """Test that feed_bootstraps_if_fresh works correctly."""

    def setUp(self):
        """Create temporary environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.original_state = leo.STATE_DIR
        self.original_bin = leo.BIN_DIR
        self.original_json = leo.JSON_DIR
        self.original_db = leo.DB_PATH

        leo.STATE_DIR = Path(self.temp_dir) / "state"
        leo.BIN_DIR = Path(self.temp_dir) / "bin"
        leo.JSON_DIR = Path(self.temp_dir) / "json"
        leo.DB_PATH = leo.STATE_DIR / "test_leo.sqlite3"

    def tearDown(self):
        """Restore environment."""
        leo.STATE_DIR = self.original_state
        leo.BIN_DIR = self.original_bin
        leo.JSON_DIR = self.original_json
        leo.DB_PATH = self.original_db

        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_fresh_db_gets_bootstraps(self):
        """Test that fresh DB receives module bootstraps."""
        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)
        field = leo.LeoField(conn)

        # Field should have tokens from embedded + README + module bootstraps
        self.assertGreater(len(field.vocab), 100)

        # Check that some bootstrap-specific words are present
        vocab_lower = [t.lower() for t in field.vocab]

        # From module bootstraps
        self.assertIn("voice", vocab_lower)  # metaleo
        self.assertIn("awareness", vocab_lower)  # mathbrain
        self.assertIn("forms", vocab_lower)  # school

        conn.close()

    def test_non_fresh_db_skips_bootstraps(self):
        """Test that non-fresh DB doesn't re-feed bootstraps."""
        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)
        field1 = leo.LeoField(conn)

        initial_token_count = len(field1.vocab)

        # Create another field from same conn (non-fresh)
        field2 = leo.LeoField(conn)

        # Token count should be the same
        self.assertEqual(len(field2.vocab), initial_token_count)

        conn.close()

    def test_bootstrap_safe_with_none_field(self):
        """Test that bootstrap() handles None field gracefully."""
        try:
            import metaleo
            # Should not raise
            metaleo.bootstrap(None)
        except ImportError:
            self.skipTest("metaleo not available")

    def test_bootstrap_safe_with_no_observe(self):
        """Test that bootstrap() handles field without observe()."""
        try:
            import mathbrain

            class FakeField:
                pass

            fake = FakeField()
            # Should not raise
            mathbrain.bootstrap(fake)
        except ImportError:
            self.skipTest("mathbrain not available")

    def test_bootstrap_hash_prevents_double_ingest(self):
        """
        Test that bootstrap hash mechanism prevents double-ingestion.
        Run bootstrap twice, verify it only feeds once by default.
        """
        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)
        field1 = leo.LeoField(conn)

        # Get initial vocab count (includes embedded seed + README + bootstraps)
        initial_count = len(field1.vocab)

        # Check that bootstrap hash is set
        hash1 = leo.get_meta(conn, "module_bootstrap_hash")
        self.assertIsNotNone(hash1)
        self.assertTrue(len(hash1) > 0)

        # Force feed_bootstraps_if_fresh again (simulating second startup)
        leo.feed_bootstraps_if_fresh(field1)

        # Refresh field to get updated vocab
        field1.refresh()

        # Vocab count should be the same (no double-ingestion)
        second_count = len(field1.vocab)
        self.assertEqual(second_count, initial_count)

        # Hash should still be the same
        hash2 = leo.get_meta(conn, "module_bootstrap_hash")
        self.assertEqual(hash1, hash2)

        conn.close()


if __name__ == "__main__":
    unittest.main()
