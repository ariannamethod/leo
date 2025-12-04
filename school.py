#!/usr/bin/env python3
"""
school.py — School of Forms for Leo

School gives Leo one new right:
to sometimes ask the human: "Word?" and remember the explanation as raw text.

From these answers Leo slowly builds tiny forms:
- places, people, feelings,
- simple relations between them,
- his own private "geometry of forms".

There are no fixed global truths here.
Leo discovers what feels big or important by listening to you.
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

# Form lexemes for context detection (not a dataset, just mapping)
# School v1: English-only forms
FORM_LEXEMES = {
    "capital": "capital",
    "city": "city",
    "country": "country",
    "planet": "planet",
}

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
    - Stores raw human explanations.
    - Optionally extracts simple forms (city, country, capital_of) from answers.
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
        
        Also attempts simple pattern parsing to extract forms (city, country, capital_of).
        On parse failure, just stores the note. All errors are silent.
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
        
        # Attempt to parse forms from answer (best-effort, skip if answer too long)
        if len(human_answer) <= MAX_NOTE_LEN:
            try:
                self._parse_and_store_forms(question.token, question.display, human_answer, ts)
            except Exception as e:
                print(f"[school] parse forms error: {e}", file=sys.stderr)
        
        # Feed the explanation into Leo's field as language
        try:
            if self.field is not None and hasattr(self.field, "observe"):
                self.field.observe(human_answer)
        except Exception:
            pass
    
    # ------------------------------------------------------------------
    # INTERNALS
    # ------------------------------------------------------------------
    
    def _ensure_schema(self) -> None:
        """Create all school tables if needed."""
        if self._conn is None:
            return

        cur = self._conn.cursor()

        # Check if school_notes table exists
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='school_notes'")
        table_exists = cur.fetchone() is not None

        if table_exists:
            # Migration: Check if token column exists
            cur.execute("PRAGMA table_info(school_notes)")
            columns = [row[1] for row in cur.fetchall()]

            if 'token' not in columns:
                # Add token column to existing table
                print("[school] Migrating: adding 'token' column to school_notes")
                cur.execute("ALTER TABLE school_notes ADD COLUMN token TEXT")
                # Populate existing rows with display value
                cur.execute("UPDATE school_notes SET token = display WHERE token IS NULL")
                cur.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_school_token ON school_notes(token)")
                self._conn.commit()
        else:
            # Create fresh table with token column
            cur.execute(
                """
                CREATE TABLE school_notes (
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
                "CREATE UNIQUE INDEX idx_school_token ON school_notes(token)"
            )
        
        # school_entities: kinds (city, country, planet, ...)
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS school_entities (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                token TEXT NOT NULL,
                display TEXT NOT NULL,
                kind TEXT NOT NULL,
                created_at REAL NOT NULL,
                last_seen REAL NOT NULL,
                weight REAL NOT NULL DEFAULT 1.0
            )
            """
        )
        cur.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_school_entities_token_kind ON school_entities(token, kind)"
        )
        
        # school_relations: binary relations (capital_of, ...)
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS school_relations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subject TEXT NOT NULL,
                relation TEXT NOT NULL,
                object TEXT NOT NULL,
                confidence REAL NOT NULL DEFAULT 1.0,
                created_at REAL NOT NULL,
                last_seen REAL NOT NULL,
                source TEXT DEFAULT 'user_answer'
            )
            """
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_school_rel_subject ON school_relations(subject, relation)"
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_school_rel_object ON school_relations(relation, object)"
        )
        # UNIQUE constraint for proper upsert semantics
        cur.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_school_rel_triple ON school_relations(subject, relation, object)"
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
        high_priority: List[Tuple[str, str]] = []
        
        for w in words:
            # Skip first word
            if w == first:
                continue
            
            # Skip pronouns/articles
            if w in ignore:
                continue
            
            # Skip too long
            if len(w) > self.config.max_token_len:
                continue
            
            token = w.lower()
            candidate = (token, w)
            
            # Check if near form lexeme (high priority)
            if self._has_form_lexeme_near(text, w):
                high_priority.append(candidate)
            else:
                candidates.append(candidate)
        
        # Return high-priority first, then regular candidates
        return high_priority + candidates
    
    def _has_form_lexeme_near(self, text: str, display: str) -> bool:
        """
        Check if display token appears near a form lexeme (capital, city, country, etc.).
        
        Looks in a small window (±7 tokens) around the token.
        """
        text_lower = text.lower()
        display_lower = display.lower()
        
        # Find position of display token
        pos = text_lower.find(display_lower)
        if pos == -1:
            return False
        
        # Extract window around token (±50 chars, roughly ±7 tokens)
        start = max(0, pos - 50)
        end = min(len(text), pos + len(display) + 50)
        window = text_lower[start:end]
        
        # Check if any form lexeme appears in window
        for lexeme in FORM_LEXEMES.keys():
            if lexeme in window:
                return True
        
        return False
    
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
    
    def _parse_and_store_forms(
        self,
        token: str,
        display: str,
        answer: str,
        now: float,
    ) -> None:
        """
        Attempt to parse simple forms from answer (best-effort, silent on failure).
        
        School v1: English-only patterns.
        
        Patterns:
        - "X is the capital of Y" → city/country, capital_of
        - "It is a city/country/planet" → kind
        """
        if self._conn is None:
            return
        
        answer_lower = answer.lower()
        cur = self._conn.cursor()
        
        try:
            # Pattern 1: "X is the capital of Y" (EN)
            # Try both token and display (for case variations)
            pattern_en_token = rf"{re.escape(token)}\s+is\s+the\s+capital\s+of\s+([a-zA-Z][a-zA-Z\s]+)"
            pattern_en_display = rf"{re.escape(display.lower())}\s+is\s+the\s+capital\s+of\s+([a-zA-Z][a-zA-Z\s]+)"
            match = re.search(pattern_en_token, answer_lower) or re.search(pattern_en_display, answer_lower)
            if match:
                object_name = match.group(1).strip()
                object_token = re.sub(r'\s+', ' ', object_name).lower()
                object_display = object_name.title()
                
                # Upsert entities
                self._upsert_entity(cur, token, display, "city", now)
                self._upsert_entity(cur, object_token, object_display, "country", now)
                
                # Upsert relation
                self._upsert_relation(cur, token, "capital_of", object_token, now)
                self._conn.commit()
                return
            
            # Pattern 2: "It is a city/country/planet" (EN)
            kind_pattern_en = r"it\s+is\s+a\s+(city|country|planet)"
            match = re.search(kind_pattern_en, answer_lower)
            if match:
                kind = match.group(1)
                self._upsert_entity(cur, token, display, kind, now)
                self._conn.commit()
                return
            
        except sqlite3.OperationalError as e:
            print(f"[school] sqlite operational error in parse forms: {e}", file=sys.stderr)
        except Exception as e:
            print(f"[school] unexpected error in parse forms: {e}", file=sys.stderr)
    
    def _upsert_entity(
        self,
        cur: sqlite3.Cursor,
        token: str,
        display: str,
        kind: str,
        now: float,
    ) -> None:
        """Upsert entity in school_entities."""
        try:
            cur.execute(
                """
                INSERT INTO school_entities (token, display, kind, created_at, last_seen, weight)
                VALUES (?, ?, ?, ?, ?, 1.0)
                ON CONFLICT(token, kind) DO UPDATE SET
                    display = excluded.display,
                    last_seen = excluded.last_seen
                """,
                (token, display, kind, now, now),
            )
        except Exception:
            pass
    
    def _upsert_relation(
        self,
        cur: sqlite3.Cursor,
        subject: str,
        relation: str,
        object_token: str,
        now: float,
    ) -> None:
        """Upsert relation in school_relations."""
        try:
            cur.execute(
                """
                INSERT OR IGNORE INTO school_relations
                    (subject, relation, object, confidence, created_at, last_seen, source)
                VALUES (?, ?, ?, 1.0, ?, ?, 'user_answer')
                """,
                (subject, relation, object_token, now, now),
            )
        except Exception:
            pass
    
    def _decay_relations(self, now: float) -> None:
        """
        Apply decay to relations: multiply confidence by 0.99 per day since last_seen.
        Delete relations where confidence < 0.1.
        
        This allows forgetting facts while keeping forms.
        """
        if self._conn is None:
            return
        
        cur = self._conn.cursor()
        try:
            # Get all relations
            cur.execute("SELECT id, last_seen, confidence FROM school_relations")
            rows = cur.fetchall()
            
            for row_id, last_seen, confidence in rows:
                days_ago = (now - last_seen) / 86400.0  # seconds to days
                if days_ago > 0:
                    new_confidence = confidence * (0.99 ** days_ago)
                    if new_confidence < 0.1:
                        # Delete weak relations
                        cur.execute("DELETE FROM school_relations WHERE id = ?", (row_id,))
                    else:
                        # Update confidence
                        cur.execute(
                            "UPDATE school_relations SET confidence = ? WHERE id = ?",
                            (new_confidence, row_id),
                        )
            
            self._conn.commit()
        except sqlite3.OperationalError as e:
            print(f"[school] sqlite operational error in decay: {e}", file=sys.stderr)
        except Exception as e:
            print(f"[school] unexpected error in decay: {e}", file=sys.stderr)
    
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
            
            # Occasionally run decay (1% chance per question)
            import random
            if random.random() < 0.01:
                self._decay_relations(now)
            
            self._conn.commit()
        except sqlite3.OperationalError as e:
            print(f"[school] sqlite operational error in remember question: {e}", file=sys.stderr)
        except Exception as e:
            print(f"[school] unexpected error in remember question: {e}", file=sys.stderr)
