#!/usr/bin/env python3
"""
async_santaclaus.py — Async Resonant Recall Layer

Async version of SantaKlaus for async Leo.

Changes from sync version:
- recall() is now async def
- Database queries use aiosqlite
- last_used_at update is async
"""

from __future__ import annotations

import time
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence

# Async database
import aiosqlite

# Import from sync santaclaus for constants and data structures
from santaclaus import (
    SantaContext,
    RECENCY_WINDOW_HOURS,
    RECENCY_PENALTY_STRENGTH,
    STICKY_PHRASES,
    tokenize,
)


# ============================================================================
# ASYNC SANTA KLAUS
# ============================================================================

class AsyncSantaKlaus:
    """
    Async resonant recall layer for Leo.

    Remembers Leo's best moments (snapshots) and brings them back
    when they resonate with the current prompt.

    ASYNC: All database operations are non-blocking.
    """

    def __init__(
        self,
        db_path: Path | str,
        max_memories: int = 5,
        max_tokens_per_memory: int = 64,
        alpha: float = 0.3,
    ) -> None:
        """
        Args:
            db_path: path to Leo's SQLite state file
            max_memories: how many snapshots to recall per prompt
            max_tokens_per_memory: truncate recalled text before scoring
            alpha: overall strength of sampling bias
        """
        self.db_path = Path(db_path)
        self.max_memories = max_memories
        self.max_tokens_per_memory = max_tokens_per_memory
        self.alpha = alpha

    async def recall(
        self,
        field: Any,  # AsyncLeoField
        prompt_text: str,
        pulse: Dict[str, float],
        active_themes: Optional[Sequence[str]] = None,
    ) -> Optional[SantaContext]:
        """
        Main entry point (async).

        Returns None on any error or if there is nothing useful to recall.
        """
        try:
            # Early exits
            if not prompt_text or not prompt_text.strip():
                return None

            if not self.db_path.exists():
                return None

            # Tokenize prompt
            prompt_tokens = tokenize(prompt_text)
            prompt_token_set = set(prompt_tokens)

            if not prompt_token_set:
                return None

            # Query snapshots (ASYNC)
            try:
                async with aiosqlite.connect(str(self.db_path)) as conn:
                    conn.row_factory = aiosqlite.Row

                    # Check if snapshots table exists
                    async with conn.cursor() as cur:
                        await cur.execute("""
                            SELECT name FROM sqlite_master
                            WHERE type='table' AND name='snapshots'
                        """)
                        table_check = await cur.fetchone()
                        if not table_check:
                            return None

                    # Get recent snapshots (last 512 to keep it cheap)
                    async with conn.cursor() as cur:
                        await cur.execute("""
                            SELECT id, text, quality, emotional, created_at, last_used_at, use_count
                            FROM snapshots
                            ORDER BY created_at DESC
                            LIMIT 512
                        """)
                        rows = await cur.fetchall()

            except Exception:
                # Silent fallback on DB errors
                return None

            if not rows:
                return None

            # Score each snapshot
            scored: List[tuple[float, dict]] = []

            for row in rows:
                snapshot_text = row["text"]
                if not snapshot_text:
                    continue

                snapshot_tokens = tokenize(snapshot_text)
                snapshot_token_set = set(snapshot_tokens)

                if not snapshot_token_set:
                    continue

                # 1. Token overlap (Jaccard)
                overlap = len(prompt_token_set & snapshot_token_set)
                union = len(prompt_token_set | snapshot_token_set)
                token_overlap = overlap / union if union > 0 else 0.0

                # 2. Theme overlap (if available)
                theme_overlap = 0.0
                if active_themes:
                    # Simple: count how many active theme words appear in snapshot
                    theme_words_in_snapshot = sum(1 for t in active_themes if t in snapshot_token_set)
                    theme_overlap = theme_words_in_snapshot / len(active_themes) if active_themes else 0.0

                # 3. Arousal proximity
                snap_arousal = row["emotional"] or 0.0
                current_arousal = pulse.get("arousal", 0.0)
                arousal_diff = abs(current_arousal - snap_arousal)
                arousal_score = max(0.0, 1.0 - arousal_diff)

                # 4. Quality prior
                quality = row["quality"] or 0.5

                # 5. RECENCY PENALTY
                # Recent usage reduces effective quality, giving other memories a chance
                last_used = row["last_used_at"] or 0
                snapshot_id = row["id"]  # Save for later update
                now = int(time.time())

                if last_used > 0:
                    hours_since_use = (now - last_used) / 3600.0
                    if hours_since_use < RECENCY_WINDOW_HOURS:
                        # Penalty is strongest right after use, decays to zero over window
                        recency_penalty = 1.0 - (hours_since_use / RECENCY_WINDOW_HOURS)
                    else:
                        recency_penalty = 0.0  # Outside window = no penalty
                else:
                    recency_penalty = 0.0  # Never used = no penalty

                # Apply penalty to quality component
                quality_with_recency = quality * (1.0 - RECENCY_PENALTY_STRENGTH * recency_penalty)

                # STICKY PHRASE PENALTY (Option D - Musketeers)
                # Known contaminated phrases get 90% penalty to prevent recall
                snapshot_lower = snapshot_text.lower()
                for phrase in STICKY_PHRASES:
                    if phrase in snapshot_lower:
                        # 90% penalty - almost kill this snapshot's chance
                        quality_with_recency *= 0.1
                        break  # One penalty is enough

                # Combine scores (with sticky phrase penalty applied)
                score = (
                    0.4 * token_overlap +
                    0.2 * theme_overlap +
                    0.2 * arousal_score +
                    0.2 * quality_with_recency
                )

                if score > 0.1:  # threshold
                    scored.append((score, {
                        "id": snapshot_id,
                        "text": snapshot_text,
                        "tokens": snapshot_tokens,
                    }))

            if not scored:
                return None

            # Sort by score descending, take top max_memories
            scored.sort(key=lambda x: x[0], reverse=True)
            top_memories = scored[:self.max_memories]

            # Build recalled texts (truncate if needed)
            recalled_texts: List[str] = []
            all_recalled_tokens: List[str] = []

            for _, memory in top_memories:
                text = memory["text"]
                tokens = memory["tokens"]

                # Truncate to max_tokens_per_memory
                if len(tokens) > self.max_tokens_per_memory:
                    truncated_tokens = tokens[:self.max_tokens_per_memory]
                    # Reconstruct text (simple: join with spaces)
                    text = " ".join(truncated_tokens)

                recalled_texts.append(text)
                all_recalled_tokens.extend(tokens)

            # Build token boosts
            token_counts = Counter(all_recalled_tokens)
            if not token_counts:
                return None

            max_count = max(token_counts.values())
            token_boosts: Dict[str, float] = {}
            for token, count in token_counts.items():
                # Normalize to [0, 1] then scale by alpha
                normalized = count / max_count if max_count > 0 else 0.0
                token_boosts[token] = self.alpha * normalized

            # UPDATE last_used_at for winning snapshot (ASYNC)
            if top_memories:
                try:
                    winning_id = top_memories[0][1].get("id")
                    if winning_id is not None:
                        async with aiosqlite.connect(str(self.db_path)) as conn:
                            async with conn.cursor() as cur:
                                await cur.execute("""
                                    UPDATE snapshots
                                    SET last_used_at = ?, use_count = use_count + 1
                                    WHERE id = ?
                                """, (int(time.time()), winning_id))
                            await conn.commit()
                except Exception:
                    pass  # Silent fallback - recency update must never break recall

            return SantaContext(
                recalled_texts=recalled_texts,
                token_boosts=token_boosts,
            )

        except Exception:
            # Silent fallback on any error
            return None


__all__ = ["AsyncSantaKlaus"]
