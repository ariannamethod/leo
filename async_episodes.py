#!/usr/bin/env python3
"""
async_episodes.py — Async wrapper for RAGBrain (episodic memory module)

Inherits from sync RAGBrain and adds async database I/O for episode storage/retrieval.
"""

from __future__ import annotations

import time
from pathlib import Path
from typing import Any, Dict, List, Optional

# Async SQLite
import aiosqlite

# Import sync RAGBrain (we inherit from it)
from episodes import RAGBrain, Episode, MathState, MATH_AVAILABLE, state_to_features


class AsyncRAGBrain(RAGBrain):
    """
    Async version of RAGBrain (episodic memory).

    Inherits from sync RAGBrain but overrides database operations
    to use aiosqlite for non-blocking queries.

    Usage:
        rag = AsyncRAGBrain(db_path=...)
        await rag.async_init()  # Create schema
        await rag.async_observe_episode(episode)  # Store
        results = await rag.async_query_similar(metrics)  # Query
    """

    def __init__(self, db_path: Path | None = None) -> None:
        """
        Initialize async RAGBrain.

        Args:
            db_path: Path to SQLite DB (default: state/leo_rag.sqlite3)
        """
        # Set db_path
        if db_path is None:
            base = Path(__file__).parent
            if base.name == "src":
                base = base.parent
            db_path = base / "state" / "leo_rag.sqlite3"

        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)

        # NOTE: Do NOT call _ensure_schema() here (sync)
        # Instead call async_init() after creation

    async def async_init(self) -> None:
        """
        Async initialization - creates database schema.

        Call this after __init__:
            rag = AsyncRAGBrain(...)
            await rag.async_init()
        """
        try:
            await self._async_ensure_schema()
        except Exception:
            # Silent fail — RAG must never break Leo
            pass

    async def _async_ensure_schema(self) -> None:
        """Create tables if they don't exist (async)."""
        async with aiosqlite.connect(str(self.db_path)) as conn:
            async with conn.cursor() as cur:
                await cur.execute("""
                    CREATE TABLE IF NOT EXISTS episodes (
                        id              INTEGER PRIMARY KEY AUTOINCREMENT,
                        created_at      REAL NOT NULL,
                        prompt          TEXT NOT NULL,
                        reply           TEXT NOT NULL,

                        -- scalar metrics from MathState
                        entropy         REAL NOT NULL,
                        novelty         REAL NOT NULL,
                        arousal         REAL NOT NULL,
                        pulse           REAL NOT NULL,
                        trauma_level    REAL NOT NULL,
                        active_themes   REAL NOT NULL,
                        emerging_score  REAL NOT NULL,
                        fading_score    REAL NOT NULL,
                        reply_len_norm  REAL NOT NULL,
                        unique_ratio    REAL NOT NULL,
                        expert_temp     REAL NOT NULL,
                        expert_semantic REAL NOT NULL,
                        metaleo_weight  REAL NOT NULL,
                        used_metaleo    INTEGER NOT NULL,
                        overthinking_on INTEGER NOT NULL,
                        rings_present   INTEGER NOT NULL,

                        -- target
                        quality         REAL NOT NULL
                    )
                """)

                await cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_episodes_created
                    ON episodes(created_at)
                """)

            await conn.commit()

    async def async_observe_episode(self, episode: Episode) -> None:
        """
        Insert one episode into the DB (async).

        Clampsall floats to [0, 1] or reasonable ranges.
        Ignores NaNs and replaces with 0.0.
        Catches all errors and fails silently.
        """
        if not MATH_AVAILABLE or state_to_features is None:
            return

        try:
            metrics = episode.metrics

            # Clamp and sanitize all values
            def clamp(x: float, min_val: float = 0.0, max_val: float = 1.0) -> float:
                if x != x:  # NaN check
                    return 0.0
                return max(min_val, min(max_val, x))

            async with aiosqlite.connect(str(self.db_path)) as conn:
                async with conn.cursor() as cur:
                    await cur.execute("""
                        INSERT INTO episodes (
                            created_at, prompt, reply,
                            entropy, novelty, arousal, pulse,
                            trauma_level, active_themes, emerging_score, fading_score,
                            reply_len_norm, unique_ratio,
                            expert_temp, expert_semantic,
                            metaleo_weight, used_metaleo, overthinking_on, rings_present,
                            quality
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        time.time(),
                        episode.prompt,
                        episode.reply,
                        clamp(metrics.entropy),
                        clamp(metrics.novelty),
                        clamp(metrics.arousal),
                        clamp(metrics.pulse),
                        clamp(metrics.trauma_level),
                        clamp(metrics.active_theme_count / max(1, metrics.total_themes)),
                        clamp(metrics.emerging_score),
                        clamp(metrics.fading_score),
                        clamp(min(1.0, metrics.reply_len / 64.0)),
                        clamp(metrics.unique_ratio),
                        clamp(metrics.expert_temp, 0.0, 2.0),
                        clamp(metrics.expert_semantic),
                        clamp(metrics.metaleo_weight),
                        1 if metrics.used_metaleo else 0,
                        1 if metrics.overthinking_enabled else 0,
                        metrics.rings_present,
                        clamp(metrics.quality),
                    ))

                await conn.commit()

        except Exception:
            # Silent fail — do NOTHING
            pass

    async def async_query_similar(
        self,
        metrics: MathState,
        top_k: int = 5,
        min_quality: float = 0.0,
    ) -> List[Dict[str, Any]]:
        """
        Find past episodes with similar internal configuration (async).

        Returns a list of small dicts with episode info.
        If DB is empty, or any error occurs — returns [].
        """
        if not MATH_AVAILABLE or state_to_features is None:
            return []

        try:
            # Convert query state to vector
            query_vec = state_to_features(metrics)

            async with aiosqlite.connect(str(self.db_path)) as conn:
                conn.row_factory = aiosqlite.Row
                async with conn.cursor() as cur:
                    # Get all episodes (for small DBs this is fine)
                    await cur.execute("""
                        SELECT
                            id, created_at, prompt, reply, quality,
                            entropy, novelty, arousal, pulse,
                            trauma_level, active_themes, emerging_score, fading_score,
                            reply_len_norm, unique_ratio,
                            expert_temp, expert_semantic,
                            metaleo_weight, used_metaleo, overthinking_on, rings_present
                        FROM episodes
                        WHERE quality >= ?
                        ORDER BY created_at DESC
                        LIMIT 500
                    """, (min_quality,))

                    rows = await cur.fetchall()

            if not rows:
                return []

            # Compute cosine similarity for each episode
            scored = []
            for row in rows:
                # Reconstruct episode vector (same order as state_to_features)
                ep_vec = [
                    row["entropy"],
                    row["novelty"],
                    row["arousal"],
                    row["pulse"],
                    row["trauma_level"],
                    row["active_themes"],
                    row["emerging_score"],
                    row["fading_score"],
                    row["reply_len_norm"],
                    row["unique_ratio"],
                    row["expert_temp"],
                    row["expert_semantic"],
                    row["metaleo_weight"],
                    float(row["used_metaleo"]),
                    float(row["overthinking_on"]),
                    float(row["rings_present"]),
                ]

                # Cosine similarity
                dot = sum(a * b for a, b in zip(query_vec, ep_vec))
                norm_q = sum(a * a for a in query_vec) ** 0.5
                norm_ep = sum(b * b for b in ep_vec) ** 0.5

                if norm_q > 0 and norm_ep > 0:
                    sim = dot / (norm_q * norm_ep)
                else:
                    sim = 0.0

                scored.append((sim, row))

            # Sort by similarity descending
            scored.sort(key=lambda x: x[0], reverse=True)

            # Return top_k results
            results = []
            for sim, row in scored[:top_k]:
                results.append({
                    "id": row["id"],
                    "similarity": sim,
                    "prompt": row["prompt"],
                    "reply": row["reply"],
                    "quality": row["quality"],
                    "created_at": row["created_at"],
                })

            return results

        except Exception:
            # Silent fail
            return []

    # Override sync methods to do nothing (use async versions)
    def _ensure_schema(self) -> None:
        """Sync wrapper - does nothing. Use async_init() instead."""
        pass

    def observe_episode(self, episode: Episode) -> None:
        """Sync wrapper - does nothing. Use async_observe_episode() instead."""
        pass

    def query_similar(
        self,
        metrics: MathState,
        top_k: int = 5,
        min_quality: float = 0.0,
    ) -> List[Dict[str, Any]]:
        """Sync wrapper - returns empty. Use async_query_similar() instead."""
        return []


__all__ = ["AsyncRAGBrain"]
