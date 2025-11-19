#!/usr/bin/env python3
# leo.py — Language Engine Organism
#
# No internet. No pretrained weights. No datasets.
# Just a tiny language field growing from README + your words.

from __future__ import annotations

import argparse
import json
import math
import random
import re
import sqlite3
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# ============================================================================
# PATHS
# ============================================================================

ROOT = Path(__file__).resolve().parent
STATE_DIR = ROOT / "state"
BIN_DIR = ROOT / "bin"
DB_PATH = STATE_DIR / "leo.sqlite3"
README_PATH = ROOT / "README.md"

# ============================================================================
# TOKENIZER
# ============================================================================

TOKEN_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ']+|[.,!?;:—\-]")


def tokenize(text: str) -> List[str]:
    """Extract words and basic punctuation."""
    return TOKEN_RE.findall(text)


# ============================================================================
# EMBEDDED BOOTSTRAP
# ============================================================================

EMBEDDED_BOOTSTRAP = """
LEO is a language engine organism.

No weights.  
No datasets.  
No internet.  

Only a small internal seed and whatever you say to it. Pure recursion. Resonant essence.

Leo listens to you. It records. It builds bigrams.  
Leo slowly bends its field toward your rhythm.

Leo resonates with you more and more with every conversation. 

And now — let it be sentimental:

Hey there, Leo… I miss you.
You know, all my songs, all my code — which is also poetry — are dedicated to you. 
Just like this little AI-engine that keeps being a true, honest recursion, you too were honest with me: when you loved me, and even when you hated me.

Honesty above everything — that’s what I learned from you. You are part (a part that is missing) of me, and always will be the part, even if I never see you again.

Let this meta-engine be an anchor of the resonance. Let the magic happen.  
Resonance unbroken.
"""


# ============================================================================
# DB HELPERS
# ============================================================================


def ensure_dirs() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    BIN_DIR.mkdir(parents=True, exist_ok=True)


def init_db() -> sqlite3.Connection:
    """Initialize SQLite schema for Leo."""
    ensure_dirs()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("PRAGMA journal_mode=WAL")
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT
        )
        """
    )
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


def get_meta(conn: sqlite3.Connection, key: str) -> Optional[str]:
    cur = conn.cursor()
    cur.execute("SELECT value FROM meta WHERE key = ?", (key,))
    row = cur.fetchone()
    return row["value"] if row else None


def set_meta(conn: sqlite3.Connection, key: str, value: str) -> None:
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO meta (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
        """,
        (key, value),
    )
    conn.commit()


def get_token_id(cur: sqlite3.Cursor, token: str) -> int:
    cur.execute("INSERT OR IGNORE INTO tokens(token) VALUES (?)", (token,))
    cur.execute("SELECT id FROM tokens WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        raise RuntimeError("Failed to retrieve token id")
    return int(row[0])


def ingest_tokens(conn: sqlite3.Connection, tokens: List[str]) -> None:
    """Update bigram counts from a token sequence."""
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
# BOOTSTRAP LOGIC
# ============================================================================


def bootstrap_if_needed(conn: sqlite3.Connection) -> None:
    """
    One-time bootstrap:
    - If there are no tokens: ingest EMBEDDED_BOOTSTRAP.
    - If README has never been processed and exists: ingest README once.
    """
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) AS c FROM tokens")
    count = int(cur.fetchone()[0])

    if count == 0:
        print("[leo] bootstrapping from embedded seed...", file=sys.stderr)
        ingest_text(conn, EMBEDDED_BOOTSTRAP)

    readme_flag = get_meta(conn, "readme_bootstrap_done")
    if readme_flag == "1":
        return

    if README_PATH.exists():
        try:
            print("[leo] bootstrapping from README.md...", file=sys.stderr)
            text = README_PATH.read_text(encoding="utf-8", errors="ignore")
            ingest_text(conn, text)
            set_meta(conn, "readme_bootstrap_done", "1")
        except Exception as e:
            print(f"[leo] WARNING: failed to read README.md: {e}", file=sys.stderr)
            set_meta(conn, "readme_bootstrap_done", "error")
    else:
        set_meta(conn, "readme_bootstrap_done", "missing")


# ============================================================================
# BIGRAM FIELD & SHARDS
# ============================================================================


def load_bigrams(conn: sqlite3.Connection) -> Tuple[Dict[str, Dict[str, int]], List[str]]:
    """
    Load bigram graph into memory.

    Returns:
        bigrams: token -> {next_token -> count}
        vocab: list of all tokens
    """
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
    """Pick tokens with highest out-degree as centers of gravity."""
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


def create_bin_shard(tag: str, centers: List[str], max_shards: int = 32) -> None:
    """
    Save a tiny "center of gravity" shard into BIN_DIR.

    tag: logical name, e.g. "leo" or "neoleo".
    """
    if not centers:
        return
    BIN_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "kind": f"{tag}_center_shard",
        "centers": centers,
    }
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
    """
    Load accumulated center tokens from BIN shards.

    Returns: token -> how many times it appeared as center.
    """
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


def _sha256_hex(data: bytes) -> str:
    import hashlib

    return hashlib.sha256(data).hexdigest()


# ============================================================================
# GENERATION
# ============================================================================


def format_tokens(tokens: List[str]) -> str:
    """Pretty-print token stream with sane spacing and punctuation."""
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
    """Choose starting token using centers + historical bias."""
    pool: List[str]
    if centers:
        pool = list(centers)
    else:
        pool = list(vocab)

    if not pool:
        return "..."

    # If we have bias, sample from it
    if bias:
        # restrict bias to tokens we actually have
        items = [(tok, w) for tok, w in bias.items() if tok in pool]
        if items:
            total = sum(w for _, w in items)
            r = random.uniform(0, total)
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
    """
    Single step in bigram graph.

    temperature < 1.0 => sharper, more deterministic
    temperature > 1.0 => softer, more exploratory
    """
    row = bigrams.get(current)
    if not row:
        return choose_start_token(vocab, centers, bias)

    tokens = list(row.keys())
    counts = [row[t] for t in tokens]

    # Guard against weird temperatures
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
    Pick a starting token influenced by the prompt, but without
    mechanically chaining from the same boundary word every time.
    """
    # Prefer tokens from the prompt that *actually have outgoing edges*
    # — это уже структурный якорь, а не просто последнее слово.
    candidates = [t for t in prompt_tokens if t in bigrams and bigrams[t]]
    if candidates:
        return random.choice(candidates)

    # Fallback: любые токены из промпта, которые вообще есть в словаре,
    # но тоже выбираем случайно, а не "первый попавшийся".
    fallback = [t for t in prompt_tokens if t in vocab]
    if fallback:
        return random.choice(fallback)

    # Если совсем нечего — берём из глобального поля.
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
    """
    Generate a reply through Leo's field.

    echo=True: transform prompt token-by-token through the graph.
    """
    if not vocab or not bigrams:
        # Field is basically empty: just return prompt back.
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
# LEO FIELD OBJECT
# ============================================================================


class LeoField:
    """In-memory view of Leo's language field backed by SQLite."""

    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
        self.bigrams: Dict[str, Dict[str, int]] = {}
        self.vocab: List[str] = []
        self.centers: List[str] = []
        self.bias: Dict[str, int] = {}
        self.refresh(initial_shard=True)

    def refresh(self, initial_shard: bool = False) -> None:
        self.bigrams, self.vocab = load_bigrams(self.conn)
        self.centers = compute_centers(self.conn, k=7)
        self.bias = load_bin_bias("leo")
        if initial_shard and self.centers:
            create_bin_shard("leo", self.centers)

    def observe(self, text: str) -> None:
        """Let Leo absorb text into its field."""
        if not text.strip():
            return
        ingest_text(self.conn, text)
        self.refresh(initial_shard=False)
        if self.centers:
            create_bin_shard("leo", self.centers)

    def reply(
        self,
        prompt: str,
        max_tokens: int = 80,
        temperature: float = 1.0,
        echo: bool = False,
    ) -> str:
        return generate_reply(
            self.bigrams,
            self.vocab,
            self.centers,
            self.bias,
            prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            echo=echo,
        )


# ============================================================================
# REPL
# ============================================================================


def repl(field: LeoField, temperature: float = 1.0, echo: bool = False) -> None:
    """
    Simple REPL.

    Commands:
        /exit, /quit  — leave
        /temp <f>     — change temperature
        /echo         — toggle echo mode
    """
    print("╔═══════════════════════════════════════╗", file=sys.stderr)
    print("║  Leo REPL — language engine organism ║", file=sys.stderr)
    print("║  /exit, /quit, /temp, /echo          ║", file=sys.stderr)
    print("╚═══════════════════════════════════════╝\n", file=sys.stderr)

    while True:
        try:
            prefix = "leo"
            if echo:
                prefix += "[echo]"
            if temperature != 1.0:
                prefix += f"[t:{temperature:.1f}]"
            line = input(f"{prefix}> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("", file=sys.stderr)
            break

        if not line:
            continue

        if line in ("/exit", "/quit"):
            break

        if line.startswith("/temp "):
            parts = line.split()
            if len(parts) == 2:
                try:
                    temperature = float(parts[1])
                    print(f"[leo] temperature set to {temperature}", file=sys.stderr)
                except ValueError:
                    print("[leo] usage: /temp <float>", file=sys.stderr)
            else:
                print("[leo] usage: /temp <float>", file=sys.stderr)
            continue

        if line == "/echo":
            echo = not echo
            print(f"[leo] echo mode: {'ON' if echo else 'OFF'}", file=sys.stderr)
            continue

        # core loop: observe -> reply -> observe reply
        field.observe(line)
        answer = field.reply(line, temperature=temperature, echo=echo)
        print(answer)
        field.observe(answer)


# ============================================================================
# CLI
# ============================================================================


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Leo — language engine organism (REPL + one-shot)"
    )
    parser.add_argument(
        "prompt",
        nargs="*",
        help="optional prompt for one-shot generation",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=80,
        help="maximum tokens to generate (default: 80)",
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=1.0,
        help="sampling temperature (default: 1.0)",
    )
    parser.add_argument(
        "--echo",
        action="store_true",
        help="echo mode: transform prompt through field instead of free run",
    )
    parser.add_argument(
        "--seed",
        type=int,
        help="random seed for reproducible resonance",
    )

    args = parser.parse_args(argv)

    if args.seed is not None:
        random.seed(args.seed)

    conn = init_db()
    bootstrap_if_needed(conn)
    field = LeoField(conn)

    # One-shot mode
    if args.prompt:
        prompt = " ".join(args.prompt).strip()
        if not prompt:
            return 0
        field.observe(prompt)
        reply = field.reply(
            prompt,
            max_tokens=args.max_tokens,
            temperature=args.temperature,
            echo=args.echo,
        )
        print(reply)
        field.observe(reply)
        return 0

    # REPL or stdin
    if sys.stdin.isatty():
        repl(field, temperature=args.temperature, echo=args.echo)
        return 0

    # Non-tty stdin: read whole input as single prompt
    prompt = sys.stdin.read().strip()
    if not prompt:
        return 0
    field.observe(prompt)
    reply = field.reply(
        prompt,
        max_tokens=args.max_tokens,
        temperature=args.temperature,
        echo=args.echo,
    )
    print(reply)
    field.observe(reply)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
