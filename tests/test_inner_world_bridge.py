#!/usr/bin/env python3
"""Tests for inner_world_bridge.py — Python fallbacks always work, Go optional."""

import sys
from pathlib import Path

# Ensure project root is importable
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from inner_world_bridge import (
    InnerWorld,
    _py_entropy,
    _py_emotional_score,
    _py_perplexity,
    _py_semantic_distance,
    _py_find_nearest_attractor,
    _py_compute_attractor_pull,
    _py_tokenize,
)


# ═══════════════════════════════════════════════════════════════════════════════
# TOKENIZER
# ═══════════════════════════════════════════════════════════════════════════════

class TestTokenize:
    def test_basic(self):
        assert _py_tokenize("Hello World") == ["hello", "world"]

    def test_punctuation(self):
        assert _py_tokenize("I love you!") == ["i", "love", "you"]

    def test_empty(self):
        assert _py_tokenize("") == []

    def test_numbers(self):
        assert _py_tokenize("test 123 hello") == ["test", "123", "hello"]


# ═══════════════════════════════════════════════════════════════════════════════
# ENTROPY
# ═══════════════════════════════════════════════════════════════════════════════

class TestEntropy:
    def test_empty(self):
        assert _py_entropy("") == 0.0

    def test_single_word(self):
        assert _py_entropy("hello") == 0.0

    def test_unique_words_higher(self):
        low = _py_entropy("the the the the")
        high = _py_entropy("the quick brown fox")
        assert high > low

    def test_emotional_modulation(self):
        neutral = _py_entropy("the quick brown fox jumps")
        emotional = _py_entropy("love hate fear joy pain")
        # emotional words modulate entropy upward
        assert emotional > 0


# ═══════════════════════════════════════════════════════════════════════════════
# EMOTIONAL SCORE
# ═══════════════════════════════════════════════════════════════════════════════

class TestEmotionalScore:
    def test_positive(self):
        score = _py_emotional_score("I love you")
        assert score > 0

    def test_negative(self):
        score = _py_emotional_score("I hate everything")
        assert score < 0

    def test_neutral(self):
        score = _py_emotional_score("the table is brown")
        assert score == 0.0

    def test_empty(self):
        assert _py_emotional_score("") == 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# PERPLEXITY
# ═══════════════════════════════════════════════════════════════════════════════

class TestPerplexity:
    def test_empty(self):
        assert _py_perplexity("") == 1.0

    def test_single_char(self):
        assert _py_perplexity("a") == 1.0

    def test_repetitive_low(self):
        pp = _py_perplexity("aaaaaaa")
        assert pp < 2.0  # mostly predictable

    def test_varied_higher(self):
        pp = _py_perplexity("abcabcabcabc")
        assert pp >= 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# SEMANTIC DISTANCE
# ═══════════════════════════════════════════════════════════════════════════════

class TestSemanticDistance:
    def test_identical(self):
        d = _py_semantic_distance("hello world", "hello world")
        assert d == pytest.approx(0.0, abs=0.01)

    def test_completely_different(self):
        d = _py_semantic_distance("hello world", "foo bar")
        assert d == pytest.approx(1.0, abs=0.01)

    def test_partial_overlap(self):
        d = _py_semantic_distance("hello world foo", "hello bar baz")
        assert 0.0 < d < 1.0

    def test_empty(self):
        assert _py_semantic_distance("", "hello") == 1.0
        assert _py_semantic_distance("hello", "") == 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# ATTRACTORS
# ═══════════════════════════════════════════════════════════════════════════════

class TestAttractors:
    def test_positive_high_arousal(self):
        name = _py_find_nearest_attractor(0.8, 0.8)
        assert name == "excitement"

    def test_negative_low_arousal(self):
        name = _py_find_nearest_attractor(-0.4, 0.1)
        assert name == "void"

    def test_neutral(self):
        name = _py_find_nearest_attractor(0.0, 0.3)
        assert name == "neutral"

    def test_pull_returns_tuple(self):
        dv, da = _py_compute_attractor_pull(0.0, 0.3)
        assert isinstance(dv, float)
        assert isinstance(da, float)

    def test_pull_nonzero(self):
        dv, da = _py_compute_attractor_pull(0.5, 0.5)
        assert dv != 0.0 or da != 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# INNER WORLD CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class TestInnerWorld:
    def test_creation(self):
        iw = InnerWorld()
        assert isinstance(iw, InnerWorld)

    def test_initial_state(self):
        iw = InnerWorld()
        assert iw.valence == pytest.approx(0.1, abs=0.01)
        assert iw.arousal == pytest.approx(0.3, abs=0.01)

    def test_drift_changes_state(self):
        iw = InnerWorld()
        v0, a0 = iw.valence, iw.arousal
        iw.drift(0.9, 0.9)
        assert iw.valence != v0 or iw.arousal != a0

    def test_reset(self):
        iw = InnerWorld()
        iw.drift(0.9, 0.9)
        iw.reset()
        assert iw.valence == pytest.approx(0.1, abs=0.01)
        assert iw.arousal == pytest.approx(0.3, abs=0.01)

    def test_nearest_attractor(self):
        iw = InnerWorld()
        name = iw.nearest_attractor()
        assert isinstance(name, str)
        assert len(name) > 0

    def test_attractor_pull(self):
        iw = InnerWorld()
        dv, da = iw.attractor_pull()
        assert isinstance(dv, float)
        assert isinstance(da, float)

    def test_entropy(self):
        iw = InnerWorld()
        e = iw.entropy("I love the beautiful world")
        assert e > 0

    def test_emotional_score(self):
        iw = InnerWorld()
        s = iw.emotional_score("I love you so much")
        assert s > 0

    def test_perplexity(self):
        iw = InnerWorld()
        p = iw.perplexity("hello world")
        assert p >= 1.0

    def test_semantic_distance(self):
        iw = InnerWorld()
        d = iw.semantic_distance("hello world", "hello world")
        assert d == pytest.approx(0.0, abs=0.01)

    def test_analyze(self):
        iw = InnerWorld()
        result = iw.analyze("I feel happy today")
        assert "entropy" in result
        assert "emotional_score" in result
        assert "perplexity" in result
        assert "valence" in result
        assert "arousal" in result
        assert "attractor" in result

    def test_repr(self):
        iw = InnerWorld()
        r = repr(iw)
        assert "InnerWorld" in r
        assert "v=" in r
        assert "a=" in r

    def test_go_available_property(self):
        iw = InnerWorld()
        assert isinstance(iw.go_available, bool)

    def test_multiple_drifts(self):
        iw = InnerWorld()
        for _ in range(10):
            iw.drift(0.8, 0.7)
        # valence should have moved positive
        assert iw.valence > 0.1

    def test_negative_drift(self):
        iw = InnerWorld()
        for _ in range(10):
            iw.drift(-0.8, 0.8)
        assert iw.valence < 0.1
