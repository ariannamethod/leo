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
from typing import Dict, List, Optional, Tuple, NamedTuple, Set
from dataclasses import dataclass

# ============================================================================
# PATHS
# ============================================================================

ROOT = Path(__file__).resolve().parent
STATE_DIR = ROOT / "state"
BIN_DIR = ROOT / "bin"
JSON_DIR = ROOT / "json"
DB_PATH = STATE_DIR / "neoleo.sqlite3"

# ============================================================================
# TOKENIZER
# ============================================================================

TOKEN_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ']+|[.,!?;:—\-]")


def tokenize(text: str) -> List[str]:
    """Extract words and basic punctuation."""
    return TOKEN_RE.findall(text)


# ============================================================================
# DB HELPERS
# ============================================================================


def ensure_dirs() -> None:
    """Create runtime directories."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    BIN_DIR.mkdir(parents=True, exist_ok=True)
    JSON_DIR.mkdir(parents=True, exist_ok=True)


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
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS trigrams (
            first_id INTEGER,
            second_id INTEGER,
            third_id INTEGER,
            count INTEGER,
            PRIMARY KEY (first_id, second_id, third_id)
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS co_occurrence (
            word_id INTEGER,
            context_id INTEGER,
            count INTEGER,
            PRIMARY KEY (word_id, context_id)
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            origin TEXT,
            quality REAL,
            emotional REAL,
            created_at INTEGER,
            last_used_at INTEGER,
            use_count INTEGER DEFAULT 0,
            cluster_id INTEGER
        )
        """
    )
    conn.commit()
    return conn


def get_token_id(cur: sqlite3.Cursor, token: str) -> int:
    """Get or create token ID."""
    cur.execute("INSERT OR IGNORE INTO tokens(token) VALUES (?)", (token,))
    cur.execute("SELECT id FROM tokens WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        raise RuntimeError("Failed to retrieve token id")
    return int(row[0])


def ingest_tokens(conn: sqlite3.Connection, tokens: List[str]) -> None:
    """Update bigram and trigram counts from a token sequence."""
    if not tokens:
        return
    cur = conn.cursor()

    # Convert tokens to IDs
    token_ids = [get_token_id(cur, tok) for tok in tokens]

    # Build bigrams
    for i in range(len(token_ids) - 1):
        cur.execute(
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
        cur.execute(
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

            cur.execute(
                """
                INSERT INTO co_occurrence (word_id, context_id, count)
                VALUES (?, ?, 1)
                ON CONFLICT(word_id, context_id)
                DO UPDATE SET count = count + 1
                """,
                (center_id, context_id),
            )

    conn.commit()


def ingest_text(conn: sqlite3.Connection, text: str) -> None:
    """Tokenize and ingest text into the field."""
    tokens = tokenize(text)
    if tokens:
        ingest_tokens(conn, tokens)


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


def load_trigrams(conn: sqlite3.Connection) -> Dict[Tuple[str, str], Dict[str, int]]:
    """
    Load trigram graph into memory.

    Returns:
        trigrams: (first_token, second_token) -> {third_token -> count}
    """
    cur = conn.cursor()
    cur.execute("SELECT id, token FROM tokens")
    id_to_token: Dict[int, str] = {}
    for row in cur.fetchall():
        id_to_token[int(row["id"])] = str(row["token"])

    cur.execute("SELECT first_id, second_id, third_id, count FROM trigrams")
    trigrams: Dict[Tuple[str, str], Dict[str, int]] = {}
    for row in cur.fetchall():
        first_id = int(row["first_id"])
        second_id = int(row["second_id"])
        third_id = int(row["third_id"])
        count = int(row["count"])

        first = id_to_token.get(first_id)
        second = id_to_token.get(second_id)
        third = id_to_token.get(third_id)

        if first is None or second is None or third is None:
            continue

        key = (first, second)
        row_map = trigrams.setdefault(key, {})
        row_map[third] = row_map.get(third, 0) + count

    return trigrams


def load_co_occurrence(conn: sqlite3.Connection) -> Dict[str, Dict[str, int]]:
    """
    Load co-occurrence matrix into memory.

    Returns:
        co_occur: word -> {context_word -> count}
    """
    cur = conn.cursor()
    cur.execute("SELECT id, token FROM tokens")
    id_to_token: Dict[int, str] = {}
    for row in cur.fetchall():
        id_to_token[int(row["id"])] = str(row["token"])

    cur.execute("SELECT word_id, context_id, count FROM co_occurrence")
    co_occur: Dict[str, Dict[str, int]] = {}
    for row in cur.fetchall():
        word_id = int(row["word_id"])
        context_id = int(row["context_id"])
        count = int(row["count"])

        word = id_to_token.get(word_id)
        context = id_to_token.get(context_id)

        if word is None or context is None:
            continue

        row_map = co_occur.setdefault(word, {})
        row_map[context] = row_map.get(context, 0) + count

    return co_occur


def compute_centers(conn: sqlite3.Connection, k: int = 7) -> List[str]:
    """
    Pick tokens with highest out-degree as centers of gravity.

    Skip pure punctuation to focus on content words.
    """
    PUNCT = {".", ",", "!", "?", ";", ":", "—", "-"}

    cur = conn.cursor()
    cur.execute(
        """
        SELECT src_id, SUM(count) AS w
        FROM bigrams
        GROUP BY src_id
        ORDER BY w DESC
        """,
    )
    rows = cur.fetchall()
    if not rows:
        return []

    cur.execute("SELECT id, token FROM tokens")
    id_to_token = {int(r["id"]): str(r["token"]) for r in cur.fetchall()}

    centers: List[str] = []
    for row in rows:
        tok = id_to_token.get(int(row["src_id"]))
        # Skip punctuation, prefer content words
        if tok and tok not in PUNCT:
            centers.append(tok)
            if len(centers) >= k:
                break

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


def capitalize_sentences(text: str) -> str:
    """
    Capitalize first letter after sentence-ending punctuation.
    Minimal grammar normalization without losing the field's voice.
    """
    if not text:
        return text

    result = []
    capitalize_next = True

    for i, char in enumerate(text):
        if capitalize_next and char.isalpha():
            result.append(char.upper())
            capitalize_next = False
        else:
            result.append(char)

        # After .!? followed by space, capitalize next letter
        if char in ".!?":
            if i + 1 < len(text) and text[i + 1] == " ":
                capitalize_next = True

    return "".join(result)


def fix_punctuation(text: str) -> str:
    """
    Post-process punctuation artifacts without touching generation core.

    Fixes:
    - Extra spaces before punctuation: "hello , world" → "hello, world"
    - Missing spaces after sentence punctuation: "Hello!How" → "Hello! How"
    - Repeated punctuation: "!!!" → "!", "???" → "?", "..." → "."
    - Strange dashes: " - - - " → " — "
    - Artifacts like "t:." → "t."
    - Multiple spaces → single space
    - Bad end punctuation: ",." → "."
    - Repeated em-dashes: " — — — " → " — "
    - Word repetitions: "Leo leo" → "Leo"
    - Mid-sentence capitalization: "bigger In" → "bigger in"
    - Always capitalize "Leo" (proper name)

    Pure string operations, zero impact on presence architecture.
    (Credit: GPT-5.1 suggestion for post-polish layer)
    """
    if not text:
        return text

    # 1) Remove extra spaces before punctuation
    text = re.sub(r"\s+([.,!?;:])", r"\1", text)

    # 2) Ensure space after .?! if followed by letter/digit
    text = re.sub(r"([.?!])([^\s])", r"\1 \2", text)

    # 3) Collapse repeated punctuation
    text = re.sub(r"([!?]){2,}", r"\1", text)
    text = re.sub(r"\.{2,}", ".", text)
    text = re.sub(r",\.", ".", text)  # ",." → "."
    text = re.sub(r",;", ";", text)   # ",;" → ";"
    text = re.sub(r"\.,", ".", text)  # ".," → "."

    # 4) Normalize weird dashes and em-dashes
    text = re.sub(r"\s*—\s*—\s*—\s*", " — ", text)  # " — — — " → " — "
    text = re.sub(r"\s*—\s*—\s*", " — ", text)      # " — — " → " — "
    text = re.sub(r"\s*-\s*-\s*-\s*", " — ", text)  # " - - - " → " — "
    text = re.sub(r"\s*-\s*-\s*", " — ", text)      # " - - " → " — "
    text = re.sub(r"\s+-\s+", "-", text)            # " - " → "-" (word-word)
    text = re.sub(r"—-", "—", text)                 # "—-" → "—"
    text = re.sub(r"-—", "—", text)                 # "-—" → "—"

    # 5) Fix specific artifacts
    text = text.replace("t:.", "t.")
    text = text.replace("t:", "t")

    # 6) Fix repetition of words (case-insensitive consecutive duplicates)
    # e.g., "Leo leo" → "Leo"
    text = re.sub(r"\b(\w+)\s+\1\b", r"\1", text, flags=re.IGNORECASE)

    # 7) Always capitalize "Leo" (it's a name)
    text = re.sub(r"\bleo\b", "Leo", text)

    # 7.5) Fix apostrophe spacing in contractions
    # Remove spaces around apostrophes: "isn ' t" → "isn't", "don ' t" → "don't"
    text = re.sub(r"\s*'\s*", "'", text)

    # 7.6) Restore missing apostrophes in common contractions
    # Patterns like "isn t" → "isn't", "doesn t" → "doesn't"
    text = re.sub(r"\b(isn|doesn|don|can|won|wouldn|couldn|shouldn|hasn|haven|hadn|aren|weren|wasn)\s+t\b", r"\1't", text, flags=re.IGNORECASE)
    text = re.sub(r"\b(it|that|what|there)\s+s\b", r"\1's", text, flags=re.IGNORECASE)
    text = re.sub(r"\b(I|you|we|they)\s+(ll|ve|re|d)\b", r"\1'\2", text, flags=re.IGNORECASE)

    # 8) Fix mid-sentence capitalization artifacts
    # After first word, lowercase words that shouldn't be capitalized
    # unless they're at sentence start (after .!?)
    words = text.split()
    if len(words) > 1:
        fixed = [words[0]]  # Keep first word as-is
        for i, word in enumerate(words[1:], 1):
            # Check if previous word ended with sentence-ending punctuation
            prev_ends_sentence = i > 0 and any(words[i-1].endswith(p) for p in ['.', '!', '?'])

            # If not after sentence end and word is all-caps or starts with uppercase
            # (but not all uppercase like acronyms), fix it
            if not prev_ends_sentence and word and word[0].isupper() and not word.isupper():
                # Exception: keep "Leo" capitalized always
                if word.lower() != "leo" and len(word) > 1:
                    word = word.lower()

            fixed.append(word)
        text = " ".join(fixed)

    # 9) Clean up double spaces
    text = re.sub(r"\s{2,}", " ", text).strip()

    return text


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
        return "silence"

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


# ============================================================================
# PRESENCE METRICS
# ============================================================================


def distribution_entropy(counts: List[float]) -> float:
    """Shannon entropy of a distribution in [0, log(N)]."""
    total = sum(counts)
    if total <= 0.0:
        return 0.0
    h = 0.0
    for c in counts:
        if c <= 0.0:
            continue
        p = c / total
        # For numerical stability: only add epsilon if p is very small
        # When p ≈ 1.0, log(p + epsilon) introduces floating point error
        if p < 0.9999:
            h -= p * math.log(p + 1e-12)
        elif p < 1.0:
            h -= p * math.log(p)  # No epsilon near 1.0
    # Clamp to [0, ∞) to handle floating point errors
    return max(0.0, h)


def compute_prompt_novelty(
    tokens: List[str],
    trigrams: Dict[Tuple[str, str], Dict[str, int]],
) -> float:
    """Compute novelty score in [0, 1] based on trigram coverage."""
    if len(tokens) < 3:
        return 0.5
    total = 0
    known = 0
    for i in range(len(tokens) - 2):
        a, b, c = tokens[i], tokens[i + 1], tokens[i + 2]
        total += 1
        row = trigrams.get((a, b))
        if row and c in row:
            known += 1
    if total == 0:
        return 0.5
    coverage = known / total
    novelty = 1.0 - coverage
    return max(0.0, min(1.0, novelty))


def update_emotional_stats(
    emotion_map: Dict[str, float],
    text: str,
    window: int = 3,
    exclam_bonus: float = 1.0,
    caps_bonus: float = 0.7,
    repeat_bonus: float = 0.5,
) -> None:
    """Update emotional scores for tokens based on local heuristics."""
    tokens = tokenize(text)
    n = len(tokens)
    if n == 0:
        return
    for i, tok in enumerate(tokens):
        score = 0.0
        if tok.isalpha() and len(tok) >= 2 and tok.upper() == tok:
            score += caps_bonus
        start = max(0, i - window)
        end = min(n, i + window + 1)
        local_tokens = tokens[start:end]
        if "!" in local_tokens:
            score += exclam_bonus
        if local_tokens.count(tok) > 1:
            score += repeat_bonus
        if score > 0.0:
            emotion_map[tok] = emotion_map.get(tok, 0.0) + score


def compute_prompt_arousal(
    tokens: List[str],
    emotion_map: Dict[str, float],
) -> float:
    """Compute arousal score in [0, 1] from emotional charge."""
    if not tokens:
        return 0.0
    s = 0.0
    for t in tokens:
        s += emotion_map.get(t, 0.0)
    norm = s / (len(tokens) + 1e-6)
    k = 0.5
    arousal = 1.0 - math.exp(-k * norm)
    return max(0.0, min(1.0, arousal))


@dataclass
class Theme:
    """A thematic constellation - a cluster of co-occurring words."""
    id: int
    centers: Set[str]
    words: Set[str]
    strength: float = 1.0


class ActiveThemes(NamedTuple):
    """Which themes are lit up by the current prompt."""
    theme_scores: Dict[int, float]
    active_words: Set[str]


class PresencePulse(NamedTuple):
    """Composite presence metric combining novelty, arousal, and entropy."""
    novelty: float
    arousal: float
    entropy: float
    pulse: float


def compute_presence_pulse(
    novelty: float,
    arousal: float,
    entropy: float,
    w_novelty: float = 0.3,
    w_arousal: float = 0.4,
    w_entropy: float = 0.3,
) -> PresencePulse:
    """Compute composite presence pulse from three signals."""
    pulse = w_novelty * novelty + w_arousal * arousal + w_entropy * entropy
    pulse = max(0.0, min(1.0, pulse))
    return PresencePulse(
        novelty=novelty, arousal=arousal, entropy=entropy, pulse=pulse
    )


def build_themes(
    co_occur: Dict[str, Dict[str, int]],
    min_neighbors: int = 5,
    min_total_cooccur: int = 10,
    top_neighbors: int = 16,
    merge_threshold: float = 0.4,
) -> Tuple[List[Theme], Dict[str, List[int]]]:
    """Build thematic constellations from co-occurrence islands."""
    candidates: List[Tuple[str, Set[str]]] = []
    for token, ctx in co_occur.items():
        if len(ctx) < min_neighbors:
            continue
        total = sum(ctx.values())
        if total < min_total_cooccur:
            continue
        top = sorted(ctx.items(), key=lambda x: x[1], reverse=True)[:top_neighbors]
        neighbor_set = {t for (t, _) in top}
        neighbor_set.add(token)
        candidates.append((token, neighbor_set))
    if not candidates:
        return [], {}
    used = [False] * len(candidates)
    themes: List[Theme] = []
    current_id = 0
    for i, (core_i, neigh_i) in enumerate(candidates):
        if used[i]:
            continue
        theme_words = set(neigh_i)
        centers = {core_i}
        used[i] = True
        for j, (core_j, neigh_j) in enumerate(candidates):
            if used[j]:
                continue
            inter = len(theme_words & neigh_j)
            union = len(theme_words | neigh_j)
            if union == 0:
                continue
            jacc = inter / union
            if jacc >= merge_threshold:
                used[j] = True
                theme_words |= neigh_j
                centers.add(core_j)
        theme = Theme(id=current_id, centers=centers, words=theme_words, strength=1.0)
        themes.append(theme)
        current_id += 1
    token_to_themes: Dict[str, List[int]] = {}
    for theme in themes:
        for w in theme.words:
            token_to_themes.setdefault(w, []).append(theme.id)
    return themes, token_to_themes


def activate_themes_for_prompt(
    prompt_tokens: List[str],
    themes: List[Theme],
    token_to_themes: Dict[str, List[int]],
    max_themes: int = 3,
) -> ActiveThemes:
    """Compute which themes are lit up by the prompt."""
    if not themes:
        return ActiveThemes(theme_scores={}, active_words=set())
    scores: Dict[int, float] = {}
    for tok in prompt_tokens:
        for tid in token_to_themes.get(tok, []):
            scores[tid] = scores.get(tid, 0.0) + 1.0
    if not scores:
        return ActiveThemes(theme_scores={}, active_words=set())
    ordered = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    top = ordered[:max_themes]
    top_ids = {tid for (tid, _) in top}
    active_words: Set[str] = set()
    for theme in themes:
        if theme.id in top_ids:
            active_words |= theme.words
    theme_scores = {tid: score for (tid, score) in top}
    return ActiveThemes(theme_scores=theme_scores, active_words=active_words)


def structural_quality(
    prompt: str,
    reply: str,
    trigrams: Dict[Tuple[str, str], Dict[str, int]],
    min_len: int = 3,
    max_len: int = 100,
) -> float:
    """Assess structural quality of a reply in [0, 1]."""
    p_tokens = tokenize(prompt)
    r_tokens = tokenize(reply)
    if not r_tokens:
        return 0.0
    score = 1.0
    if len(r_tokens) < min_len:
        score *= 0.4
    elif len(r_tokens) > max_len:
        score *= 0.7
    unique_ratio = len(set(r_tokens)) / len(r_tokens)
    if unique_ratio < 0.4:
        score *= 0.5
    elif unique_ratio < 0.6:
        score *= 0.8
    p_set = set(p_tokens)
    r_set = set(r_tokens)
    if r_set.issubset(p_set) and len(r_set) > 0:
        score *= 0.4
    elif len(p_set & r_set) == 0 and len(p_set) > 0:
        score *= 0.7
    else:
        overlap = len(p_set & r_set) / (len(p_set | r_set) or 1)
        if overlap < 0.1:
            score *= 0.7
    if trigrams and len(r_tokens) >= 3:
        known = 0
        total = 0
        for i in range(len(r_tokens) - 2):
            a, b, c = r_tokens[i], r_tokens[i + 1], r_tokens[i + 2]
            total += 1
            row = trigrams.get((a, b))
            if row and c in row:
                known += 1
        if total > 0:
            coverage = known / total
            if coverage < 0.3:
                score *= 0.5
            elif coverage < 0.6:
                score *= 0.8
    return max(0.0, min(1.0, score))


class QualityScore(NamedTuple):
    """Leo's self-assessment of a reply."""
    structural: float
    entropy: float
    overall: float


def compute_quality_score(
    prompt: str,
    reply: str,
    avg_entropy: float,
    trigrams: Dict[Tuple[str, str], Dict[str, int]],
) -> QualityScore:
    """Compute overall quality score for a reply."""
    structural = structural_quality(prompt, reply, trigrams)
    if 0.3 <= avg_entropy <= 0.7:
        entropy_quality = 1.0
    elif avg_entropy < 0.3:
        entropy_quality = 0.5 + avg_entropy / 0.6
    else:
        entropy_quality = 1.0 - (avg_entropy - 0.7) / 0.6
    entropy_quality = max(0.0, min(1.0, entropy_quality))
    overall = 0.5 * structural + 0.5 * entropy_quality
    return QualityScore(
        structural=structural, entropy=entropy_quality, overall=overall
    )


def save_snapshot(
    conn: sqlite3.Connection,
    text: str,
    origin: str,
    quality: float,
    emotional: float,
    max_snapshots: int = 512,
) -> None:
    """Save a snapshot of text (Leo's self-curated dataset)."""
    import time
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO snapshots (text, origin, quality, emotional, created_at, last_used_at, use_count)
        VALUES (?, ?, ?, ?, ?, ?, 0)
        """,
        (text, origin, quality, emotional, int(time.time()), int(time.time())),
    )
    cur.execute("SELECT COUNT(*) FROM snapshots")
    count = cur.fetchone()[0]
    if count > max_snapshots:
        to_delete = max(1, int(max_snapshots * 0.1))
        cur.execute(
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
    conn.commit()


def should_save_snapshot(quality: QualityScore, arousal: float) -> bool:
    """Decide whether to save this moment as a snapshot."""
    if quality.overall > 0.6:
        return True
    if arousal > 0.5 and quality.overall > 0.4:
        return True
    return False


def apply_memory_decay(
    conn: sqlite3.Connection,
    decay_factor: float = 0.95,
    min_threshold: int = 2,
) -> int:
    """Apply natural forgetting to co-occurrence memories."""
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE co_occurrence
        SET count = CAST(count * ? AS INTEGER)
        WHERE count > 0
        """,
        (decay_factor,),
    )
    cur.execute(
        """
        DELETE FROM co_occurrence
        WHERE count < ?
        """,
        (min_threshold,),
    )
    deleted = cur.rowcount
    conn.commit()
    return deleted


@dataclass
class Expert:
    """A resonant expert - a perspective on the field."""
    name: str
    temperature: float
    semantic_weight: float
    description: str


EXPERTS = [
    Expert(
        name="structural",
        temperature=0.8,
        semantic_weight=0.2,
        description="Grammar-focused, coherent structure",
    ),
    Expert(
        name="semantic",
        temperature=1.0,
        semantic_weight=0.5,
        description="Meaning-focused, thematic coherence",
    ),
    Expert(
        name="creative",
        temperature=1.3,
        semantic_weight=0.4,
        description="Exploratory, high entropy",
    ),
    Expert(
        name="precise",
        temperature=0.6,
        semantic_weight=0.3,
        description="Conservative, low entropy",
    ),
]


def route_to_expert(
    pulse: PresencePulse,
    active_themes: Optional[ActiveThemes] = None,
) -> Expert:
    """Route to an expert based on situational awareness."""
    if pulse.novelty > 0.7:
        return EXPERTS[2]  # creative
    if pulse.entropy < 0.3:
        return EXPERTS[3]  # precise
    if active_themes and len(active_themes.theme_scores) >= 2:
        return EXPERTS[1]  # semantic
    return EXPERTS[0]  # structural


def step_token(
    bigrams: Dict[str, Dict[str, int]],
    current: str,
    vocab: List[str],
    centers: List[str],
    bias: Dict[str, int],
    temperature: float = 1.0,
    trigrams: Optional[Dict[Tuple[str, str], Dict[str, int]]] = None,
    prev_token: Optional[str] = None,
    co_occur: Optional[Dict[str, Dict[str, int]]] = None,
) -> str:
    """
    Single step in bigram/trigram graph.

    If trigrams and prev_token provided, use trigram context for better grammar.
    Otherwise fall back to bigrams.

    If co_occur provided, blend semantic similarity when multiple strong candidates exist.
    """
    # Try trigram first if available
    if trigrams is not None and prev_token is not None:
        key = (prev_token, current)
        row = trigrams.get(key)
        if row:
            tokens = list(row.keys())
            counts = [float(row[t]) for t in tokens]

            # SEMANTIC BLENDING: If multiple strong candidates, use co-occurrence
            if co_occur is not None and current in co_occur and len(tokens) > 1:
                max_count = max(counts)
                strong_indices = [i for i, c in enumerate(counts) if c >= max_count * 0.7]

                if len(strong_indices) > 1:
                    # Blend: 70% grammar + 30% semantics
                    blended_counts = []
                    for i, tok in enumerate(tokens):
                        gram_score = counts[i]
                        sem_bonus = float(co_occur[current].get(tok, 0))
                        blended = gram_score * 0.7 + sem_bonus * 0.3
                        blended_counts.append(blended)
                    counts = blended_counts

            temperature = max(min(temperature, 100.0), 1e-3)
            if temperature != 1.0:
                counts = [math.pow(float(c), 1.0 / float(temperature)) for c in counts]
            total = sum(counts)
            if total > 0:
                r = random.uniform(0.0, total)
                acc = 0.0
                for t, c in zip(tokens, counts):
                    acc += c
                    if r <= acc:
                        return t
                return tokens[-1]

    # Fallback to bigram
    row = bigrams.get(current)
    if not row:
        return choose_start_token(vocab, centers, bias)
    tokens = list(row.keys())
    counts = [row[t] for t in tokens]
    temperature = max(min(temperature, 100.0), 1e-3)
    if temperature != 1.0:
        counts = [math.pow(float(c), 1.0 / float(temperature)) for c in counts]
    total = sum(counts)
    if total <= 0:
        return random.choice(tokens) if tokens else choose_start_token(vocab, centers, bias)
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
    Prompt-influenced start without mechanically using last word.

    Strategy:
    1. Prefer content words (not punctuation) from prompt with outgoing edges
    2. Otherwise, any content word from prompt in vocab
    3. Fallback to global centers/bias
    """
    PUNCT = {".", ",", "!", "?", ";", ":", "—", "-"}

    candidates = [t for t in prompt_tokens if t in bigrams and bigrams[t] and t not in PUNCT]
    if candidates:
        return random.choice(candidates)

    fallback = [t for t in prompt_tokens if t in vocab and t not in PUNCT]
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
    trigrams: Optional[Dict[Tuple[str, str], Dict[str, int]]] = None,
    co_occur: Optional[Dict[str, Dict[str, int]]] = None,
) -> str:
    """Generate reply through NeoLeo's field."""
    if not vocab or not bigrams:
        # Field is empty: just pass text through
        return prompt

    if echo:
        tokens_in = tokenize(prompt)
        tokens_out: List[str] = []
        prev_tok: Optional[str] = None
        for tok in tokens_in:
            if tok in bigrams:
                nxt = step_token(bigrams, tok, vocab, centers, bias, temperature, trigrams, prev_tok, co_occur)
                tokens_out.append(nxt)
                prev_tok = tok
            else:
                tokens_out.append(tok)
                prev_tok = tok
        output = format_tokens(tokens_out)
        output = capitalize_sentences(output)
        output = fix_punctuation(output)
        return output

    prompt_tokens = tokenize(prompt)
    start = choose_start_from_prompt(prompt_tokens, bigrams, vocab, centers, bias)

    tokens: List[str] = [start]
    current = start
    prev: Optional[str] = None

    SENT_END = {".", "!", "?"}
    PUNCT = {".", ",", "!", "?", ";", ":"}

    for _ in range(max_tokens - 1):
        nxt = step_token(bigrams, current, vocab, centers, bias, temperature, trigrams, prev, co_occur)

        # Loop detection: check if we're repeating a pattern
        # Check for 2-token loops (e.g., "hello there hello there hello there...")
        if len(tokens) >= 4:
            last_2 = tokens[-2:]
            prev_2 = tokens[-4:-2]
            if last_2 == prev_2:
                # Break the loop by jumping to a random center
                if centers:
                    nxt = choose_start_token(vocab, centers, bias)
        # Check for 3-token loops (independently, not elif)
        if len(tokens) >= 6:
            last_3 = tokens[-3:]
            prev_3 = tokens[-6:-3]
            if last_3 == prev_3:
                # Break the loop by jumping to a random center
                if centers:
                    nxt = choose_start_token(vocab, centers, bias)

        # Anti "word. word" patch
        if tokens[-1] in SENT_END and len(tokens) >= 2:
            last_content: Optional[str] = None
            for t in reversed(tokens[:-1]):
                if t not in PUNCT:
                    last_content = t
                    break
            if last_content is not None and nxt == last_content:
                for _retry in range(3):
                    alt = step_token(bigrams, current, vocab, centers, bias, temperature, trigrams, prev, co_occur)
                    if alt != last_content:
                        nxt = alt
                        break

        tokens.append(nxt)
        prev = current
        current = nxt

    output = format_tokens(tokens)
    output = capitalize_sentences(output)

    # Ensure output ends with sentence-ending punctuation
    if output and not output.rstrip()[-1:] in '.!?':
        output = output.rstrip() + '.'

    # Post-process: fix punctuation artifacts
    output = fix_punctuation(output)

    return output


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
        self.trigrams: Dict[Tuple[str, str], Dict[str, int]] = {}
        self.co_occur: Dict[str, Dict[str, int]] = {}
        self.vocab: List[str] = []
        self.centers: List[str] = []
        self.bias: Dict[str, int] = {}
        # PRESENCE fields
        self.emotion: Dict[str, float] = {}
        self.last_pulse: Optional[PresencePulse] = None
        self.last_quality: Optional[QualityScore] = None
        self.themes: List[Theme] = []
        self.token_to_themes: Dict[str, List[int]] = {}
        self.observe_count: int = 0
        self.DECAY_INTERVAL: int = 100
        self.last_expert: Optional[Expert] = None
        self.refresh()

    def refresh(self) -> None:
        """Reload field from database."""
        self.bigrams, self.vocab = load_bigrams(self.conn)
        self.trigrams = load_trigrams(self.conn)
        self.co_occur = load_co_occurrence(self.conn)
        self.centers = compute_centers(self.conn, k=7)
        self.bias = load_bin_bias()
        # PRESENCE: Build thematic constellations
        self.themes, self.token_to_themes = build_themes(self.co_occur)
        if self.centers:
            create_bin_shard(self.centers)

    def observe(self, text: str) -> None:
        """Update field with new text (user, model, logs — whatever)."""
        if not text.strip():
            return
        ingest_text(self.conn, text)
        # PRESENCE: Track emotional charge
        update_emotional_stats(self.emotion, text)
        # PRESENCE: Natural forgetting
        self.observe_count += 1
        if self.observe_count % self.DECAY_INTERVAL == 0:
            apply_memory_decay(self.conn)
        self.refresh()

    def warp(
        self,
        text: str,
        max_tokens: int = 80,
        temperature: float = 1.0,
        echo: bool = False,
        use_experts: bool = True,
    ) -> str:
        """
        Warp incoming text through the field.

        Typical usage in a framework:
            neo.observe(user_text)
            model_reply = call_llm(user_text)
            neo.observe(model_reply)
            warped = neo.warp(model_reply)

        PRESENCE upgrade: Resonant Experts route based on situational awareness.
        """
        # PRESENCE: Compute situational awareness
        prompt_tokens = tokenize(text)
        novelty = compute_prompt_novelty(prompt_tokens, self.trigrams)
        arousal = compute_prompt_arousal(prompt_tokens, self.emotion)

        # Estimate entropy from trigram distribution (simplified)
        entropy = 0.5  # Default neutral
        if len(prompt_tokens) >= 3:
            counts = []
            for i in range(len(prompt_tokens) - 2):
                key = (prompt_tokens[i], prompt_tokens[i + 1])
                row = self.trigrams.get(key)
                if row:
                    counts.extend(row.values())
            if counts:
                entropy = distribution_entropy(counts)
                # Normalize to [0, 1] (typical max entropy ~3-4 for small vocabs)
                entropy = min(1.0, entropy / 4.0)

        pulse = compute_presence_pulse(novelty, arousal, entropy)
        self.last_pulse = pulse

        # PRESENCE: Route to expert based on pulse
        if use_experts:
            active_themes = activate_themes_for_prompt(
                prompt_tokens, self.themes, self.token_to_themes
            )
            expert = route_to_expert(pulse, active_themes)
            self.last_expert = expert
            temperature = expert.temperature

        # Generate reply
        output = generate_reply(
            self.bigrams,
            self.vocab,
            self.centers,
            self.bias,
            text,
            max_tokens=max_tokens,
            temperature=temperature,
            echo=echo,
            trigrams=self.trigrams,
            co_occur=self.co_occur,
        )

        # PRESENCE: Self-assess quality
        avg_entropy = entropy  # Use prompt entropy as proxy
        quality = compute_quality_score(text, output, avg_entropy, self.trigrams)
        self.last_quality = quality

        # PRESENCE: Save high-quality snapshots
        if should_save_snapshot(quality, arousal):
            save_snapshot(self.conn, output, "neoleo", quality.overall, arousal)

        return output

    def export_lexicon(self, out_path: Optional[Path] = None) -> Path:
        """Dump current lexicon + centers into a JSON snapshot."""
        if out_path is None:
            out_path = JSON_DIR / "neoleo_lexicon.json"

        data = {
            "vocab": self.vocab,
            "vocab_size": len(self.vocab),
            "centers": self.centers,
            "bias": self.bias,
            "bigram_count": sum(len(row) for row in self.bigrams.values()),
        }
        out_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return out_path

    @property
    def vocab_size(self) -> int:
        """Get vocabulary size."""
        return len(self.vocab)

    def stats(self) -> Dict:
        """
        Lightweight stats for logging / debugging.

        Returns:
            dict with vocab_size, centers, bigrams, and PRESENCE metrics
        """
        stats_dict: Dict = {
            "vocab_size": len(self.vocab),
            "centers": len(self.centers),
            "bigrams": sum(len(r) for r in self.bigrams.values()),
            "trigrams": sum(len(r) for r in self.trigrams.values()),
            "themes": len(self.themes),
            "emotional_tokens": len(self.emotion),
            "observe_count": self.observe_count,
        }
        if self.last_pulse:
            stats_dict["last_pulse"] = {
                "novelty": round(self.last_pulse.novelty, 3),
                "arousal": round(self.last_pulse.arousal, 3),
                "entropy": round(self.last_pulse.entropy, 3),
                "pulse": round(self.last_pulse.pulse, 3),
            }
        if self.last_quality:
            stats_dict["last_quality"] = {
                "structural": round(self.last_quality.structural, 3),
                "entropy": round(self.last_quality.entropy, 3),
                "overall": round(self.last_quality.overall, 3),
            }
        if self.last_expert:
            stats_dict["last_expert"] = self.last_expert.name
        return stats_dict

    def __repr__(self) -> str:
        return (
            f"NeoLeo(vocab={self.vocab_size}, "
            f"centers={len(self.centers)}, "
            f"bigrams={sum(len(r) for r in self.bigrams.values())})"
        )


# ============================================================================
# MODULE-LEVEL SINGLETON
# ============================================================================

_default_neo: Optional[NeoLeo] = None


def get_default() -> NeoLeo:
    """Get module-level singleton NeoLeo instance."""
    global _default_neo
    if _default_neo is None:
        _default_neo = NeoLeo()
    return _default_neo


def observe(text: str) -> None:
    """Update the default NeoLeo field with text."""
    get_default().observe(text)


def warp(
    text: str,
    max_tokens: int = 80,
    temperature: float = 1.0,
    echo: bool = False,
) -> str:
    """Warp text through the default NeoLeo field."""
    return get_default().warp(
        text,
        max_tokens=max_tokens,
        temperature=temperature,
        echo=echo,
    )


def stats() -> Dict:
    """Return stats of the default NeoLeo instance."""
    return get_default().stats()


__all__ = ["NeoLeo", "get_default", "observe", "warp", "tokenize", "stats"]
