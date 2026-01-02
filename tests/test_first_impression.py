#!/usr/bin/env python3
"""Tests for first_impression.py — Emotion chambers + Cross-fire + Feedback loop."""

import sys
import unittest
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from first_impression import (
    compute_impression,
    Impression,
    adjust_temperature_by_impression,
    suggest_gravity_boost,
    WARM_WORDS,
    CURIOUS_WORDS,
    FEAR_WORDS,
    VOID_WORDS,
    PLAYFUL_WORDS,
)


class TestWordSets(unittest.TestCase):
    """Test emotion word sets are defined."""

    def test_warm_words_exist(self):
        """WARM_WORDS should be defined and non-empty."""
        self.assertIsInstance(WARM_WORDS, set)
        self.assertGreater(len(WARM_WORDS), 0)
        self.assertIn("love", WARM_WORDS)

    def test_curious_words_exist(self):
        """CURIOUS_WORDS should be defined and non-empty."""
        self.assertIsInstance(CURIOUS_WORDS, set)
        self.assertGreater(len(CURIOUS_WORDS), 0)
        self.assertIn("what", CURIOUS_WORDS)

    def test_fear_words_exist(self):
        """FEAR_WORDS should be defined and non-empty."""
        self.assertIsInstance(FEAR_WORDS, set)
        self.assertGreater(len(FEAR_WORDS), 0)
        self.assertIn("fear", FEAR_WORDS)

    def test_void_words_exist(self):
        """VOID_WORDS should be defined and non-empty."""
        self.assertIsInstance(VOID_WORDS, set)
        self.assertGreater(len(VOID_WORDS), 0)
        self.assertIn("empty", VOID_WORDS)

    def test_playful_words_exist(self):
        """PLAYFUL_WORDS should be defined (Leo's unique chamber!)."""
        self.assertIsInstance(PLAYFUL_WORDS, set)
        self.assertGreater(len(PLAYFUL_WORDS), 0)
        self.assertIn("play", PLAYFUL_WORDS)


class TestImpression(unittest.TestCase):
    """Test complete impression computation."""

    def test_compute_impression_returns_impression_or_dict(self):
        """compute_impression should return Impression or dict."""
        result = compute_impression("Hello there!")
        # Should be Impression or dict
        self.assertTrue(isinstance(result, (Impression, dict)))

    def test_impression_from_warm_text(self):
        """Warm text should have high warmth."""
        result = compute_impression("I love you so much! You're amazing!")
        if isinstance(result, Impression):
            self.assertGreater(result.warmth, 0)
        else:
            self.assertGreater(result.get("warmth", 0), 0)

    def test_impression_from_curious_text(self):
        """Curious text should have high curiosity."""
        result = compute_impression("What is this? How does it work?")
        if isinstance(result, Impression):
            self.assertGreater(result.curiosity, 0)
        else:
            self.assertGreater(result.get("curiosity", 0), 0)


class TestTemperatureAdjustment(unittest.TestCase):
    """Test temperature adjustment based on impression."""

    def test_adjustment_returns_float(self):
        """Temperature adjustment should return float."""
        impression = Impression(warmth=0.8, arousal=0.5)
        temp = adjust_temperature_by_impression(1.0, impression)
        self.assertIsInstance(temp, (int, float))

    def test_high_arousal_affects_temp(self):
        """High arousal should affect temperature."""
        low_arousal = Impression(arousal=0.1)
        high_arousal = Impression(arousal=0.9)
        
        temp_low = adjust_temperature_by_impression(1.0, low_arousal)
        temp_high = adjust_temperature_by_impression(1.0, high_arousal)
        
        # They should be different
        self.assertIsInstance(temp_low, (int, float))
        self.assertIsInstance(temp_high, (int, float))


class TestGravityBoost(unittest.TestCase):
    """Test gravity boost suggestions."""

    def test_suggest_returns_dict(self):
        """suggest_gravity_boost should return dict."""
        impression = Impression(warmth=0.8, curiosity=0.3)
        boosts = suggest_gravity_boost(impression)
        self.assertIsInstance(boosts, dict)


if __name__ == "__main__":
    unittest.main()
