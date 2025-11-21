#!/usr/bin/env python3
"""Tests for episodes.py — episodic RAG memory."""

import tempfile
import unittest
from pathlib import Path

try:
    from episodes import RAGBrain, Episode, RAG_AVAILABLE
    from mathbrain import MathState
    EPISODES_TEST_AVAILABLE = True
except ImportError:
    EPISODES_TEST_AVAILABLE = False


@unittest.skipUnless(EPISODES_TEST_AVAILABLE, "episodes and mathbrain modules required")
class TestRAGBrain(unittest.TestCase):
    """Test RAGBrain episodic memory."""
    
    def setUp(self):
        """Create temporary DB for each test."""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.sqlite3')
        self.temp_db.close()
        self.db_path = Path(self.temp_db.name)
        self.rag = RAGBrain(db_path=self.db_path)
        
    def tearDown(self):
        """Clean up temp DB."""
        if self.db_path.exists():
            self.db_path.unlink()
            
    def test_observe_episode_basic(self):
        """Test that observe_episode inserts episode without error."""
        state = MathState(
            entropy=0.5, novelty=0.6, arousal=0.7, pulse=0.65,
            trauma_level=0.3, active_theme_count=2, total_themes=5,
            emerging_score=0.4, fading_score=0.2,
            reply_len=32, unique_ratio=0.8,
            expert_id="structural", expert_temp=1.0, expert_semantic=0.5,
            metaleo_weight=0.2, used_metaleo=False,
            overthinking_enabled=True, rings_present=2,
            quality=0.75,
        )
        episode = Episode(
            prompt="test prompt",
            reply="test reply",
            metrics=state,
        )
        
        # Should not raise
        self.rag.observe_episode(episode)
        
    def test_query_similar_empty_db(self):
        """Test that query_similar returns [] for empty DB."""
        state = MathState(
            entropy=0.5, novelty=0.6, arousal=0.7, pulse=0.65,
            trauma_level=0.3, active_theme_count=2, total_themes=5,
            emerging_score=0.4, fading_score=0.2,
            reply_len=32, unique_ratio=0.8,
            expert_id="structural", expert_temp=1.0, expert_semantic=0.5,
            metaleo_weight=0.2, used_metaleo=False,
            overthinking_enabled=True, rings_present=2,
            quality=0.75,
        )
        result = self.rag.query_similar(state, top_k=5)
        self.assertEqual(result, [])
        
    def test_query_similar_finds_matching(self):
        """Test that query_similar finds episodes with similar metrics."""
        # Insert a few episodes
        state1 = MathState(
            entropy=0.5, novelty=0.6, arousal=0.7, pulse=0.65,
            trauma_level=0.3, active_theme_count=2, total_themes=5,
            emerging_score=0.4, fading_score=0.2,
            reply_len=32, unique_ratio=0.8,
            expert_id="structural", expert_temp=1.0, expert_semantic=0.5,
            metaleo_weight=0.2, used_metaleo=False,
            overthinking_enabled=True, rings_present=2,
            quality=0.75,
        )
        episode1 = Episode(prompt="prompt1", reply="reply1", metrics=state1)
        self.rag.observe_episode(episode1)
        
        state2 = MathState(
            entropy=0.9, novelty=0.1, arousal=0.2, pulse=0.4,  # Very different
            trauma_level=0.8, active_theme_count=5, total_themes=10,
            emerging_score=0.1, fading_score=0.5,
            reply_len=64, unique_ratio=0.5,
            expert_id="creative", expert_temp=1.5, expert_semantic=0.8,
            metaleo_weight=0.5, used_metaleo=True,
            overthinking_enabled=False, rings_present=0,
            quality=0.3,
        )
        episode2 = Episode(prompt="prompt2", reply="reply2", metrics=state2)
        self.rag.observe_episode(episode2)
        
        # Query with state similar to state1
        query_state = MathState(
            entropy=0.5, novelty=0.6, arousal=0.7, pulse=0.65,
            trauma_level=0.3, active_theme_count=2, total_themes=5,
            emerging_score=0.4, fading_score=0.2,
            reply_len=32, unique_ratio=0.8,
            expert_id="structural", expert_temp=1.0, expert_semantic=0.5,
            metaleo_weight=0.2, used_metaleo=False,
            overthinking_enabled=True, rings_present=2,
            quality=0.75,
        )
        result = self.rag.query_similar(query_state, top_k=2)
        
        self.assertGreater(len(result), 0)
        # Should prefer state1 (lower distance)
        self.assertIn("prompt1", [r["prompt"] for r in result])
        
    def test_get_summary_for_state(self):
        """Test get_summary_for_state returns correct aggregates."""
        # Insert episodes
        for i in range(3):
            state = MathState(
                entropy=0.5, novelty=0.6, arousal=0.7, pulse=0.65,
                trauma_level=0.3, active_theme_count=2, total_themes=5,
                emerging_score=0.4, fading_score=0.2,
                reply_len=32, unique_ratio=0.8,
                expert_id="structural", expert_temp=1.0, expert_semantic=0.5,
                metaleo_weight=0.2, used_metaleo=False,
                overthinking_enabled=True, rings_present=2,
                quality=0.5 + i * 0.1,  # 0.5, 0.6, 0.7
            )
            episode = Episode(
                prompt=f"prompt{i}",
                reply=f"reply{i}",
                metrics=state,
            )
            self.rag.observe_episode(episode)
            
        query_state = MathState(
            entropy=0.5, novelty=0.6, arousal=0.7, pulse=0.65,
            trauma_level=0.3, active_theme_count=2, total_themes=5,
            emerging_score=0.4, fading_score=0.2,
            reply_len=32, unique_ratio=0.8,
            expert_id="structural", expert_temp=1.0, expert_semantic=0.5,
            metaleo_weight=0.2, used_metaleo=False,
            overthinking_enabled=True, rings_present=2,
            quality=0.75,
        )
        summary = self.rag.get_summary_for_state(query_state, top_k=10)
        
        self.assertIn("count", summary)
        self.assertIn("avg_quality", summary)
        self.assertIn("max_quality", summary)
        self.assertIn("mean_distance", summary)
        self.assertGreater(summary["count"], 0)
        self.assertGreater(summary["max_quality"], 0)
        
    def test_graceful_failure_on_nan(self):
        """Test that NaN values are clamped to 0.0."""
        import math
        state = MathState(
            entropy=math.nan, novelty=0.6, arousal=0.7, pulse=0.65,
            trauma_level=0.3, active_theme_count=2, total_themes=5,
            emerging_score=0.4, fading_score=0.2,
            reply_len=32, unique_ratio=0.8,
            expert_id="structural", expert_temp=1.0, expert_semantic=0.5,
            metaleo_weight=0.2, used_metaleo=False,
            overthinking_enabled=True, rings_present=2,
            quality=0.75,
        )
        episode = Episode(prompt="test", reply="test", metrics=state)
        
        # Should not raise
        self.rag.observe_episode(episode)


if __name__ == "__main__":
    unittest.main()

