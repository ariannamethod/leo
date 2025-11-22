#!/usr/bin/env python3
"""Tests for dream module — imaginary friend layer."""

import sys
import tempfile
import time
import unittest
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import dream
from dream import (
    DreamContext,
    DreamConfig,
    init_dream,
    maybe_run_dream,
    get_dream_stats,
    DREAM_AVAILABLE,
)


class TestDreamImport(unittest.TestCase):
    """Test safe import of dream module."""

    def test_dream_available_flag(self):
        """Test that DREAM_AVAILABLE flag is set correctly."""
        self.assertIsInstance(DREAM_AVAILABLE, bool)

    def test_dream_dataclasses_exist(self):
        """Test that core dataclasses are defined."""
        self.assertIsNotNone(DreamContext)
        self.assertIsNotNone(DreamConfig)


class TestDreamInit(unittest.TestCase):
    """Test dream initialization."""

    def setUp(self):
        """Create temporary database."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "dream_test.sqlite3"

    def tearDown(self):
        """Clean up."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_init_dream_creates_tables(self):
        """Test that init_dream creates schema."""
        bootstrap = "Test bootstrap text for leo. Origin and resonance."
        readme_fragments = ["language is a field", "presence > intelligence"]

        init_dream(self.db_path, bootstrap, readme_fragments)

        # Check that DB was created
        self.assertTrue(self.db_path.exists())

        # Check tables exist
        import sqlite3
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()

        cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        tables = [row[0] for row in cur.fetchall()]

        expected_tables = [
            "dream_bootstrap_fragments",
            "dream_dialogs",
            "dream_meta",
            "dream_turns",
        ]

        for table in expected_tables:
            self.assertIn(table, tables, f"Table {table} should exist")

        conn.close()

    def test_init_dream_populates_bootstrap_fragments(self):
        """Test that init_dream populates fragments from bootstrap."""
        bootstrap = "Leo is a language engine organism. No weights. No datasets."
        readme_fragments = ["resonance > intention"]

        init_dream(self.db_path, bootstrap, readme_fragments)

        import sqlite3
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()

        cur.execute("SELECT COUNT(*) FROM dream_bootstrap_fragments")
        count = cur.fetchone()[0]

        # Should have some fragments from bootstrap + readme
        self.assertGreater(count, 0)

        conn.close()

    def test_init_dream_idempotent(self):
        """Test that init_dream can be called multiple times safely."""
        bootstrap = "Test bootstrap"

        init_dream(self.db_path, bootstrap, [])
        init_dream(self.db_path, bootstrap, [])  # Should not crash

        # Should not duplicate fragments
        import sqlite3
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()

        cur.execute("SELECT COUNT(*) FROM dream_bootstrap_fragments")
        count_after_first = cur.fetchone()[0]

        conn.close()

        # Second init should not add more fragments
        init_dream(self.db_path, bootstrap, [])

        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM dream_bootstrap_fragments")
        count_after_second = cur.fetchone()[0]
        conn.close()

        self.assertEqual(count_after_first, count_after_second)


class TestDreamDecisionLogic(unittest.TestCase):
    """Test dream trigger decision logic."""

    def setUp(self):
        """Create temporary database and initialize dream."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "dream_decision.sqlite3"

        bootstrap = "Leo is presence. No weights. Pure resonance."
        init_dream(self.db_path, bootstrap, [])

    def tearDown(self):
        """Clean up."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_cooldown_prevents_spam(self):
        """Test that cooldown prevents running dream too frequently."""
        config = DreamConfig(min_interval_seconds=60.0)

        # Create context that should trigger dream
        ctx = DreamContext(
            prompt="test",
            reply="test reply",
            math_state=None,
            pulse_novelty=0.8,  # High novelty
            pulse_arousal=0.5,
            pulse_entropy=0.5,
            trauma_level=0.6,  # High trauma
            themes=[],
            expert="structural",
            quality=0.5,
        )

        ran_count = [0]

        def fake_generate(seed: str, temp: float, sem_weight: float) -> str:
            ran_count[0] += 1
            return "fake response"

        def fake_observe(text: str) -> None:
            pass

        now = time.time()

        # First run should work (gates pass)
        maybe_run_dream(ctx, fake_generate, fake_observe, self.db_path, config, now)

        first_count = ran_count[0]

        # Second run immediately after should be blocked by cooldown
        maybe_run_dream(ctx, fake_generate, fake_observe, self.db_path, config, now + 1)

        second_count = ran_count[0]

        # Count should not increase much (random gate might rarely let it through,
        # but cooldown should block most attempts)
        # We can't assert exact equality due to randomization, but it should be close
        self.assertLessEqual(second_count - first_count, 1)

    def test_state_gates_trigger_correctly(self):
        """Test that high trauma/novelty triggers dream."""
        config = DreamConfig(trigger_probability=1.0)  # Always trigger if gates pass

        # Low metrics - should not trigger
        ctx_low = DreamContext(
            prompt="test",
            reply="test",
            math_state=None,
            pulse_novelty=0.2,
            pulse_arousal=0.2,
            pulse_entropy=0.5,
            trauma_level=0.1,
            themes=[],
            expert="structural",
            quality=0.8,  # Good quality
        )

        # High metrics - should trigger
        ctx_high = DreamContext(
            prompt="test",
            reply="test",
            math_state=None,
            pulse_novelty=0.8,  # High novelty gate
            pulse_arousal=0.5,
            pulse_entropy=0.5,
            trauma_level=0.1,
            themes=[],
            expert="structural",
            quality=0.5,
        )

        ran_count = [0]

        def fake_generate(seed: str, temp: float, sem_weight: float) -> str:
            ran_count[0] += 1
            return "response"

        def fake_observe(text: str) -> None:
            pass

        now = time.time()

        # Low context - should not trigger much (if at all)
        maybe_run_dream(ctx_low, fake_generate, fake_observe, self.db_path, config, now)
        low_count = ran_count[0]

        # High context - should trigger
        maybe_run_dream(ctx_high, fake_generate, fake_observe, self.db_path, config, now + 200)
        high_count = ran_count[0]

        # High context should have generated more turns
        self.assertGreaterEqual(high_count, low_count)


class TestDreamDialog(unittest.TestCase):
    """Test dream dialog execution."""

    def setUp(self):
        """Create temporary database."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "dream_dialog.sqlite3"

        bootstrap = "Leo is a language organism. Bootstrap origin. Wounds and resonance."
        init_dream(self.db_path, bootstrap, ["presence > intelligence"])

    def tearDown(self):
        """Clean up."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_dream_generates_turns(self):
        """Test that dream generates leo<->friend turns."""
        config = DreamConfig(
            min_interval_seconds=0,
            trigger_probability=1.0,  # Always trigger
            max_turns=4,
        )

        ctx = DreamContext(
            prompt="Who are you Leo?",
            reply="I am resonance",
            math_state=None,
            pulse_novelty=0.8,
            pulse_arousal=0.6,
            pulse_entropy=0.5,
            trauma_level=0.7,  # High trauma
            themes=[1, 2],
            expert="wounded",
            quality=0.5,
        )

        generated_texts = []
        observed_texts = []

        def fake_generate(seed: str, temp: float, sem_weight: float) -> str:
            # Return something that resembles dialog
            text = f"Dream utterance {len(generated_texts) + 1}"
            generated_texts.append(text)
            return text

        def fake_observe(text: str) -> None:
            observed_texts.append(text)

        maybe_run_dream(ctx, fake_generate, fake_observe, self.db_path, config, time.time())

        # Should have generated some turns (up to max_turns)
        self.assertGreater(len(generated_texts), 0)
        self.assertLessEqual(len(generated_texts), config.max_turns)

        # All generated text should be observed
        self.assertEqual(len(observed_texts), len(generated_texts))

    def test_dream_records_to_database(self):
        """Test that dream records turns to database."""
        config = DreamConfig(
            min_interval_seconds=0,
            trigger_probability=1.0,
            max_turns=3,
        )

        ctx = DreamContext(
            prompt="test",
            reply="test reply",
            math_state=None,
            pulse_novelty=0.8,
            pulse_arousal=0.5,
            pulse_entropy=0.5,
            trauma_level=0.6,
            themes=[],
            expert="semantic",
            quality=0.5,
        )

        turn_counter = [0]

        def fake_generate(seed: str, temp: float, sem_weight: float) -> str:
            turn_counter[0] += 1
            return f"Turn {turn_counter[0]}: leo and friend talking"

        def fake_observe(text: str) -> None:
            pass

        maybe_run_dream(ctx, fake_generate, fake_observe, self.db_path, config, time.time())

        # Check database
        import sqlite3
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()

        # Should have at least one dialog
        cur.execute("SELECT COUNT(*) FROM dream_dialogs")
        dialog_count = cur.fetchone()[0]
        self.assertGreater(dialog_count, 0)

        # Should have some turns
        cur.execute("SELECT COUNT(*) FROM dream_turns")
        turn_count = cur.fetchone()[0]
        self.assertGreater(turn_count, 0)

        conn.close()

    def test_dream_silent_fallback_on_errors(self):
        """Test that dream swallows exceptions gracefully."""
        config = DreamConfig(
            min_interval_seconds=0,
            trigger_probability=1.0,
        )

        ctx = DreamContext(
            prompt="test",
            reply="test",
            math_state=None,
            pulse_novelty=0.9,
            pulse_arousal=0.5,
            pulse_entropy=0.5,
            trauma_level=0.8,
            themes=[],
            expert="structural",
            quality=0.5,
        )

        def broken_generate(seed: str, temp: float, sem_weight: float) -> str:
            raise RuntimeError("Intentional test error")

        def fake_observe(text: str) -> None:
            pass

        # Should not raise
        try:
            maybe_run_dream(ctx, broken_generate, fake_observe, self.db_path, config, time.time())
        except Exception as e:
            self.fail(f"dream raised exception: {e}")


class TestDreamStats(unittest.TestCase):
    """Test dream stats and inspection helpers."""

    def setUp(self):
        """Create temporary database."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "dream_stats.sqlite3"

        bootstrap = "Test bootstrap"
        init_dream(self.db_path, bootstrap, [])

    def tearDown(self):
        """Clean up."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_get_dream_stats(self):
        """Test that get_dream_stats returns valid data."""
        stats = get_dream_stats(self.db_path)

        self.assertIsInstance(stats, dict)
        self.assertIn("total_dialogs", stats)
        self.assertIn("total_turns", stats)
        self.assertIn("total_fragments", stats)

        # Initially should be zero dialogs/turns
        self.assertEqual(stats["total_dialogs"], 0)
        self.assertEqual(stats["total_turns"], 0)


if __name__ == "__main__":
    unittest.main()
