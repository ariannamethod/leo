"""
leo_storage.py — Async storage layer for Leo

All SQLite and file I/O operations live here.
Leo's organism (leo.py) imports these for persistence.

Uses aiosqlite for non-blocking database access and aiofiles for file I/O.
Sync wrappers provided for backward compatibility during migration.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
import sqlite3
import sys
import time
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any

try:
    import aiosqlite
    AIOSQLITE_AVAILABLE = True
except ImportError:
    aiosqlite = None  # type: ignore
    AIOSQLITE_AVAILABLE = False

try:
    import aiofiles
    AIOFILES_AVAILABLE = True
except ImportError:
    aiofiles = None  # type: ignore
    AIOFILES_AVAILABLE = False


# ============================================================================
# PATHS
# ============================================================================

ROOT = Path(__file__).resolve().parent
STATE_DIR = ROOT / "state"
BIN_DIR = ROOT / "bin"
JSON_DIR = ROOT / "json"
DB_PATH = STATE_DIR / "leo.sqlite3"
README_PATH = ROOT / "README.md"


# ============================================================================
# TOKENIZER (needed for ingest)
# ============================================================================

TOKEN_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ']+|[.,!?;:—\-]")


def tokenize(text: str) -> List[str]:
    """Extract words and punctuation from text."""
    return TOKEN_RE.findall(text.lower())


# ============================================================================
# DIRECTORY SETUP
# ============================================================================

def ensure_dirs() -> None:
    """Create runtime directories."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    BIN_DIR.mkdir(parents=True, exist_ok=True)
    JSON_DIR.mkdir(parents=True, exist_ok=True)


# ============================================================================
# ASYNC DATABASE OPERATIONS
# ============================================================================

_SCHEMA_SQL = [
    "PRAGMA journal_mode=WAL",
    """CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        token TEXT UNIQUE
    )""",
    """CREATE TABLE IF NOT EXISTS bigrams (
        src_id INTEGER,
        dst_id INTEGER,
        count INTEGER,
        PRIMARY KEY (src_id, dst_id)
    )""",
    """CREATE TABLE IF NOT EXISTS trigrams (
        first_id INTEGER,
        second_id INTEGER,
        third_id INTEGER,
        count INTEGER,
        PRIMARY KEY (first_id, second_id, third_id)
    )""",
    """CREATE TABLE IF NOT EXISTS co_occurrence (
        word_id INTEGER,
        context_id INTEGER,
        count INTEGER,
        PRIMARY KEY (word_id, context_id)
    )""",
    """CREATE TABLE IF NOT EXISTS snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        origin TEXT,
        quality REAL,
        emotional REAL,
        created_at INTEGER,
        last_used_at INTEGER,
        use_count INTEGER DEFAULT 0,
        cluster_id INTEGER
    )""",
]


async def async_init_db() -> aiosqlite.Connection:
    """Initialize SQLite schema for Leo (async)."""
    ensure_dirs()
    db = await aiosqlite.connect(str(DB_PATH))
    db.row_factory = aiosqlite.Row
    for sql in _SCHEMA_SQL:
        await db.execute(sql)
    await db.commit()
    return db


async def async_get_meta(db: aiosqlite.Connection, key: str) -> Optional[str]:
    """Get metadata value (async)."""
    cursor = await db.execute("SELECT value FROM meta WHERE key = ?", (key,))
    row = await cursor.fetchone()
    return row[0] if row else None


async def async_set_meta(db: aiosqlite.Connection, key: str, value: str) -> None:
    """Set metadata value (async)."""
    await db.execute(
        "INSERT INTO meta (key, value) VALUES (?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        (key, value),
    )
    await db.commit()


async def _async_get_token_id(db: aiosqlite.Connection, token: str) -> int:
    """Get or create token ID (async)."""
    await db.execute("INSERT OR IGNORE INTO tokens(token) VALUES (?)", (token,))
    cursor = await db.execute("SELECT id FROM tokens WHERE token = ?", (token,))
    row = await cursor.fetchone()
    if row is None:
        raise RuntimeError("Failed to retrieve token id")
    return int(row[0])


async def async_ingest_tokens(db: aiosqlite.Connection, tokens: List[str]) -> None:
    """Update bigram and trigram counts from a token sequence (async).

    Novelty bonus: NEW tokens get initial co-occurrence count of 2.
    """
    if not tokens:
        return

    # Detect which tokens are NEW (not yet in tokens table)
    new_token_ids: set = set()
    token_ids = []
    for tok in tokens:
        cursor = await db.execute("SELECT id FROM tokens WHERE token = ?", (tok,))
        existing = await cursor.fetchone()
        tid = await _async_get_token_id(db, tok)
        token_ids.append(tid)
        if existing is None:
            new_token_ids.add(tid)

    # Bigrams
    for i in range(len(token_ids) - 1):
        await db.execute(
            "INSERT INTO bigrams (src_id, dst_id, count) VALUES (?, ?, 1) "
            "ON CONFLICT(src_id, dst_id) DO UPDATE SET count = count + 1",
            (token_ids[i], token_ids[i + 1]),
        )

    # Trigrams
    for i in range(len(token_ids) - 2):
        await db.execute(
            "INSERT INTO trigrams (first_id, second_id, third_id, count) VALUES (?, ?, ?, 1) "
            "ON CONFLICT(first_id, second_id, third_id) DO UPDATE SET count = count + 1",
            (token_ids[i], token_ids[i + 1], token_ids[i + 2]),
        )

    # Co-occurrence (sliding window of 5)
    # Novelty bonus: pairs involving a NEW token start at count=2
    window_size = 5
    for i, center_id in enumerate(token_ids):
        start = max(0, i - window_size)
        end = min(len(token_ids), i + window_size + 1)
        for j in range(start, end):
            if j == i:
                continue
            context_id = token_ids[j]
            initial = 2 if (center_id in new_token_ids or context_id in new_token_ids) else 1
            await db.execute(
                "INSERT INTO co_occurrence (word_id, context_id, count) VALUES (?, ?, ?) "
                "ON CONFLICT(word_id, context_id) DO UPDATE SET count = count + 1",
                (center_id, context_id, initial),
            )

    await db.commit()


async def async_ingest_text(db: aiosqlite.Connection, text: str) -> None:
    """Tokenize and ingest text into the field (async)."""
    tokens = tokenize(text)
    if tokens:
        await async_ingest_tokens(db, tokens)


async def async_load_bigrams(
    db: aiosqlite.Connection,
) -> Tuple[Dict[str, Dict[str, int]], List[str]]:
    """Load bigram graph into memory (async)."""
    cursor = await db.execute("SELECT id, token FROM tokens")
    rows = await cursor.fetchall()
    id_to_token: Dict[int, str] = {int(r[0]): str(r[1]) for r in rows}

    cursor = await db.execute("SELECT src_id, dst_id, count FROM bigrams")
    rows = await cursor.fetchall()
    bigrams: Dict[str, Dict[str, int]] = {}
    for row in rows:
        a = id_to_token.get(int(row[0]))
        b = id_to_token.get(int(row[1]))
        if a is None or b is None:
            continue
        row_map = bigrams.setdefault(a, {})
        row_map[b] = row_map.get(b, 0) + int(row[2])

    vocab = list(id_to_token.values())
    return bigrams, vocab


async def async_load_trigrams(
    db: aiosqlite.Connection,
) -> Dict[Tuple[str, str], Dict[str, int]]:
    """Load trigram graph into memory (async)."""
    cursor = await db.execute("SELECT id, token FROM tokens")
    rows = await cursor.fetchall()
    id_to_token: Dict[int, str] = {int(r[0]): str(r[1]) for r in rows}

    cursor = await db.execute("SELECT first_id, second_id, third_id, count FROM trigrams")
    rows = await cursor.fetchall()
    trigrams: Dict[Tuple[str, str], Dict[str, int]] = {}
    for row in rows:
        first = id_to_token.get(int(row[0]))
        second = id_to_token.get(int(row[1]))
        third = id_to_token.get(int(row[2]))
        if first is None or second is None or third is None:
            continue
        key = (first, second)
        row_map = trigrams.setdefault(key, {})
        row_map[third] = row_map.get(third, 0) + int(row[3])

    return trigrams


async def async_load_co_occurrence(
    db: aiosqlite.Connection,
) -> Dict[str, Dict[str, int]]:
    """Load co-occurrence matrix into memory (async)."""
    cursor = await db.execute("SELECT id, token FROM tokens")
    rows = await cursor.fetchall()
    id_to_token: Dict[int, str] = {int(r[0]): str(r[1]) for r in rows}

    cursor = await db.execute("SELECT word_id, context_id, count FROM co_occurrence")
    rows = await cursor.fetchall()
    co_occur: Dict[str, Dict[str, int]] = {}
    for row in rows:
        word = id_to_token.get(int(row[0]))
        context = id_to_token.get(int(row[1]))
        if word is None or context is None:
            continue
        row_map = co_occur.setdefault(word, {})
        row_map[context] = row_map.get(context, 0) + int(row[2])

    return co_occur


async def async_compute_centers(db: aiosqlite.Connection, k: int = 7) -> List[str]:
    """Pick tokens with highest out-degree as centers of gravity (async)."""
    PUNCT = {".", ",", "!", "?", ";", ":", "—", "-"}

    cursor = await db.execute(
        "SELECT src_id, SUM(count) AS w FROM bigrams GROUP BY src_id ORDER BY w DESC"
    )
    rows = await cursor.fetchall()
    if not rows:
        return []

    cursor = await db.execute("SELECT id, token FROM tokens")
    token_rows = await cursor.fetchall()
    id_to_token = {int(r[0]): str(r[1]) for r in token_rows}

    centers: List[str] = []
    for row in rows:
        tok = id_to_token.get(int(row[0]))
        if tok and tok not in PUNCT:
            centers.append(tok)
            if len(centers) >= k:
                break

    return centers


async def async_save_snapshot(
    db: aiosqlite.Connection,
    text: str,
    origin: str,
    quality: float,
    emotional: float,
    max_snapshots: int = 512,
) -> None:
    """Save a snapshot of text (async)."""
    now = int(time.time())
    await db.execute(
        "INSERT INTO snapshots (text, origin, quality, emotional, created_at, last_used_at, use_count) "
        "VALUES (?, ?, ?, ?, ?, ?, 0)",
        (text, origin, quality, emotional, now, now),
    )

    cursor = await db.execute("SELECT COUNT(*) FROM snapshots")
    row = await cursor.fetchone()
    count = row[0]

    if count > max_snapshots:
        to_delete = max(1, int(max_snapshots * 0.1))
        await db.execute(
            "DELETE FROM snapshots WHERE id IN ("
            "SELECT id FROM snapshots ORDER BY use_count ASC, created_at ASC LIMIT ?"
            ")",
            (to_delete,),
        )

    await db.commit()


async def async_apply_memory_decay(
    db: aiosqlite.Connection,
    decay_factor: float = 0.95,
    min_threshold: int = 1,
) -> int:
    """Apply natural forgetting to co-occurrence memories (async).

    min_threshold=1 (was 2): new words survive longer before fading.
    """
    await db.execute(
        "UPDATE co_occurrence SET count = CAST(count * ? AS INTEGER) WHERE count > 0",
        (decay_factor,),
    )
    cursor = await db.execute(
        "DELETE FROM co_occurrence WHERE count < ?",
        (min_threshold,),
    )
    deleted = cursor.rowcount
    await db.commit()
    return deleted


async def async_bootstrap_if_needed(db: aiosqlite.Connection) -> None:
    """One-time bootstrap: ingest embedded seed + README (async)."""
    # Lazy import to avoid circular dependency
    from leo import EMBEDDED_BOOTSTRAP, strip_code_blocks

    cursor = await db.execute("SELECT COUNT(*) AS c FROM tokens")
    row = await cursor.fetchone()
    count = int(row[0])

    if count == 0:
        print("[leo] bootstrapping from embedded seed...", file=sys.stderr)
        await async_ingest_text(db, EMBEDDED_BOOTSTRAP)

    readme_flag = await async_get_meta(db, "readme_bootstrap_done")
    if readme_flag == "1":
        return

    readme_path = ROOT / "README.md"
    if not readme_path.exists():
        return

    print("[leo] reading README.md for first time...", file=sys.stderr)
    if AIOFILES_AVAILABLE:
        async with aiofiles.open(str(readme_path), encoding="utf-8") as f:
            readme_text = await f.read()
    else:
        readme_text = readme_path.read_text(encoding="utf-8")

    readme_clean = strip_code_blocks(readme_text)
    await async_ingest_text(db, readme_clean)
    await async_set_meta(db, "readme_bootstrap_done", "1")


# ============================================================================
# FILE I/O (BIN SHARDS)
# ============================================================================

def _sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def create_bin_shard(tag: str, centers: List[str], max_shards: int = 32) -> None:
    """Save a tiny center-of-gravity shard into BIN_DIR (sync, fast)."""
    if not centers:
        return
    BIN_DIR.mkdir(parents=True, exist_ok=True)
    payload = {"kind": f"{tag}_center_shard", "centers": centers}
    raw = json.dumps(payload, sort_keys=True).encode("utf-8")
    h = _sha256_hex(raw)[:16]
    shard_path = BIN_DIR / f"{tag}_{h}.bin"
    shard_path.write_bytes(raw)

    pattern = f"{tag}_*.bin"
    shards = sorted(BIN_DIR.glob(pattern), key=lambda p: p.stat().st_mtime)
    while len(shards) > max_shards:
        victim = shards.pop(0)
        try:
            victim.unlink()
        except OSError:
            pass


def load_bin_bias(tag: str) -> Dict[str, int]:
    """Load accumulated center tokens from BIN shards (sync, fast)."""
    if not BIN_DIR.exists():
        return {}
    bias: Dict[str, int] = {}
    pattern = f"{tag}_*.bin"
    for path in BIN_DIR.glob(pattern):
        try:
            data = json.loads(path.read_bytes().decode("utf-8"))
        except Exception:
            continue
        if data.get("kind") != f"{tag}_center_shard":
            continue
        for tok in data.get("centers", []):
            bias[tok] = bias.get(tok, 0) + 1
    return bias


# ============================================================================
# SYNC WRAPPERS (backward compatibility during migration)
# ============================================================================

def init_db() -> sqlite3.Connection:
    """Initialize SQLite schema for Leo (sync, delegates to leo.py)."""
    # During migration, this just calls the original leo.init_db
    # After full migration, this can be removed
    from leo import init_db as _orig_init_db
    return _orig_init_db()


def get_meta(conn: sqlite3.Connection, key: str) -> Optional[str]:
    """Get metadata value (sync)."""
    cur = conn.cursor()
    cur.execute("SELECT value FROM meta WHERE key = ?", (key,))
    row = cur.fetchone()
    if row is None:
        return None
    return row["value"] if isinstance(row, sqlite3.Row) else row[0]


def set_meta(conn: sqlite3.Connection, key: str, value: str) -> None:
    """Set metadata value (sync)."""
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO meta (key, value) VALUES (?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        (key, value),
    )
    conn.commit()
