#!/usr/bin/env python3
"""
Tests for MultiLeo Phase 3: Islands-aware regulation.

Phase 3 adds associative awareness - MultiLeo learns which semantic islands
(themes) historically helped escape bad states and biases regulation accordingly.

Tests cover:
- Profile key generation
- Profile aggregation (running averages)
- Querying helpful profiles
- Recording regulation outcomes
- Integration with LeoField
"""

import unittest
import tempfile
import os
from pathlib import Path

try:
    from mathbrain import (
        MathBrain,
        MathState,
        MultiLeoContext,
        _bucket,
        _generate_profile_key,
        _init_multileo_phase3_tables,
        _query_helpful_profiles,
        _update_profile_aggregate,
        _record_regulation_event,
    )
    import leo
    PHASE3_AVAILABLE = True
except ImportError:
    PHASE3_AVAILABLE = False


@unittest.skipIf(not PHASE3_AVAILABLE, "Phase 3 not available")
class TestPhase3Helpers(unittest.TestCase):
    """Test Phase 3 helper functions."""

    def test_bucket_low(self):
        """Test that values < 0.33 are bucketed as 'L'."""
        self.assertEqual(_bucket(0.0), "L")
        self.assertEqual(_bucket(0.2), "L")
        self.assertEqual(_bucket(0.32), "L")

    def test_bucket_medium(self):
        """Test that values 0.33-0.66 are bucketed as 'M'."""
        self.assertEqual(_bucket(0.33), "M")
        self.assertEqual(_bucket(0.5), "M")
        self.assertEqual(_bucket(0.65), "M")

    def test_bucket_high(self):
        """Test that values >= 0.66 are bucketed as 'H'."""
        self.assertEqual(_bucket(0.66), "H")
        self.assertEqual(_bucket(0.8), "H")
        self.assertEqual(_bucket(1.0), "H")

    def test_profile_key_generation_basic(self):
        """Test basic profile key generation."""
        key = _generate_profile_key(
            theme_ids=[1, 2, 3],
            boredom=0.5,
            overwhelm=0.3,
            stuck=0.7
        )
        # Format: "themes:T1,T2,T3|bored:M|over:L|stuck:H"
        self.assertIn("themes:1,2,3", key)
        self.assertIn("bored:M", key)
        self.assertIn("over:L", key)
        self.assertIn("stuck:H", key)

    def test_profile_key_generation_no_themes(self):
        """Test profile key with no themes."""
        key = _generate_profile_key(
            theme_ids=[],
            boredom=0.5,
            overwhelm=0.5,
            stuck=0.5
        )
        self.assertIn("themes:none", key)

    def test_profile_key_generation_sorted_themes(self):
        """Test that themes are sorted in profile key."""
        key1 = _generate_profile_key([3, 1, 2], 0.5, 0.5, 0.5)
        key2 = _generate_profile_key([1, 2, 3], 0.5, 0.5, 0.5)
        # Should be identical after sorting
        self.assertEqual(key1, key2)

    def test_profile_key_generation_max_themes(self):
        """Test that only first N themes are used."""
        key = _generate_profile_key(
            theme_ids=[1, 2, 3, 4, 5, 6],
            boredom=0.5,
            overwhelm=0.5,
            stuck=0.5,
            max_themes=3
        )
        # Should only include first 3 after sorting
        self.assertIn("themes:1,2,3", key)
        self.assertNotIn("4", key)


@unittest.skipIf(not PHASE3_AVAILABLE, "Phase 3 not available")
class TestPhase3Database(unittest.TestCase):
    """Test Phase 3 database operations."""

    def setUp(self):
        """Create temporary database."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_phase3.sqlite3"

        # Monkey-patch DB_PATH (same pattern as other tests)
        self.original_db_path = leo.DB_PATH
        leo.DB_PATH = self.db_path

        self.conn = leo.init_db()

    def tearDown(self):
        """Clean up temporary database."""
        if self.conn:
            self.conn.close()

        # Restore original DB_PATH
        leo.DB_PATH = self.original_db_path

        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_init_tables(self):
        """Test that Phase 3 tables are created."""
        _init_multileo_phase3_tables(self.conn)

        cur = self.conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cur.fetchall()]

        self.assertIn("multileo_events", tables)
        self.assertIn("multileo_profiles", tables)

    def test_init_tables_graceful_with_none(self):
        """Test that init_tables handles None connection gracefully."""
        # Should not raise
        _init_multileo_phase3_tables(None)

    def test_update_profile_aggregate_new(self):
        """Test creating new profile aggregate."""
        _init_multileo_phase3_tables(self.conn)

        profile_key = "themes:1,2,3|bored:M|over:L|stuck:H"
        _update_profile_aggregate(
            self.conn, profile_key,
            delta_boredom=-0.2,
            delta_overwhelm=0.1,
            delta_stuck=-0.15,
            delta_quality=0.25
        )

        # Verify record exists
        row = self.conn.execute(
            "SELECT samples, avg_delta_boredom, avg_delta_quality FROM multileo_profiles WHERE profile_key = ?",
            (profile_key,)
        ).fetchone()

        self.assertIsNotNone(row)
        samples, avg_b, avg_q = row
        self.assertEqual(samples, 1)
        self.assertAlmostEqual(avg_b, -0.2, places=4)
        self.assertAlmostEqual(avg_q, 0.25, places=4)

    def test_update_profile_aggregate_running_average(self):
        """Test that running average is computed correctly."""
        _init_multileo_phase3_tables(self.conn)

        profile_key = "themes:1,2|bored:H|over:L|stuck:M"

        # First update
        _update_profile_aggregate(
            self.conn, profile_key,
            delta_boredom=-0.3,
            delta_overwhelm=0.0,
            delta_stuck=-0.2,
            delta_quality=0.4
        )

        # Second update
        _update_profile_aggregate(
            self.conn, profile_key,
            delta_boredom=-0.1,
            delta_overwhelm=0.0,
            delta_stuck=-0.1,
            delta_quality=0.2
        )

        # Check running average: (-0.3 + -0.1) / 2 = -0.2
        row = self.conn.execute(
            "SELECT samples, avg_delta_boredom, avg_delta_quality FROM multileo_profiles WHERE profile_key = ?",
            (profile_key,)
        ).fetchone()

        samples, avg_b, avg_q = row
        self.assertEqual(samples, 2)
        self.assertAlmostEqual(avg_b, -0.2, places=4)
        self.assertAlmostEqual(avg_q, 0.3, places=4)  # (0.4 + 0.2) / 2

    def test_query_helpful_profiles_empty(self):
        """Test querying when no profiles exist."""
        _init_multileo_phase3_tables(self.conn)

        hints = _query_helpful_profiles(
            self.conn,
            theme_ids=[1, 2, 3],
            boredom=0.8,
            overwhelm=0.3,
            stuck=0.5,
        )

        self.assertEqual(hints["preferred_themes"], [])
        self.assertEqual(hints["preferred_snapshots"], [])
        self.assertEqual(hints["preferred_episodes"], [])

    def test_query_helpful_profiles_insufficient_samples(self):
        """Test that profiles with too few samples are ignored."""
        _init_multileo_phase3_tables(self.conn)

        profile_key = _generate_profile_key([1, 2, 3], 0.8, 0.3, 0.5)

        # Add 2 samples (below min_samples=3)
        _update_profile_aggregate(self.conn, profile_key, -0.3, 0.0, -0.2, 0.3)
        _update_profile_aggregate(self.conn, profile_key, -0.2, 0.0, -0.1, 0.2)

        hints = _query_helpful_profiles(
            self.conn,
            theme_ids=[1, 2, 3],
            boredom=0.8,
            overwhelm=0.3,
            stuck=0.5,
            min_samples=3
        )

        # Should be empty because samples < 3
        self.assertEqual(hints["preferred_themes"], [])

    def test_query_helpful_profiles_with_data(self):
        """Test querying helpful profiles with sufficient data."""
        _init_multileo_phase3_tables(self.conn)

        profile_key = _generate_profile_key([5, 6, 7], 0.7, 0.3, 0.5)

        # Add 3 samples showing boredom reduction
        for _ in range(3):
            _update_profile_aggregate(
                self.conn, profile_key,
                delta_boredom=-0.2,  # Reduced boredom
                delta_overwhelm=0.0,
                delta_stuck=0.0,
                delta_quality=0.15   # Improved quality
            )

        hints = _query_helpful_profiles(
            self.conn,
            theme_ids=[5, 6, 7],
            boredom=0.7,  # High boredom
            overwhelm=0.3,
            stuck=0.5,
            min_samples=3
        )

        # Should return themes that helped
        self.assertIn(5, hints["preferred_themes"])
        self.assertIn(6, hints["preferred_themes"])
        self.assertIn(7, hints["preferred_themes"])

    def test_query_helpful_profiles_none_connection(self):
        """Test that query handles None connection gracefully."""
        hints = _query_helpful_profiles(
            None,
            theme_ids=[1, 2],
            boredom=0.8,
            overwhelm=0.3,
            stuck=0.5,
        )

        self.assertEqual(hints["preferred_themes"], [])

    def test_record_regulation_event(self):
        """Test recording regulation event."""
        _init_multileo_phase3_tables(self.conn)

        context = MultiLeoContext(
            boredom_before=0.8,
            overwhelm_before=0.3,
            stuck_before=0.6,
            quality_before=0.4,
            active_theme_ids=[1, 2, 3],
            temp_before=1.0,
            expert_before="structural"
        )

        _record_regulation_event(
            self.conn,
            context_before=context,
            boredom_after=0.5,
            overwhelm_after=0.3,
            stuck_after=0.4,
            quality_after=0.6,
            temp_after=1.2,
            expert_after="creative",
            turn_id="test_turn_123"
        )

        # Verify event was recorded
        events = self.conn.execute("SELECT * FROM multileo_events").fetchall()
        self.assertEqual(len(events), 1)

        # Verify profile was updated
        profiles = self.conn.execute("SELECT * FROM multileo_profiles").fetchall()
        self.assertEqual(len(profiles), 1)


@unittest.skipIf(not PHASE3_AVAILABLE, "Phase 3 not available")
class TestPhase3Integration(unittest.TestCase):
    """Test Phase 3 integration with MathBrain."""

    def setUp(self):
        """Create temporary MathBrain with Phase 3."""
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_leo.sqlite3"

        # Monkey-patch DB_PATH
        self.original_db_path = leo.DB_PATH
        leo.DB_PATH = self.db_path

        # Create LeoField-like mock with conn
        class MockField:
            def __init__(self, conn):
                self.conn = conn

        self.conn = leo.init_db()
        self.mock_field = MockField(self.conn)
        self.brain = MathBrain(
            leo_field=self.mock_field,
            state_path=Path(self.temp_dir) / "mathbrain.json"
        )

    def tearDown(self):
        """Clean up temporary files."""
        if self.conn:
            self.conn.close()

        # Restore original DB_PATH
        leo.DB_PATH = self.original_db_path

        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_multileo_regulate_returns_semantic_hints(self):
        """Test that multileo_regulate returns semantic hints."""
        state = MathState(
            novelty=0.5,
            arousal=0.5,
            trauma_level=0.3,
            entropy=0.5,
            total_themes=10,
            active_theme_count=5,
        )

        temp, expert, hints = self.brain.multileo_regulate(
            temperature=1.0,
            expert_name="structural",
            state=state,
            active_theme_ids=[1, 2, 3]
        )

        # Should return dict with expected keys
        self.assertIn("preferred_themes", hints)
        self.assertIn("preferred_snapshots", hints)
        self.assertIn("preferred_episodes", hints)
        self.assertIsInstance(hints["preferred_themes"], list)

    def test_record_regulation_outcome(self):
        """Test recording regulation outcome."""
        state_before = MathState(
            novelty=0.1,
            arousal=0.1,
            trauma_level=0.2,
            entropy=0.5,
            total_themes=10,
            active_theme_count=2,
        )

        context = MultiLeoContext(
            boredom_before=0.8,
            overwhelm_before=0.2,
            stuck_before=0.7,
            quality_before=0.3,
            active_theme_ids=[1, 2],
            temp_before=1.0,
            expert_before="structural"
        )

        state_after = MathState(
            novelty=0.6,
            arousal=0.5,
            trauma_level=0.2,
            entropy=0.5,
            total_themes=10,
            active_theme_count=5,
        )

        # Should not raise
        self.brain.record_regulation_outcome(
            context_before=context,
            state_after=state_after,
            quality_after=0.6,
            temp_after=1.2,
            expert_after="creative",
            turn_id="test_turn"
        )

        # Verify event was recorded
        events = self.conn.execute("SELECT * FROM multileo_events").fetchall()
        self.assertGreater(len(events), 0)

    def test_multileo_context_default_values(self):
        """Test MultiLeoContext initializes with correct defaults."""
        context = MultiLeoContext(
            boredom_before=0.5,
            overwhelm_before=0.3,
            stuck_before=0.4,
            quality_before=0.6,
            active_theme_ids=[1, 2, 3]
        )

        self.assertEqual(context.used_snapshot_ids, [])
        self.assertEqual(context.used_episode_ids, [])
        self.assertEqual(context.used_shard_ids, [])
        self.assertEqual(context.temp_before, 1.0)
        self.assertEqual(context.expert_before, "structural")

    def test_phase3_graceful_failure_on_db_error(self):
        """Test that Phase 3 fails gracefully on database errors."""
        # Close connection to simulate DB error
        self.conn.close()
        self.conn = None
        self.mock_field.conn = None

        state = MathState(novelty=0.5, arousal=0.5)

        # Should not raise, should return empty hints
        temp, expert, hints = self.brain.multileo_regulate(
            temperature=1.0,
            expert_name="structural",
            state=state,
            active_theme_ids=[1, 2]
        )

        self.assertEqual(hints["preferred_themes"], [])


if __name__ == '__main__':
    unittest.main()
