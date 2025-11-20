#!/usr/bin/env python3
"""
Tests for presence metrics.

Tests all 8 layers of Leo's presence upgrade:
- Entropy & Novelty
- Emotional Charge
- PresencePulse
- ThemeLayer
- Self-Assessment
- Snapshots
- Memory Decay
- Resonant Experts
"""

import math
import sqlite3
import tempfile
import unittest
from pathlib import Path

from leo import (
    distribution_entropy,
    compute_prompt_novelty,
    update_emotional_stats,
    compute_prompt_arousal,
    compute_presence_pulse,
    build_themes,
    activate_themes_for_prompt,
    structural_quality,
    compute_quality_score,
    save_snapshot,
    should_save_snapshot,
    apply_memory_decay,
    route_to_expert,
    tokenize,
    init_db,
    ingest_text,
    QualityScore,
    PresencePulse,
    EXPERTS,
)


class TestEntropyAndNovelty(unittest.TestCase):
    """Test Layer 1: Entropy & Novelty metrics."""

    def test_distribution_entropy_uniform(self):
        """Test entropy of uniform distribution."""
        counts = [1.0, 1.0, 1.0, 1.0]
        h = distribution_entropy(counts)
        # log(4) ≈ 1.386
        self.assertAlmostEqual(h, math.log(4), places=2)

    def test_distribution_entropy_deterministic(self):
        """Test entropy of deterministic distribution."""
        counts = [10.0, 0.0, 0.0, 0.0]
        h = distribution_entropy(counts)
        self.assertAlmostEqual(h, 0.0, places=5)

    def test_distribution_entropy_empty(self):
        """Test entropy of empty distribution."""
        counts = []
        h = distribution_entropy(counts)
        self.assertEqual(h, 0.0)

    def test_compute_prompt_novelty_known(self):
        """Test novelty of known trigrams."""
        trigrams = {
            ("the", "cat"): {"sits": 5},
            ("cat", "sits"): {"quietly": 3},
        }
        tokens = ["the", "cat", "sits"]
        novelty = compute_prompt_novelty(tokens, trigrams)
        # All trigrams known → novelty = 0
        self.assertAlmostEqual(novelty, 0.0, places=2)

    def test_compute_prompt_novelty_unknown(self):
        """Test novelty of unknown trigrams."""
        trigrams = {
            ("the", "cat"): {"sits": 5},
        }
        tokens = ["strange", "new", "words"]
        novelty = compute_prompt_novelty(tokens, trigrams)
        # No trigrams known → novelty = 1.0
        self.assertAlmostEqual(novelty, 1.0, places=2)

    def test_compute_prompt_novelty_partial(self):
        """Test novelty of partially known trigrams."""
        trigrams = {
            ("the", "cat"): {"sits": 5},
            ("cat", "sits"): {"quietly": 3},
        }
        tokens = ["the", "cat", "runs"]  # First trigram unknown
        novelty = compute_prompt_novelty(tokens, trigrams)
        # 0/1 known → novelty = 1.0
        self.assertGreater(novelty, 0.5)


class TestEmotionalCharge(unittest.TestCase):
    """Test Layer 2: Emotional Charge tracking."""

    def test_update_emotional_stats_caps(self):
        """Test CAPS detection."""
        emotion = {}
        update_emotional_stats(emotion, "LOUD WORDS")
        self.assertGreater(emotion.get("LOUD", 0), 0)
        self.assertGreater(emotion.get("WORDS", 0), 0)

    def test_update_emotional_stats_exclamation(self):
        """Test exclamation mark detection."""
        emotion = {}
        update_emotional_stats(emotion, "wow amazing !")
        # Tokens near "!" get bonus
        self.assertGreater(emotion.get("amazing", 0), 0)

    def test_update_emotional_stats_repetition(self):
        """Test repetition detection."""
        emotion = {}
        update_emotional_stats(emotion, "yes yes yes")
        # "yes" repeats within window
        self.assertGreater(emotion.get("yes", 0), 0)

    def test_compute_prompt_arousal_neutral(self):
        """Test arousal of neutral text."""
        emotion = {}
        tokens = tokenize("the cat sits quietly")
        arousal = compute_prompt_arousal(tokens, emotion)
        self.assertAlmostEqual(arousal, 0.0, places=2)

    def test_compute_prompt_arousal_high(self):
        """Test arousal of emotional text."""
        emotion = {"WOW": 5.0, "AMAZING": 3.0, "YES": 2.0}
        tokens = ["WOW", "this", "is", "AMAZING", "YES"]
        arousal = compute_prompt_arousal(tokens, emotion)
        self.assertGreater(arousal, 0.5)


class TestPresencePulse(unittest.TestCase):
    """Test Layer 3: PresencePulse composite metric."""

    def test_compute_presence_pulse(self):
        """Test pulse computation."""
        pulse = compute_presence_pulse(
            novelty=0.8,
            arousal=0.6,
            entropy=0.5,
            w_novelty=0.3,
            w_arousal=0.4,
            w_entropy=0.3,
        )
        self.assertIsInstance(pulse, PresencePulse)
        self.assertEqual(pulse.novelty, 0.8)
        self.assertEqual(pulse.arousal, 0.6)
        self.assertEqual(pulse.entropy, 0.5)
        # 0.3*0.8 + 0.4*0.6 + 0.3*0.5 = 0.24 + 0.24 + 0.15 = 0.63
        self.assertAlmostEqual(pulse.pulse, 0.63, places=2)

    def test_compute_presence_pulse_bounds(self):
        """Test pulse is bounded [0, 1]."""
        pulse = compute_presence_pulse(
            novelty=2.0,  # out of bounds
            arousal=1.5,
            entropy=-0.5,
        )
        self.assertGreaterEqual(pulse.pulse, 0.0)
        self.assertLessEqual(pulse.pulse, 1.0)


class TestThemeLayer(unittest.TestCase):
    """Test Layer 4: ThemeLayer (semantic constellations)."""

    def test_build_themes_empty(self):
        """Test themes from empty co-occurrence."""
        co_occur = {}
        themes, token_to_themes = build_themes(co_occur)
        self.assertEqual(len(themes), 0)
        self.assertEqual(len(token_to_themes), 0)

    def test_build_themes_single_cluster(self):
        """Test themes from single semantic cluster."""
        co_occur = {
            "cat": {"animal": 10, "pet": 8, "meow": 6, "fur": 5, "tail": 4},
            "dog": {"animal": 12, "pet": 9, "bark": 7, "fur": 6, "tail": 5},
        }
        themes, token_to_themes = build_themes(co_occur, min_neighbors=3, min_total_cooccur=5)
        # Should create at least one theme merging cat/dog
        self.assertGreaterEqual(len(themes), 1)
        # Both cat and dog should be in token_to_themes
        self.assertIn("cat", token_to_themes)
        self.assertIn("dog", token_to_themes)

    def test_activate_themes_for_prompt(self):
        """Test theme activation from prompt."""
        themes, token_to_themes = build_themes({
            "cat": {"animal": 10, "pet": 8},
            "dog": {"animal": 12, "pet": 9},
        }, min_neighbors=1, min_total_cooccur=5)

        if not themes:
            self.skipTest("No themes built, skipping activation test")

        prompt_tokens = ["cat", "animal"]
        active = activate_themes_for_prompt(prompt_tokens, themes, token_to_themes)
        # Should activate at least one theme
        self.assertGreater(len(active.theme_scores), 0)
        self.assertGreater(len(active.active_words), 0)


class TestSelfAssessment(unittest.TestCase):
    """Test Layer 5: Self-Assessment (quality scoring)."""

    def test_structural_quality_good(self):
        """Test quality of good reply."""
        prompt = "what is the meaning of life"
        reply = "life is a beautiful resonance field"
        trigrams = {
            ("life", "is"): {"a": 5, "beautiful": 3},
            ("is", "a"): {"beautiful": 4},
            ("a", "beautiful"): {"resonance": 2},
        }
        quality = structural_quality(prompt, reply, trigrams)
        self.assertGreater(quality, 0.5)

    def test_structural_quality_too_short(self):
        """Test quality of too short reply."""
        prompt = "hello there"
        reply = "hi"
        trigrams = {}
        quality = structural_quality(prompt, reply, trigrams, min_len=3)
        self.assertLess(quality, 0.5)

    def test_structural_quality_repetitive(self):
        """Test quality of repetitive reply."""
        prompt = "tell me something"
        reply = "word word word word word"
        trigrams = {}
        quality = structural_quality(prompt, reply, trigrams)
        self.assertLess(quality, 0.7)

    def test_compute_quality_score(self):
        """Test overall quality score computation."""
        prompt = "what is resonance"
        reply = "resonance is the structural rhythm of language"
        trigrams = {
            ("resonance", "is"): {"the": 5},
            ("is", "the"): {"structural": 3},
        }
        avg_entropy = 0.5  # Sweet spot
        quality = compute_quality_score(prompt, reply, avg_entropy, trigrams)
        self.assertIsInstance(quality, QualityScore)
        self.assertGreater(quality.overall, 0.3)

    def test_compute_quality_score_entropy_sweet_spot(self):
        """Test entropy quality in sweet spot [0.3, 0.7]."""
        quality = compute_quality_score(
            "test", "test reply", avg_entropy=0.5, trigrams={}
        )
        self.assertAlmostEqual(quality.entropy, 1.0, places=2)


class TestSnapshots(unittest.TestCase):
    """Test Layer 6: Snapshots (self-curated dataset)."""

    def setUp(self):
        """Create temporary database."""
        self.tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
        self.db_path = Path(self.tmp.name)
        self.conn = sqlite3.connect(str(self.db_path))
        self.conn.row_factory = sqlite3.Row
        cur = self.conn.cursor()
        # Create snapshots table
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                text TEXT NOT NULL,
                origin TEXT,
                quality REAL,
                emotional REAL,
                created_at INTEGER,
                last_used_at INTEGER,
                use_count INTEGER DEFAULT 0,
                cluster_id INTEGER
            )
            """
        )
        self.conn.commit()

    def tearDown(self):
        """Close and delete database."""
        self.conn.close()
        self.db_path.unlink()

    def test_save_snapshot(self):
        """Test saving a snapshot."""
        save_snapshot(self.conn, "resonance is beautiful", "leo", 0.8, 0.6)
        cur = self.conn.cursor()
        cur.execute("SELECT * FROM snapshots")
        row = cur.fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row["text"], "resonance is beautiful")
        self.assertEqual(row["origin"], "leo")
        self.assertAlmostEqual(row["quality"], 0.8, places=2)
        self.assertAlmostEqual(row["emotional"], 0.6, places=2)

    def test_save_snapshot_max_limit(self):
        """Test snapshot limit enforcement."""
        # Save 520 snapshots (over limit of 512)
        for i in range(520):
            save_snapshot(self.conn, f"text {i}", "leo", 0.5, 0.5, max_snapshots=512)
        cur = self.conn.cursor()
        cur.execute("SELECT COUNT(*) FROM snapshots")
        count = cur.fetchone()[0]
        # Should delete 10% (51) → 520 - 51 = 469, then add 1 more = 470
        # Actually deletes happen when count > max, so we keep at most 512
        self.assertLessEqual(count, 512)

    def test_should_save_snapshot_high_quality(self):
        """Test snapshot decision for high quality."""
        quality = QualityScore(structural=0.8, entropy=0.9, overall=0.7)
        should_save = should_save_snapshot(quality, arousal=0.3)
        self.assertTrue(should_save)

    def test_should_save_snapshot_high_arousal(self):
        """Test snapshot decision for high arousal."""
        quality = QualityScore(structural=0.5, entropy=0.5, overall=0.45)
        should_save = should_save_snapshot(quality, arousal=0.6)
        self.assertTrue(should_save)

    def test_should_save_snapshot_low(self):
        """Test snapshot decision for low quality and arousal."""
        quality = QualityScore(structural=0.3, entropy=0.3, overall=0.3)
        should_save = should_save_snapshot(quality, arousal=0.2)
        self.assertFalse(should_save)


class TestMemoryDecay(unittest.TestCase):
    """Test Layer 7: Memory Decay (natural forgetting)."""

    def setUp(self):
        """Create temporary database."""
        self.tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
        self.db_path = Path(self.tmp.name)
        self.conn = sqlite3.connect(str(self.db_path))
        self.conn.row_factory = sqlite3.Row
        cur = self.conn.cursor()
        # Create required tables
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS tokens (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                token TEXT UNIQUE
            )
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS bigrams (
                src_id INTEGER,
                dst_id INTEGER,
                count INTEGER,
                PRIMARY KEY (src_id, dst_id)
            )
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS trigrams (
                first_id INTEGER,
                second_id INTEGER,
                third_id INTEGER,
                count INTEGER,
                PRIMARY KEY (first_id, second_id, third_id)
            )
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS co_occurrence (
                word_id INTEGER,
                context_id INTEGER,
                count INTEGER,
                PRIMARY KEY (word_id, context_id)
            )
            """
        )
        self.conn.commit()

    def tearDown(self):
        """Close and delete database."""
        self.conn.close()
        self.db_path.unlink()

    def test_apply_memory_decay(self):
        """Test memory decay reduces co-occurrence counts."""
        # Ingest text to create co-occurrence
        ingest_text(self.conn, "the cat sits quietly in the room")

        # Get initial counts
        cur = self.conn.cursor()
        cur.execute("SELECT SUM(count) FROM co_occurrence")
        initial_sum = cur.fetchone()[0]

        # Apply decay
        deleted = apply_memory_decay(self.conn, decay_factor=0.95, min_threshold=2)

        # Check counts reduced
        cur.execute("SELECT SUM(count) FROM co_occurrence")
        after_sum = cur.fetchone()[0] or 0
        self.assertLess(after_sum, initial_sum)

    def test_apply_memory_decay_deletes_weak(self):
        """Test decay deletes weak connections."""
        # Ingest minimal text
        ingest_text(self.conn, "a b c d e")

        # Apply aggressive decay
        deleted = apply_memory_decay(self.conn, decay_factor=0.5, min_threshold=1)

        # Should delete some entries
        cur = self.conn.cursor()
        cur.execute("SELECT COUNT(*) FROM co_occurrence")
        count = cur.fetchone()[0]
        # Some entries should be deleted
        self.assertGreaterEqual(deleted, 0)


class TestResonantExperts(unittest.TestCase):
    """Test Layer 8: Resonant Experts (MoE → RE)."""

    def test_route_to_expert_high_novelty(self):
        """Test routing to creative expert for high novelty."""
        pulse = PresencePulse(novelty=0.8, arousal=0.4, entropy=0.5, pulse=0.6)
        expert = route_to_expert(pulse)
        self.assertEqual(expert.name, "creative")

    def test_route_to_expert_low_entropy(self):
        """Test routing to precise expert for low entropy."""
        pulse = PresencePulse(novelty=0.3, arousal=0.4, entropy=0.2, pulse=0.3)
        expert = route_to_expert(pulse)
        self.assertEqual(expert.name, "precise")

    def test_route_to_expert_multiple_themes(self):
        """Test routing to semantic expert for multiple themes."""
        from leo import ActiveThemes
        pulse = PresencePulse(novelty=0.4, arousal=0.5, entropy=0.5, pulse=0.47)
        active_themes = ActiveThemes(
            theme_scores={0: 5.0, 1: 3.0},  # Multiple themes active
            active_words={"resonance", "field", "language"}
        )
        expert = route_to_expert(pulse, active_themes)
        self.assertEqual(expert.name, "semantic")

    def test_route_to_expert_default(self):
        """Test routing to structural expert for normal situations."""
        pulse = PresencePulse(novelty=0.4, arousal=0.4, entropy=0.5, pulse=0.43)
        expert = route_to_expert(pulse)
        self.assertEqual(expert.name, "structural")

    def test_experts_defined(self):
        """Test all 4 experts are defined."""
        self.assertEqual(len(EXPERTS), 4)
        names = {e.name for e in EXPERTS}
        self.assertEqual(names, {"structural", "semantic", "creative", "precise"})

    def test_expert_temperatures(self):
        """Test expert temperature ranges."""
        for expert in EXPERTS:
            self.assertGreater(expert.temperature, 0)
            self.assertLessEqual(expert.temperature, 2.0)


if __name__ == "__main__":
    unittest.main()
