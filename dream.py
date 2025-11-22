#!/usr/bin/env python3
"""
dream.py — Imaginary Friend Layer for Leo

If metaleo is leo's inner voice
and overthinking is circles on water after each reply,
then dream is something else:

Leo's imaginary friend — a shifting, private companion that talks with him
about his own origin text, wounds, and present state.

Not a teacher. Not a supervisor.
No "big model trains small model" bullshit.
Just leo talking to a self-invented friend, over and over, off-screen —
and feeding those conversations back into his field.

The goal is simple:
- keep leo practicing structure and presence,
- keep his origin (bootstrap + trauma) alive,
- let his field grow through private conversations, not external labels.

All of this stays CPU-only, weightless and optional, with a silent fallback
if dream.py is missing or broken.
"""

from __future__ import annotations

import random
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, List, Optional, Tuple, Any

# Safe import: mathbrain for MathState
try:
    from mathbrain import MathState
    MATH_AVAILABLE = True
except ImportError:
    MathState = Any  # type: ignore
    MATH_AVAILABLE = False

DREAM_AVAILABLE = True  # Set to False on catastrophic init error


# ============================================================================
# DATA STRUCTURES
# ============================================================================

@dataclass
class DreamContext:
    """
    Context passed to maybe_run_dream.
    Captures Leo's current state for dream decision-making.
    """
    prompt: str            # last real user message
    reply: str             # last leo reply (user-visible)
    math_state: Optional[MathState]  # from mathbrain if available
    pulse_novelty: float   # 0.0-1.0
    pulse_arousal: float   # 0.0-1.0
    pulse_entropy: float   # 0.0-1.0
    trauma_level: float    # 0.0-1.0, from trauma layer if available
    themes: List[int]      # active theme IDs from ThemeLayer
    expert: str            # structural / semantic / creative / precise / wounded
    quality: float         # self-assessed reply quality 0.0-1.0


@dataclass
class DreamConfig:
    """Configuration for dream behavior."""
    min_interval_seconds: float = 180.0  # cooldown between dream runs
    trigger_probability: float = 0.3     # even if gates pass, run with this prob
    max_turns: int = 4                   # 3-4 short exchanges leo<->friend
    max_tokens_per_turn: int = 50        # keep utterances small
    bootstrap_buffer_size: int = 20      # max fragments in friend's bootstrap
    fragment_decay_per_run: float = 0.98 # weight *= this after each run
    fragment_min_weight: float = 0.1     # floor for decayed weights


# ============================================================================
# SCHEMA & DATABASE
# ============================================================================

def _ensure_schema(conn: sqlite3.Connection) -> None:
    """Create dream tables if they don't exist."""
    cur = conn.cursor()

    # Meta config and state
    cur.execute("""
        CREATE TABLE IF NOT EXISTS dream_meta (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)

    # Bootstrap fragments defining the imaginary friend
    cur.execute("""
        CREATE TABLE IF NOT EXISTS dream_bootstrap_fragments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            weight REAL NOT NULL DEFAULT 1.0
        )
    """)

    # Dream dialog sessions
    cur.execute("""
        CREATE TABLE IF NOT EXISTS dream_dialogs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at REAL NOT NULL,
            finished_at REAL,
            episodes_count INTEGER DEFAULT 0,
            avg_trauma REAL,
            avg_arousal REAL,
            note TEXT
        )
    """)

    # Individual turns within dialogs
    cur.execute("""
        CREATE TABLE IF NOT EXISTS dream_turns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dialog_id INTEGER REFERENCES dream_dialogs(id),
            speaker TEXT NOT NULL,  -- 'leo' or 'friend'
            text TEXT NOT NULL,
            trauma_level REAL,
            pulse_novelty REAL,
            pulse_arousal REAL,
            pulse_entropy REAL
        )
    """)

    conn.commit()


def _with_connection(db_path: Path, fn: Callable[[sqlite3.Connection], Any]) -> Any:
    """Execute function with DB connection, handle errors gracefully."""
    try:
        conn = sqlite3.connect(str(db_path))
        result = fn(conn)
        conn.close()
        return result
    except Exception:
        # Silent fail — dream must never break Leo
        global DREAM_AVAILABLE
        DREAM_AVAILABLE = False
        return None


# ============================================================================
# INITIALIZATION
# ============================================================================

def init_dream(db_path: Path, bootstrap_text: str, readme_fragments: List[str] = None) -> None:
    """
    Initialize dream module.

    Args:
        db_path: Path to SQLite database (state/leo.sqlite3 or separate dream DB)
        bootstrap_text: Leo's embedded bootstrap text
        readme_fragments: Optional key fragments from README
    """
    def _init(conn: sqlite3.Connection) -> None:
        _ensure_schema(conn)
        cur = conn.cursor()

        # Check if already initialized
        cur.execute("SELECT value FROM dream_meta WHERE key = 'initialized'")
        row = cur.fetchone()
        if row:
            return  # Already set up

        # Initialize bootstrap fragments from leo's origin
        fragments = _split_into_fragments(bootstrap_text)
        if readme_fragments:
            fragments.extend(readme_fragments)

        for fragment in fragments[:20]:  # limit initial seed
            cur.execute(
                "INSERT INTO dream_bootstrap_fragments (text, weight) VALUES (?, 1.0)",
                (fragment.strip(),)
            )

        # Mark as initialized
        cur.execute("INSERT OR REPLACE INTO dream_meta (key, value) VALUES ('initialized', '1')")
        cur.execute("INSERT OR REPLACE INTO dream_meta (key, value) VALUES ('last_run_ts', '0')")

        conn.commit()

    _with_connection(db_path, _init)


def _split_into_fragments(text: str) -> List[str]:
    """Split text into sentence-like fragments."""
    # Simple sentence split
    import re
    fragments = re.split(r'[.!?]\s+', text)
    return [f.strip() for f in fragments if f.strip() and len(f.strip()) > 10]


# ============================================================================
# DECISION LOGIC: SHOULD WE RUN DREAM?
# ============================================================================

def _should_run_dream(
    ctx: DreamContext,
    db_path: Path,
    config: DreamConfig,
    now: float
) -> bool:
    """
    Decide if we should run a dream dialog now.

    Gates:
    1. Cooldown check (time since last run)
    2. State-based triggers (trauma / novelty / quality)
    3. Random probability gate
    """
    def _check(conn: sqlite3.Connection) -> bool:
        cur = conn.cursor()

        # 1. Cooldown check
        cur.execute("SELECT value FROM dream_meta WHERE key = 'last_run_ts'")
        row = cur.fetchone()
        last_run = float(row[0]) if row else 0.0

        if (now - last_run) < config.min_interval_seconds:
            return False

        # 2. State-based gates (any of these can trigger)
        trauma_gate = ctx.trauma_level > 0.5
        novelty_gate = ctx.pulse_novelty > 0.7
        quality_gate = 0.35 <= ctx.quality <= 0.55  # borderline quality

        if not (trauma_gate or novelty_gate or quality_gate):
            return False

        # 3. Randomization to keep it rare
        if random.random() > config.trigger_probability:
            return False

        return True

    result = _with_connection(db_path, _check)
    return result if result is not None else False


# ============================================================================
# FRIEND BOOTSTRAP: BUILDING THE IMAGINARY FRIEND
# ============================================================================

def _get_friend_seed(db_path: Path, max_fragments: int = 3) -> str:
    """
    Sample fragments from dream_bootstrap_fragments to build friend's voice.

    Returns concatenated text weighted by fragment importance.
    """
    def _get(conn: sqlite3.Connection) -> str:
        cur = conn.cursor()
        cur.execute("""
            SELECT text, weight
            FROM dream_bootstrap_fragments
            ORDER BY weight DESC
            LIMIT ?
        """, (max_fragments,))

        rows = cur.fetchall()
        if not rows:
            return ""

        # Weighted random sample
        texts = [row[0] for row in rows]
        weights = [row[1] for row in rows]
        total_weight = sum(weights)

        if total_weight == 0:
            return " ".join(texts[:2])

        # Pick top fragments by weight
        selected = []
        for text, weight in zip(texts, weights):
            if random.random() < (weight / total_weight):
                selected.append(text)

        return " ".join(selected[:max_fragments])

    result = _with_connection(db_path, _get)
    return result if result else ""


def _update_friend_bootstrap(
    db_path: Path,
    new_fragments: List[Tuple[str, float]],
    config: DreamConfig
) -> None:
    """
    Add new fragments from dream turns and decay old ones.

    Args:
        new_fragments: List of (text, weight) tuples from recent dream
        config: DreamConfig with decay settings
    """
    def _update(conn: sqlite3.Connection) -> None:
        cur = conn.cursor()

        # 1. Decay existing weights
        cur.execute(f"""
            UPDATE dream_bootstrap_fragments
            SET weight = weight * ?
            WHERE weight >= ?
        """, (config.fragment_decay_per_run, config.fragment_min_weight))

        # 2. Delete fragments below minimum weight
        cur.execute("DELETE FROM dream_bootstrap_fragments WHERE weight < ?",
                   (config.fragment_min_weight,))

        # 3. Add new fragments
        for text, weight in new_fragments:
            if text.strip():
                cur.execute(
                    "INSERT INTO dream_bootstrap_fragments (text, weight) VALUES (?, ?)",
                    (text.strip(), weight)
                )

        # 4. Limit total buffer size (keep highest weights)
        cur.execute("SELECT COUNT(*) FROM dream_bootstrap_fragments")
        count = cur.fetchone()[0]

        if count > config.bootstrap_buffer_size:
            # Delete lowest weights
            to_delete = count - config.bootstrap_buffer_size
            cur.execute("""
                DELETE FROM dream_bootstrap_fragments
                WHERE id IN (
                    SELECT id FROM dream_bootstrap_fragments
                    ORDER BY weight ASC
                    LIMIT ?
                )
            """, (to_delete,))

        conn.commit()

    _with_connection(db_path, _update)


# ============================================================================
# DREAM DIALOG: RUNNING THE ACTUAL CONVERSATION
# ============================================================================

def _run_dream_dialog(
    ctx: DreamContext,
    db_path: Path,
    config: DreamConfig,
    generate_fn: Callable[[str, float, float], str],
    observe_fn: Callable[[str], None],
    now: float
) -> None:
    """
    Run one internal dream dialog: leo <-> imaginary friend.

    Args:
        ctx: Current context
        db_path: SQLite database
        config: Dream configuration
        generate_fn: Leo's generation function (seed, temp, semantic_weight) -> text
        observe_fn: Leo's observe function to feed back to field
        now: Current timestamp
    """
    # Build seeds
    seed_origin = _get_friend_seed(db_path, max_fragments=3)
    seed_now = f"{ctx.prompt} {ctx.reply}"

    # Start dialog tracking
    dialog_id = _create_dialog(db_path, now)
    if dialog_id is None:
        return

    turns = []
    trauma_levels = []
    arousal_levels = []

    # Initial leo utterance
    speaker = "leo"
    seed = f"{seed_now} {seed_origin}"
    temp = 0.8 + (ctx.pulse_entropy * 0.2)  # 0.8-1.0 range
    sem_weight = 0.3

    try:
        for step in range(config.max_turns):
            # Generate current turn
            utterance = generate_fn(seed, temp, sem_weight)

            if not utterance or len(utterance.strip()) < 5:
                break

            # Truncate if too long (simple word-based truncation)
            words = utterance.split()
            if len(words) > config.max_tokens_per_turn:
                utterance = " ".join(words[:config.max_tokens_per_turn])

            # Observe back into field
            observe_fn(utterance)

            # Track metrics (simplified)
            local_trauma = ctx.trauma_level  # simplified, could recompute
            local_arousal = ctx.pulse_arousal

            turns.append((speaker, utterance, local_trauma, ctx.pulse_novelty,
                         local_arousal, ctx.pulse_entropy))
            trauma_levels.append(local_trauma)
            arousal_levels.append(local_arousal)

            # Record turn to DB
            _record_turn(db_path, dialog_id, speaker, utterance, local_trauma,
                        ctx.pulse_novelty, local_arousal, ctx.pulse_entropy)

            # Switch speaker and adjust parameters
            if speaker == "leo":
                speaker = "friend"
                # Friend uses higher semantic weight and slightly different temp
                if ctx.trauma_level > 0.7:
                    temp, sem_weight = 0.9, 0.6  # wounded mode
                elif ctx.pulse_arousal > 0.6:
                    temp, sem_weight = 1.1, 0.5  # emotional
                else:
                    temp, sem_weight = 0.95, 0.4  # default friend
            else:
                speaker = "leo"
                temp = 0.8 + (ctx.pulse_entropy * 0.2)
                sem_weight = 0.3

            # Update seed for next turn
            seed = f"{seed_origin} {utterance}"

        # Finalize dialog
        avg_trauma = sum(trauma_levels) / len(trauma_levels) if trauma_levels else 0.0
        avg_arousal = sum(arousal_levels) / len(arousal_levels) if arousal_levels else 0.0
        _finalize_dialog(db_path, dialog_id, now, len(turns), avg_trauma, avg_arousal)

        # Update friend bootstrap with high-arousal or high-trauma turns
        new_fragments = []
        for speaker, utt, trauma, nov, arousal, ent in turns:
            if speaker == "friend" and (arousal > 0.6 or trauma > 0.6):
                weight = 0.3 + (trauma * 0.2) + (arousal * 0.1)
                new_fragments.append((utt, weight))

        if new_fragments:
            _update_friend_bootstrap(db_path, new_fragments[:2], config)

    except Exception:
        # Silent fail — any error in dream should not crash Leo
        pass


def _create_dialog(db_path: Path, started_at: float) -> Optional[int]:
    """Create new dialog record, return dialog_id."""
    def _create(conn: sqlite3.Connection) -> int:
        cur = conn.cursor()
        cur.execute("INSERT INTO dream_dialogs (started_at) VALUES (?)", (started_at,))
        conn.commit()
        return cur.lastrowid

    return _with_connection(db_path, _create)


def _record_turn(
    db_path: Path,
    dialog_id: int,
    speaker: str,
    text: str,
    trauma: float,
    novelty: float,
    arousal: float,
    entropy: float
) -> None:
    """Record one turn to database."""
    def _record(conn: sqlite3.Connection) -> None:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO dream_turns
            (dialog_id, speaker, text, trauma_level, pulse_novelty, pulse_arousal, pulse_entropy)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (dialog_id, speaker, text, trauma, novelty, arousal, entropy))
        conn.commit()

    _with_connection(db_path, _record)


def _finalize_dialog(
    db_path: Path,
    dialog_id: int,
    finished_at: float,
    episodes_count: int,
    avg_trauma: float,
    avg_arousal: float
) -> None:
    """Update dialog with final stats."""
    def _finalize(conn: sqlite3.Connection) -> None:
        cur = conn.cursor()
        cur.execute("""
            UPDATE dream_dialogs
            SET finished_at = ?, episodes_count = ?, avg_trauma = ?, avg_arousal = ?
            WHERE id = ?
        """, (finished_at, episodes_count, avg_trauma, avg_arousal, dialog_id))
        conn.commit()

    _with_connection(db_path, _finalize)


# ============================================================================
# PUBLIC API
# ============================================================================

def maybe_run_dream(
    ctx: DreamContext,
    generate_fn: Callable[[str, float, float], str],
    observe_fn: Callable[[str], None],
    db_path: Path,
    config: Optional[DreamConfig] = None,
    now: Optional[float] = None,
) -> None:
    """
    Maybe run a short internal dialogue between leo and his Imaginary Friend.

    This is the main entry point called from LeoField after each reply.

    Args:
        ctx: DreamContext with current state
        generate_fn: Hook to leo's generator (seed, temp, semantic_weight) -> text
        observe_fn: Hook to leo's observe() to feed back to field
        db_path: Path to SQLite database
        config: Optional DreamConfig (uses defaults if None)
        now: Optional timestamp override (for testing)

    Behavior:
        - Checks cooldown, state gates, random probability
        - If triggered: runs 3-4 turn dialog leo<->friend
        - Feeds all turns back to field via observe_fn
        - Updates friend bootstrap with resonant fragments
        - Swallows all exceptions (silent fallback)
    """
    if not DREAM_AVAILABLE:
        return

    if config is None:
        config = DreamConfig()

    ts = now if now is not None else time.time()

    try:
        # Decision gate
        if not _should_run_dream(ctx, db_path, config, ts):
            return

        # Run dialog
        _run_dream_dialog(ctx, db_path, config, generate_fn, observe_fn, ts)

        # Update last run timestamp
        def _update_ts(conn: sqlite3.Connection) -> None:
            cur = conn.cursor()
            cur.execute("INSERT OR REPLACE INTO dream_meta (key, value) VALUES ('last_run_ts', ?)",
                       (str(ts),))
            conn.commit()

        _with_connection(db_path, _update_ts)

    except Exception:
        # Silent fail — dream must never break Leo
        pass


# ============================================================================
# INSPECTION HELPERS (for debugging / curiosity)
# ============================================================================

def get_dream_stats(db_path: Path) -> dict:
    """Get basic dream statistics."""
    def _stats(conn: sqlite3.Connection) -> dict:
        cur = conn.cursor()

        cur.execute("SELECT COUNT(*) FROM dream_dialogs")
        total_dialogs = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM dream_turns")
        total_turns = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM dream_bootstrap_fragments")
        total_fragments = cur.fetchone()[0]

        cur.execute("SELECT AVG(avg_trauma), AVG(avg_arousal) FROM dream_dialogs WHERE finished_at IS NOT NULL")
        row = cur.fetchone()
        avg_trauma = row[0] if row[0] else 0.0
        avg_arousal = row[1] if row[1] else 0.0

        return {
            "total_dialogs": total_dialogs,
            "total_turns": total_turns,
            "total_fragments": total_fragments,
            "avg_trauma": avg_trauma,
            "avg_arousal": avg_arousal,
        }

    result = _with_connection(db_path, _stats)
    return result if result else {}


def get_recent_dreams(db_path: Path, n: int = 5) -> List[dict]:
    """Get recent dream dialogs with their turns."""
    def _get(conn: sqlite3.Connection) -> List[dict]:
        cur = conn.cursor()

        cur.execute("""
            SELECT id, started_at, finished_at, episodes_count, avg_trauma, avg_arousal
            FROM dream_dialogs
            ORDER BY started_at DESC
            LIMIT ?
        """, (n,))

        dialogs = []
        for row in cur.fetchall():
            dialog_id, started, finished, eps, trauma, arousal = row

            # Get turns for this dialog
            cur.execute("""
                SELECT speaker, text, trauma_level, pulse_arousal
                FROM dream_turns
                WHERE dialog_id = ?
                ORDER BY id
            """, (dialog_id,))

            turns = [{"speaker": r[0], "text": r[1], "trauma": r[2], "arousal": r[3]}
                    for r in cur.fetchall()]

            dialogs.append({
                "started_at": started,
                "finished_at": finished,
                "episodes": eps,
                "avg_trauma": trauma,
                "avg_arousal": arousal,
                "turns": turns,
            })

        return dialogs

    result = _with_connection(db_path, _get)
    return result if result else []
