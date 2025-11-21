#!/usr/bin/env python3
"""
episodes.py — Episodic RAG for Leo's inner life

Leo remembers specific moments: prompt + reply + metrics.
This is his episodic memory — structured recall of his own experiences.

No external APIs. No heavy embeddings. Just local SQLite + simple similarity.
"""

from __future__ import annotations

import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Any

# Safe import: mathbrain for MathState
try:
    from mathbrain import MathState, state_to_features
    MATH_AVAILABLE = True
except ImportError:
    MathState = Any  # type: ignore
    MATH_AVAILABLE = False
    state_to_features = None  # type: ignore

RAG_AVAILABLE = True  # Set to False on catastrophic init error


@dataclass
class Episode:
    """One moment in Leo's life."""
    prompt: str
    reply: str
    metrics: MathState  # type: ignore


def cosine_distance(a: List[float], b: List[float]) -> float:
    """Compute cosine distance between two vectors (1 - cosine similarity)."""
    if len(a) != len(b):
        return 1.0
        
    dot = sum(x * y for x, y in zip(a, b))
    na = sum(x * x for x in a) ** 0.5
    nb = sum(y * y for y in b) ** 0.5
    
    if na == 0 or nb == 0:
        return 1.0
        
    similarity = dot / (na * nb)
    return 1.0 - similarity


class RAGBrain:
    """
    Local episodic memory for Leo.
    
    Stores (prompt, reply, MathState, quality) as episodes in SQLite.
    Provides simple similarity search over internal metrics + tokens.
    NO required coupling: safe to ignore if unavailable.
    """
    
    def __init__(self, db_path: Path | None = None) -> None:
        """
        Args:
            db_path: Path to SQLite DB (default: state/leo_rag.sqlite3)
        """
        if db_path is None:
            # Default: same pattern as other state files
            base = Path(__file__).parent
            db_path = base / "state" / "leo_rag.sqlite3"
            
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            self._ensure_schema()
        except Exception:
            # Silent fail — RAG must never break Leo
            global RAG_AVAILABLE
            RAG_AVAILABLE = False
            
    def _ensure_schema(self) -> None:
        """Create tables if they don't exist."""
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()
        
        cur.execute("""
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
        
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_episodes_created
            ON episodes(created_at)
        """)
        
        conn.commit()
        conn.close()
        
    def observe_episode(self, episode: Episode) -> None:
        """
        Insert one episode into the DB.
        
        MUST:
        - clamp all floats to [0, 1] or reasonable ranges
        - ignore NaNs and replace with 0.0
        - catch all sqlite errors and fail silently
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
                
            conn = sqlite3.connect(str(self.db_path))
            cur = conn.cursor()
            
            cur.execute("""
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
            
            conn.commit()
            conn.close()
            
        except Exception:
            # Silent fail — do NOTHING
            pass
            
    def query_similar(
        self,
        metrics: MathState,  # type: ignore
        top_k: int = 5,
        min_quality: float = 0.0,
    ) -> List[Dict[str, Any]]:
        """
        Find past episodes with similar internal configuration.
        
        Returns a list of small dicts with episode info.
        If DB is empty, or any error occurs — returns [].
        """
        if not MATH_AVAILABLE or state_to_features is None:
            return []
            
        try:
            # Convert query state to vector
            query_vec = state_to_features(metrics)
            
            conn = sqlite3.connect(str(self.db_path))
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            
            # Get all episodes (for small DBs this is fine)
            cur.execute("""
                SELECT * FROM episodes
                WHERE quality >= ?
                ORDER BY created_at DESC
                LIMIT 1000
            """, (min_quality,))
            
            rows = cur.fetchall()
            conn.close()
            
            if not rows:
                return []
                
            # Score each episode by cosine distance
            scored: List[tuple[float, Dict[str, Any]]] = []
            
            for row in rows:
                # Reconstruct vector from stored columns
                episode_vec = [
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
                    float(row["rings_present"] > 0),
                    # Expert one-hot (5 dims) - we don't store this, so use zeros
                    0.0, 0.0, 0.0, 0.0, 0.0,
                ]
                
                # Pad to match query_vec length if needed
                while len(episode_vec) < len(query_vec):
                    episode_vec.append(0.0)
                episode_vec = episode_vec[:len(query_vec)]
                
                distance = cosine_distance(query_vec, episode_vec)
                
                scored.append((distance, {
                    "episode_id": row["id"],
                    "created_at": row["created_at"],
                    "quality": row["quality"],
                    "distance": distance,
                    "entropy": row["entropy"],
                    "novelty": row["novelty"],
                    "arousal": row["arousal"],
                    "trauma_level": row["trauma_level"],
                    "prompt": row["prompt"],
                    "reply": row["reply"],
                }))
                
            # Sort by distance (lowest = most similar)
            scored.sort(key=lambda x: x[0])
            
            # Return top_k
            return [item[1] for item in scored[:top_k]]
            
        except Exception:
            # Silent fail — return empty
            return []
            
    def get_summary_for_state(
        self,
        metrics: MathState,  # type: ignore
        top_k: int = 10,
    ) -> Dict[str, Any]:
        """
        Convenience method for math.py / leo.py:
        
        - query_similar(...)
        - compute aggregate stats
        
        Return a dict with avg_quality, max_quality, mean_distance, count.
        If no episodes — return a dict with zeros.
        """
        similar = self.query_similar(metrics, top_k=top_k)
        
        if not similar:
            return {
                "count": 0,
                "avg_quality": 0.0,
                "max_quality": 0.0,
                "mean_distance": 1.0,
            }
            
        qualities = [ep["quality"] for ep in similar]
        distances = [ep["distance"] for ep in similar]
        
        return {
            "count": len(similar),
            "avg_quality": sum(qualities) / len(qualities) if qualities else 0.0,
            "max_quality": max(qualities) if qualities else 0.0,
            "mean_distance": sum(distances) / len(distances) if distances else 1.0,
        }


__all__ = ["RAGBrain", "Episode", "RAG_AVAILABLE"]

