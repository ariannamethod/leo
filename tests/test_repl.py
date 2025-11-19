#!/usr/bin/env python3
"""Tests for Leo REPL mode."""

import sys
import tempfile
import unittest
from pathlib import Path
from io import StringIO

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import leo


class TestREPLCommands(unittest.TestCase):
    """Test REPL command parsing (without full interactive session)."""

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

    def test_export_command(self):
        """Test /export command creates lexicon file."""
        conn = leo.init_db()
        leo.ingest_text(conn, "test data for export")

        field = leo.LeoField(conn)
        path = field.export_lexicon()

        self.assertTrue(path.exists())
        self.assertTrue(path.name.endswith('.json'))

    def test_stats_command(self):
        """Test stats summary format."""
        conn = leo.init_db()
        leo.ingest_text(conn, "stats test data")

        field = leo.LeoField(conn)
        stats = field.stats_summary()

        self.assertIn("vocab=", stats)
        self.assertIn("centers=", stats)
        self.assertIn("bigrams=", stats)


class TestCLIArguments(unittest.TestCase):
    """Test CLI argument parsing."""

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

    def test_stats_flag(self):
        """Test --stats flag."""
        # Capture stdout
        old_stdout = sys.stdout
        sys.stdout = StringIO()

        try:
            result = leo.main(["--stats"])
            output = sys.stdout.getvalue()

            self.assertEqual(result, 0)
            # Empty field should have vocab=0
            self.assertIn("vocab=", output)
        finally:
            sys.stdout = old_stdout

    def test_export_flag(self):
        """Test --export flag."""
        old_stderr = sys.stderr
        sys.stderr = StringIO()

        try:
            result = leo.main(["--export"])
            output = sys.stderr.getvalue()

            self.assertEqual(result, 0)
            self.assertIn("lexicon exported", output)
        finally:
            sys.stderr = old_stderr

    def test_one_shot_mode(self):
        """Test one-shot generation mode."""
        old_stdout = sys.stdout
        sys.stdout = StringIO()

        try:
            result = leo.main(["--seed", "42", "test prompt"])
            output = sys.stdout.getvalue()

            self.assertEqual(result, 0)
            self.assertIsInstance(output, str)
        finally:
            sys.stdout = old_stdout


class TestBootstrap(unittest.TestCase):
    """Test bootstrap behavior."""

    def setUp(self):
        """Create clean temporary environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.original_state = leo.STATE_DIR
        self.original_bin = leo.BIN_DIR
        self.original_json = leo.JSON_DIR
        self.original_db = leo.DB_PATH
        self.original_readme = leo.README_PATH

        leo.STATE_DIR = Path(self.temp_dir) / "state"
        leo.BIN_DIR = Path(self.temp_dir) / "bin"
        leo.JSON_DIR = Path(self.temp_dir) / "json"
        leo.DB_PATH = leo.STATE_DIR / "test_leo.sqlite3"
        leo.README_PATH = Path(self.temp_dir) / "README.md"

    def tearDown(self):
        """Restore environment."""
        leo.STATE_DIR = self.original_state
        leo.BIN_DIR = self.original_bin
        leo.JSON_DIR = self.original_json
        leo.DB_PATH = self.original_db
        leo.README_PATH = self.original_readme

        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_bootstrap_embedded_only(self):
        """Test bootstrap with embedded seed only (no README)."""
        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)

        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM tokens")
        count = cur.fetchone()[0]

        # Should have tokens from embedded bootstrap
        self.assertGreater(count, 0)
        conn.close()

    def test_bootstrap_with_readme(self):
        """Test bootstrap with README file."""
        # Create test README
        leo.README_PATH.write_text("Test README content for bootstrapping")

        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)

        # Check that README was processed
        flag = leo.get_meta(conn, "readme_bootstrap_done")
        self.assertEqual(flag, "1")

        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM tokens")
        count = cur.fetchone()[0]

        # Should have tokens from both embedded + README
        self.assertGreater(count, 0)
        conn.close()

    def test_bootstrap_idempotent(self):
        """Test that bootstrap only runs once."""
        leo.README_PATH.write_text("Bootstrap once")

        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)

        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM tokens")
        count1 = cur.fetchone()[0]

        # Run bootstrap again
        leo.bootstrap_if_needed(conn)

        cur.execute("SELECT COUNT(*) FROM tokens")
        count2 = cur.fetchone()[0]

        # Count should be the same (no double bootstrap)
        self.assertEqual(count1, count2)
        conn.close()


if __name__ == "__main__":
    unittest.main()
