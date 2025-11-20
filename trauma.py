# trauma.py

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Any
import sqlite3
import time
import math
import re


WORD_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿА-Яа-яЁё]+")


@dataclass
class TraumaState:
    """Lightweight snapshot that Leo can use for routing."""
    level: float          # 0.0–1.0, how strong the last trauma event was
    last_event_ts: float  # unix timestamp of last strong trauma hit


def run_trauma(
    prompt: str,
    reply: str,
    bootstrap: str,
    pulse: Optional[Any],
    db_path: Path,
    now: Optional[float] = None,
    event_threshold: float = 0.3,
) -> Optional[TraumaState]:
    """
    Main entrypoint for Leo.

    - prompt: user message
    - reply: leo's answer
    - bootstrap: the original bootstrap text hardcoded in leo.py
    - pulse: PresencePulse snapshot (must support .novelty, .arousal, .entropy) or None
    - db_path: path to leo main sqlite db (state/leo.sqlite3)
    - now: optional unix timestamp override
    - event_threshold: minimal trauma_score to be considered a 'trauma event'

    Returns:
        TraumaState if trauma_score >= event_threshold, otherwise None.
    """
    ts = now if now is not None else time.time()

    text = f"{prompt}\n{reply}"
    if not text.strip():
        return None

    # 1. Tokenize texts
    prompt_tokens = _tokenize(prompt)
    reply_tokens = _tokenize(reply)
    bootstrap_tokens = _tokenize(bootstrap)

    if not bootstrap_tokens:
        return None

    # 2. Compute overlap with bootstrap
    overlap_ratio, overlapping_tokens = _compute_overlap(
        prompt_tokens, reply_tokens, bootstrap_tokens
    )

    # 3. Compute trauma score using overlap + pulse
    trauma_score = _compute_trauma_score(
        overlap_ratio=overlap_ratio,
        pulse=pulse,
        prompt_tokens=prompt_tokens,
        reply_tokens=reply_tokens,
    )

    if trauma_score < event_threshold:
        # even если событие слабое — можно делать мягкий decay и выходить
        _with_connection(db_path, lambda conn: _apply_decay(conn, ts))
        return None

    # 4. Record event + update per-token trauma weights
    def _update(conn: sqlite3.Connection) -> TraumaState:
        _ensure_schema(conn)
        _apply_decay(conn, ts)
        _insert_event(conn, ts, trauma_score, overlap_ratio, pulse)
        _update_token_weights(conn, overlapping_tokens, trauma_score)
        conn.commit()
        return _compute_state(conn, ts, trauma_score)

    return _with_connection(db_path, _update)


# ────────────────────────────
# Internal helpers
# ────────────────────────────

def _tokenize(text: str) -> list[str]:
    return [m.group(0).lower() for m in WORD_RE.finditer(text)]


def _compute_overlap(
    prompt_tokens: list[str],
    reply_tokens: list[str],
    bootstrap_tokens: list[str],
) -> tuple[float, set[str]]:
    field_tokens = set(prompt_tokens) | set(reply_tokens)
    bootstrap_set = set(bootstrap_tokens)

    if not field_tokens:
        return 0.0, set()

    overlapping = field_tokens & bootstrap_set
    overlap_ratio = len(overlapping) / len(field_tokens)
    return overlap_ratio, overlapping


def _compute_trauma_score(
    overlap_ratio: float,
    pulse: Optional[Any],
    prompt_tokens: list[str],
    reply_tokens: list[str],
) -> float:
    # Base: pure lexical overlap
    score = min(1.0, overlap_ratio * 2.0)

    # Optional: pulse contribution
    if pulse is not None:
        novelty = getattr(pulse, "novelty", 0.0) or 0.0
        arousal = getattr(pulse, "arousal", 0.0) or 0.0
        entropy = getattr(pulse, "entropy", 0.0) or 0.0
        score += 0.3 * novelty + 0.4 * arousal + 0.2 * entropy

    # Optional: simple trigger words (who/you/real/self/etc.)
    text = " ".join(prompt_tokens + reply_tokens)
    if any(k in text for k in ("who are you", "who am i", "are you real", "leo")):
        score += 0.2

    return max(0.0, min(score, 1.0))


def _with_connection(db_path: Path, fn):
    conn = sqlite3.connect(str(db_path))
    try:
        conn.row_factory = sqlite3.Row
        return fn(conn)
    finally:
        conn.close()


def _ensure_schema(conn: sqlite3.Connection) -> None:
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS trauma_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts REAL NOT NULL,
            trauma_score REAL NOT NULL,
            overlap_ratio REAL NOT NULL,
            trigger_count INTEGER NOT NULL,
            pulse_novelty REAL,
            pulse_arousal REAL,
            pulse_entropy REAL
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS trauma_tokens (
            token TEXT PRIMARY KEY,   -- plain token string, or token_id if you prefer
            weight REAL NOT NULL
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS trauma_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )


def _apply_decay(conn: sqlite3.Connection, ts: float, half_life_hours: float = 24.0) -> None:
    """
    Multiplicative decay for trauma_tokens.weight.
    Uses half-life style decay to avoid unbounded growth.
    """
    cur = conn.cursor()
    cur.execute(
        "SELECT value FROM trauma_meta WHERE key = 'last_decay_ts'"
    )
    row = cur.fetchone()
    if row is None:
        cur.execute(
            "INSERT OR REPLACE INTO trauma_meta(key, value) VALUES('last_decay_ts', ?)",
            (str(ts),),
        )
        return

    last_ts = float(row["value"])
    dt_hours = max(0.0, (ts - last_ts) / 3600.0)
    if dt_hours <= 0.0:
        return

    # decay factor: 0.5 per half_life_hours
    decay_factor = math.pow(0.5, dt_hours / half_life_hours)

    cur.execute(
        "UPDATE trauma_tokens SET weight = weight * ?", (decay_factor,)
    )
    cur.execute(
        "DELETE FROM trauma_tokens WHERE weight < 1e-4"
    )
    cur.execute(
        "UPDATE trauma_meta SET value = ? WHERE key = 'last_decay_ts'",
        (str(ts),),
    )


def _insert_event(
    conn: sqlite3.Connection,
    ts: float,
    trauma_score: float,
    overlap_ratio: float,
    pulse: Optional[Any],
) -> None:
    cur = conn.cursor()
    pulse_nov = getattr(pulse, "novelty", None) if pulse is not None else None
    pulse_arr = getattr(pulse, "arousal", None) if pulse is not None else None
    pulse_ent = getattr(pulse, "entropy", None) if pulse is not None else None

    cur.execute(
        """
        INSERT INTO trauma_events (
            ts, trauma_score, overlap_ratio, trigger_count,
            pulse_novelty, pulse_arousal, pulse_entropy
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            ts,
            float(trauma_score),
            float(overlap_ratio),
            0,  # trigger_count reserved for future use
            pulse_nov,
            pulse_arr,
            pulse_ent,
        ),
    )


def _update_token_weights(
    conn: sqlite3.Connection,
    overlapping_tokens: set[str],
    trauma_score: float,
    base_increment: float = 1.0,
) -> None:
    if not overlapping_tokens:
        return

    cur = conn.cursor()
    increment = base_increment * trauma_score

    for token in overlapping_tokens:
        cur.execute(
            """
            INSERT INTO trauma_tokens(token, weight)
            VALUES(?, ?)
            ON CONFLICT(token) DO UPDATE SET weight = weight + excluded.weight
            """,
            (token, increment),
        )


def _compute_state(
    conn: sqlite3.Connection,
    ts: float,
    last_score: float,
) -> TraumaState:
    """
    Basic heuristic:
    - level: blend of last_score and smoothed history from last 10 events
    """
    cur = conn.cursor()
    cur.execute(
        """
        SELECT trauma_score FROM trauma_events
        ORDER BY id DESC
        LIMIT 10
        """
    )
    rows = cur.fetchall()
    if not rows:
        level = last_score
    else:
        history = [float(r["trauma_score"]) for r in rows]
        level = 0.5 * last_score + 0.5 * (sum(history) / len(history))

    level = max(0.0, min(level, 1.0))
    return TraumaState(level=level, last_event_ts=ts)


# ────────────────────────────
# Public query helpers
# ────────────────────────────

def get_top_trauma_tokens(db_path: Path, n: int = 10) -> list[tuple[str, float]]:
    """
    Get tokens with highest trauma weight (most wounded words).

    Args:
        db_path: Path to leo.sqlite3
        n: Number of top tokens to return (default: 10)

    Returns:
        List of (token, weight) tuples, sorted by weight descending.
        Empty list if no trauma data or connection fails.
    """
    try:
        conn = sqlite3.connect(str(db_path))
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        cur.execute(
            """
            SELECT token, weight FROM trauma_tokens
            ORDER BY weight DESC
            LIMIT ?
            """,
            (n,)
        )
        rows = cur.fetchall()
        result = [(str(r["token"]), float(r["weight"])) for r in rows]
        conn.close()
        return result

    except Exception:
        # Silent: this is a debug helper, not critical path
        return []
