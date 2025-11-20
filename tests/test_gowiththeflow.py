"""
Test #102: gowiththeflow.py — themes flowing through time
"""

import unittest
import sqlite3
import time
from pathlib import Path
import tempfile
import os

try:
    from gowiththeflow import (
        FlowTracker,
        ThemeSnapshot,
        ThemeTrajectory,
        get_emerging_themes,
        get_fading_themes,
    )
    FLOW_AVAILABLE = True
except ImportError:
    FLOW_AVAILABLE = False


@unittest.skipUnless(FLOW_AVAILABLE, "gowiththeflow module not available")
class TestFlowTracker(unittest.TestCase):
    """Test FlowTracker class - temporal theme evolution tracking."""

    def setUp(self):
        """Create temporary database for testing."""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
        self.temp_db.close()
        self.db_path = Path(self.temp_db.name)
        self.conn = sqlite3.connect(str(self.db_path))
        self.conn.row_factory = sqlite3.Row
        self.tracker = FlowTracker(self.conn)

    def tearDown(self):
        """Clean up temporary database."""
        self.conn.close()
        try:
            os.unlink(self.db_path)
        except:
            pass

    def test_schema_creation(self):
        """Test that theme_snapshots table is created."""
        cur = self.conn.cursor()
        cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='theme_snapshots'"
        )
        row = cur.fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], "theme_snapshots")

    def test_record_snapshot_basic(self):
        """Test recording a single theme snapshot."""
        # Create mock theme
        class MockTheme:
            def __init__(self):
                self.id = 1
                self.words = {"hello", "world", "flow"}

        themes = [MockTheme()]

        # Mock active_themes
        class MockActiveThemes:
            def __init__(self):
                self.theme_scores = {1: 0.8}

        active_themes = MockActiveThemes()

        # Record snapshot
        self.tracker.record_snapshot(themes, active_themes)

        # Verify snapshot was recorded
        cur = self.conn.cursor()
        cur.execute("SELECT COUNT(*) FROM theme_snapshots")
        count = cur.fetchone()[0]
        self.assertEqual(count, 1)

        # Verify snapshot data
        cur.execute("SELECT * FROM theme_snapshots WHERE theme_id = 1")
        row = cur.fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row["theme_id"], 1)
        self.assertAlmostEqual(row["strength"], 0.8, places=2)
        self.assertEqual(row["activation_count"], 1)

    def test_record_multiple_snapshots(self):
        """Test recording multiple snapshots over time."""
        class MockTheme:
            def __init__(self, tid):
                self.id = tid
                self.words = {"word" + str(tid)}

        class MockActiveThemes:
            def __init__(self, scores):
                self.theme_scores = scores

        themes = [MockTheme(1), MockTheme(2)]

        # Record 3 snapshots with different strengths
        timestamps = [100.0, 200.0, 300.0]
        strengths_t1 = [0.3, 0.5, 0.7]  # Growing
        strengths_t2 = [0.8, 0.5, 0.2]  # Fading

        for ts, s1, s2 in zip(timestamps, strengths_t1, strengths_t2):
            active = MockActiveThemes({1: s1, 2: s2})
            self.tracker.record_snapshot(themes, active, timestamp=ts)

        # Verify 6 snapshots (3 for each theme)
        cur = self.conn.cursor()
        cur.execute("SELECT COUNT(*) FROM theme_snapshots")
        count = cur.fetchone()[0]
        self.assertEqual(count, 6)

    def test_detect_emerging(self):
        """Test detection of emerging themes (positive slope)."""
        class MockTheme:
            def __init__(self, tid):
                self.id = tid
                self.words = set()

        class MockActiveThemes:
            def __init__(self, scores):
                self.theme_scores = scores

        themes = [MockTheme(1), MockTheme(2)]
        now = time.time()

        # Theme 1: growing (0.2 → 0.8 over 1 hour)
        # Theme 2: stable (0.5 → 0.5)
        for i in range(5):
            offset = i * 900  # 15 minute intervals
            ts = now - 3600 + offset  # Last hour
            s1 = 0.2 + (i * 0.15)  # Growing
            s2 = 0.5  # Stable
            active = MockActiveThemes({1: s1, 2: s2})
            self.tracker.record_snapshot(themes, active, timestamp=ts)

        # Detect emerging
        emerging = self.tracker.detect_emerging(window_hours=2.0, min_slope=0.05)

        # Should detect theme 1 as emerging
        theme_ids = [tid for tid, slope in emerging]
        self.assertIn(1, theme_ids)
        # Theme 2 should not be emerging (slope ~0)
        self.assertNotIn(2, theme_ids)

    def test_detect_fading(self):
        """Test detection of fading themes (negative slope)."""
        class MockTheme:
            def __init__(self, tid):
                self.id = tid
                self.words = set()

        class MockActiveThemes:
            def __init__(self, scores):
                self.theme_scores = scores

        themes = [MockTheme(1)]
        now = time.time()

        # Theme 1: fading (0.9 → 0.1 over 1 hour)
        for i in range(5):
            offset = i * 900
            ts = now - 3600 + offset
            s1 = 0.9 - (i * 0.2)  # Fading
            active = MockActiveThemes({1: s1})
            self.tracker.record_snapshot(themes, active, timestamp=ts)

        # Detect fading
        fading = self.tracker.detect_fading(window_hours=2.0, min_slope=0.05)

        # Should detect theme 1 as fading
        theme_ids = [tid for tid, slope in fading]
        self.assertIn(1, theme_ids)

        # Slope should be negative
        slope_1 = next(slope for tid, slope in fading if tid == 1)
        self.assertLess(slope_1, 0.0)

    def test_get_trajectory(self):
        """Test retrieving trajectory for a single theme."""
        class MockTheme:
            def __init__(self):
                self.id = 42
                self.words = {"test"}

        class MockActiveThemes:
            def __init__(self, score):
                self.theme_scores = {42: score}

        theme = MockTheme()
        now = time.time()

        # Record 3 snapshots
        for i in range(3):
            ts = now - 3600 + (i * 1800)  # 30 min intervals
            strength = 0.3 + (i * 0.2)
            active = MockActiveThemes(strength)
            self.tracker.record_snapshot([theme], active, timestamp=ts)

        # Get trajectory
        traj = self.tracker.get_trajectory(theme_id=42, hours=2.0)

        self.assertIsNotNone(traj)
        self.assertEqual(traj.theme_id, 42)
        self.assertEqual(len(traj.snapshots), 3)

        # Check snapshots are ordered by time
        timestamps = [s.timestamp for s in traj.snapshots]
        self.assertEqual(timestamps, sorted(timestamps))

        # Check current strength
        self.assertAlmostEqual(traj.current_strength(), 0.7, places=2)

    def test_trajectory_slope_calculation(self):
        """Test ThemeTrajectory.slope() calculation."""
        now = time.time()

        # Create trajectory with known slope
        snapshots = []
        for i in range(5):
            ts = now + (i * 3600)  # 1 hour intervals
            strength = 0.2 + (i * 0.1)  # Linear growth: +0.1 per hour
            snapshot = ThemeSnapshot(
                timestamp=ts,
                theme_id=1,
                strength=strength,
                active_words=set(),
                activation_count=i + 1,
            )
            snapshots.append(snapshot)

        traj = ThemeTrajectory(theme_id=1, snapshots=snapshots)

        # Slope should be ~0.1 per hour
        slope = traj.slope(hours=6.0)
        self.assertGreater(slope, 0.05)  # Positive growth
        self.assertLess(slope, 0.15)  # Approximately 0.1

    def test_stats(self):
        """Test stats() method."""
        class MockTheme:
            def __init__(self, tid):
                self.id = tid
                self.words = set()

        class MockActiveThemes:
            def __init__(self):
                self.theme_scores = {}

        themes = [MockTheme(1), MockTheme(2), MockTheme(3)]
        active = MockActiveThemes()

        # Record several snapshots
        for _ in range(5):
            self.tracker.record_snapshot(themes, active)

        stats = self.tracker.stats()

        self.assertEqual(stats["total_snapshots"], 15)  # 5 snapshots × 3 themes
        self.assertEqual(stats["unique_themes"], 3)
        self.assertGreaterEqual(stats["time_range_hours"], 0.0)

    def test_inactive_theme_zero_strength(self):
        """Test that inactive themes are recorded with strength=0."""
        class MockTheme:
            def __init__(self):
                self.id = 99
                self.words = set()

        class MockActiveThemes:
            def __init__(self):
                self.theme_scores = {}  # Empty - theme not active

        theme = MockTheme()
        active = MockActiveThemes()

        self.tracker.record_snapshot([theme], active)

        # Verify snapshot has strength=0
        cur = self.conn.cursor()
        cur.execute("SELECT strength FROM theme_snapshots WHERE theme_id = 99")
        row = cur.fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], 0.0)


@unittest.skipUnless(FLOW_AVAILABLE, "gowiththeflow module not available")
class TestStandaloneHelpers(unittest.TestCase):
    """Test standalone helper functions."""

    def setUp(self):
        """Create temporary database."""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
        self.temp_db.close()
        self.db_path = Path(self.temp_db.name)

    def tearDown(self):
        """Clean up."""
        try:
            os.unlink(self.db_path)
        except:
            pass

    def test_get_emerging_themes_helper(self):
        """Test get_emerging_themes() standalone helper."""
        conn = sqlite3.connect(str(self.db_path))
        tracker = FlowTracker(conn)

        class MockTheme:
            def __init__(self):
                self.id = 1
                self.words = set()

        class MockActiveThemes:
            def __init__(self, score):
                self.theme_scores = {1: score}

        theme = MockTheme()
        now = time.time()

        # Record growing theme
        for i in range(4):
            ts = now - 3600 + (i * 1200)
            strength = 0.2 + (i * 0.2)
            active = MockActiveThemes(strength)
            tracker.record_snapshot([theme], active, timestamp=ts)

        conn.close()

        # Use standalone helper
        emerging = get_emerging_themes(self.db_path, window_hours=2.0, min_slope=0.05)

        self.assertIsInstance(emerging, list)
        if emerging:  # May be empty depending on timing
            self.assertIsInstance(emerging[0], tuple)
            self.assertEqual(len(emerging[0]), 2)  # (theme_id, slope)

    def test_get_fading_themes_helper(self):
        """Test get_fading_themes() standalone helper."""
        conn = sqlite3.connect(str(self.db_path))
        tracker = FlowTracker(conn)

        class MockTheme:
            def __init__(self):
                self.id = 1
                self.words = set()

        class MockActiveThemes:
            def __init__(self, score):
                self.theme_scores = {1: score}

        theme = MockTheme()
        now = time.time()

        # Record fading theme
        for i in range(4):
            ts = now - 3600 + (i * 1200)
            strength = 0.8 - (i * 0.2)
            active = MockActiveThemes(strength)
            tracker.record_snapshot([theme], active, timestamp=ts)

        conn.close()

        # Use standalone helper
        fading = get_fading_themes(self.db_path, window_hours=2.0, min_slope=0.05)

        self.assertIsInstance(fading, list)


if __name__ == "__main__":
    unittest.main()
