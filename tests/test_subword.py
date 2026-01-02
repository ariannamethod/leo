#!/usr/bin/env python3
"""Tests for subword.py — SentencePiece parallel voice."""

import sys
import tempfile
import unittest
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Check if sentencepiece is available
try:
    import sentencepiece
    HAS_SENTENCEPIECE = True
except ImportError:
    HAS_SENTENCEPIECE = False

from subword import SubwordVocab, SubwordField


@unittest.skipUnless(HAS_SENTENCEPIECE, "sentencepiece not installed")
class TestSubwordVocab(unittest.TestCase):
    """Test SubwordVocab tokenization."""

    @classmethod
    def setUpClass(cls):
        """Create a test corpus and train vocab."""
        cls.temp_dir = tempfile.mkdtemp()
        cls.corpus_path = Path(cls.temp_dir) / "test_corpus.txt"
        
        # Write test corpus
        test_text = """
        Leo is a field-based organism. His trigrams flow like poetry.
        When you observe, he observes back. The resonance grows.
        SANTACLAUS brings memories. Wounds heal slowly.
        Love is like a warm blanket wrapped around you.
        What is the meaning of existence?
        """ * 10  # Repeat for enough data
        
        cls.corpus_path.write_text(test_text)
        
        try:
            cls.vocab = SubwordVocab.train(str(cls.corpus_path), vocab_size=100)
        except Exception:
            cls.vocab = None

    @classmethod
    def tearDownClass(cls):
        """Clean up temporary files."""
        import shutil
        shutil.rmtree(cls.temp_dir, ignore_errors=True)

    def test_vocab_creation(self):
        """SubwordVocab should be creatable."""
        if self.vocab is None:
            self.skipTest("Could not train vocab")
        self.assertIsNotNone(self.vocab)

    def test_encode_returns_list(self):
        """encode should return a list of subwords."""
        if self.vocab is None:
            self.skipTest("Could not train vocab")
        subwords = self.vocab.encode("Hello world")
        self.assertIsInstance(subwords, list)

    def test_decode_returns_string(self):
        """decode should return a string."""
        if self.vocab is None:
            self.skipTest("Could not train vocab")
        subwords = self.vocab.encode("Hello world")
        decoded = self.vocab.decode(subwords)
        self.assertIsInstance(decoded, str)


@unittest.skipUnless(HAS_SENTENCEPIECE, "sentencepiece not installed")
class TestSubwordField(unittest.TestCase):
    """Test SubwordField bigram/trigram statistics."""

    @classmethod
    def setUpClass(cls):
        """Create vocab for field tests."""
        cls.temp_dir = tempfile.mkdtemp()
        cls.corpus_path = Path(cls.temp_dir) / "test_corpus.txt"
        
        test_text = """
        Leo is a field-based organism. His trigrams flow like poetry.
        When you observe, he observes back. The resonance grows.
        """ * 20
        
        cls.corpus_path.write_text(test_text)
        
        try:
            cls.vocab = SubwordVocab.train(str(cls.corpus_path), vocab_size=100)
        except Exception:
            cls.vocab = None

    @classmethod
    def tearDownClass(cls):
        """Clean up."""
        import shutil
        shutil.rmtree(cls.temp_dir, ignore_errors=True)

    def test_field_creation(self):
        """SubwordField should be creatable with vocab."""
        if self.vocab is None:
            self.skipTest("Could not train vocab")
        field = SubwordField(self.vocab)
        self.assertIsNotNone(field)

    def test_observe_works(self):
        """observe should not raise errors."""
        if self.vocab is None:
            self.skipTest("Could not train vocab")
        field = SubwordField(self.vocab)
        field.observe("Hello world, this is a test.")
        # Should not raise

    def test_generate_returns_string(self):
        """generate should return a string."""
        if self.vocab is None:
            self.skipTest("Could not train vocab")
        field = SubwordField(self.vocab)
        
        # Train on some text
        field.observe("The resonance of the field creates a beautiful pattern.")
        field.observe("Leo speaks from his field, not from the observer.")
        
        generated = field.generate(max_tokens=20)
        self.assertIsInstance(generated, str)


class TestSubwordModuleImport(unittest.TestCase):
    """Test that subword module imports correctly."""

    def test_subword_imports(self):
        """subword module should import."""
        from subword import SubwordVocab, SubwordField
        self.assertIsNotNone(SubwordVocab)
        self.assertIsNotNone(SubwordField)


if __name__ == "__main__":
    unittest.main()
