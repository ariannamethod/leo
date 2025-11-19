#!/usr/bin/env python3
"""Tests for leo.py — Language Engine Organism."""

import sys
import tempfile
import unittest
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

import leo


class TestTokenizer(unittest.TestCase):
    """Test tokenization logic."""

    def test_basic_tokenization(self):
        """Test basic word extraction."""
        tokens = leo.tokenize("Hello, world!")
        self.assertEqual(tokens, ["Hello", ",", "world", "!"])

    def test_unicode_support(self):
        """Test Unicode character support (Latin extended)."""
        tokens = leo.tokenize("résumé, café, naïve")
        # Leo supports Latin + extended Latin (À-ÖØ-öø-ÿ), not Cyrillic
        self.assertIn("résumé", tokens)
        self.assertIn("café", tokens)
        self.assertIn("naïve", tokens)

    def test_punctuation_separation(self):
        """Test punctuation is separated."""
        tokens = leo.tokenize("word.word")
        self.assertEqual(tokens, ["word", ".", "word"])


class TestFormatting(unittest.TestCase):
    """Test token formatting and capitalization."""

    def test_format_tokens_basic(self):
        """Test basic token formatting."""
        tokens = ["hello", ",", "world", "!"]
        formatted = leo.format_tokens(tokens)
        self.assertEqual(formatted, "hello, world!")

    def test_format_tokens_spacing(self):
        """Test punctuation doesn't get extra spaces."""
        tokens = ["word", ".", "another", ",", "token"]
        formatted = leo.format_tokens(tokens)
        self.assertEqual(formatted, "word. another, token")

    def test_capitalize_sentences(self):
        """Test sentence capitalization."""
        text = "hello. world! how are you?"
        capitalized = leo.capitalize_sentences(text)
        self.assertEqual(capitalized, "Hello. World! How are you?")

    def test_capitalize_first_char(self):
        """Test first character is capitalized."""
        text = "lowercase start"
        capitalized = leo.capitalize_sentences(text)
        self.assertTrue(capitalized[0].isupper())


class TestDatabase(unittest.TestCase):
    """Test database operations."""

    def setUp(self):
        """Create temporary database for each test."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_leo.sqlite3"

        # Monkey-patch DB_PATH for testing
        self.original_db_path = leo.DB_PATH
        leo.DB_PATH = self.db_path

    def tearDown(self):
        """Clean up temporary database."""
        leo.DB_PATH = self.original_db_path
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_init_db(self):
        """Test database initialization."""
        conn = leo.init_db()
        self.assertIsNotNone(conn)

        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cur.fetchall()]

        self.assertIn("tokens", tables)
        self.assertIn("bigrams", tables)
        self.assertIn("meta", tables)
        conn.close()

    def test_ingest_text(self):
        """Test text ingestion into database."""
        conn = leo.init_db()
        leo.ingest_text(conn, "hello world hello")

        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM tokens")
        token_count = cur.fetchone()[0]

        # Should have 2 unique tokens: "hello", "world"
        self.assertEqual(token_count, 2)

        cur.execute("SELECT COUNT(*) FROM bigrams")
        bigram_count = cur.fetchone()[0]

        # Should have 2 bigrams: hello->world, world->hello
        self.assertEqual(bigram_count, 2)
        conn.close()

    def test_get_set_meta(self):
        """Test metadata storage."""
        conn = leo.init_db()
        leo.set_meta(conn, "test_key", "test_value")
        value = leo.get_meta(conn, "test_key")
        self.assertEqual(value, "test_value")
        conn.close()


class TestBigramField(unittest.TestCase):
    """Test bigram field operations."""

    def setUp(self):
        """Create temporary database."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_leo.sqlite3"
        self.original_db_path = leo.DB_PATH
        leo.DB_PATH = self.db_path

    def tearDown(self):
        """Clean up."""
        leo.DB_PATH = self.original_db_path
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_load_bigrams(self):
        """Test bigram loading from database."""
        conn = leo.init_db()
        leo.ingest_text(conn, "a b c a b")

        bigrams, vocab = leo.load_bigrams(conn)

        self.assertIn("a", bigrams)
        self.assertIn("b", bigrams["a"])
        self.assertEqual(bigrams["a"]["b"], 2)  # a->b appears twice
        self.assertEqual(len(vocab), 3)  # a, b, c
        conn.close()

    def test_compute_centers(self):
        """Test center computation."""
        conn = leo.init_db()
        # Create a simple graph: a->b, a->c, a->d (a is the hub)
        leo.ingest_text(conn, "a b a c a d")

        centers = leo.compute_centers(conn, k=1)

        # 'a' should be the center (highest out-degree)
        self.assertEqual(centers[0], "a")
        conn.close()


class TestGeneration(unittest.TestCase):
    """Test text generation."""

    def setUp(self):
        """Create temporary database with sample data."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_leo.sqlite3"
        self.original_db_path = leo.DB_PATH
        leo.DB_PATH = self.db_path

        self.conn = leo.init_db()
        # Create a simple deterministic field
        leo.ingest_text(self.conn, "hello world. hello universe. hello cosmos.")

    def tearDown(self):
        """Clean up."""
        self.conn.close()
        leo.DB_PATH = self.original_db_path
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_choose_start_token(self):
        """Test start token selection."""
        bigrams, vocab = leo.load_bigrams(self.conn)
        centers = leo.compute_centers(self.conn, k=3)
        bias = {}

        start = leo.choose_start_token(vocab, centers, bias)
        self.assertIn(start, vocab)

    def test_generate_reply(self):
        """Test reply generation."""
        bigrams, vocab = leo.load_bigrams(self.conn)
        centers = leo.compute_centers(self.conn, k=3)
        bias = {}

        reply = leo.generate_reply(
            bigrams, vocab, centers, bias,
            prompt="hello",
            max_tokens=5,
            temperature=1.0
        )

        self.assertIsInstance(reply, str)
        self.assertTrue(len(reply) > 0)

    def test_echo_mode(self):
        """Test echo mode generation."""
        bigrams, vocab = leo.load_bigrams(self.conn)
        centers = leo.compute_centers(self.conn, k=3)
        bias = {}

        reply = leo.generate_reply(
            bigrams, vocab, centers, bias,
            prompt="hello world",
            max_tokens=5,
            temperature=1.0,
            echo=True
        )

        # In echo mode, should transform each token
        self.assertIsInstance(reply, str)
        # hello -> should become something else from bigrams[hello]
        # world -> should become something else from bigrams[world]


class TestLeoField(unittest.TestCase):
    """Test LeoField class."""

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

    def test_field_initialization(self):
        """Test LeoField initialization."""
        conn = leo.init_db()
        leo.ingest_text(conn, "test text for field")

        field = leo.LeoField(conn)

        self.assertIsNotNone(field.bigrams)
        self.assertIsNotNone(field.vocab)
        self.assertTrue(len(field.vocab) > 0)

    def test_field_observe(self):
        """Test field observation."""
        conn = leo.init_db()
        field = leo.LeoField(conn)

        initial_vocab_size = len(field.vocab)
        field.observe("new unique tokens here")

        # Vocab should grow
        self.assertGreater(len(field.vocab), initial_vocab_size)

    def test_field_reply(self):
        """Test field reply generation."""
        conn = leo.init_db()
        leo.ingest_text(conn, "language is a field. field is language.")

        field = leo.LeoField(conn)
        reply = field.reply("language")

        self.assertIsInstance(reply, str)
        self.assertTrue(len(reply) > 0)

    def test_field_stats(self):
        """Test field statistics."""
        conn = leo.init_db()
        leo.ingest_text(conn, "test statistics")

        field = leo.LeoField(conn)
        stats = field.stats_summary()

        self.assertIn("vocab", stats)
        self.assertIn("centers", stats)
        self.assertIn("bigrams", stats)


if __name__ == "__main__":
    unittest.main()
