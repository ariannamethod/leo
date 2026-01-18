#!/usr/bin/env python3
"""Tests for neoleo.py — pure resonance layer."""

import sys
import tempfile
import unittest
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import neoleo


class TestNeoLeoTokenizer(unittest.TestCase):
    """Test neoleo tokenization."""

    def test_tokenize_basic(self):
        """Test basic tokenization."""
        tokens = neoleo.tokenize("pure resonance layer")
        self.assertEqual(tokens, ["pure", "resonance", "layer"])

    def test_tokenize_punctuation(self):
        """Test punctuation handling."""
        tokens = neoleo.tokenize("word, word! word?")
        self.assertIn(",", tokens)
        self.assertIn("!", tokens)
        self.assertIn("?", tokens)


class TestNeoLeoDatabase(unittest.TestCase):
    """Test neoleo database operations."""

    def setUp(self):
        """Create temporary database."""
        self.temp_dir = tempfile.mkdtemp()
        self.original_db = neoleo.DB_PATH
        neoleo.DB_PATH = Path(self.temp_dir) / "test_neoleo.sqlite3"

    def tearDown(self):
        """Clean up."""
        neoleo.DB_PATH = self.original_db
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_init_db(self):
        """Test database initialization."""
        conn = neoleo.init_db()
        self.assertIsNotNone(conn)

        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cur.fetchall()]

        # neoleo has no meta table (no bootstrap)
        self.assertIn("tokens", tables)
        self.assertIn("bigrams", tables)
        conn.close()

    def test_ingest_text(self):
        """Test text ingestion."""
        conn = neoleo.init_db()
        neoleo.ingest_text(conn, "observe warp observe")

        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM tokens")
        count = cur.fetchone()[0]

        # Should have 2 unique tokens
        self.assertEqual(count, 2)
        conn.close()


class TestNeoLeoBigramField(unittest.TestCase):
    """Test neoleo bigram operations."""

    def setUp(self):
        """Create temporary database."""
        self.temp_dir = tempfile.mkdtemp()
        self.original_db = neoleo.DB_PATH
        neoleo.DB_PATH = Path(self.temp_dir) / "test_neoleo.sqlite3"

    def tearDown(self):
        """Clean up."""
        neoleo.DB_PATH = self.original_db
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_load_bigrams(self):
        """Test bigram loading."""
        conn = neoleo.init_db()
        neoleo.ingest_text(conn, "a b a b a")

        bigrams, vocab = neoleo.load_bigrams(conn)

        self.assertIn("a", bigrams)
        self.assertIn("b", bigrams["a"])
        self.assertEqual(len(vocab), 2)
        conn.close()

    def test_compute_centers(self):
        """Test center computation."""
        conn = neoleo.init_db()
        neoleo.ingest_text(conn, "center a center b center c")

        centers = neoleo.compute_centers(conn, k=1)

        # 'center' should be the hub
        self.assertEqual(centers[0], "center")
        conn.close()


class TestNeoLeoClass(unittest.TestCase):
    """Test NeoLeo class."""

    def setUp(self):
        """Create temporary environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.original_state = neoleo.STATE_DIR
        self.original_bin = neoleo.BIN_DIR
        self.original_json = neoleo.JSON_DIR
        self.original_db = neoleo.DB_PATH

        neoleo.STATE_DIR = Path(self.temp_dir) / "state"
        neoleo.BIN_DIR = Path(self.temp_dir) / "bin"
        neoleo.JSON_DIR = Path(self.temp_dir) / "json"
        neoleo.DB_PATH = neoleo.STATE_DIR / "test_neoleo.sqlite3"

    def tearDown(self):
        """Restore environment."""
        neoleo.STATE_DIR = self.original_state
        neoleo.BIN_DIR = self.original_bin
        neoleo.JSON_DIR = self.original_json
        neoleo.DB_PATH = self.original_db

        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_neoleo_initialization(self):
        """Test NeoLeo object creation."""
        neo = neoleo.NeoLeo()

        self.assertIsNotNone(neo)
        self.assertEqual(neo.vocab_size, 0)  # No bootstrap, should start empty

    def test_neoleo_observe(self):
        """Test observation of text."""
        neo = neoleo.NeoLeo()

        initial_size = neo.vocab_size
        neo.observe("this is new text")

        # Vocab should grow
        self.assertGreater(neo.vocab_size, initial_size)

    def test_neoleo_warp(self):
        """Test warping text through field."""
        neo = neoleo.NeoLeo()

        # Observe some text to build field
        neo.observe("resonance field pure layer")
        neo.observe("pure resonance through field")

        # Warp should return something
        warped = neo.warp("resonance", max_tokens=5)

        self.assertIsInstance(warped, str)
        self.assertTrue(len(warped) > 0)

    def test_neoleo_stats(self):
        """Test statistics retrieval."""
        neo = neoleo.NeoLeo()
        neo.observe("test stats data")

        stats = neo.stats()

        self.assertIn("vocab_size", stats)
        self.assertIn("centers", stats)
        self.assertIn("bigrams", stats)
        self.assertGreater(stats["vocab_size"], 0)

    def test_neoleo_export_lexicon(self):
        """Test lexicon export."""
        neo = neoleo.NeoLeo()
        neo.observe("export this lexicon")

        path = neo.export_lexicon()

        self.assertTrue(path.exists())

        # Check JSON is valid
        import json
        with open(path, 'r') as f:
            data = json.load(f)

        self.assertIn("vocab", data)
        self.assertIn("centers", data)
        self.assertIn("vocab_size", data)


class TestNeoLeoModuleFunctions(unittest.TestCase):
    """Test module-level singleton functions."""

    def setUp(self):
        """Reset singleton before each test."""
        neoleo._default_neo = None

        self.temp_dir = tempfile.mkdtemp()
        self.original_state = neoleo.STATE_DIR
        self.original_bin = neoleo.BIN_DIR
        self.original_json = neoleo.JSON_DIR
        self.original_db = neoleo.DB_PATH

        neoleo.STATE_DIR = Path(self.temp_dir) / "state"
        neoleo.BIN_DIR = Path(self.temp_dir) / "bin"
        neoleo.JSON_DIR = Path(self.temp_dir) / "json"
        neoleo.DB_PATH = neoleo.STATE_DIR / "test_neoleo.sqlite3"

    def tearDown(self):
        """Clean up."""
        neoleo._default_neo = None

        neoleo.STATE_DIR = self.original_state
        neoleo.BIN_DIR = self.original_bin
        neoleo.JSON_DIR = self.original_json
        neoleo.DB_PATH = self.original_db

        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_get_default(self):
        """Test singleton creation."""
        neo1 = neoleo.get_default()
        neo2 = neoleo.get_default()

        # Should be the same instance
        self.assertIs(neo1, neo2)

    def test_module_observe(self):
        """Test module-level observe function."""
        neoleo.observe("module level observation")

        neo = neoleo.get_default()
        self.assertGreater(neo.vocab_size, 0)

    def test_module_warp(self):
        """Test module-level warp function."""
        neoleo.observe("some text for warping")
        warped = neoleo.warp("text", max_tokens=3)

        self.assertIsInstance(warped, str)

    def test_module_stats(self):
        """Test module-level stats function."""
        neoleo.observe("stats test")
        stats = neoleo.stats()

        self.assertIsInstance(stats, dict)
        self.assertIn("vocab_size", stats)


class TestNeoLeoFormatting(unittest.TestCase):
    """Test formatting functions."""

    def test_format_tokens(self):
        """Test token formatting."""
        tokens = ["word", ",", "another", "."]
        formatted = neoleo.format_tokens(tokens)
        self.assertEqual(formatted, "word, another.")

    def test_capitalize_sentences(self):
        """Test sentence capitalization."""
        text = "first. second! third?"
        capitalized = neoleo.capitalize_sentences(text)
        self.assertEqual(capitalized, "First. Second! Third?")


class TestNeoLeoPromptConnection(unittest.TestCase):
    """Test the NO FIRST SEED FROM PROMPT + prompt connection functionality."""
    
    def test_get_prompt_connection_basic(self):
        """Test basic prompt connection extraction."""
        prompt = "What is resonance?"
        tokens = neoleo.tokenize(prompt)
        vocab = ["resonance", "field", "neo"]
        
        connection = neoleo.get_prompt_connection(tokens, vocab)
        
        # Should return 'resonance' (in vocab, not a stop word)
        self.assertEqual(connection, "resonance")
    
    def test_get_prompt_connection_filters_stop_words(self):
        """Test that stop words are filtered out."""
        prompt = "What is the meaning of this"
        tokens = neoleo.tokenize(prompt)
        vocab = []
        
        connection = neoleo.get_prompt_connection(tokens, vocab)
        
        # Should return 'meaning' (only non-stop word >= 3 chars)
        self.assertEqual(connection, "meaning")
    
    def test_get_prompt_connection_empty_prompt(self):
        """Test that empty prompt returns None."""
        connection = neoleo.get_prompt_connection([], [])
        self.assertIsNone(connection)
    
    def test_stop_words_constant(self):
        """Test that STOP_WORDS constant is properly defined."""
        self.assertIsInstance(neoleo.STOP_WORDS, (set, frozenset))
        self.assertIn("what", neoleo.STOP_WORDS)
        self.assertIn("the", neoleo.STOP_WORDS)
    
    def test_prompt_connection_constants(self):
        """Test that prompt connection constants are properly defined."""
        self.assertGreaterEqual(neoleo.PROMPT_CONNECTION_PROBABILITY, 0.0)
        self.assertLessEqual(neoleo.PROMPT_CONNECTION_PROBABILITY, 1.0)
        self.assertGreater(neoleo.PROMPT_CONNECTION_POSITION, 0)


if __name__ == "__main__":
    unittest.main()
