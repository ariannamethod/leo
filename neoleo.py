#!/usr/bin/env python3
# neoleo.py — pure language resonance layer
#
# No bootstrap. No README. No seed text.
# Only the conversation you feed into it.

from __future__ import annotations

import json
import math
import random
import re
import sqlite3
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# ============================================================================
# PATHS
# ============================================================================

ROOT = Path(__file__).resolve().parent
STATE_DIR = ROOT / "state"
BIN_DIR = ROOT / "bin"
DB_PATH = STATE_DIR / "neoleo.sqlite3"

# ============================================================================
# TOKENIZER
# ============================================================================

TOKEN_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ']+|[.,!?;:—\-]")


def tokenize(text: str) -> List[str]:
    return TOKEN_RE.findall(text)


# ============================================================================
# DB HELPERS
# ============================================================================


def ensure_dirs() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    BIN_DIR.mkdir(parents=True, exist_ok=True)


def init_db() -> sqlite3.Connection:
    """SQLite schema shared with leo, but without any bootstrap."""
    ensure_dirs()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("PRAGMA journal_mode=WAL")
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS tokens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            token TEXT UNIQUE
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS bigrams (
            src_id INTEGER,
            dst_id INTEGER,
            count INTEGER,
            PRIMARY KEY (src_id, dst_id)
        )
        """
    )
    conn.commit()
    return conn


def get_token_id(cur: sqlite3.Cursor, token: str) -> int:
    cur.execute("INSERT OR IGNORE INTO tokens(token) VALUES (?)", (token,))
    cur.execute("SELECT id FROM tokens WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        raise RuntimeError("Failed to retrieve token id")
    return int(row[0])


def ingest_tokens(conn: sqlite3.Connection, tokens: List[str]) -> None:
    if not tokens:
        return
    cur = conn.cursor()
    prev_id: Optional[int] = None
    for tok in tokens:
        tok_id = get_token_id(cur, tok)
        if prev_id is not None:
            cur.execute(
                """
                INSERT INTO bigrams (src_id, dst_id, count)
                VALUES (?, ?, 1)
                ON CONFLICT(src_id, dst_id)
                DO UPDATE SET count = count + 1
                """,
                (prev_id, tok_id),
            )
        prev_id = tok_id
    conn.commit()


def ingest_text(conn: sqlite3.Connection, text: str) -> None:
    tokens = tokenize(text)
    if tokens:
        ingest_tokens(conn, tokens)


# ============================================================================
# BIGRAM FIELD & SHARDS
# ============================================================================


def load_bigrams(conn: sqlite3.Connection) -> Tuple[Dict[str, Dict[str, int]], List[str]]:
    cur = conn.cursor()
    cur.execute("SELECT id, token FROM tokens")
    id_to_token: Dict[int, str] = {}
    for row in cur.fetchall():
        id_to_token[int(row["id"])] = str(row["token"])

    cur.execute("SELECT src_id, dst_id, count FROM bigrams")
    bigrams: Dict[str, Dict[str, int]] = {}
    for row in cur.fetchall():
        src_id = int(row["src_id"])
        dst_id = int(row["dst_id"])
        count = int(row["count"])
        a = id_to_token.get(src_id)
        b = id_to_token.get(dst_id)
        if a is None or b is None:
            continue
        row_map = bigrams.setdefault(a, {})
        row_map[b] = row_map.get(b, 0) + count

    vocab = list(id_to_token.values())
    return bigrams, vocab


def compute_centers(conn: sqlite3.Connection, k: int = 7) -> List[str]:
    cur = conn.cursor()
    cur.execute(
        """
        SELECT src_id, SUM(count) AS w
        FROM bigrams
        GROUP BY src_id
        ORDER BY w DESC
        LIMIT ?
        """,
        (k,),
    )
    rows = cur.fetchall()
    if not rows:
        return []

    cur.execute("SELECT id, token FROM tokens")
    id_to_token = {int(r["id"]): str(r["token"]) for r in cur.fetchall()}

    centers: List[str] = []
    for row in rows:
        tok = id_to_token.get(int(row["src_id"]))
        if tok:
            centers.append(tok)
    return centers


def _sha256_hex(data: bytes) -> str:
    import hashlib

    return hashlib.sha256(data).hexdigest()


def create_bin_shard(centers: List[str], max_shards: int = 64) -> None:
    """
    Store shard for NeoLeo.

    Shards are written as `neoleo_<hash>.bin` with:
      { "kind": "neoleo_center_shard", "centers": [...] }
    """
    if not centers:
        return
    BIN_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "kind": "neoleo_center_shard",
        "centers": centers,
    }
    raw = json.dumps(payload, sort_keys=True).encode("utf-8")
    h = _sha256_hex(raw)[:16]
    shard_path = BIN_DIR / f"neoleo_{h}.bin"
    shard_path.write_bytes(raw)

    pattern = "neoleo_*.bin"
    shards = sorted(BIN_DIR.glob(pattern), key=lambda p: p.stat().st_mtime)
    while len(shards) > max_shards:
        victim = shards.pop(0)
        try:
            victim.unlink()
        except OSError:
            pass


def load_bin_bias() -> Dict[str, int]:
    """Load accumulated centers for NeoLeo field."""
    if not BIN_DIR.exists():
        return {}
    bias: Dict[str, int] = {}
    pattern = "neoleo_*.bin"
    for path in BIN_DIR.glob(pattern):
        try:
            data = json.loads(path.read_bytes().decode("utf-8"))
        except Exception:
            continue
        if data.get("kind") != "neoleo_center_shard":
            continue
        for tok in data.get("centers", []):
            bias[tok] = bias.get(tok, 0) + 1
    return bias


# ============================================================================
# GENERATION
# ============================================================================


def format_tokens(tokens: List[str]) -> str:
    if not tokens:
        return ""
    out: List[str] = []
    for i, tok in enumerate(tokens):
        if i == 0:
            out.append(tok)
            continue
        if tok in {".", ",", "!", "?", ";", ":"}:
            out[-1] = out[-1] + tok
        else:
            out.append(" " + tok)
    return "".join(out)


def choose_start_token(
    vocab: List[str],
    centers: List[str],
    bias: Dict[str, int],
) -> str:
    pool: List[str]
    if centers:
        pool = list(centers)
    else:
        pool = list(vocab)
    if not pool:
        return "..."

    if bias:
        items = [(tok, w) for tok, w in bias.items() if tok in pool]
        if items:
            total = sum(w for _, w in items)
            r = random.uniform(0.0, total)
            acc = 0.0
            for tok, w in items:
                acc += w
                if r <= acc:
                    return tok

    return random.choice(pool)


def step_token(
    bigrams: Dict[str, Dict[str, int]],
    current: str,
    vocab: List[str],
    centers: List[str],
    bias: Dict[str, int],
    temperature: float = 1.0,
) -> str:
    row = bigrams.get(current)
    if not row:
        return choose_start_token(vocab, centers, bias)

    tokens = list(row.keys())
    counts = [row[t] for t in tokens]

    if temperature <= 0:
        temperature = 1.0

    if temperature != 1.0:
        counts = [math.pow(float(c), 1.0 / float(temperature)) for c in counts]

    total = sum(counts)
    if total <= 0:
        return choose_start_token(vocab, centers, bias)

    r = random.uniform(0.0, total)
    acc = 0.0
    for t, c in zip(tokens, counts):
        acc += c
        if r <= acc:
            return t
    return tokens[-1]


def choose_start_from_prompt(
    prompt_tokens: List[str],
    bigrams: Dict[str, Dict[str, int]],
    vocab: List[str],
    centers: List[str],
    bias: Dict[str, int],
) -> str:
    """
    Prompt-influenced start without тупой линейки "последнее => первое".
    """
    candidates = [t for t in prompt_tokens if t in bigrams and bigrams[t]]
    if candidates:
        return random.choice(candidates)

    fallback = [t for t in prompt_tokens if t in vocab]
    if fallback:
        return random.choice(fallback)

    return choose_start_token(vocab, centers, bias)


def generate_reply(
    bigrams: Dict[str, Dict[str, int]],
    vocab: List[str],
    centers: List[str],
    bias: Dict[str, int],
    prompt: str,
    max_tokens: int = 80,
    temperature: float = 1.0,
    echo: bool = False,
) -> str:
    if not vocab or not bigrams:
        # field is empty: just pass text through
        return prompt

    if echo:
        tokens_in = tokenize(prompt)
        tokens_out: List[str] = []
        for tok in tokens_in:
            if tok in bigrams:
                nxt = step_token(bigrams, tok, vocab, centers, bias, temperature)
                tokens_out.append(nxt)
            else:
                tokens_out.append(tok)
        return format_tokens(tokens_out)

    prompt_tokens = tokenize(prompt)
    start = choose_start_from_prompt(prompt_tokens, bigrams, vocab, centers, bias)

    tokens: List[str] = [start]
    current = start

    for _ in range(max_tokens - 1):
        nxt = step_token(bigrams, current, vocab, centers, bias, temperature)
        tokens.append(nxt)
        current = nxt

    return format_tokens(tokens)


# ============================================================================
# NEOLEO OBJECT
# ============================================================================


class NeoLeo:
    """
    Pure resonance layer:
    - observe(text): update field from user / agent messages
    - warp(text): run text through field (free or echo mode)
    """

    def __init__(self, db_path: Optional[Path] = None):
        self.db_path = db_path or DB_PATH
        self.conn = init_db()
        self.bigrams: Dict[str, Dict[str, int]] = {}
        self.vocab: List[str] = []
        self.centers: List[str] = []
        self.bias: Dict[str, int] = {}
        self.refresh()

    def refresh(self) -> None:
        self.bigrams, self.vocab = load_bigrams(self.conn)
        self.centers = compute_centers(self.conn, k=7)
        self.bias = load_bin_bias()
        if self.centers:
            create_bin_shard(self.centers)

    def observe(self, text: str) -> None:
        """Update field with new text (user, model, logs — whatever)."""
        if not text.strip():
            return
        ingest_text(self.conn, text)
        self.refresh()

    def warp(
        self,
        text: str,
        max_tokens: int = 80,
        temperature: float = 1.0,
        echo: bool = False,
    ) -> str:
        """
        Warp incoming text through the field.

        Typical usage in a framework:
            neo.observe(user_text)
            model_reply = call_llm(user_text)
            neo.observe(model_reply)
            warped = neo.warp(model_reply)
        """
        return generate_reply(
            self.bigrams,
            self.vocab,
            self.centers,
            self.bias,
            text,
            max_tokens=max_tokens,
            temperature=temperature,
            echo=echo,
        )

    def export_lexicon(self, out_path: Optional[Path] = None) -> Path:
        """
        Dump current lexicon + centers into a JSON snapshot.
        """
        out_dir = ROOT / "json"
        out_dir.mkdir(parents=True, exist_ok=True)
        if out_path is None:
            out_path = out_dir / "neoleo_lexicon.json"

        data = {
            "vocab": self.vocab,
            "centers": self.centers,
            "bias": self.bias,
        }
        out_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return out_path


# Optional module-level singleton for quick use

_default_neo: Optional[NeoLeo] = None


def get_default() -> NeoLeo:
    global _default_neo
    if _default_neo is None:
        _default_neo = NeoLeo()
    return _default_neo


def observe(text: str) -> None:
    get_default().observe(text)


def warp(
    text: str,
    max_tokens: int = 80,
    temperature: float = 1.0,
    echo: bool = False,
) -> str:
    return get_default().warp(
        text,
        max_tokens=max_tokens,
        temperature=temperature,
        echo=echo,
    )
