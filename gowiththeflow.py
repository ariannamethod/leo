"""
gowiththeflow.py — themes flowing through time

"Go with the flow" — evolutionary tracking of semantic constellations.

Core idea:
- Themes aren't static snapshots — they flow, grow, fade, merge
- Record theme state after each reply → build archaeological record
- Detect emerging themes (↗), fading themes (↘), persistent themes (→)
- Enable wound-theme correlation: which islands appear during trauma?
- Track conversation phases as meaning flows through time

This is memory archaeology: watching semantic currents shift and eddy.
Not training data — just temporal awareness of the flow.
"""

from __future__ import annotations

import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Set, Tuple, Optional, Any


# ============================================================================
# DATA STRUCTURES
# ============================================================================


@dataclass
class ThemeSnapshot:
    """
    Snapshot of a theme at a specific moment in the flow.

    Captures:
    - When the theme was active
    - How strongly it flowed
    - Which words belonged to it at that moment
    - How many times it appeared in the conversation
    """
    timestamp: float
    theme_id: int
    strength: float  # activation score from ActiveThemes
    active_words: Set[str]
    activation_count: int  # cumulative count across conversation


@dataclass
class ThemeTrajectory:
    """
    Evolution of a single theme as it flows through time.

    Contains:
    - Full history of snapshots
    - Computed slope (growing/fading)
    - Current state
    """
    theme_id: int
    snapshots: List[ThemeSnapshot]

    def slope(self, hours: float = 6.0) -> float:
        """
        Compute flow trajectory over last N hours.

        Positive slope → emerging theme (↗ growing)
        Negative slope → fading theme (↘ dying)
        Zero slope → stable theme (→ persistent)

        Uses simple linear regression over strength values.

        Args:
            hours: Time window to compute slope (default: 6 hours)

        Returns:
            Slope value: positive = growing, negative = fading, ~0 = stable
        """
        if len(self.snapshots) < 2:
            return 0.0

        now = time.time()
        cutoff = now - (hours * 3600)

        # Filter recent snapshots
        recent = [s for s in self.snapshots if s.timestamp >= cutoff]

        if len(recent) < 2:
            return 0.0

        # Simple linear regression: slope = cov(x,y) / var(x)
        # x = time offset from first snapshot
        # y = strength
        times = [s.timestamp - recent[0].timestamp for s in recent]
        strengths = [s.strength for s in recent]

        n = len(times)
        mean_t = sum(times) / n
        mean_s = sum(strengths) / n

        # Covariance and variance
        cov = sum((times[i] - mean_t) * (strengths[i] - mean_s) for i in range(n))
        var = sum((times[i] - mean_t) ** 2 for i in range(n))

        if var == 0:
            return 0.0

        # Slope in strength per second
        slope_per_sec = cov / var

        # Convert to strength per hour for readability
        slope_per_hour = slope_per_sec * 3600

        return slope_per_hour

    def current_strength(self) -> float:
        """Get most recent strength value."""
        if not self.snapshots:
            return 0.0
        return self.snapshots[-1].strength

    def lifetime_hours(self) -> float:
        """How long has this theme been flowing?"""
        if len(self.snapshots) < 2:
            return 0.0
        return (self.snapshots[-1].timestamp - self.snapshots[0].timestamp) / 3600


# ============================================================================
# FLOW TRACKER
# ============================================================================


class FlowTracker:
    """
    Track the flow of themes through time.

    This is Leo's memory archaeology:
    - Record theme snapshots after each reply
    - Detect emerging vs fading themes
    - Query theme history and trajectories
    - Enable wound-theme correlation analysis

    Storage:
    - SQLite table: theme_snapshots
    - In-memory cache of recent trajectories
    """

    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
        self._ensure_schema()
        # Cache of theme_id → activation count
        self._activation_counts: Dict[int, int] = {}

    def _ensure_schema(self) -> None:
        """Create theme_snapshots table if it doesn't exist."""
        cur = self.conn.cursor()

        cur.execute("""
            CREATE TABLE IF NOT EXISTS theme_snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL NOT NULL,
                theme_id INTEGER NOT NULL,
                strength REAL NOT NULL,
                activation_count INTEGER NOT NULL,
                words TEXT NOT NULL
            )
        """)

        # Indices for fast queries
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_snapshots_time
            ON theme_snapshots(timestamp)
        """)

        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_snapshots_theme
            ON theme_snapshots(theme_id)
        """)

        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_snapshots_theme_time
            ON theme_snapshots(theme_id, timestamp)
        """)

        self.conn.commit()

    def record_snapshot(
        self,
        themes: List[Any],  # List[Theme] from leo.py
        active_themes: Optional[Any] = None,  # ActiveThemes from leo.py
        timestamp: Optional[float] = None,
    ) -> None:
        """
        Record current state of themes in the flow.

        Call this after each reply to build temporal history.

        Args:
            themes: List of Theme objects from LeoField
            active_themes: ActiveThemes object (theme_scores, active_words)
            timestamp: Unix timestamp (default: current time)
        """
        if timestamp is None:
            timestamp = time.time()

        if not themes:
            return

        cur = self.conn.cursor()

        # Extract active theme scores
        active_scores: Dict[int, float] = {}
        if active_themes and hasattr(active_themes, 'theme_scores'):
            active_scores = active_themes.theme_scores or {}

        # Record snapshot for each theme
        for theme in themes:
            theme_id = theme.id

            # Strength = activation score (or 0 if not active)
            strength = active_scores.get(theme_id, 0.0)

            # Update activation count
            if theme_id not in self._activation_counts:
                # Load from DB or initialize
                cur.execute(
                    "SELECT activation_count FROM theme_snapshots "
                    "WHERE theme_id = ? ORDER BY id DESC LIMIT 1",
                    (theme_id,)
                )
                row = cur.fetchone()
                self._activation_counts[theme_id] = int(row[0]) if row else 0

            # Increment if theme is active
            if strength > 0:
                self._activation_counts[theme_id] += 1

            activation_count = self._activation_counts[theme_id]

            # Serialize words (JSON-like simple format)
            words = theme.words if hasattr(theme, 'words') else set()
            words_str = ",".join(sorted(words))

            # Insert snapshot
            cur.execute(
                """
                INSERT INTO theme_snapshots
                (timestamp, theme_id, strength, activation_count, words)
                VALUES (?, ?, ?, ?, ?)
                """,
                (timestamp, theme_id, strength, activation_count, words_str)
            )

        self.conn.commit()

    def detect_emerging(
        self,
        window_hours: float = 6.0,
        min_slope: float = 0.1,
    ) -> List[Tuple[int, float]]:
        """
        Detect themes that are flowing stronger (↗ emerging).

        Args:
            window_hours: Time window to analyze (default: 6 hours)
            min_slope: Minimum slope to consider "emerging" (default: 0.1)

        Returns:
            List of (theme_id, slope) for emerging themes, sorted by slope descending
        """
        trajectories = self._build_trajectories(window_hours)

        emerging = []
        for theme_id, traj in trajectories.items():
            slope = traj.slope(window_hours)
            if slope >= min_slope:
                emerging.append((theme_id, slope))

        # Sort by slope descending (fastest growing first)
        emerging.sort(key=lambda x: x[1], reverse=True)
        return emerging

    def detect_fading(
        self,
        window_hours: float = 6.0,
        min_slope: float = 0.1,
    ) -> List[Tuple[int, float]]:
        """
        Detect themes that are flowing weaker (↘ fading).

        Args:
            window_hours: Time window to analyze (default: 6 hours)
            min_slope: Minimum absolute slope to consider "fading" (default: 0.1)

        Returns:
            List of (theme_id, slope) for fading themes, sorted by slope ascending
        """
        trajectories = self._build_trajectories(window_hours)

        fading = []
        for theme_id, traj in trajectories.items():
            slope = traj.slope(window_hours)
            if slope <= -min_slope:
                fading.append((theme_id, slope))

        # Sort by slope ascending (fastest fading first)
        fading.sort(key=lambda x: x[1])
        return fading

    def get_trajectory(
        self,
        theme_id: int,
        hours: float = 24.0,
    ) -> Optional[ThemeTrajectory]:
        """
        Get flow history of a single theme.

        Args:
            theme_id: Theme ID to query
            hours: How far back to look (default: 24 hours)

        Returns:
            ThemeTrajectory object or None if no data
        """
        now = time.time()
        cutoff = now - (hours * 3600)

        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT timestamp, strength, activation_count, words
            FROM theme_snapshots
            WHERE theme_id = ? AND timestamp >= ?
            ORDER BY timestamp ASC
            """,
            (theme_id, cutoff)
        )

        rows = cur.fetchall()
        if not rows:
            return None

        snapshots = []
        for row in rows:
            words_str = row[3]
            words = set(words_str.split(",")) if words_str else set()

            snapshot = ThemeSnapshot(
                timestamp=float(row[0]),
                theme_id=theme_id,
                strength=float(row[1]),
                active_words=words,
                activation_count=int(row[2]),
            )
            snapshots.append(snapshot)

        return ThemeTrajectory(theme_id=theme_id, snapshots=snapshots)

    def _build_trajectories(
        self,
        window_hours: float,
    ) -> Dict[int, ThemeTrajectory]:
        """Build trajectories for all themes in time window."""
        now = time.time()
        cutoff = now - (window_hours * 3600)

        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT theme_id, timestamp, strength, activation_count, words
            FROM theme_snapshots
            WHERE timestamp >= ?
            ORDER BY theme_id, timestamp ASC
            """,
            (cutoff,)
        )

        rows = cur.fetchall()

        # Group by theme_id
        trajectories: Dict[int, List[ThemeSnapshot]] = {}
        for row in rows:
            theme_id = int(row[0])
            timestamp = float(row[1])
            strength = float(row[2])
            activation_count = int(row[3])
            words_str = row[4]
            words = set(words_str.split(",")) if words_str else set()

            snapshot = ThemeSnapshot(
                timestamp=timestamp,
                theme_id=theme_id,
                strength=strength,
                active_words=words,
                activation_count=activation_count,
            )

            trajectories.setdefault(theme_id, []).append(snapshot)

        # Convert to ThemeTrajectory objects
        return {
            tid: ThemeTrajectory(theme_id=tid, snapshots=snaps)
            for tid, snaps in trajectories.items()
        }

    def stats(self) -> Dict[str, Any]:
        """
        Get flow statistics.

        Returns:
            Dict with total_snapshots, unique_themes, time_range, etc.
        """
        cur = self.conn.cursor()

        # Total snapshots
        cur.execute("SELECT COUNT(*) FROM theme_snapshots")
        total_snapshots = cur.fetchone()[0]

        # Unique themes
        cur.execute("SELECT COUNT(DISTINCT theme_id) FROM theme_snapshots")
        unique_themes = cur.fetchone()[0]

        # Time range
        cur.execute("SELECT MIN(timestamp), MAX(timestamp) FROM theme_snapshots")
        row = cur.fetchone()
        min_time = row[0] if row[0] else 0.0
        max_time = row[1] if row[1] else 0.0

        time_range_hours = (max_time - min_time) / 3600 if max_time > min_time else 0.0

        return {
            "total_snapshots": total_snapshots,
            "unique_themes": unique_themes,
            "time_range_hours": round(time_range_hours, 2),
            "earliest_snapshot": min_time,
            "latest_snapshot": max_time,
        }


# ============================================================================
# PUBLIC HELPERS
# ============================================================================


def get_emerging_themes(
    db_path: Path,
    window_hours: float = 6.0,
    min_slope: float = 0.1,
) -> List[Tuple[int, float]]:
    """
    Standalone helper: detect emerging themes.

    Args:
        db_path: Path to leo.sqlite3
        window_hours: Time window to analyze
        min_slope: Minimum slope threshold

    Returns:
        List of (theme_id, slope) for emerging themes
    """
    try:
        conn = sqlite3.connect(str(db_path))
        tracker = FlowTracker(conn)
        result = tracker.detect_emerging(window_hours, min_slope)
        conn.close()
        return result
    except Exception:
        return []


def get_fading_themes(
    db_path: Path,
    window_hours: float = 6.0,
    min_slope: float = 0.1,
) -> List[Tuple[int, float]]:
    """
    Standalone helper: detect fading themes.

    Args:
        db_path: Path to leo.sqlite3
        window_hours: Time window to analyze
        min_slope: Minimum absolute slope threshold

    Returns:
        List of (theme_id, slope) for fading themes
    """
    try:
        conn = sqlite3.connect(str(db_path))
        tracker = FlowTracker(conn)
        result = tracker.detect_fading(window_hours, min_slope)
        conn.close()
        return result
    except Exception:
        return []
