#!/usr/bin/env python3
"""
mathbrain_phase4.py — Leo's Island Bridges

Phase 4 for Leo's MathBrain:
- Learns bridges between islands (experience units) from dialogue trajectories
- Allows fuzzy similarity between island states (not exact match)
- Suggests next islands as "climate flows", not rigid choices

Philosophy:
- Not a planner. Memory of where the field usually flows.
- "When life felt like this and passed through here, it often flowed there."
- Fuzzy matches with explicit thresholds (0.6-0.8)
- Respect boredom/overwhelm/stuck signals

Only dependencies: sqlite3 + math (stdlib). Optional: numpy for precision.
"""

from __future__ import annotations

import json
import math
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Optional numpy for precision (graceful fallback)
try:
    import numpy as np
    NUMPY_AVAILABLE = True
except ImportError:
    np = None
    NUMPY_AVAILABLE = False


# ============================================================================
# DATA STRUCTURES
# ============================================================================

MetricVector = Dict[str, float]


@dataclass
class IslandTransitionStats:
    """Statistics for a single island → island transition."""
    from_island: str
    to_island: str
    count: int
    avg_similarity: float
    avg_presence_delta: float
    overwhelm_rate: float
    boredom_rate: float
    stuck_rate: float

    @property
    def score(self) -> float:
        """
        Composite score for ranking transitions.

        Intuition:
        - higher similarity is good (field flows naturally)
        - positive presence_delta is good (life gets better)
        - high overwhelm_rate is bad (penalty)
        - high boredom_rate is slightly bad
        """
        # Base: similarity * (1 + presence boost)
        presence_factor = 1.0 + max(-0.5, min(0.5, self.avg_presence_delta))
        base = self.avg_similarity * presence_factor

        # Penalties
        overwhelm_penalty = 1.0 - min(1.0, max(0.0, self.overwhelm_rate))
        boredom_penalty = 1.0 - 0.3 * min(1.0, max(0.0, self.boredom_rate))
        stuck_penalty = 1.0 - 0.2 * min(1.0, max(0.0, self.stuck_rate))

        return base * overwhelm_penalty * boredom_penalty * stuck_penalty


# ============================================================================
# MATH HELPERS (with optional numpy precision)
# ============================================================================


def cosine_similarity(a: MetricVector, b: MetricVector) -> float:
    """
    Cosine similarity over shared metric keys.

    Returns 0.0 if vectors are empty or orthogonal.
    Uses numpy if available for precision.
    """
    if not a or not b:
        return 0.0

    keys = set(a.keys()) & set(b.keys())
    if not keys:
        return 0.0

    if NUMPY_AVAILABLE:
        # Numpy path: more precise
        vec_a = np.array([a[k] for k in keys])
        vec_b = np.array([b[k] for k in keys])

        norm_a = np.linalg.norm(vec_a)
        norm_b = np.linalg.norm(vec_b)

        if norm_a == 0.0 or norm_b == 0.0:
            return 0.0

        return float(np.dot(vec_a, vec_b) / (norm_a * norm_b))
    else:
        # Pure Python fallback
        dot = sum(a[k] * b[k] for k in keys)
        norm_a = math.sqrt(sum(a[k] * a[k] for k in keys))
        norm_b = math.sqrt(sum(b[k] * b[k] for k in keys))

        if norm_a == 0.0 or norm_b == 0.0:
            return 0.0

        return dot / (norm_a * norm_b)


def euclidean_distance(a: MetricVector, b: MetricVector) -> float:
    """
    Euclidean distance over shared keys.
    Useful for "how different" rather than "how aligned".
    """
    if not a or not b:
        return float('inf')

    keys = set(a.keys()) & set(b.keys())
    if not keys:
        return float('inf')

    if NUMPY_AVAILABLE:
        vec_a = np.array([a[k] for k in keys])
        vec_b = np.array([b[k] for k in keys])
        return float(np.linalg.norm(vec_a - vec_b))
    else:
        return math.sqrt(sum((a[k] - b[k]) ** 2 for k in keys))


def get_presence(metric_vec: MetricVector) -> float:
    """Extract presence_pulse from metrics, default 0.0."""
    return float(metric_vec.get("presence_pulse", metric_vec.get("pulse", 0.0)))


def metric_entropy(metric_vec: MetricVector) -> float:
    """
    Shannon entropy of metric distribution.
    Higher = more diverse/uncertain state.
    """
    if not metric_vec:
        return 0.0

    values = [abs(v) for v in metric_vec.values() if v != 0]
    if not values:
        return 0.0

    total = sum(values)
    if total == 0:
        return 0.0

    probs = [v / total for v in values]

    if NUMPY_AVAILABLE:
        probs_arr = np.array(probs)
        probs_arr = probs_arr[probs_arr > 0]  # filter zeros
        return float(-np.sum(probs_arr * np.log2(probs_arr)))
    else:
        return -sum(p * math.log2(p) for p in probs if p > 0)


# ============================================================================
# PHASE 4 CORE
# ============================================================================


class MathBrainPhase4:
    """
    Phase 4: Island bridges and flows.

    Learns from dialogue trajectories which islands follow which,
    under what metric conditions, and with what outcomes.

    Usage:
        phase4 = MathBrainPhase4(db_path)

        # After each turn where an island was activated:
        phase4.record_activation(
            island_id="theme_loneliness",
            metrics_before=before_state,
            metrics_after=after_state,
            prev_island_id="theme_fear",
            turn_id="conv123_turn5",
            boredom=False,
            overwhelm=False,
            stuck=False,
        )

        # To get suggestions:
        flows = phase4.suggest_next_islands("theme_loneliness")
    """

    def __init__(self, db_path: Path):
        self.db_path = Path(db_path)
        self.conn = sqlite3.connect(str(self.db_path))
        self.conn.row_factory = sqlite3.Row
        self._ensure_schema()

    # -------------------- Schema --------------------

    def _ensure_schema(self) -> None:
        """Create Phase 4 tables if they don't exist."""
        cur = self.conn.cursor()

        # Log of individual activations (for debugging / future analysis)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS phase4_activation_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts REAL NOT NULL,
                turn_id TEXT,
                prev_island_id TEXT,
                island_id TEXT NOT NULL,
                metrics_before TEXT,
                metrics_after TEXT,
                boredom INTEGER DEFAULT 0,
                overwhelm INTEGER DEFAULT 0,
                stuck INTEGER DEFAULT 0
            );
        """)

        # Aggregate transitions between islands
        cur.execute("""
            CREATE TABLE IF NOT EXISTS phase4_transitions (
                from_island_id TEXT NOT NULL,
                to_island_id TEXT NOT NULL,
                count INTEGER NOT NULL DEFAULT 0,
                sum_similarity REAL NOT NULL DEFAULT 0.0,
                sum_presence_delta REAL NOT NULL DEFAULT 0.0,
                sum_overwhelm REAL NOT NULL DEFAULT 0.0,
                sum_boredom REAL NOT NULL DEFAULT 0.0,
                sum_stuck REAL NOT NULL DEFAULT 0.0,
                PRIMARY KEY (from_island_id, to_island_id)
            );
        """)

        # Island state snapshots
        cur.execute("""
            CREATE TABLE IF NOT EXISTS phase4_island_state (
                island_id TEXT PRIMARY KEY,
                last_metrics TEXT,
                activations_total INTEGER NOT NULL DEFAULT 0,
                last_updated REAL
            );
        """)

        # Index for faster queries
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_phase4_transitions_from
            ON phase4_transitions(from_island_id);
        """)

        self.conn.commit()

    # -------------------- Write Path --------------------

    def record_island_state(self, island_id: str, metrics: MetricVector) -> None:
        """Keep a lightweight snapshot of island's last known metric vector."""
        cur = self.conn.cursor()
        cur.execute("""
            INSERT INTO phase4_island_state (island_id, last_metrics, activations_total, last_updated)
            VALUES (?, ?, 1, ?)
            ON CONFLICT(island_id) DO UPDATE SET
                last_metrics = excluded.last_metrics,
                activations_total = phase4_island_state.activations_total + 1,
                last_updated = excluded.last_updated;
        """, (island_id, json.dumps(metrics), time.time()))
        self.conn.commit()

    def record_activation(
        self,
        island_id: str,
        metrics_before: MetricVector,
        metrics_after: MetricVector,
        *,
        prev_island_id: Optional[str] = None,
        turn_id: Optional[str] = None,
        boredom: bool = False,
        overwhelm: bool = False,
        stuck: bool = False,
    ) -> None:
        """
        Main entry point from Leo core.

        Call this once per turn when an island was actually used
        (selected by Phase-3 MathBrain).
        """
        ts = time.time()
        cur = self.conn.cursor()

        # 1) Log activation for future analysis
        cur.execute("""
            INSERT INTO phase4_activation_log (
                ts, turn_id, prev_island_id, island_id,
                metrics_before, metrics_after,
                boredom, overwhelm, stuck
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            ts,
            turn_id,
            prev_island_id,
            island_id,
            json.dumps(metrics_before),
            json.dumps(metrics_after),
            int(boredom),
            int(overwhelm),
            int(stuck),
        ))

        # 2) Update island_state snapshot
        self.record_island_state(island_id, metrics_after)

        # 3) Update transition aggregates if we have a previous island
        if prev_island_id:
            similarity = cosine_similarity(metrics_before, metrics_after)
            presence_delta = get_presence(metrics_after) - get_presence(metrics_before)

            cur.execute("""
                INSERT INTO phase4_transitions (
                    from_island_id, to_island_id,
                    count, sum_similarity, sum_presence_delta,
                    sum_overwhelm, sum_boredom, sum_stuck
                ) VALUES (?, ?, 1, ?, ?, ?, ?, ?)
                ON CONFLICT(from_island_id, to_island_id) DO UPDATE SET
                    count = phase4_transitions.count + 1,
                    sum_similarity = phase4_transitions.sum_similarity + excluded.sum_similarity,
                    sum_presence_delta = phase4_transitions.sum_presence_delta + excluded.sum_presence_delta,
                    sum_overwhelm = phase4_transitions.sum_overwhelm + excluded.sum_overwhelm,
                    sum_boredom = phase4_transitions.sum_boredom + excluded.sum_boredom,
                    sum_stuck = phase4_transitions.sum_stuck + excluded.sum_stuck;
            """, (
                prev_island_id,
                island_id,
                similarity,
                presence_delta,
                float(overwhelm),
                float(boredom),
                float(stuck),
            ))

        self.conn.commit()

    # -------------------- Read Path --------------------

    def _load_transitions_from(self, from_island_id: str) -> List[IslandTransitionStats]:
        """Load all transitions from a given island."""
        cur = self.conn.cursor()
        cur.execute("""
            SELECT
                from_island_id, to_island_id, count,
                sum_similarity, sum_presence_delta,
                sum_overwhelm, sum_boredom, sum_stuck
            FROM phase4_transitions
            WHERE from_island_id = ?;
        """, (from_island_id,))

        rows = cur.fetchall()
        stats: List[IslandTransitionStats] = []

        for row in rows:
            count = row["count"] or 1
            stats.append(IslandTransitionStats(
                from_island=row["from_island_id"],
                to_island=row["to_island_id"],
                count=count,
                avg_similarity=(row["sum_similarity"] or 0.0) / count,
                avg_presence_delta=(row["sum_presence_delta"] or 0.0) / count,
                overwhelm_rate=(row["sum_overwhelm"] or 0.0) / count,
                boredom_rate=(row["sum_boredom"] or 0.0) / count,
                stuck_rate=(row["sum_stuck"] or 0.0) / count,
            ))

        return stats

    def get_transition_stats(
        self,
        from_island: str,
        to_island: str,
    ) -> Optional[IslandTransitionStats]:
        """Get stats for a specific transition, or None if not found."""
        cur = self.conn.cursor()
        cur.execute("""
            SELECT
                from_island_id, to_island_id, count,
                sum_similarity, sum_presence_delta,
                sum_overwhelm, sum_boredom, sum_stuck
            FROM phase4_transitions
            WHERE from_island_id = ? AND to_island_id = ?;
        """, (from_island, to_island))

        row = cur.fetchone()
        if not row:
            return None

        count = row["count"] or 1
        return IslandTransitionStats(
            from_island=row["from_island_id"],
            to_island=row["to_island_id"],
            count=count,
            avg_similarity=(row["sum_similarity"] or 0.0) / count,
            avg_presence_delta=(row["sum_presence_delta"] or 0.0) / count,
            overwhelm_rate=(row["sum_overwhelm"] or 0.0) / count,
            boredom_rate=(row["sum_boredom"] or 0.0) / count,
            stuck_rate=(row["sum_stuck"] or 0.0) / count,
        )

    def suggest_next_islands(
        self,
        current_island_id: str,
        *,
        min_similarity: float = 0.6,
        max_candidates: int = 5,
        exclude_overwhelming: bool = True,
        overwhelm_threshold: float = 0.7,
    ) -> List[Tuple[str, float, IslandTransitionStats]]:
        """
        Suggest next candidate islands from the current one.

        Returns a list of (island_id, score, stats) sorted by descending score.

        The caller (Leo core) is free to:
        - take top-1
        - sample by score
        - deliberately pick 2nd/3rd for боковое мышление

        This is not a recommender. This is honest memory:
        "when the field passed through here, it usually flowed there."
        """
        transitions = self._load_transitions_from(current_island_id)
        filtered: List[Tuple[str, float, IslandTransitionStats]] = []

        for t in transitions:
            # Filter by similarity threshold
            if t.avg_similarity < min_similarity:
                continue

            # Filter overwhelming bridges
            if exclude_overwhelming and t.overwhelm_rate > overwhelm_threshold:
                continue

            score = t.score
            if score <= 0.0:
                continue

            filtered.append((t.to_island, score, t))

        # Sort by score descending
        filtered.sort(key=lambda x: x[1], reverse=True)

        return filtered[:max_candidates]

    # -------------------- Debug Helpers --------------------

    def debug_print_transitions(self, island_id: str, limit: int = 10) -> None:
        """Print top transitions from an island. Good for quick inspection."""
        candidates = self.suggest_next_islands(
            island_id,
            max_candidates=limit,
            min_similarity=0.0,  # show all
            exclude_overwhelming=False,
        )

        print(f"Transitions from island '{island_id}':")
        if not candidates:
            print("  (no transitions recorded)")
            return

        for i, (to_id, score, stats) in enumerate(candidates, start=1):
            print(
                f"  {i:02d}. → {stats.to_island} | "
                f"score={score:.3f} | "
                f"sim={stats.avg_similarity:.3f} | "
                f"Δpresence={stats.avg_presence_delta:+.3f} | "
                f"overwhelm={stats.overwhelm_rate:.2f} | "
                f"count={stats.count}"
            )

    def get_all_islands(self) -> List[str]:
        """Get list of all known islands."""
        cur = self.conn.cursor()
        cur.execute("SELECT DISTINCT island_id FROM phase4_island_state ORDER BY island_id;")
        return [row[0] for row in cur.fetchall()]

    def get_transition_count(self) -> int:
        """Get total number of recorded transitions."""
        cur = self.conn.cursor()
        cur.execute("SELECT SUM(count) FROM phase4_transitions;")
        result = cur.fetchone()[0]
        return result or 0


# ============================================================================
# SMOKE TEST
# ============================================================================

if __name__ == "__main__":
    import tempfile

    print("MathBrain Phase 4 — Smoke Test")
    print("=" * 50)
    print(f"NumPy available: {NUMPY_AVAILABLE}")
    print()

    # Create temp DB
    with tempfile.NamedTemporaryFile(suffix=".sqlite3", delete=False) as f:
        db_path = Path(f.name)

    phase4 = MathBrainPhase4(db_path)

    # Simulate some activations
    metrics_a = {"presence_pulse": 0.3, "entropy": 0.4, "arousal": 0.2}
    metrics_b = {"presence_pulse": 0.5, "entropy": 0.45, "arousal": 0.3}
    metrics_c = {"presence_pulse": 0.8, "entropy": 0.6, "arousal": 0.5}
    metrics_bad = {"presence_pulse": 0.1, "entropy": 0.9, "arousal": 0.9}

    # Record transitions: A → B (good), A → B (good), A → C (good), A → bad (overwhelm)
    phase4.record_activation("island_A", metrics_a, metrics_b, turn_id="t1")
    phase4.record_activation("island_B", metrics_b, metrics_c, prev_island_id="island_A", turn_id="t2")
    phase4.record_activation("island_B", metrics_a, metrics_b, prev_island_id="island_A", turn_id="t3")
    phase4.record_activation("island_C", metrics_b, metrics_c, prev_island_id="island_A", turn_id="t4")
    phase4.record_activation("island_bad", metrics_a, metrics_bad, prev_island_id="island_A", turn_id="t5", overwhelm=True)

    print("Recorded transitions:")
    phase4.debug_print_transitions("island_A")
    print()

    print("Suggestions (filtered):")
    suggestions = phase4.suggest_next_islands("island_A")
    for island_id, score, stats in suggestions:
        print(f"  → {island_id}: score={score:.3f}")

    print()
    print(f"Total transitions: {phase4.get_transition_count()}")
    print(f"Known islands: {phase4.get_all_islands()}")

    # Cleanup
    db_path.unlink()
    print("\n✓ Smoke test passed!")
