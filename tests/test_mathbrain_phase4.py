#!/usr/bin/env python3
"""
test_mathbrain_phase4.py — Tests for Leo's Island Bridges (Phase 4)

Covers:
1. Recording transitions
2. Similarity edge cases
3. Suggesting flows
4. Overwhelm filtering
5. Score calculations
"""

import tempfile
from pathlib import Path
import pytest

from mathbrain_phase4 import (
    MathBrainPhase4,
    IslandTransitionStats,
    cosine_similarity,
    euclidean_distance,
    get_presence,
    metric_entropy,
    NUMPY_AVAILABLE,
)


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def temp_db():
    """Create a temporary database for testing."""
    with tempfile.NamedTemporaryFile(suffix=".sqlite3", delete=False) as f:
        db_path = Path(f.name)
    yield db_path
    # Cleanup
    if db_path.exists():
        db_path.unlink()


@pytest.fixture
def phase4(temp_db):
    """Create a Phase4 instance with temp database."""
    return MathBrainPhase4(temp_db)


# ============================================================================
# MATH HELPERS
# ============================================================================

class TestCosineSimilarity:
    """Tests for cosine_similarity function."""

    def test_identical_vectors(self):
        """Identical vectors should have similarity 1.0."""
        a = {"x": 1.0, "y": 2.0, "z": 3.0}
        b = {"x": 1.0, "y": 2.0, "z": 3.0}
        assert abs(cosine_similarity(a, b) - 1.0) < 0.001

    def test_orthogonal_vectors(self):
        """Orthogonal vectors should have similarity 0.0."""
        a = {"x": 1.0, "y": 0.0}
        b = {"x": 0.0, "y": 1.0}
        assert abs(cosine_similarity(a, b)) < 0.001

    def test_opposite_vectors(self):
        """Opposite vectors should have similarity -1.0."""
        a = {"x": 1.0, "y": 1.0}
        b = {"x": -1.0, "y": -1.0}
        assert abs(cosine_similarity(a, b) + 1.0) < 0.001

    def test_empty_vectors(self):
        """Empty vectors should return 0.0."""
        assert cosine_similarity({}, {"x": 1.0}) == 0.0
        assert cosine_similarity({"x": 1.0}, {}) == 0.0
        assert cosine_similarity({}, {}) == 0.0

    def test_no_shared_keys(self):
        """Vectors with no shared keys should return 0.0."""
        a = {"x": 1.0}
        b = {"y": 1.0}
        assert cosine_similarity(a, b) == 0.0

    def test_partial_overlap(self):
        """Vectors with partial key overlap should work."""
        a = {"x": 1.0, "y": 2.0, "z": 3.0}
        b = {"x": 1.0, "y": 2.0, "w": 100.0}
        # Should only use x and y
        sim = cosine_similarity(a, b)
        assert 0.9 < sim <= 1.0

    def test_all_zeros(self):
        """Zero vectors should return 0.0."""
        a = {"x": 0.0, "y": 0.0}
        b = {"x": 0.0, "y": 0.0}
        assert cosine_similarity(a, b) == 0.0


class TestEuclideanDistance:
    """Tests for euclidean_distance function."""

    def test_identical_vectors(self):
        """Identical vectors should have distance 0.0."""
        a = {"x": 1.0, "y": 2.0}
        b = {"x": 1.0, "y": 2.0}
        assert euclidean_distance(a, b) == 0.0

    def test_simple_distance(self):
        """Simple known distance."""
        a = {"x": 0.0, "y": 0.0}
        b = {"x": 3.0, "y": 4.0}
        assert abs(euclidean_distance(a, b) - 5.0) < 0.001

    def test_empty_vectors(self):
        """Empty vectors should return inf."""
        assert euclidean_distance({}, {"x": 1.0}) == float('inf')


class TestMetricEntropy:
    """Tests for metric_entropy function."""

    def test_uniform_distribution(self):
        """Uniform distribution should have high entropy."""
        a = {"x": 1.0, "y": 1.0, "z": 1.0, "w": 1.0}
        entropy = metric_entropy(a)
        assert entropy > 1.5  # log2(4) = 2.0

    def test_single_value(self):
        """Single non-zero value should have entropy 0."""
        a = {"x": 1.0, "y": 0.0, "z": 0.0}
        assert metric_entropy(a) == 0.0

    def test_empty_dict(self):
        """Empty dict should have entropy 0."""
        assert metric_entropy({}) == 0.0


# ============================================================================
# PHASE 4 RECORDING
# ============================================================================

class TestRecordActivation:
    """Tests for recording island activations."""

    def test_record_single_activation(self, phase4):
        """Record a single activation without previous island."""
        metrics_before = {"presence_pulse": 0.3, "entropy": 0.4}
        metrics_after = {"presence_pulse": 0.5, "entropy": 0.45}

        phase4.record_activation(
            island_id="island_A",
            metrics_before=metrics_before,
            metrics_after=metrics_after,
            turn_id="t1",
        )

        islands = phase4.get_all_islands()
        assert "island_A" in islands

    def test_record_transition(self, phase4):
        """Record a transition from one island to another."""
        metrics_a = {"presence_pulse": 0.3, "entropy": 0.4}
        metrics_b = {"presence_pulse": 0.5, "entropy": 0.45}

        phase4.record_activation("island_A", metrics_a, metrics_b, turn_id="t1")
        phase4.record_activation(
            "island_B", metrics_b, {"presence_pulse": 0.7, "entropy": 0.5},
            prev_island_id="island_A",
            turn_id="t2",
        )

        stats = phase4.get_transition_stats("island_A", "island_B")
        assert stats is not None
        assert stats.count == 1
        assert stats.avg_similarity > 0

    def test_multiple_transitions_aggregate(self, phase4):
        """Multiple transitions should aggregate correctly."""
        m1 = {"presence_pulse": 0.3}
        m2 = {"presence_pulse": 0.5}

        # Record A → B three times
        for i in range(3):
            phase4.record_activation(
                "island_B", m1, m2,
                prev_island_id="island_A",
                turn_id=f"t{i}",
            )

        stats = phase4.get_transition_stats("island_A", "island_B")
        assert stats is not None
        assert stats.count == 3

    def test_overwhelm_flag(self, phase4):
        """Overwhelm flag should be recorded."""
        m1 = {"presence_pulse": 0.3}
        m2 = {"presence_pulse": 0.1}

        phase4.record_activation(
            "island_bad", m1, m2,
            prev_island_id="island_A",
            turn_id="t1",
            overwhelm=True,
        )

        stats = phase4.get_transition_stats("island_A", "island_bad")
        assert stats is not None
        assert stats.overwhelm_rate == 1.0


# ============================================================================
# PHASE 4 SUGGESTIONS
# ============================================================================

class TestSuggestNextIslands:
    """Tests for suggesting next islands."""

    def test_suggest_returns_sorted(self, phase4):
        """Suggestions should be sorted by score descending."""
        m1 = {"presence_pulse": 0.3, "entropy": 0.4}
        m2 = {"presence_pulse": 0.5, "entropy": 0.45}
        m3 = {"presence_pulse": 0.8, "entropy": 0.5}

        # A → B (twice, good)
        phase4.record_activation("island_B", m1, m2, prev_island_id="island_A", turn_id="t1")
        phase4.record_activation("island_B", m1, m2, prev_island_id="island_A", turn_id="t2")

        # A → C (once, better presence)
        phase4.record_activation("island_C", m1, m3, prev_island_id="island_A", turn_id="t3")

        suggestions = phase4.suggest_next_islands("island_A", min_similarity=0.0)

        assert len(suggestions) >= 2
        # First should have higher score
        assert suggestions[0][1] >= suggestions[1][1]

    def test_filter_by_similarity(self, phase4):
        """Low similarity transitions should be filtered."""
        # Vectors with LOW similarity (~0.5)
        # m1 points mostly in x, m2 points mostly in y
        m1 = {"x": 1.0, "y": 0.2, "z": 0.0}
        m2 = {"x": 0.2, "y": 1.0, "z": 0.0}  # ~0.38 similarity

        phase4.record_activation("island_low", m1, m2, prev_island_id="island_A", turn_id="t1")

        # Also add a high-similarity transition
        m3 = {"x": 1.0, "y": 0.5, "z": 0.0}
        m4 = {"x": 1.0, "y": 0.5, "z": 0.0}  # Same = similarity 1.0
        phase4.record_activation("island_high", m3, m4, prev_island_id="island_A", turn_id="t2")

        # High threshold (0.8) should only include high-similarity
        suggestions = phase4.suggest_next_islands("island_A", min_similarity=0.8)
        island_ids = [s[0] for s in suggestions]
        assert "island_high" in island_ids
        assert "island_low" not in island_ids

        # Low threshold should include both
        suggestions = phase4.suggest_next_islands("island_A", min_similarity=0.3)
        assert len(suggestions) >= 2

    def test_exclude_overwhelming(self, phase4):
        """Overwhelming transitions should be excluded by default."""
        m1 = {"presence_pulse": 0.3, "entropy": 0.5}
        m2 = {"presence_pulse": 0.4, "entropy": 0.5}

        # Record transitions: 3 with overwhelm, 2 without (60% overwhelm rate)
        for i in range(3):
            phase4.record_activation(
                "island_risky", m1, m2,
                prev_island_id="island_A",
                turn_id=f"overwhelm_{i}",
                overwhelm=True,
            )
        for i in range(2):
            phase4.record_activation(
                "island_risky", m1, m2,
                prev_island_id="island_A",
                turn_id=f"ok_{i}",
                overwhelm=False,
            )

        # Should be excluded with threshold 0.5 (rate is 0.6)
        suggestions = phase4.suggest_next_islands(
            "island_A",
            min_similarity=0.0,
            exclude_overwhelming=True,
            overwhelm_threshold=0.5,
        )
        island_ids = [s[0] for s in suggestions]
        assert "island_risky" not in island_ids

        # Should be included when not excluding (still has positive score)
        suggestions = phase4.suggest_next_islands(
            "island_A",
            min_similarity=0.0,
            exclude_overwhelming=False,
        )
        island_ids = [s[0] for s in suggestions]
        assert "island_risky" in island_ids

    def test_max_candidates(self, phase4):
        """Should respect max_candidates limit."""
        m1 = {"presence_pulse": 0.3}
        m2 = {"presence_pulse": 0.5}

        # Create many transitions
        for i in range(10):
            phase4.record_activation(
                f"island_{i}", m1, m2,
                prev_island_id="island_A",
                turn_id=f"t{i}",
            )

        suggestions = phase4.suggest_next_islands("island_A", min_similarity=0.0, max_candidates=3)
        assert len(suggestions) <= 3

    def test_no_transitions(self, phase4):
        """Island with no transitions should return empty list."""
        phase4.record_activation("island_lonely", {"x": 1}, {"x": 2}, turn_id="t1")

        suggestions = phase4.suggest_next_islands("island_lonely")
        assert suggestions == []


# ============================================================================
# SCORE CALCULATIONS
# ============================================================================

class TestIslandTransitionStats:
    """Tests for score calculation in IslandTransitionStats."""

    def test_score_positive_presence(self):
        """Positive presence delta should increase score."""
        stats_positive = IslandTransitionStats(
            from_island="A", to_island="B", count=10,
            avg_similarity=0.8, avg_presence_delta=0.3,
            overwhelm_rate=0.0, boredom_rate=0.0, stuck_rate=0.0,
        )
        stats_negative = IslandTransitionStats(
            from_island="A", to_island="C", count=10,
            avg_similarity=0.8, avg_presence_delta=-0.3,
            overwhelm_rate=0.0, boredom_rate=0.0, stuck_rate=0.0,
        )

        assert stats_positive.score > stats_negative.score

    def test_score_overwhelm_penalty(self):
        """High overwhelm should decrease score."""
        stats_calm = IslandTransitionStats(
            from_island="A", to_island="B", count=10,
            avg_similarity=0.8, avg_presence_delta=0.1,
            overwhelm_rate=0.0, boredom_rate=0.0, stuck_rate=0.0,
        )
        stats_overwhelming = IslandTransitionStats(
            from_island="A", to_island="C", count=10,
            avg_similarity=0.8, avg_presence_delta=0.1,
            overwhelm_rate=0.9, boredom_rate=0.0, stuck_rate=0.0,
        )

        assert stats_calm.score > stats_overwhelming.score

    def test_score_boredom_penalty(self):
        """High boredom should slightly decrease score."""
        stats_engaging = IslandTransitionStats(
            from_island="A", to_island="B", count=10,
            avg_similarity=0.8, avg_presence_delta=0.1,
            overwhelm_rate=0.0, boredom_rate=0.0, stuck_rate=0.0,
        )
        stats_boring = IslandTransitionStats(
            from_island="A", to_island="C", count=10,
            avg_similarity=0.8, avg_presence_delta=0.1,
            overwhelm_rate=0.0, boredom_rate=0.9, stuck_rate=0.0,
        )

        assert stats_engaging.score > stats_boring.score


# ============================================================================
# INTEGRATION
# ============================================================================

class TestIntegration:
    """Integration tests simulating real usage."""

    def test_dialogue_simulation(self, phase4):
        """Simulate a short dialogue with island transitions."""
        # Turn 1: Start with theme_loneliness
        phase4.record_activation(
            "theme_loneliness",
            {"presence_pulse": 0.2, "entropy": 0.5, "arousal": 0.3},
            {"presence_pulse": 0.4, "entropy": 0.45, "arousal": 0.4},
            turn_id="conv1_t1",
        )

        # Turn 2: Flow to theme_connection
        phase4.record_activation(
            "theme_connection",
            {"presence_pulse": 0.4, "entropy": 0.45, "arousal": 0.4},
            {"presence_pulse": 0.6, "entropy": 0.4, "arousal": 0.5},
            prev_island_id="theme_loneliness",
            turn_id="conv1_t2",
        )

        # Turn 3: Flow to theme_hope
        phase4.record_activation(
            "theme_hope",
            {"presence_pulse": 0.6, "entropy": 0.4, "arousal": 0.5},
            {"presence_pulse": 0.8, "entropy": 0.35, "arousal": 0.6},
            prev_island_id="theme_connection",
            turn_id="conv1_t3",
        )

        # Verify transitions recorded
        assert phase4.get_transition_count() == 2

        # Verify suggestions
        suggestions = phase4.suggest_next_islands("theme_loneliness", min_similarity=0.0)
        assert len(suggestions) >= 1
        assert suggestions[0][0] == "theme_connection"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
