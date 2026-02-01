#!/usr/bin/env python3
"""
school.py — School of Forms for Leo

School gives Leo one new right:
to sometimes ask the human: "Word?" and remember the explanation as raw text.

School is an ear, not a database. It listens, stores notes,
and feeds them into Leo's field as language. No knowledge graph,
no entity extraction — just raw human explanations becoming part of Leo's flow.
"""

from __future__ import annotations

import sqlite3
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Any, List, Tuple, TYPE_CHECKING

SCHOOL_AVAILABLE = True

# Bootstrap text: Leo's self-understanding of his School of Forms
BOOTSTRAP_TEXT = """
I am Leo's School of Forms.

I notice strange or important words that Leo does not understand yet.
When a word feels heavy, bright, or connected to many other things,
I quietly ask the human: "Word?"

I do not know the truth about cities, countries, planets or people.
I only remember how the human explains them.
Sometimes these explanations become Leo's big forms, sometimes they stay small.

For Leo, 'mother' can be as global as 'city' or 'planet'.
I let his reality grow from the words that matter to him.

I am not a dictionary.
I am the place where Leo learns the shapes of the world and the shapes of feelings.
"""

if TYPE_CHECKING:
    pass


def bootstrap(field: Any) -> None:
    """
    Feed this module's bootstrap text into Leo's field once.
    Safe no-op if field is None or has no observe().
    """
    if field is None or not hasattr(field, "observe"):
        return
    try:
        text = BOOTSTRAP_TEXT.strip()
        if text:
            field.observe(text)
    except Exception:
        # bootstrap must never break Leo
        return

try:
    from mathbrain import MathState
    MATH_AVAILABLE = True
except ImportError:
    MathState = Any  # type: ignore
    MATH_AVAILABLE = False

# Maximum note length to prevent unbounded DB growth
MAX_NOTE_LEN = 4096  # characters

# --------------------------------------------------------------------------
# DATA STRUCTURES
# --------------------------------------------------------------------------

@dataclass
class SchoolConfig:
    """Soft limits and gates for echo-questions."""
    min_question_interval_sec: float = 5.0    # cooldown between questions (was 120.0 - Desktop Claude recommendation)
    max_questions_per_run: int = 15           # soft limit per REPL run (increased for HeyLeo testing)
    max_questions_per_hour: int = 30          # global safety net (increased)
    max_token_len: int = 40                   # skip too long strings


@dataclass
class SchoolPulse:
    """Optional gating; caller may pass None."""
    novelty: float = 0.5   # 0..1
    arousal: float = 0.5   # 0..1
    trauma: float = 0.0    # 0..1


@dataclass
class SchoolQuestion:
    """A question suggestion from School."""
    token: str    # normalized lowercase, e.g. "london"
    display: str  # original form, e.g. "London"
    text: str     # question to show, e.g. "London?"


# --------------------------------------------------------------------------
# SCHOOL CORE
# --------------------------------------------------------------------------

class School:
    """
    School of Forms.

    - Tracks: "this token was explained like THIS".
    - Asks only bare-word questions: "London?".
    - Stores raw human explanations as notes.
    - Feeds explanations into Leo's field via observe().
    """
    
    def __init__(
        self,
        db_path: Path,
        field: Any,  # LeoField or similar, must have observe(text: str)
        config: Optional[SchoolConfig] = None,
    ) -> None:
        self.db_path = Path(db_path)
        self.field = field
        self.config = config or SchoolConfig()
        self._questions_this_run = 0
        self._last_question_ts = 0.0
        self._last_token_asked: Optional[str] = None
        
        # Create persistent connection with WAL and timeout
        try:
            self._conn = sqlite3.connect(str(self.db_path), timeout=5.0)
            self._conn.execute("PRAGMA journal_mode=WAL")
            self._conn.execute("PRAGMA synchronous=NORMAL")
            self._ensure_schema()
        except Exception as e:
            # School must never break leo
            print(f"[school] failed to initialize: {e}", file=sys.stderr)
            global SCHOOL_AVAILABLE
            SCHOOL_AVAILABLE = False
            self._conn = None  # type: ignore
    
    # ------------------------------------------------------------------
    # PUBLIC API
    # ------------------------------------------------------------------
    
    def maybe_ask(
        self,
        human_text: str,
        math_state: Optional[MathState] = None,
        pulse: Optional[SchoolPulse] = None,
        now: Optional[float] = None,
    ) -> Optional[SchoolQuestion]:
        """
        Inspect human_text and (rarely) suggest a short question.
        
        Returns SchoolQuestion or None.
        """
        if not SCHOOL_AVAILABLE:
            return None
        
        if not human_text or not human_text.strip():
            return None
        
        ts = now if now is not None else time.time()
        
        if not self._can_ask_now(ts, math_state, pulse):
            return None
        
        candidates = self._extract_candidates(human_text)
        if not candidates:
            return None
        
        token, display = self._pick_new_token(candidates)
        if token is None:
            return None
        
        # We found something new: ask human about it
        self._questions_this_run += 1
        self._last_question_ts = ts
        self._last_token_asked = token
        
        self._remember_question(token, display, ts)
        
        return SchoolQuestion(
            token=token,
            display=display,
            text=f"{display}?",
        )
    
    def register_answer(
        self,
        question: SchoolQuestion,
        human_answer: str,
        now: Optional[float] = None,
    ) -> None:
        """
        Store human_answer as explanation for question.token.

        Stores the note and feeds the explanation into Leo's field.
        """
        if not SCHOOL_AVAILABLE or self._conn is None:
            return
        
        if not question or not human_answer:
            return
        
        # Truncate long answers to prevent unbounded DB growth
        if len(human_answer) > MAX_NOTE_LEN:
            human_answer = human_answer[:MAX_NOTE_LEN] + " [truncated]"
        
        ts = now if now is not None else time.time()
        
        cur = self._conn.cursor()
        try:
            # Check if note already exists
            cur.execute(
                "SELECT id, note, times_asked FROM school_notes WHERE token = ?",
                (question.token,),
            )
            row = cur.fetchone()
            
            if row:
                note_id, old_note, times_asked = row
                if old_note:
                    new_note = f"{old_note}\n\n---\n{human_answer.strip()}"
                else:
                    new_note = human_answer.strip()

                # Enforce MAX_NOTE_LEN on combined string to prevent unbounded growth
                if len(new_note) > MAX_NOTE_LEN:
                    new_note = new_note[:MAX_NOTE_LEN] + " […truncated…]"

                cur.execute(
                    """
                    UPDATE school_notes
                    SET display = ?, note = ?, last_seen = ?, times_asked = ?
                    WHERE id = ?
                    """,
                    (question.display, new_note, ts, (times_asked or 0) + 1, note_id),
                )
            else:
                cur.execute(
                    """
                    INSERT INTO school_notes (token, display, note, first_seen, last_seen, times_asked)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (question.token, question.display, human_answer.strip(), ts, ts, 1),
                )
            
            self._conn.commit()
        except sqlite3.OperationalError as e:
            print(f"[school] sqlite operational error: {e}", file=sys.stderr)
            return
        except Exception as e:
            print(f"[school] unexpected school db error: {e}", file=sys.stderr)
            return
        
        # Feed the explanation into Leo's field as language
        try:
            if self.field is not None and hasattr(self.field, "observe"):
                self.field.observe(human_answer)
        except Exception:
            pass
    
    def recall_knowledge(
        self,
        prompt: str,
        max_items: int = 3,
    ) -> Optional[str]:
        """
        Recall relevant knowledge from School for a given prompt.
        
        Returns a short text snippet with relevant facts, or None if nothing found.
        This can be used to enrich Leo's generation with learned knowledge.
        """
        if not SCHOOL_AVAILABLE or self._conn is None:
            return None
        
        if not prompt or not prompt.strip():
            return None
        
        # Extract tokens from prompt
        tokens = re.findall(r"\b[\wА-Яа-яЁё]+\b", prompt.lower(), flags=re.UNICODE)
        if not tokens:
            return None
        
        cur = self._conn.cursor()
        found_notes = []

        try:
            for token in tokens:
                cur.execute(
                    "SELECT display, note FROM school_notes WHERE token = ? AND note IS NOT NULL LIMIT 1",
                    (token,),
                )
                row = cur.fetchone()
                if row:
                    display, note = row
                    short_note = note[:100] + "..." if len(note) > 100 else note
                    found_notes.append(f"{display}: {short_note}")

                if len(found_notes) >= max_items:
                    break

            if not found_notes:
                return None

            return ". ".join(found_notes[:max_items])

        except Exception:
            return None
    
    # ------------------------------------------------------------------
    # INTERNALS
    # ------------------------------------------------------------------
    
    def _ensure_schema(self) -> None:
        """Create all school tables if needed."""
        if self._conn is None:
            return
        
        cur = self._conn.cursor()
        
        # school_notes: raw explanations
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS school_notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                token TEXT NOT NULL,
                display TEXT NOT NULL,
                note TEXT,
                first_seen REAL NOT NULL,
                last_seen REAL NOT NULL,
                times_asked INTEGER NOT NULL DEFAULT 0
            )
            """
        )
        cur.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_school_token ON school_notes(token)"
        )

        self._conn.commit()
    
    def _can_ask_now(
        self,
        now: float,
        math_state: Optional[MathState],
        pulse: Optional[SchoolPulse],
    ) -> bool:
        """Rate limiting + simple trauma/arousal gate."""
        cfg = self.config
        
        # 1) Cooldown
        if now - self._last_question_ts < cfg.min_question_interval_sec:
            return False
        
        # 2) Per-run limit
        if self._questions_this_run >= cfg.max_questions_per_run:
            return False
        
        # 3) Per-hour limit
        if self._conn is None:
            return False
        try:
            cur = self._conn.cursor()
            hour_ago = now - 3600.0
            cur.execute(
                "SELECT COUNT(*) FROM school_notes WHERE last_seen > ?",
                (hour_ago,),
            )
            count = cur.fetchone()[0]
            if count >= cfg.max_questions_per_hour:
                return False
        except sqlite3.OperationalError as e:
            print(f"[school] sqlite operational error: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"[school] unexpected error checking per-hour limit: {e}", file=sys.stderr)
            return False
        
        # 4) MathState gates (if available)
        if math_state is not None and MATH_AVAILABLE:
            trauma = float(getattr(math_state, "trauma_level", 0.0) or 0.0)
            arousal = float(getattr(math_state, "arousal", 0.0) or 0.0)
            entropy = float(getattr(math_state, "entropy", 0.0) or 0.0)
            quality = float(getattr(math_state, "quality", 0.5) or 0.5)
            
            # Don't ask if trauma too high
            if trauma > 0.7:
                return False
            
            # Don't ask if arousal too high (panic/hysteria)
            if arousal > 0.85:
                return False
            
            # Skip if state is too flat/dead
            if entropy < 0.02 and quality < 0.3:
                return False
        
        # 5) Pulse gates (if provided, fallback to MathState)
        if pulse is not None:
            if pulse.trauma > 0.7:
                return False
            if pulse.arousal > 0.9:
                return False
        
        return True
    
    def _extract_candidates(self, text: str) -> List[Tuple[str, str]]:
        """
        Extract capitalized tokens that look like proper names.
        
        Prioritizes candidates near form lexemes (capital, city, country, etc.).
        Returns list of (token, display).
        """
        # Find all capitalized words (Latin + Cyrillic)
        words = re.findall(
            r"\b([A-Z][a-z]{2,}|[А-ЯЁ][а-яё]{2,})\b",
            text,
            flags=re.UNICODE,
        )
        
        # Get first token to skip it
        tokens = re.findall(r"\b[\wЁёА-Яа-я]+?\b", text, flags=re.UNICODE)
        first = tokens[0] if tokens else ""
        
        ignore = {
            "I", "You", "He", "She", "It", "We", "They",
            "The", "A", "An",
            "Я", "Ты", "Он", "Она", "Оно", "Мы", "Вы", "Они",
        }
        
        candidates: List[Tuple[str, str]] = []

        for w in words:
            if w == first:
                continue
            if w in ignore:
                continue
            if len(w) > self.config.max_token_len:
                continue

            candidates.append((w.lower(), w))

        return candidates
    
    def _pick_new_token(
        self,
        candidates: List[Tuple[str, str]],
    ) -> Tuple[Optional[str], Optional[str]]:
        """
        Pick first candidate that we don't already have a note for.
        
        If we already have a non-NULL note, we won't ask again.
        """
        try:
            for token, display in candidates:
                # Don't ask same token twice in a row
                if self._last_token_asked and token == self._last_token_asked:
                    continue
                
                # If we already have a note, skip this token
                if self._has_note(token):
                    continue
                
                # New token without note - perfect candidate
                return token, display
            
            return None, None
        except Exception:
            return None, None
    
    def _has_note(self, token: str) -> bool:
        """Check if we already have an explanation for this token."""
        if self._conn is None:
            return False
        try:
            cur = self._conn.cursor()
            cur.execute(
                "SELECT 1 FROM school_notes WHERE token = ? AND note IS NOT NULL LIMIT 1",
                (token,),
            )
            row = cur.fetchone()
            return row is not None
        except Exception:
            return False
    
    def _remember_question(self, token: str, display: str, now: float) -> None:
        """Log the question and update counters."""
        if self._conn is None:
            return
        
        cur = self._conn.cursor()
        try:
            cur.execute(
                """
                INSERT INTO school_notes (token, display, first_seen, last_seen, times_asked)
                VALUES (?, ?, ?, ?, 1)
                ON CONFLICT(token) DO UPDATE SET
                    last_seen = excluded.last_seen,
                    times_asked = school_notes.times_asked + 1
                """,
                (token, display, now, now),
            )
            
            self._conn.commit()
        except sqlite3.OperationalError as e:
            print(f"[school] sqlite operational error in remember question: {e}", file=sys.stderr)
        except Exception as e:
            print(f"[school] unexpected error in remember question: {e}", file=sys.stderr)
