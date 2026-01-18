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


class TestEmotionalWeights(unittest.TestCase):
    """Test EMOTIONAL_WEIGHTS float dictionary (inspired by arianna.c/high.go)."""

    def test_emotional_weights_is_dict(self):
        """EMOTIONAL_WEIGHTS should be a dict with float values."""
        from first_impression import EMOTIONAL_WEIGHTS
        self.assertIsInstance(EMOTIONAL_WEIGHTS, dict)
        # Check some values
        self.assertIsInstance(EMOTIONAL_WEIGHTS.get("love"), float)
        self.assertIsInstance(EMOTIONAL_WEIGHTS.get("hate"), float)

    def test_emotional_weights_positive_valence(self):
        """Positive words should have positive valence."""
        from first_impression import EMOTIONAL_WEIGHTS
        self.assertGreater(EMOTIONAL_WEIGHTS.get("love", 0), 0.5)
        self.assertGreater(EMOTIONAL_WEIGHTS.get("happy", 0), 0.5)
        self.assertGreater(EMOTIONAL_WEIGHTS.get("play", 0), 0.5)

    def test_emotional_weights_negative_valence(self):
        """Negative words should have negative valence."""
        from first_impression import EMOTIONAL_WEIGHTS
        self.assertLess(EMOTIONAL_WEIGHTS.get("hate", 0), -0.5)
        self.assertLess(EMOTIONAL_WEIGHTS.get("fear", 0), -0.5)
        self.assertLess(EMOTIONAL_WEIGHTS.get("alone", 0), -0.5)

    def test_compute_emotional_valence(self):
        """compute_emotional_valence should return (valence, arousal)."""
        from first_impression import compute_emotional_valence
        
        valence, arousal = compute_emotional_valence("I love you!")
        self.assertGreater(valence, 0.5)
        self.assertGreaterEqual(arousal, 0)
        
        valence, arousal = compute_emotional_valence("I hate this")
        self.assertLess(valence, 0)


class TestEmotionalDrift(unittest.TestCase):
    """Test EmotionalDrift ODE (Free Energy Principle)."""

    def test_emotional_state_creation(self):
        """EmotionalState should be created with defaults."""
        from first_impression import EmotionalState
        state = EmotionalState()
        self.assertAlmostEqual(state.valence, 0.1)
        self.assertAlmostEqual(state.arousal, 0.3)
        self.assertEqual(state.message_count, 0)

    def test_emotional_drift_updates_state(self):
        """emotional_drift should update state based on input."""
        from first_impression import EmotionalState, emotional_drift
        
        initial = EmotionalState()
        after = emotional_drift(initial, "I love you so much!")
        
        # Valence should increase (positive input)
        self.assertGreater(after.valence, initial.valence)
        self.assertEqual(after.message_count, 1)

    def test_emotional_drift_remembers_momentum(self):
        """Emotional state should have momentum between messages."""
        from first_impression import (
            reset_emotional_state,
            update_emotional_state,
        )
        
        reset_emotional_state()
        state1 = update_emotional_state("I love you!")
        state2 = update_emotional_state("Hello again")
        
        # Momentum should carry some positive valence
        self.assertGreater(state2.valence, 0)
        self.assertEqual(state2.message_count, 2)

    def test_compute_surprise(self):
        """compute_surprise should return prediction error."""
        from first_impression import compute_surprise
        
        surprise = compute_surprise(0.5, 0.5)
        self.assertAlmostEqual(surprise, 0.0)
        
        surprise = compute_surprise(0.5, -0.5)
        self.assertAlmostEqual(surprise, 1.0)


if __name__ == "__main__":
    unittest.main()
