"""
test_overthinking.py — Tests for overthinking module

Tests internal reflection system: rings, adapters, silent fallback.
"""

import unittest
from datetime import datetime, timezone

from overthinking import (
    OverthinkingConfig,
    OverthinkingEvent,
    PulseSnapshot,
    run_overthinking,
)


class TestPulseSnapshot(unittest.TestCase):
    """Test PulseSnapshot data container."""

    def test_pulse_snapshot_creation(self):
        """Test direct PulseSnapshot creation."""
        pulse = PulseSnapshot(novelty=0.8, arousal=0.6, entropy=0.5)
        self.assertEqual(pulse.novelty, 0.8)
        self.assertEqual(pulse.arousal, 0.6)
        self.assertEqual(pulse.entropy, 0.5)

    def test_pulse_snapshot_from_obj(self):
        """Test creating PulseSnapshot from object with attributes."""
        class FakePulse:
            def __init__(self):
                self.novelty = 0.7
                self.arousal = 0.4
                self.entropy = 0.3

        fake = FakePulse()
        pulse = PulseSnapshot.from_obj(fake)
        self.assertEqual(pulse.novelty, 0.7)
        self.assertEqual(pulse.arousal, 0.4)
        self.assertEqual(pulse.entropy, 0.3)

    def test_pulse_snapshot_from_obj_missing_attrs(self):
        """Test PulseSnapshot.from_obj with missing attributes (defaults to 0)."""
        class Incomplete:
            pass

        pulse = PulseSnapshot.from_obj(Incomplete())
        self.assertEqual(pulse.novelty, 0.0)
        self.assertEqual(pulse.arousal, 0.0)
        self.assertEqual(pulse.entropy, 0.0)


class TestOverthinkingConfig(unittest.TestCase):
    """Test OverthinkingConfig."""

    def test_default_config(self):
        """Test default configuration values."""
        config = OverthinkingConfig()
        self.assertEqual(config.rings, 3)
        self.assertEqual(config.ring0_max_tokens, 30)
        self.assertEqual(config.ring1_max_tokens, 40)
        self.assertEqual(config.ring2_max_tokens, 20)
        self.assertTrue(config.enable_logging)

    def test_custom_config(self):
        """Test custom configuration."""
        config = OverthinkingConfig(rings=2, ring0_max_tokens=20, enable_logging=False)
        self.assertEqual(config.rings, 2)
        self.assertEqual(config.ring0_max_tokens, 20)
        self.assertFalse(config.enable_logging)


class TestRunOverthinking(unittest.TestCase):
    """Test run_overthinking main entrypoint."""

    def test_run_overthinking_basic(self):
        """Test basic overthinking execution with 3 rings."""
        generated = []
        observed = []

        def fake_generate(seed, temp, max_tok, sem_weight, mode):
            text = f"{mode}:{seed[:20]}"
            generated.append(text)
            return text

        def fake_observe(text, source):
            observed.append((text, source))

        events = run_overthinking(
            prompt="test prompt",
            reply="test reply",
            generate_fn=fake_generate,
            observe_fn=fake_observe,
        )

        # Should generate 3 rings
        self.assertEqual(len(events), 3)
        self.assertEqual(len(generated), 3)
        self.assertEqual(len(observed), 3)

        # Check ring numbers
        self.assertEqual(events[0].ring, 0)
        self.assertEqual(events[1].ring, 1)
        self.assertEqual(events[2].ring, 2)

        # Check tags
        self.assertEqual(events[0].tag, "ring0/echo")
        self.assertEqual(events[1].tag, "ring1/drift")
        self.assertEqual(events[2].tag, "ring2/meta")

        # Check observe was called with correct sources
        self.assertEqual(observed[0][1], "overthinking:ring0")
        self.assertEqual(observed[1][1], "overthinking:ring1")
        self.assertEqual(observed[2][1], "overthinking:ring2")

    def test_run_overthinking_with_config(self):
        """Test overthinking with custom config (fewer rings)."""
        generated = []

        def fake_generate(seed, temp, max_tok, sem_weight, mode):
            return f"{mode}:{seed[:10]}"

        def fake_observe(text, source):
            pass

        config = OverthinkingConfig(rings=1)
        events = run_overthinking(
            prompt="test",
            reply="test",
            generate_fn=fake_generate,
            observe_fn=fake_observe,
            config=config,
        )

        # Only 1 ring
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].ring, 0)

    def test_run_overthinking_empty_input(self):
        """Test overthinking with empty prompt and reply."""
        events = run_overthinking(
            prompt="",
            reply="",
            generate_fn=lambda *args: "x",
            observe_fn=lambda *args: None,
        )
        # Should return empty list
        self.assertEqual(len(events), 0)

    def test_run_overthinking_with_pulse(self):
        """Test overthinking with pulse snapshot."""
        pulse = PulseSnapshot(novelty=0.9, arousal=0.7, entropy=0.4)

        events = run_overthinking(
            prompt="test",
            reply="test",
            generate_fn=lambda *args: "thought",
            observe_fn=lambda *args: None,
            pulse=pulse,
        )

        # All events should have the pulse attached
        for event in events:
            self.assertIsNotNone(event.pulse)
            self.assertEqual(event.pulse.novelty, 0.9)
            self.assertEqual(event.pulse.arousal, 0.7)

    def test_run_overthinking_silent_generate_failure(self):
        """Test that generate failures don't crash overthinking."""
        def broken_generate(*args):
            raise RuntimeError("generation failed")

        def fake_observe(text, source):
            pass

        # Should not raise, should fallback gracefully
        events = run_overthinking(
            prompt="test prompt",
            reply="test reply",
            generate_fn=broken_generate,
            observe_fn=fake_observe,
        )

        # Events should still be created (with seed as fallback)
        self.assertEqual(len(events), 3)

    def test_run_overthinking_silent_observe_failure(self):
        """Test that observe failures don't crash overthinking."""
        def fake_generate(seed, *args):
            return seed + " thought"

        def broken_observe(*args):
            raise RuntimeError("observe failed")

        # Should not raise
        events = run_overthinking(
            prompt="test",
            reply="test",
            generate_fn=fake_generate,
            observe_fn=broken_observe,
        )

        # Events should be created even if observe failed
        self.assertEqual(len(events), 3)

    def test_overthinking_event_structure(self):
        """Test OverthinkingEvent structure."""
        pulse = PulseSnapshot(novelty=0.5, arousal=0.5, entropy=0.5)

        events = run_overthinking(
            prompt="hello",
            reply="world",
            generate_fn=lambda *args: "internal thought",
            observe_fn=lambda *args: None,
            pulse=pulse,
        )

        event = events[0]
        self.assertEqual(event.ring, 0)
        self.assertIsInstance(event.created_at, datetime)
        self.assertEqual(event.prompt, "hello")
        self.assertEqual(event.reply, "world")
        self.assertEqual(event.thought, "internal thought")
        self.assertEqual(event.pulse, pulse)
        self.assertEqual(event.tag, "ring0/echo")


if __name__ == "__main__":
    unittest.main()
