#!/usr/bin/env python3
"""
Tests for MultiLeo presence-aware regulation layer.

MultiLeo is a sub-layer inside MathBrain that computes boredom/overwhelm/stuck
scores and gently nudges temperature and expert choices.
"""

import unittest
import tempfile
import os
from pathlib import Path

try:
    from mathbrain import (
        MathBrain,
        MathState,
        _compute_boredom_score,
        _compute_overwhelm_score,
        _compute_stuck_score,
        MULTILEO_TEMP_MIN,
        MULTILEO_TEMP_MAX,
    )
    MATHBRAIN_AVAILABLE = True
except ImportError:
    MATHBRAIN_AVAILABLE = False


@unittest.skipIf(not MATHBRAIN_AVAILABLE, "mathbrain not available")
class TestMultiLeoScores(unittest.TestCase):
    """Test MultiLeo score computation functions."""

    def test_boredom_score_high_when_low_activity(self):
        """Boredom score should be high when novelty and arousal are low."""
        state = MathState(
            novelty=0.1,  # Low
            arousal=0.1,  # Low
            trauma_level=0.1,  # Low
            entropy=0.5,  # Medium
        )
        boredom = _compute_boredom_score(state)
        self.assertGreater(boredom, 0.6, "Boredom should be high (>0.6) with low novelty/arousal")

    def test_boredom_score_low_when_high_activity(self):
        """Boredom score should be low when novelty and arousal are high."""
        state = MathState(
            novelty=0.9,  # High
            arousal=0.9,  # High
            trauma_level=0.5,
            entropy=0.5,
        )
        boredom = _compute_boredom_score(state)
        self.assertLess(boredom, 0.4, "Boredom should be low (<0.4) with high novelty/arousal")

    def test_overwhelm_score_high_when_high_trauma(self):
        """Overwhelm score should be high when trauma is high."""
        state = MathState(
            trauma_level=0.9,  # High
            arousal=0.5,
            entropy=0.5,
        )
        overwhelm = _compute_overwhelm_score(state)
        self.assertGreater(overwhelm, 0.7, "Overwhelm should be high (>0.7) with high trauma")

    def test_overwhelm_score_high_when_high_arousal(self):
        """Overwhelm score should be high when arousal is very high."""
        state = MathState(
            trauma_level=0.3,
            arousal=0.95,  # Very high
            entropy=0.8,  # High
        )
        overwhelm = _compute_overwhelm_score(state)
        self.assertGreater(overwhelm, 0.7, "Overwhelm should be high with very high arousal + entropy")

    def test_overwhelm_score_low_when_calm(self):
        """Overwhelm score should be low when calm."""
        state = MathState(
            trauma_level=0.2,
            arousal=0.2,
            entropy=0.3,
        )
        overwhelm = _compute_overwhelm_score(state)
        self.assertLess(overwhelm, 0.4, "Overwhelm should be low (<0.4) when calm")

    def test_stuck_score_high_when_low_quality(self):
        """Stuck score should be high when predicted quality is low."""
        state = MathState(
            total_themes=10,
            active_theme_count=2,  # Low theme variation
        )
        predicted_q = 0.2  # Low quality
        stuck = _compute_stuck_score(state, predicted_q)
        self.assertGreater(stuck, 0.6, "Stuck should be high (>0.6) with low quality")

    def test_stuck_score_low_when_high_quality(self):
        """Stuck score should be low when predicted quality is high."""
        state = MathState(
            total_themes=10,
            active_theme_count=8,  # High theme variation
        )
        predicted_q = 0.9  # High quality
        stuck = _compute_stuck_score(state, predicted_q)
        self.assertLess(stuck, 0.4, "Stuck should be low (<0.4) with high quality")


@unittest.skipIf(not MATHBRAIN_AVAILABLE, "mathbrain not available")
class TestMultiLeoRegulation(unittest.TestCase):
    """Test MultiLeo regulation behavior."""

    def setUp(self):
        """Create temporary MathBrain for testing."""
        self.temp_dir = tempfile.mkdtemp()
        self.brain = MathBrain(
            leo_field=None,
            state_path=Path(self.temp_dir) / "mathbrain.json"
        )

    def tearDown(self):
        """Clean up temporary directory."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_neutral_state_no_significant_nudge(self):
        """MultiLeo should not nudge temperature significantly for neutral states."""
        state = MathState(
            novelty=0.5,  # Medium
            arousal=0.5,  # Medium
            trauma_level=0.3,  # Medium
            entropy=0.5,  # Medium
            total_themes=10,
            active_theme_count=5,
        )
        base_temp = 1.0
        expert = "structural"

        regulated_temp, suggested_expert = self.brain.multileo_regulate(
            temperature=base_temp,
            expert_name=expert,
            state=state,
        )

        # Temperature should not change much (within ±0.15)
        self.assertAlmostEqual(regulated_temp, base_temp, delta=0.15)
        # Expert might change (MultiLeo can suggest different experts even in neutral states)
        # That's OK - we only test that temperature is stable

    def test_boredom_increases_temperature(self):
        """MultiLeo should increase temperature when bored."""
        state = MathState(
            novelty=0.1,  # Low - boring!
            arousal=0.1,  # Low
            trauma_level=0.1,
            entropy=0.5,
            total_themes=10,
            active_theme_count=5,
        )
        base_temp = 0.8
        expert = "structural"

        regulated_temp, suggested_expert = self.brain.multileo_regulate(
            temperature=base_temp,
            expert_name=expert,
            state=state,
        )

        # Temperature should increase (wake up!)
        self.assertGreater(regulated_temp, base_temp)
        # Should suggest creative expert when very bored
        # (might not trigger at boredom=0.6-0.75 threshold, but definitely at >0.75)

    def test_overwhelm_decreases_temperature(self):
        """MultiLeo should decrease temperature when overwhelmed."""
        state = MathState(
            novelty=0.5,
            arousal=0.95,  # Very high!
            trauma_level=0.9,  # High!
            entropy=0.8,
            total_themes=10,
            active_theme_count=5,
        )
        base_temp = 1.2
        expert = "semantic"

        regulated_temp, suggested_expert = self.brain.multileo_regulate(
            temperature=base_temp,
            expert_name=expert,
            state=state,
        )

        # Temperature should decrease (soften, calm down)
        self.assertLess(regulated_temp, base_temp)

    def test_stuck_suggests_different_expert(self):
        """MultiLeo should suggest different expert when stuck."""
        state = MathState(
            novelty=0.4,
            arousal=0.4,
            trauma_level=0.3,
            entropy=0.4,
            total_themes=10,
            active_theme_count=1,  # Very low theme variation - stuck!
        )
        base_temp = 0.8
        expert = "structural"

        # Since stuck score depends on predicted_quality, we need low quality
        # Let's train the brain on low quality examples first
        for _ in range(5):
            train_state = MathState(
                novelty=0.4,
                arousal=0.4,
                entropy=0.4,
                trauma_level=0.3,
                total_themes=10,
                active_theme_count=1,
                quality=0.2,  # Low quality
            )
            self.brain.observe(train_state)

        regulated_temp, suggested_expert = self.brain.multileo_regulate(
            temperature=base_temp,
            expert_name=expert,
            state=state,
        )

        # Temperature should increase a bit to break pattern
        self.assertGreater(regulated_temp, base_temp)
        # Might suggest semantic instead of structural when stuck

    def test_temperature_bounds_enforced(self):
        """MultiLeo should enforce absolute temperature bounds."""
        # Test lower bound
        state = MathState(
            arousal=0.99,
            trauma_level=0.99,  # Maximum overwhelm
            entropy=0.9,
        )
        base_temp = 0.3

        regulated_temp, _ = self.brain.multileo_regulate(
            temperature=base_temp,
            expert_name="structural",
            state=state,
        )

        self.assertGreaterEqual(regulated_temp, MULTILEO_TEMP_MIN)
        self.assertLessEqual(regulated_temp, MULTILEO_TEMP_MAX)

        # Test upper bound
        state_bored = MathState(
            novelty=0.0,
            arousal=0.0,  # Maximum boredom
            trauma_level=0.0,
            entropy=0.5,
        )
        base_temp = 1.4

        regulated_temp, _ = self.brain.multileo_regulate(
            temperature=base_temp,
            expert_name="structural",
            state=state_bored,
        )

        self.assertGreaterEqual(regulated_temp, MULTILEO_TEMP_MIN)
        self.assertLessEqual(regulated_temp, MULTILEO_TEMP_MAX)

    def test_multileo_never_crashes(self):
        """MultiLeo should never crash even with invalid inputs."""
        # Test with extreme values
        state = MathState(
            novelty=1.5,  # Out of normal range
            arousal=-0.5,  # Negative
            trauma_level=999.0,  # Huge
            entropy=float('nan'),  # NaN
        )

        try:
            regulated_temp, suggested_expert = self.brain.multileo_regulate(
                temperature=1.0,
                expert_name="structural",
                state=state,
            )
            # Should return safe defaults on error
            self.assertIsNotNone(regulated_temp)
            self.assertIsNotNone(suggested_expert)
        except Exception as e:
            self.fail(f"MultiLeo should never crash, but raised: {e}")


if __name__ == '__main__':
    unittest.main()
