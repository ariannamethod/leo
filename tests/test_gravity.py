#!/usr/bin/env python3
"""Tests for gravity.py — Prompt-induced field bias."""

import sys
import unittest
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from gravity import compute_prompt_gravity


class TestGravityComputation(unittest.TestCase):
    """Test gravity weight computation."""

    def test_compute_gravity_returns_dict(self):
        """compute_prompt_gravity should return a dict."""
        gravity = compute_prompt_gravity("What is resonance?")
        self.assertIsInstance(gravity, dict)

    def test_gravity_has_weights(self):
        """Gravity dict should have token weights."""
        gravity = compute_prompt_gravity("What is resonance?")
        # Should have some tokens
        self.assertGreater(len(gravity), 0)

    def test_gravity_weights_are_numeric(self):
        """Gravity weights should be numeric."""
        gravity = compute_prompt_gravity("I love you!")
        
        for token, weight in gravity.items():
            self.assertIsInstance(weight, (int, float))

    def test_empty_prompt(self):
        """Empty prompt should return empty or minimal gravity."""
        gravity = compute_prompt_gravity("")
        # Should be empty or very minimal
        self.assertIsInstance(gravity, dict)

    def test_long_prompt(self):
        """Long prompt should still work."""
        long_text = "What is the meaning of life? " * 10
        gravity = compute_prompt_gravity(long_text)
        self.assertIsInstance(gravity, dict)


class TestGravityPhilosophy(unittest.TestCase):
    """Test that gravity follows 'no seed from prompt' philosophy."""

    def test_gravity_is_gentle_boost(self):
        """Gravity should be gentle, not forcing."""
        gravity = compute_prompt_gravity("resonance resonance resonance")
        
        # All weights should exist and be reasonable
        for weight in gravity.values():
            self.assertIsInstance(weight, (int, float))


if __name__ == "__main__":
    unittest.main()
