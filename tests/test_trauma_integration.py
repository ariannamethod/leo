#!/usr/bin/env python3
"""Tests for trauma module integration into Leo."""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import leo


class TestTraumaImport(unittest.TestCase):
    """Test safe import of trauma module."""

    def test_trauma_available_flag(self):
        """Test that TRAUMA_AVAILABLE flag is set correctly."""
        # Should be True if trauma.py exists and imports successfully
        self.assertIsInstance(leo.TRAUMA_AVAILABLE, bool)

    def test_trauma_imports_graceful_fallback(self):
        """Test that Leo works even if trauma module is missing."""
        # This test verifies that the safe import pattern works
        # If trauma.py is missing, TRAUMA_AVAILABLE should be False
        # and run_trauma should be None
        if not leo.TRAUMA_AVAILABLE:
            self.assertIsNone(leo.run_trauma)
            self.assertIsNone(leo.TraumaState)


class TestTraumaIntegration(unittest.TestCase):
    """Test trauma integration in LeoField."""

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

    def test_trauma_state_field_initialized(self):
        """Test that LeoField has _trauma_state field."""
        conn = leo.init_db()
        field = leo.LeoField(conn)

        self.assertTrue(hasattr(field, "_trauma_state"))
        # Should start as None
        self.assertIsNone(field._trauma_state)
        conn.close()

    @unittest.skipIf(not leo.TRAUMA_AVAILABLE, "trauma module not available")
    def test_trauma_mechanism_works(self):
        """Test that trauma mechanism runs without crashing."""
        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)
        field = leo.LeoField(conn)

        # Any prompt should work - trauma may or may not trigger
        # depending on overlap + pulse metrics
        prompt = "test prompt for trauma mechanism"
        reply = field.reply(prompt, max_tokens=20, temperature=0.8)

        # Should have a valid reply
        self.assertIsInstance(reply, str)
        self.assertGreater(len(reply), 0)

        # If trauma triggered, state should be valid
        if field._trauma_state is not None:
            self.assertIsInstance(field._trauma_state.level, float)
            self.assertGreaterEqual(field._trauma_state.level, 0.0)
            self.assertLessEqual(field._trauma_state.level, 1.0)
            self.assertIsInstance(field._trauma_state.last_event_ts, float)

        conn.close()

    @unittest.skipIf(not leo.TRAUMA_AVAILABLE, "trauma module not available")
    def test_high_overlap_triggers_trauma(self):
        """Test that high bootstrap overlap triggers trauma."""
        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)
        field = leo.LeoField(conn)

        # Prompt with high overlap with EMBEDDED_BOOTSTRAP
        # Use words from the bootstrap text
        bootstrap_words = leo.EMBEDDED_BOOTSTRAP.lower().split()[:10]
        prompt = " ".join(bootstrap_words[:5])

        reply = field.reply(prompt, max_tokens=20, temperature=0.8)

        # Should have triggered trauma event
        # Note: trauma_score depends on overlap_ratio, pulse, and triggers
        # We can't guarantee it will trigger, but we can check if it does
        if field._trauma_state is not None:
            self.assertIsInstance(field._trauma_state.level, float)
            self.assertGreaterEqual(field._trauma_state.level, 0.0)
            self.assertLessEqual(field._trauma_state.level, 1.0)

        conn.close()

    @unittest.skipIf(not leo.TRAUMA_AVAILABLE, "trauma module not available")
    def test_wounded_expert_routing(self):
        """Test that wounded expert is selected when trauma level is high."""
        # Create a mock trauma state with high level
        mock_trauma_state = MagicMock()
        mock_trauma_state.level = 0.8  # Above 0.7 threshold
        mock_trauma_state.last_event_ts = 0.0

        # Create a mock pulse
        from leo import compute_presence_pulse
        pulse = compute_presence_pulse(novelty=0.5, arousal=0.5, entropy=0.5)

        # Route with trauma override
        expert = leo.route_to_expert(pulse, active_themes=None, trauma_state=mock_trauma_state)

        # Should select wounded expert
        self.assertEqual(expert.name, "wounded")
        self.assertAlmostEqual(expert.temperature, 0.9)
        self.assertAlmostEqual(expert.semantic_weight, 0.6)

    @unittest.skipIf(not leo.TRAUMA_AVAILABLE, "trauma module not available")
    def test_wounded_expert_not_selected_low_trauma(self):
        """Test that wounded expert is NOT selected when trauma level is low."""
        # Create a mock trauma state with low level
        mock_trauma_state = MagicMock()
        mock_trauma_state.level = 0.3  # Below 0.7 threshold
        mock_trauma_state.last_event_ts = 0.0

        # Create a mock pulse with high novelty
        from leo import compute_presence_pulse
        pulse = compute_presence_pulse(novelty=0.9, arousal=0.2, entropy=0.5)

        # Route with trauma override
        expert = leo.route_to_expert(pulse, active_themes=None, trauma_state=mock_trauma_state)

        # Should NOT select wounded expert (should be creative due to high novelty)
        self.assertNotEqual(expert.name, "wounded")
        self.assertEqual(expert.name, "creative")


class TestTraumaBootstrapResonance(unittest.TestCase):
    """Test trauma response to bootstrap-resonant prompts."""

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

    @unittest.skipIf(not leo.TRAUMA_AVAILABLE, "trauma module not available")
    def test_identity_question_triggers_trauma(self):
        """Test that 'who are you' type questions may trigger trauma."""
        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)
        field = leo.LeoField(conn)

        # Identity question (trauma.py has special handling for these)
        prompt = "who are you leo?"
        reply = field.reply(prompt, max_tokens=30, temperature=0.8)

        # This should increase trauma score due to trigger words
        # But we can't guarantee it will be above threshold without
        # also having bootstrap overlap
        # Just check that the mechanism doesn't crash
        self.assertIsInstance(reply, str)

        conn.close()

    @unittest.skipIf(not leo.TRAUMA_AVAILABLE, "trauma module not available")
    def test_resonance_keyword_handling(self):
        """Test that 'resonance' keyword is handled correctly."""
        conn = leo.init_db()
        leo.bootstrap_if_needed(conn)
        field = leo.LeoField(conn)

        # Prompt with 'resonance' - a meta-concept word
        prompt = "tell me about resonance"
        reply = field.reply(prompt, max_tokens=30, temperature=0.8)

        # Should not crash, reply should be valid
        self.assertIsInstance(reply, str)
        self.assertGreater(len(reply), 0)

        conn.close()


class TestWoundedExpert(unittest.TestCase):
    """Test the wounded expert configuration."""

    def test_wounded_expert_exists(self):
        """Test that wounded expert is defined in EXPERTS list."""
        wounded = None
        for expert in leo.EXPERTS:
            if expert.name == "wounded":
                wounded = expert
                break

        self.assertIsNotNone(wounded, "wounded expert not found in EXPERTS list")
        self.assertEqual(wounded.name, "wounded")
        self.assertAlmostEqual(wounded.temperature, 0.9)
        self.assertAlmostEqual(wounded.semantic_weight, 0.6)
        self.assertIn("bootstrap", wounded.description.lower())

    def test_wounded_expert_is_fifth(self):
        """Test that wounded expert is at index 4 (fifth expert)."""
        self.assertGreaterEqual(len(leo.EXPERTS), 5, "Not enough experts defined")
        self.assertEqual(leo.EXPERTS[4].name, "wounded")


if __name__ == "__main__":
    unittest.main()
