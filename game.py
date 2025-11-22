#!/usr/bin/env python3
"""
game.py — Sequential playfield for Leo

Lightweight sequencing layer that learns conversational rhythm:
"Given the last 1-2 turns, what type of turn usually comes next?"

Returns soft hints (mode, expert, length, tension) for:
- expert routing (Resonant Experts)
- theme emphasis (ThemeLayer / SANTACLAUS)
- length / temperature nudges

If game.py is missing or fails, leo behaves exactly as now.
No hard dependency. Advisory, not sovereign.
"""

from __future__ import annotations

import sqlite3
import random
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Tuple, List, Optional, Sequence, Literal, Any

# Safe import: mathbrain for MathState
try:
    from mathbrain import MathState
    MATH_AVAILABLE = True
except ImportError:
    MathState = Any  # type: ignore
    MATH_AVAILABLE = False

GAME_AVAILABLE = True  # Set to False on catastrophic init error


# ============================================================================
# TYPE DEFINITIONS
# ============================================================================

Role = Literal["human", "leo"]
Mode = Literal["q", "a", "meta", "story", "ack"]
Bucket = Literal["low", "mid", "high"]
ExpertName = Literal["structural", "semantic", "creative", "precise", "wounded"]
LengthHint = Literal["short", "medium", "long"]
TensionShift = Literal["softer", "same", "stronger"]


# ============================================================================
# GAME TURN — one conversational move
# ============================================================================

@dataclass
class GameTurn:
    """
    Abstraction over "what kind of step this was".

    Built from existing signals (pulse, trauma, expert, themes, quality).
    """
    role: Role
    mode: Mode                # question / answer / meta / story / short ack
    arousal: Bucket           # from PresencePulse
    trauma: Bucket            # from trauma.level
    entropy: Bucket           # from pulse.entropy
    expert: ExpertName        # which expert actually replied
    theme_id: int             # dominant theme id, or -1 if none
    quality: Bucket           # self-assessed quality bucket (for leo only)

    def to_id(self) -> str:
        """
        Compact, stable identifier for this turn type.

        Example:
            "H:Q:A_LOW:T_LOW:E_MID:TH_-1:EX_structural:Q_MID"
        """
        role_short = "H" if self.role == "human" else "L"
        mode_short = self.mode.upper()
        return (
            f"{role_short}:{mode_short}:"
            f"A_{self.arousal.upper()}:T_{self.trauma.upper()}:E_{self.entropy.upper()}:"
            f"TH_{self.theme_id}:EX_{self.expert}:Q_{self.quality.upper()}"
        )

    @classmethod
    def from_context(
        cls,
        role: Role,
        mode: Mode,
        math_state: MathState,
        theme_id: int,
        expert: ExpertName,
        quality_value: Optional[float],
    ) -> GameTurn:
        """
        Construct GameTurn from context.

        Args:
            role: "human" or "leo"
            mode: "q", "a", "meta", "story", "ack"
            math_state: MathState with arousal, entropy, trauma_level
            theme_id: dominant theme ID or -1
            expert: expert name used for this turn
            quality_value: quality score (0-1) or None (defaults to "mid")
        """
        if not MATH_AVAILABLE:
            # Fallback if mathbrain not available
            arousal = "mid"
            trauma = "low"
            entropy = "mid"
            quality = "mid"
        else:
            arousal = bucketize(math_state.arousal)
            trauma = bucketize(math_state.trauma_level)
            entropy = bucketize(math_state.entropy)

            if quality_value is None:
                quality = "mid"
            else:
                quality = bucketize(quality_value)

        return cls(
            role=role,
            mode=mode,
            arousal=arousal,
            trauma=trauma,
            entropy=entropy,
            expert=expert,
            theme_id=theme_id,
            quality=quality,
        )


# ============================================================================
# GAME HINT — advisory output
# ============================================================================

@dataclass
class GameHint:
    """
    What leo can do with this next.

    All fields are optional. If confidence is low or data is weak,
    fields may be None. Callers must treat this as soft bias.
    """
    mode: Optional[Mode] = None
    preferred_expert: Optional[ExpertName] = None
    target_length: Optional[LengthHint] = None
    tension_shift: Optional[TensionShift] = None
    confidence: float = 0.0  # 0..1


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def bucketize(x: float, low: float = 0.33, high: float = 0.66) -> Bucket:
    """
    Convert float in [0,1] to low/mid/high bucket.

    Args:
        x: value to bucketize (assumed in [0,1])
        low: threshold for low/mid boundary
        high: threshold for mid/high boundary

    Returns:
        "low", "mid", or "high"
    """
    if x < low:
        return "low"
    if x > high:
        return "high"
    return "mid"


def decode_game_id(turn_id: str) -> Optional[Dict[str, Any]]:
    """
    Parse GameTurn.to_id() string back into components.

    Example input:
        "H:Q:A_LOW:T_MID:E_HIGH:TH_3:EX_semantic:Q_MID"

    Returns:
        Dict with keys: role, mode, arousal, trauma, entropy, theme_id, expert, quality
        or None if parsing fails
    """
    try:
        parts = turn_id.split(":")
        if len(parts) != 8:
            return None

        role_short, mode_short, arousal_part, trauma_part, entropy_part, theme_part, expert_part, quality_part = parts

        role = "human" if role_short == "H" else "leo"
        mode = mode_short.lower()  # type: ignore
        arousal = arousal_part.split("_")[1].lower()  # type: ignore
        trauma = trauma_part.split("_")[1].lower()  # type: ignore
        entropy = entropy_part.split("_")[1].lower()  # type: ignore
        theme_id = int(theme_part.split("_")[1])
        expert = expert_part.split("_")[1]  # type: ignore
        quality = quality_part.split("_")[1].lower()  # type: ignore

        return {
            "role": role,
            "mode": mode,
            "arousal": arousal,
            "trauma": trauma,
            "entropy": entropy,
            "theme_id": theme_id,
            "expert": expert,
            "quality": quality,
        }
    except Exception:
        return None


def detect_mode_from_text(text: str, is_reply: bool = False) -> Mode:
    """
    Simple heuristic to detect turn mode from text.

    Args:
        text: input text (prompt or reply)
        is_reply: True if this is leo's reply, False if human prompt

    Returns:
        Mode: "q", "ack", "meta", "story", or "a"
    """
    text_lower = text.lower().strip()

    # Meta markers first (identity, self-reference)
    if any(kw in text_lower for kw in ["who are you", "what is leo", "yourself", "your name", "trauma", "bootstrap"]):
        return "meta"

    # Question markers (check after meta, before length)
    if "?" in text or any(text_lower.startswith(q) for q in ["what", "why", "how", "who", "when", "where", "can", "do", "is", "are"]):
        return "q"

    # Very short → ack (after checking question/meta)
    if len(text) < 20:
        return "ack"

    # Long narrative → story
    if len(text) > 200 and ("..." in text or "—" in text or text.count(".") > 3):
        return "story"

    # Default
    return "a"


# ============================================================================
# GAME ENGINE — transition graph & suggestion
# ============================================================================

class GameEngine:
    """
    Lightweight A+B->C transition graph over GameTurn IDs.

    - Stores counts for transitions (A,B)->C
    - Keeps minimal global stats (#episodes) for chain length growth
    - All heavy I/O wrapped in try/except and silent on failure
    """

    def __init__(self, db_path: Optional[Path] = None) -> None:
        """
        Initialize GameEngine.

        Args:
            db_path: path to SQLite database (default: state/game.sqlite3)
        """
        if db_path is None:
            db_path = Path(__file__).parent / "state" / "game.sqlite3"

        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)

        # In-memory transition graph: (A_id, B_id) -> Counter({C_id: count})
        self._transitions: Dict[Tuple[str, str], Counter] = defaultdict(Counter)

        # Global singles: most common C overall (fallback)
        self._single: Counter = Counter()

        # Episode count for growth heuristic
        self._episode_count: int = 0

        # In-memory last turns per conversation
        self._last_turns: Dict[str, List[GameTurn]] = {}

        # Try to load from sqlite (optional)
        self._load_state_safe()

    # ========================================================================
    # PUBLIC API
    # ========================================================================

    def observe_turn(self, conv_id: str, turn: GameTurn) -> None:
        """
        Register one new GameTurn in a given conversation.

        If we have at least 2 previous turns in this conv, update A+B->C stats.

        Args:
            conv_id: conversation identifier (e.g., session ID)
            turn: GameTurn to register
        """
        try:
            # Update conversation history (keep last 3 turns)
            history = self._last_turns.setdefault(conv_id, [])
            history.append(turn)
            if len(history) > 3:
                history.pop(0)

            self._episode_count += 1

            # If we have at least 3 turns, record transition
            if len(history) >= 3:
                a, b, c = history[-3], history[-2], history[-1]
                a_id, b_id, c_id = a.to_id(), b.to_id(), c.to_id()
                key = (a_id, b_id)

                self._transitions[key][c_id] += 1
                self._single[c_id] += 1

            # Lazy save every 10 episodes
            if self._episode_count % 10 == 0:
                self._save_state_safe()

        except Exception:
            # Silent fail — game must never break leo
            pass

    def suggest_next(
        self,
        conv_id: str,
        last_turns: Optional[Sequence[GameTurn]] = None,
        state: Optional[MathState] = None,
    ) -> Optional[GameHint]:
        """
        Given last two turns in this conversation and current MathState,
        suggest what kind of turn should come next.

        1. Look up best C for (A,B) in transitions.
        2. If missing, fallback to most common single C.
        3. Decode C_id into components and map to GameHint.

        Args:
            conv_id: conversation identifier
            last_turns: explicit last turns (if None, use internal _last_turns)
            state: current MathState for modulation (optional)

        Returns:
            GameHint or None if no reasonable suggestion
        """
        try:
            # Get last turns
            if last_turns is None:
                last_turns = self._last_turns.get(conv_id, [])

            if len(last_turns) < 2:
                return None

            a_id = last_turns[-2].to_id()
            b_id = last_turns[-1].to_id()
            key = (a_id, b_id)

            # Look up transition
            counter = self._transitions.get(key)

            if not counter:
                # Fallback: global most common C
                if not self._single:
                    return None
                c_id, count = self._single.most_common(1)[0]
                confidence = 0.1
            else:
                # Sample C proportional to counts
                items = list(counter.items())
                total = sum(c for _, c in items)
                if total <= 0:
                    return None

                # Weighted random choice
                r = random.uniform(0, total)
                acc = 0.0
                c_id = None
                for cid, w in items:
                    acc += w
                    if r <= acc:
                        c_id = cid
                        break

                if c_id is None:
                    c_id = items[0][0]  # Fallback to first

                # Confidence: how peaked the distribution is
                max_c = max(counter.values())
                confidence = max_c / max(total, 1.0)

            # Decode C_id back into components
            c_key = decode_game_id(c_id)
            if c_key is None:
                return None

            # Build hint from decoded key
            hint = self._build_hint_from_key(c_key, state, confidence)
            return hint

        except Exception:
            return None

    def stats(self) -> Dict[str, float]:
        """
        Small summary for debugging and tests.

        Returns:
            Dict with episode_count, num_pairs, max_trail_length
        """
        return {
            "episode_count": float(self._episode_count),
            "num_pairs": float(len(self._transitions)),
            "max_trail_length": float(self.max_trail_length()),
        }

    def save(self) -> None:
        """Persist to sqlite. Silent on failure."""
        self._save_state_safe()

    def max_trail_length(self) -> int:
        """
        How many steps ahead leo is allowed to think, conceptually.

        v1: only used for diagnostics / future extensions.
        Growth formula: 2 + log10(episode_count + 1), capped at [2, 6].

        Returns:
            int: max trail length (2-6)
        """
        from math import log10

        N = max(self._episode_count, 0)
        base = 2 + int(log10(N + 1))
        return max(2, min(base, 6))

    # ========================================================================
    # INTERNAL HELPERS
    # ========================================================================

    def _build_hint_from_key(
        self,
        c_key: Dict[str, Any],
        state: Optional[MathState],
        confidence: float,
    ) -> GameHint:
        """
        Map decoded GameTurn components to GameHint.

        Args:
            c_key: decoded turn components (from decode_game_id)
            state: current MathState for modulation (optional)
            confidence: base confidence from transition frequency

        Returns:
            GameHint with mode, expert, length, tension suggestions
        """
        mode = c_key.get("mode")
        expert = c_key.get("expert")
        arousal = c_key.get("arousal", "mid")
        trauma = c_key.get("trauma", "mid")
        quality = c_key.get("quality", "mid")

        # Target length heuristic
        if mode == "ack" or quality == "low":
            target_length = "short"
        elif mode == "story" or arousal == "high":
            target_length = "long"
        else:
            target_length = "medium"

        # Tension shift heuristic
        if arousal == "low" and trauma == "high":
            tension_shift = "softer"
        elif arousal == "high" and trauma != "low":
            tension_shift = "stronger"
        else:
            tension_shift = "same"

        # Modulate confidence with MathState if available
        if state is not None and MATH_AVAILABLE:
            predicted_q = getattr(state, "quality", 0.5)
            if predicted_q < 0.3:
                confidence *= 0.5  # Leo is unstable, reduce confidence
            elif predicted_q > 0.7:
                confidence *= 1.2  # Leo is confident, boost slightly

        # Clamp confidence to [0, 1]
        confidence = max(0.0, min(1.0, confidence))

        return GameHint(
            mode=mode,
            preferred_expert=expert,
            target_length=target_length,
            tension_shift=tension_shift,
            confidence=confidence,
        )

    def _load_state_safe(self) -> None:
        """Load transitions and stats from SQLite. Silent on failure."""
        try:
            if not self.db_path.exists():
                return

            conn = sqlite3.connect(str(self.db_path))
            cur = conn.cursor()

            # Load episode count
            cur.execute("SELECT value FROM game_meta WHERE key = ?", ("episode_count",))
            row = cur.fetchone()
            if row:
                self._episode_count = int(row[0])

            # Load transitions
            cur.execute("SELECT a_id, b_id, c_id, count FROM game_transitions")
            for a_id, b_id, c_id, count in cur.fetchall():
                key = (a_id, b_id)
                self._transitions[key][c_id] = count
                self._single[c_id] += count

            conn.close()

        except Exception:
            # Silent fail — start fresh
            pass

    def _save_state_safe(self) -> None:
        """Save transitions and stats to SQLite. Silent on failure."""
        try:
            conn = sqlite3.connect(str(self.db_path))
            cur = conn.cursor()

            # Create tables if not exist
            cur.execute("""
                CREATE TABLE IF NOT EXISTS game_transitions (
                    a_id TEXT NOT NULL,
                    b_id TEXT NOT NULL,
                    c_id TEXT NOT NULL,
                    count INTEGER NOT NULL,
                    PRIMARY KEY (a_id, b_id, c_id)
                )
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS game_meta (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                )
            """)

            # Save episode count
            cur.execute(
                "INSERT OR REPLACE INTO game_meta (key, value) VALUES (?, ?)",
                ("episode_count", str(self._episode_count))
            )

            # Clear and save transitions
            cur.execute("DELETE FROM game_transitions")
            for (a_id, b_id), counter in self._transitions.items():
                for c_id, count in counter.items():
                    cur.execute(
                        "INSERT INTO game_transitions (a_id, b_id, c_id, count) VALUES (?, ?, ?, ?)",
                        (a_id, b_id, c_id, count)
                    )

            conn.commit()
            conn.close()

        except Exception:
            # Silent fail — persistence is best-effort
            pass


# ============================================================================
# STANDALONE HELPERS for external use
# ============================================================================

def get_last_turns(engine: GameEngine, conv_id: str) -> List[GameTurn]:
    """
    Get last turns for a conversation from GameEngine.

    Args:
        engine: GameEngine instance
        conv_id: conversation identifier

    Returns:
        List of GameTurn (last up to 3 turns)
    """
    return engine._last_turns.get(conv_id, [])
