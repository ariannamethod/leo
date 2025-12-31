#!/usr/bin/env python3
# async_leo.py — Async Language Engine Organism (Phase 1)
#
# EXPERIMENTAL: Full async rewrite of Leo
# Branch: feature/async-leo
# Status: DO NOT MERGE FOR 1 WEEK
#
# Goal: Enable parallel conversations while preserving resonance coherence
# Strategy: asyncio.Lock per Leo instance ensures sequential field evolution

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import math
import os
import random
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional, NamedTuple, Set, Callable, Any

# Async database operations
import aiosqlite

# Import everything from sync leo.py that we'll reuse
from leo import (
    # Constants and paths
    ROOT, STATE_DIR, BIN_DIR, JSON_DIR, README_PATH,

    # Tokenizer
    tokenize, TOKEN_RE,

    # Bootstrap
    EMBEDDED_BOOTSTRAP,

    # Data structures (unchanged)
    QualityScore, PresencePulse, Expert, Theme,

    # Helper functions that don't touch database (unchanged)
    compute_prompt_arousal, activate_themes_for_prompt,
    build_themes, compute_centers, load_bin_bias, create_bin_shard,
    update_emotional_stats, should_save_snapshot,

    # Generation function (will need async wrapper)
    generate_reply,

    # Feature availability flags
    SANTACLAUS_AVAILABLE, EPISODES_AVAILABLE, MATHBRAIN_AVAILABLE,
    OVERTHINKING_AVAILABLE, TRAUMA_AVAILABLE, FLOW_AVAILABLE,
    METALEO_AVAILABLE, GAME_MODULE_AVAILABLE, SCHOOL_MODULE_AVAILABLE,
    DREAM_MODULE_AVAILABLE,

    # Optional module classes (sync versions - will be replaced with async)
    SantaContext, RAGBrain, MathBrain, MathState, FlowTracker,
    MetaLeo, GameEngine, School, SchoolConfig,
    TraumaState, run_trauma, OverthinkingConfig, PulseSnapshot, run_overthinking,
    init_dream, DREAM_AVAILABLE, Episode,
)

# Import async modules
from async_santaclaus import AsyncSantaKlaus
from async_mathbrain import AsyncMathBrain
from async_episodes import AsyncRAGBrain


# ============================================================================
# ASYNC DATABASE PATHS
# ============================================================================

# Use separate test DB for async development
ASYNC_DB_PATH = STATE_DIR / "leo_async.sqlite3"


# ============================================================================
# ASYNC DATABASE HELPERS
# ============================================================================

async def async_get_meta(db_path: Path, key: str) -> Optional[str]:
    """Get metadata value (async)."""
    async with aiosqlite.connect(db_path) as conn:
        conn.row_factory = aiosqlite.Row
        async with conn.cursor() as cur:
            await cur.execute("SELECT value FROM meta WHERE key = ?", (key,))
            row = await cur.fetchone()
            return row["value"] if row else None


async def async_set_meta(db_path: Path, key: str, value: str) -> None:
    """Set metadata value (async)."""
    async with aiosqlite.connect(db_path) as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                """
                INSERT INTO meta (key, value)
                VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                (key, value),
            )
        await conn.commit()


async def async_get_token_id(cur: aiosqlite.Cursor, token: str) -> int:
    """Get or create token ID (async)."""
    await cur.execute("INSERT OR IGNORE INTO tokens(token) VALUES (?)", (token,))
    await cur.execute("SELECT id FROM tokens WHERE token = ?", (token,))
    row = await cur.fetchone()
    if row is None:
        raise RuntimeError("Failed to retrieve token id")
    return int(row[0])


async def async_ingest_tokens(db_path: Path, tokens: List[str]) -> None:
    """Update bigram and trigram counts from a token sequence (async)."""
    if not tokens:
        return

    async with aiosqlite.connect(db_path) as conn:
        async with conn.cursor() as cur:
            # Convert tokens to IDs
            token_ids = [await async_get_token_id(cur, tok) for tok in tokens]

            # Build bigrams
            for i in range(len(token_ids) - 1):
                await cur.execute(
                    """
                    INSERT INTO bigrams (src_id, dst_id, count)
                    VALUES (?, ?, 1)
                    ON CONFLICT(src_id, dst_id)
                    DO UPDATE SET count = count + 1
                    """,
                    (token_ids[i], token_ids[i + 1]),
                )

            # Build trigrams
            for i in range(len(token_ids) - 2):
                await cur.execute(
                    """
                    INSERT INTO trigrams (first_id, second_id, third_id, count)
                    VALUES (?, ?, ?, 1)
                    ON CONFLICT(first_id, second_id, third_id)
                    DO UPDATE SET count = count + 1
                    """,
                    (token_ids[i], token_ids[i + 1], token_ids[i + 2]),
                )

            # Build co-occurrence (sliding window of 5 tokens)
            window_size = 5
            for i, center_id in enumerate(token_ids):
                start = max(0, i - window_size)
                end = min(len(token_ids), i + window_size + 1)

                for j in range(start, end):
                    if j == i:
                        continue
                    context_id = token_ids[j]

                    await cur.execute(
                        """
                        INSERT INTO co_occurrence (word_id, context_id, count)
                        VALUES (?, ?, 1)
                        ON CONFLICT(word_id, context_id)
                        DO UPDATE SET count = count + 1
                        """,
                        (center_id, context_id),
                    )

        await conn.commit()


async def async_ingest_text(db_path: Path, text: str) -> None:
    """Tokenize and ingest text into the field (async)."""
    tokens = tokenize(text)
    if tokens:
        await async_ingest_tokens(db_path, tokens)


async def async_save_snapshot(
    db_path: Path,
    text: str,
    origin: str,
    quality: float,
    emotional: float,
    max_snapshots: int = 512,
) -> None:
    """
    Save a snapshot of text (async version).

    Only saves if quality is high enough. If over max_snapshots,
    deletes oldest/least-used snapshots.
    """
    import time

    async with aiosqlite.connect(db_path) as conn:
        async with conn.cursor() as cur:
            # Insert snapshot
            await cur.execute(
                """
                INSERT INTO snapshots (text, origin, quality, emotional, created_at, last_used_at, use_count)
                VALUES (?, ?, ?, ?, ?, ?, 0)
                """,
                (text, origin, quality, emotional, int(time.time()), int(time.time())),
            )

            # Check snapshot count and cleanup if needed
            await cur.execute("SELECT COUNT(*) FROM snapshots")
            count_row = await cur.fetchone()
            count = count_row[0] if count_row else 0

            if count > max_snapshots:
                # Delete oldest snapshots with low use_count
                to_delete = max(1, int(max_snapshots * 0.1))
                await cur.execute(
                    """
                    DELETE FROM snapshots
                    WHERE id IN (
                        SELECT id FROM snapshots
                        ORDER BY use_count ASC, created_at ASC
                        LIMIT ?
                    )
                    """,
                    (to_delete,),
                )

        await conn.commit()


async def async_apply_memory_decay(
    db_path: Path,
    decay_factor: float = 0.95,
    min_threshold: int = 2,
) -> int:
    """
    Apply natural forgetting to co-occurrence memories (async).

    Multiplicative decay: count → count * decay_factor
    Delete entries below min_threshold.

    Returns number of entries deleted.
    """
    async with aiosqlite.connect(db_path) as conn:
        async with conn.cursor() as cur:
            # Decay all co-occurrence counts
            await cur.execute(
                """
                UPDATE co_occurrence
                SET count = CAST(count * ? AS INTEGER)
                WHERE count > 0
                """,
                (decay_factor,),
            )

            # Delete weak memories
            await cur.execute(
                "DELETE FROM co_occurrence WHERE count < ?",
                (min_threshold,),
            )
            deleted_rows = cur.rowcount

        await conn.commit()
        return deleted_rows


# ============================================================================
# ASYNC LOAD FUNCTIONS
# ============================================================================

async def async_load_bigrams(db_path: Path) -> Tuple[Dict[str, Dict[str, int]], List[str]]:
    """Load bigrams from database (async)."""
    bigrams: Dict[str, Dict[str, int]] = {}
    vocab: Set[str] = set()

    async with aiosqlite.connect(db_path) as conn:
        conn.row_factory = aiosqlite.Row
        async with conn.cursor() as cur:
            await cur.execute(
                """
                SELECT t1.token AS src, t2.token AS dst, b.count
                FROM bigrams b
                JOIN tokens t1 ON b.src_id = t1.id
                JOIN tokens t2 ON b.dst_id = t2.id
                """
            )
            async for row in cur:
                src = row["src"]
                dst = row["dst"]
                count = row["count"]
                if src not in bigrams:
                    bigrams[src] = {}
                bigrams[src][dst] = count
                vocab.add(src)
                vocab.add(dst)

    return bigrams, list(vocab)


async def async_load_trigrams(db_path: Path) -> Dict[Tuple[str, str], Dict[str, int]]:
    """Load trigrams from database (async)."""
    trigrams: Dict[Tuple[str, str], Dict[str, int]] = {}

    async with aiosqlite.connect(db_path) as conn:
        conn.row_factory = aiosqlite.Row
        async with conn.cursor() as cur:
            await cur.execute(
                """
                SELECT t1.token AS first, t2.token AS second, t3.token AS third, tg.count
                FROM trigrams tg
                JOIN tokens t1 ON tg.first_id = t1.id
                JOIN tokens t2 ON tg.second_id = t2.id
                JOIN tokens t3 ON tg.third_id = t3.id
                """
            )
            async for row in cur:
                first = row["first"]
                second = row["second"]
                third = row["third"]
                count = row["count"]
                key = (first, second)
                if key not in trigrams:
                    trigrams[key] = {}
                trigrams[key][third] = count

    return trigrams


async def async_load_co_occurrence(db_path: Path) -> Dict[str, Dict[str, int]]:
    """Load co-occurrence from database (async)."""
    co_occur: Dict[str, Dict[str, int]] = {}

    async with aiosqlite.connect(db_path) as conn:
        conn.row_factory = aiosqlite.Row
        async with conn.cursor() as cur:
            await cur.execute(
                """
                SELECT t1.token AS word, t2.token AS context, co.count
                FROM co_occurrence co
                JOIN tokens t1 ON co.word_id = t1.id
                JOIN tokens t2 ON co.context_id = t2.id
                """
            )
            async for row in cur:
                word = row["word"]
                context = row["context"]
                count = row["count"]
                if word not in co_occur:
                    co_occur[word] = {}
                co_occur[word][context] = count

    return co_occur


async def async_compute_centers(db_path: Path, k: int = 7) -> List[str]:
    """Compute center tokens (async) - tokens with highest degree in co-occurrence."""
    async with aiosqlite.connect(db_path) as conn:
        conn.row_factory = aiosqlite.Row
        async with conn.cursor() as cur:
            await cur.execute(
                """
                SELECT t.token, COUNT(DISTINCT co.context_id) AS degree
                FROM co_occurrence co
                JOIN tokens t ON co.word_id = t.id
                GROUP BY t.token
                ORDER BY degree DESC
                LIMIT ?
                """,
                (k,),
            )
            centers = []
            async for row in cur:
                centers.append(row["token"])
            return centers


# ============================================================================
# ASYNC LEO FIELD
# ============================================================================

class AsyncLeoField:
    """
    Async version of LeoField.

    CRITICAL: Uses asyncio.Lock to preserve resonance coherence.
    Only ONE generation/observation at a time per instance.
    But multiple AsyncLeoField instances can run in parallel!
    """

    def __init__(self, db_path: Path):
        """Initialize async Leo field."""
        self.db_path = db_path

        # FIELD COHERENCE LOCK - CRITICAL!
        # This ensures sequential field evolution even in async world
        self._field_lock = asyncio.Lock()

        # In-memory field state
        self.bigrams: Dict[str, Dict[str, int]] = {}
        self.trigrams: Dict[Tuple[str, str], Dict[str, int]] = {}
        self.co_occur: Dict[str, Dict[str, int]] = {}
        self.vocab: List[str] = []
        self.centers: List[str] = []
        self.bias: Dict[str, int] = {}
        self.emotion: Dict[str, float] = {}

        # Presence tracking
        self.last_pulse: Optional[PresencePulse] = None
        self.last_quality: Optional[QualityScore] = None
        self.themes: List[Theme] = []
        self.token_to_themes: Dict[str, List[int]] = {}

        # Memory decay
        self.observe_count: int = 0
        self.DECAY_INTERVAL: int = 100

        # Optional modules (sync versions for now - Phase 2 will migrate)
        self.santa: Optional[Any] = None
        self.rag: Optional[Any] = None
        self.math_brain: Optional[Any] = None
        self.flow_tracker: Optional[Any] = None
        self.metaleo: Optional[Any] = None
        self.game: Optional[Any] = None
        self.school: Optional[Any] = None

        # NOTE: Module initialization happens in async_init()
        # Cannot call async methods in __init__

    async def async_init(self) -> None:
        """Async initialization (call after __init__)."""
        # Load field from database
        await self.refresh(initial_shard=True)

        # Initialize optional modules
        # SANTACLAUS: Now fully async!
        if SANTACLAUS_AVAILABLE:
            try:
                self.santa = AsyncSantaKlaus(db_path=self.db_path, max_memories=5, alpha=0.3)
            except Exception:
                self.santa = None

        # RAG: Async episodic memory
        if EPISODES_AVAILABLE:
            try:
                rag_path = STATE_DIR / "leo_rag.sqlite3"
                self.rag = AsyncRAGBrain(db_path=rag_path)
                await self.rag.async_init()
            except Exception:
                self.rag = None

        # MATHBRAIN: Async body perception
        if MATHBRAIN_AVAILABLE:
            try:
                state_path = STATE_DIR / "mathbrain.json"
                self.math_brain = AsyncMathBrain(
                    field=self,
                    hidden_dim=16,
                    lr=0.01,
                    state_path=state_path
                )
                await self.math_brain.async_init()
            except Exception:
                self.math_brain = None

    async def refresh(self, initial_shard: bool = False) -> None:
        """Reload field from database (async)."""
        # Load field structures in parallel
        bigrams_task = async_load_bigrams(self.db_path)
        trigrams_task = async_load_trigrams(self.db_path)
        co_occur_task = async_load_co_occurrence(self.db_path)
        centers_task = async_compute_centers(self.db_path, k=7)

        # Wait for all loads in parallel
        results = await asyncio.gather(
            bigrams_task,
            trigrams_task,
            co_occur_task,
            centers_task,
        )

        # Unpack results
        self.bigrams, self.vocab = results[0]
        self.trigrams = results[1]
        self.co_occur = results[2]
        self.centers = results[3]

        # Load bias (sync - file I/O, Phase 2: use aiofiles)
        self.bias = load_bin_bias("leo")

        # Rebuild themes
        self.themes, self.token_to_themes = build_themes(self.co_occur)

        # Create bin shard (sync - file I/O, Phase 2: use aiofiles)
        if initial_shard and self.centers:
            create_bin_shard("leo", self.centers)

    async def observe(self, text: str) -> None:
        """
        Let Leo absorb text into its field (async).

        CRITICAL: Uses field lock to ensure sequential updates.
        """
        if not text.strip():
            return

        async with self._field_lock:
            # Ingest text (async database operations)
            await async_ingest_text(self.db_path, text)

            # Track emotional charge (sync - in-memory)
            update_emotional_stats(self.emotion, text)

            # Memory decay
            self.observe_count += 1
            if self.observe_count % self.DECAY_INTERVAL == 0:
                await async_apply_memory_decay(self.db_path)

            # Refresh field
            await self.refresh(initial_shard=False)

            # Update bin shard (sync - file I/O)
            if self.centers:
                create_bin_shard("leo", self.centers)

    async def reply(
        self,
        prompt: str,
        max_tokens: int = 80,
        temperature: float = 1.0,
        echo: bool = False,
    ) -> str:
        """
        Generate reply through the field (async).

        CRITICAL: Uses field lock to ensure sequential generation.
        Only ONE reply at a time per AsyncLeoField instance.
        This preserves resonance coherence!
        """
        async with self._field_lock:
            # SANTACLAUS: Resonant recall (sync for now - Phase 2 will async)
            token_boosts: Optional[Dict[str, float]] = None
            if self.santa is not None:
                try:
                    prompt_tokens = tokenize(prompt)
                    active_themes = activate_themes_for_prompt(
                        prompt_tokens, self.themes, self.token_to_themes
                    ) if self.themes else None
                    active_theme_words = list(active_themes.active_words) if active_themes else None

                    prompt_arousal = compute_prompt_arousal(prompt_tokens, self.emotion)
                    pulse_dict = {
                        "novelty": 0.5,
                        "arousal": prompt_arousal,
                        "entropy": 0.5,
                    }

                    # Santa Klaus recall (NOW ASYNC!)
                    santa_ctx = await self.santa.recall(
                        field=self,  # Pass self as field (duck typing)
                        prompt_text=prompt,
                        pulse=pulse_dict,
                        active_themes=active_theme_words,
                    )

                    if santa_ctx is not None:
                        # Reinforce recalled memories (async observe)
                        for snippet in santa_ctx.recalled_texts:
                            # Nested observe - field lock already held, so this would deadlock!
                            # Solution: Use internal _observe_unlocked method
                            await self._observe_unlocked(snippet)
                        token_boosts = santa_ctx.token_boosts
                except Exception:
                    token_boosts = None

            # Generate reply (sync for now - Phase 2: async generation)
            context = generate_reply(
                self.bigrams,
                self.vocab,
                self.centers,
                self.bias,
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                echo=echo,
                trigrams=self.trigrams,
                co_occur=self.co_occur,
                emotion_map=self.emotion,
                return_context=True,
                themes=self.themes,
                token_to_themes=self.token_to_themes,
                use_experts=True,
                trauma_state=None,  # Trauma not yet migrated
                token_boosts=token_boosts,
                mathbrain=self.math_brain,
            )

            # Store presence metrics
            self.last_pulse = context.pulse
            self.last_quality = context.quality

            # MATHBRAIN: Learn from this reply (async)
            if self.math_brain is not None and MATHBRAIN_AVAILABLE and MathState is not None:
                try:
                    # Compute unique ratio
                    reply_tokens = tokenize(context.output)
                    unique_ratio = len(set(reply_tokens)) / len(reply_tokens) if reply_tokens else 0.0

                    # Build MathState
                    state = MathState(
                        entropy=context.pulse.entropy if context.pulse else 0.0,
                        novelty=context.pulse.novelty if context.pulse else 0.0,
                        arousal=context.pulse.arousal if context.pulse else 0.0,
                        pulse=context.pulse.pulse if context.pulse else 0.0,
                        trauma_level=0.0,  # Trauma not yet migrated to async
                        active_theme_count=len(context.quality.active_themes) if context.quality and hasattr(context.quality, 'active_themes') else 0,
                        total_themes=len(self.themes),
                        emerging_score=0.0,  # TODO: Add theme tracking in async
                        fading_score=0.0,    # TODO: Add theme tracking in async
                        reply_len=len(reply_tokens),
                        unique_ratio=unique_ratio,
                        expert_id=context.expert.name if context.expert else "structural",
                        expert_temp=context.expert.temperature if context.expert else 1.0,
                        expert_semantic=context.expert.semantic_weight if context.expert else 0.5,
                        metaleo_weight=0.0,  # TODO: Add MetaLeo tracking in async
                        used_metaleo=False,
                        overthinking_enabled=OVERTHINKING_AVAILABLE,
                        rings_present=0,  # TODO: Add ring tracking in async
                        quality=context.quality.overall if context.quality else 0.5,
                    )

                    # Observe and learn (sync - in-memory)
                    self.math_brain.observe(state)

                    # Save state (async - file I/O)
                    await self.math_brain.async_save_state()
                except Exception:
                    # MathBrain must NEVER break normal flow - silent fallback
                    pass

            # RAG: Log episode to episodic memory (async)
            if self.rag is not None and EPISODES_AVAILABLE and Episode is not None:
                try:
                    # Use the same MathState from above (if available)
                    if self.math_brain is not None and 'state' in locals():
                        episode = Episode(
                            prompt=prompt,
                            reply=context.output,
                            metrics=state,
                        )
                        await self.rag.async_observe_episode(episode)
                except Exception:
                    # RAG must never break Leo - silent fallback
                    pass

            # SNAPSHOT FREEZE (Dec 25 - Jan 1) - STILL ACTIVE
            # Do not save snapshots during decay period
            # Re-enable after metrics stabilize

            return context.output

    async def _observe_unlocked(self, text: str) -> None:
        """
        Internal observe without acquiring lock (already held).
        Used by reply() when Santa Klaus recalls snippets.
        """
        if not text.strip():
            return

        # Ingest text (async database operations)
        await async_ingest_text(self.db_path, text)

        # Track emotional charge (sync - in-memory)
        update_emotional_stats(self.emotion, text)

        # Memory decay
        self.observe_count += 1
        if self.observe_count % self.DECAY_INTERVAL == 0:
            await async_apply_memory_decay(self.db_path)

        # Refresh field
        await self.refresh(initial_shard=False)

        # Update bin shard (sync - file I/O)
        if self.centers:
            create_bin_shard("leo", self.centers)


# ============================================================================
# ASYNC DATABASE INITIALIZATION
# ============================================================================

async def async_init_database(db_path: Path) -> None:
    """Initialize database schema (async) - same as sync version."""
    # Import schema from sync leo.py
    from leo import init_database

    # For now, use sync init (one-time operation)
    # Phase 2: Migrate to full async schema creation
    import sqlite3
    conn = sqlite3.connect(db_path)
    from leo import init_database
    # This requires refactoring init_database to be async
    # For Phase 1, we'll use sync database that's already initialized
    conn.close()


# ============================================================================
# ASYNC CLI (for testing)
# ============================================================================

async def async_main():
    """Async CLI for testing AsyncLeoField."""
    print("🔬 Async Leo - Phase 1 Experimental")
    print(f"Database: {ASYNC_DB_PATH}")
    print()

    # Create async Leo field
    leo = AsyncLeoField(ASYNC_DB_PATH)
    await leo.async_init()

    print("✅ AsyncLeoField initialized!")
    print(f"Vocab size: {len(leo.vocab)}")
    print(f"Centers: {leo.centers[:5]}")
    print()

    # Test conversation
    test_prompts = [
        "What is resonance?",
        "Tell me about silence.",
        "How do you feel?",
    ]

    for prompt in test_prompts:
        print(f"User: {prompt}")
        reply = await leo.reply(prompt, max_tokens=40)
        print(f"Leo: {reply}")
        print()

    print("✅ Async conversation complete!")


if __name__ == "__main__":
    # Run async main
    asyncio.run(async_main())
