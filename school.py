#!/usr/bin/env python3
"""
school.py — School of Forms for Leo

Gives leo a tiny "School of Forms":
- not encyclopedic knowledge,
- but structures like planet → country → city → capital,
- learned from conversations, by asking the human simple questions.

Optional module: if missing or broken, leo works exactly as before.
"""

from __future__ import annotations

import json
import re
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, List, Dict, Any

SCHOOL_AVAILABLE = True


@dataclass
class SchoolConfig:
    """Configuration for School behavior."""
    min_question_interval_sec: float = 120.0  # cooldown between questions
    max_questions_per_run: int = 5  # soft limit per REPL process
    max_questions_per_hour: int = 20  # global safety net
    capital_trigger_words: List[str] = None  # ['capital', 'country', 'city', 'planet']


@dataclass
class SchoolPulse:
    """Pulse metrics for gating questions."""
    novelty: float = 0.5
    arousal: float = 0.5
    entropy: float = 0.5
    trauma: float = 0.0


@dataclass
class SchoolSuggestion:
    """A question suggestion from School."""
    question: str
    trigger_token: str
    reason: str  # e.g. "unknown_capital_candidate"


class School:
    """
    School of Forms: tracks conceptual geometry (planet, country, city, capital)
    and asks child-like questions about unknown entities.
    """
    
    def __init__(
        self,
        db_path: Path,
        field: Any,  # LeoField instance
        config: Optional[SchoolConfig] = None,
    ):
        """
        Initialize School.
        
        Args:
            db_path: path to leo.sqlite3 (or school DB)
            field: LeoField instance (for observe())
            config: optional SchoolConfig
        """
        self.db_path = Path(db_path)
        self.field = field
        self.config = config or SchoolConfig()
        
        if self.config.capital_trigger_words is None:
            self.config.capital_trigger_words = [
                'capital', 'country', 'city', 'planet',
                'столица', 'страна', 'город', 'планета',
            ]
        
        # Ensure DB exists and has schema
        self._ensure_schema()
        
        # Track question state
        self._questions_this_run = 0
        self._last_question_ts = 0.0
        
        # Load bootstrap if available
        self._load_bootstrap()
    
    def _ensure_schema(self) -> None:
        """Create school tables if they don't exist."""
        conn = sqlite3.connect(self.db_path)
        cur = conn.cursor()
        
        # Entities table
        cur.execute("""
            CREATE TABLE IF NOT EXISTS school_entities (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                kind TEXT NOT NULL,
                display_name TEXT NOT NULL,
                created_at REAL NOT NULL,
                last_seen_at REAL NOT NULL,
                weight REAL NOT NULL DEFAULT 1.0
            )
        """)
        
        # Relations table
        cur.execute("""
            CREATE TABLE IF NOT EXISTS school_relations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subject_id INTEGER NOT NULL,
                relation TEXT NOT NULL,
                object_id INTEGER NOT NULL,
                confidence REAL NOT NULL DEFAULT 1.0,
                created_at REAL NOT NULL,
                last_seen_at REAL NOT NULL,
                source TEXT DEFAULT 'user_answer'
            )
        """)
        
        # Meta table
        cur.execute("""
            CREATE TABLE IF NOT EXISTS school_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        """)
        
        # Questions log
        cur.execute("""
            CREATE TABLE IF NOT EXISTS school_questions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                asked_at REAL NOT NULL,
                question TEXT NOT NULL,
                trigger_token TEXT,
                conversation_id TEXT,
                answered INTEGER NOT NULL DEFAULT 0,
                answer TEXT
            )
        """)
        
        # Indexes
        cur.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_entities_name_kind
            ON school_entities(name, kind)
        """)
        
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_relations_subject
            ON school_relations(subject_id, relation)
        """)
        
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_relations_object
            ON school_relations(relation, object_id)
        """)
        
        conn.commit()
        conn.close()
    
    def _load_bootstrap(self) -> None:
        """Load state/school_bootstrap.json if exists."""
        # Try multiple locations
        possible_paths = [
            self.db_path.parent / "school_bootstrap.json",  # Same dir as DB
            self.db_path.parent.parent / "state" / "school_bootstrap.json",  # state/ dir
            Path("state") / "school_bootstrap.json",  # Relative to cwd
        ]
        
        bootstrap_path = None
        for path in possible_paths:
            if path.exists():
                bootstrap_path = path
                break
        
        if bootstrap_path is None:
            return  # Graceful no-op
        
        try:
            with open(bootstrap_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            conn = sqlite3.connect(self.db_path)
            cur = conn.cursor()
            now = time.time()
            
            # Load entities
            for entity in data.get('entities', []):
                name = entity['name'].lower()
                kind = entity.get('kind', 'other')
                display_name = entity.get('display_name', entity['name'])
                
                # Insert or ignore (unique constraint)
                cur.execute("""
                    INSERT OR IGNORE INTO school_entities
                    (name, kind, display_name, created_at, last_seen_at, weight)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (name, kind, display_name, now, now, 1.0))
            
            # Load relations
            for relation in data.get('relations', []):
                subject_name = relation['subject'].lower()
                rel_type = relation['relation']
                object_name = relation['object'].lower()
                
                # Get IDs
                cur.execute("SELECT id FROM school_entities WHERE name = ?", (subject_name,))
                subject_row = cur.fetchone()
                cur.execute("SELECT id FROM school_entities WHERE name = ?", (object_name,))
                object_row = cur.fetchone()
                
                if subject_row and object_row:
                    subject_id = subject_row[0]
                    object_id = object_row[0]
                    
                    cur.execute("""
                        INSERT OR IGNORE INTO school_relations
                        (subject_id, relation, object_id, confidence, created_at, last_seen_at, source)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, (subject_id, rel_type, object_id, 1.0, now, now, 'seed'))
            
            # Feed example sentences into field
            for example in data.get('examples', []):
                if self.field and hasattr(self.field, 'observe'):
                    try:
                        self.field.observe(example)
                    except Exception:
                        pass  # Silent fallback
            
            conn.commit()
            conn.close()
            
        except Exception:
            # Silent fallback - bootstrap loading must never break leo
            pass
    
    def observe_turn(
        self,
        prompt: str,
        reply: str,
        pulse: Optional[SchoolPulse] = None,
        now: Optional[float] = None,
    ) -> None:
        """
        Called after each visible leo reply.
        
        - Logs new concepts if they appear explicitly (optional).
        - Can update last_seen timestamps for known entities.
        - Does NOT ask questions by itself.
        """
        if now is None:
            now = time.time()
        
        try:
            # Extract entities from both prompt and reply
            entities = self._extract_entities(prompt + " " + reply)
            
            # Update last_seen for known entities
            conn = sqlite3.connect(self.db_path)
            cur = conn.cursor()
            
            for entity_name, kind in entities:
                cur.execute("""
                    UPDATE school_entities
                    SET last_seen_at = ?
                    WHERE name = ? AND kind = ?
                """, (now, entity_name.lower(), kind))
            
            conn.commit()
            conn.close()
            
        except Exception:
            # Silent fallback
            pass
    
    def maybe_ask_question(
        self,
        human_utterance: str,
        pulse: Optional[SchoolPulse] = None,
        now: Optional[float] = None,
    ) -> Optional[SchoolSuggestion]:
        """
        Called when the human says something.
        
        Returns a SchoolSuggestion with a short question OR None.
        Applies cooldowns, rate limits, state-based gating.
        """
        if now is None:
            now = time.time()
        
        # Check if we can ask now
        if not self._can_ask_now(pulse, now):
            return None
        
        # Extract candidate tokens
        candidates = self._extract_candidate_tokens(human_utterance)
        if not candidates:
            return None
        
        # Find unknown entity
        for token, display_name in candidates:
            if not self._entity_exists(token):
                # Found unknown entity - ask about it
                question = self._generate_question(display_name, human_utterance)
                if question:
                    # Log question
                    self._log_question(question, token, now)
                    self._questions_this_run += 1
                    self._last_question_ts = now
                    
                    return SchoolSuggestion(
                        question=question,
                        trigger_token=token,
                        reason="unknown_entity",
                    )
        
        return None
    
    def register_answer(
        self,
        suggestion: SchoolSuggestion,
        human_answer: str,
        now: Optional[float] = None,
    ) -> None:
        """
        Called after a human answers a school question.
        Parses the answer and updates concepts / facts if applicable.
        Safely no-ops on parse failure.
        """
        if now is None:
            now = time.time()
        
        try:
            # Simple parsing: look for patterns like "X is the capital of Y"
            parsed = self._parse_answer(human_answer, suggestion.trigger_token)
            if not parsed:
                # Just observe the answer into field
                if self.field and hasattr(self.field, 'observe'):
                    self.field.observe(human_answer)
                return
            
            # Update entities and relations
            conn = sqlite3.connect(self.db_path)
            cur = conn.cursor()
            
            # Ensure subject exists
            subject_name = suggestion.trigger_token.lower()
            subject_kind = parsed.get('subject_kind', 'other')
            subject_id = self._get_or_create_entity(
                cur, subject_name, subject_kind, suggestion.trigger_token, now
            )
            
            # If relation found, ensure object exists and create relation
            if 'relation' in parsed and 'object_name' in parsed:
                object_name = parsed['object_name'].lower()
                object_kind = parsed.get('object_kind', 'other')
                object_id = self._get_or_create_entity(
                    cur, object_name, object_kind, parsed.get('object_display', object_name), now
                )
                
                # Create relation
                cur.execute("""
                    INSERT OR REPLACE INTO school_relations
                    (subject_id, relation, object_id, confidence, created_at, last_seen_at, source)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    subject_id,
                    parsed['relation'],
                    object_id,
                    1.0,
                    now,
                    now,
                    'user_answer',
                ))
            
            conn.commit()
            conn.close()
            
            # Also observe answer into field
            if self.field and hasattr(self.field, 'observe'):
                self.field.observe(human_answer)
            
            # Update question log
            self._mark_question_answered(suggestion.trigger_token, human_answer, now)
            
        except Exception:
            # Silent fallback
            pass
    
    def _can_ask_now(self, pulse: Optional[SchoolPulse], now: float) -> bool:
        """Check if we can ask a question now."""
        # 1) Global cooldown
        if now - self._last_question_ts < self.config.min_question_interval_sec:
            return False
        
        # 2) Rate limits
        if self._questions_this_run >= self.config.max_questions_per_run:
            return False
        
        # Check per-hour limit
        conn = sqlite3.connect(self.db_path)
        cur = conn.cursor()
        hour_ago = now - 3600.0
        cur.execute("""
            SELECT COUNT(*) FROM school_questions
            WHERE asked_at > ?
        """, (hour_ago,))
        count = cur.fetchone()[0]
        conn.close()
        
        if count >= self.config.max_questions_per_hour:
            return False
        
        # 3) Avoid asking in highly wounded / chaotic states
        if pulse is not None:
            if pulse.trauma > 0.7:
                return False
            if pulse.arousal > 0.8:
                return False
        
        return True
    
    def _extract_candidate_tokens(self, text: str) -> List[tuple]:
        """
        Extract candidate entity tokens from text.
        
        Returns list of (normalized_name, display_name) tuples.
        """
        # Simple heuristic: capitalized words (not at sentence start)
        words = re.findall(r'\b[A-Z][a-z]+\b', text)
        
        # Filter out common pronouns and sentence starters
        ignore = {'I', 'You', 'He', 'She', 'It', 'We', 'They', 'The', 'A', 'An'}
        
        candidates = []
        for word in words:
            if word not in ignore and len(word) > 2:
                candidates.append((word.lower(), word))
        
        return candidates
    
    def _entity_exists(self, name: str) -> bool:
        """Check if entity exists in DB."""
        try:
            conn = sqlite3.connect(self.db_path)
            cur = conn.cursor()
            cur.execute("SELECT 1 FROM school_entities WHERE name = ? LIMIT 1", (name.lower(),))
            exists = cur.fetchone() is not None
            conn.close()
            return exists
        except Exception:
            return False
    
    def _generate_question(self, display_name: str, context: str) -> str:
        """
        Generate a child-like question about unknown entity.
        
        This is a simple template for now. In future, Leo could generate
        the question through his own field, making it more organic.
        For now, we use context-aware templates that feel natural.
        """
        # Check if context mentions capital/country/city
        context_lower = context.lower()
        if any(word in context_lower for word in ['capital', 'столица']):
            return f"{display_name}? Is it the capital of a country?"
        elif any(word in context_lower for word in ['country', 'страна']):
            return f"{display_name}? Is it a country?"
        elif any(word in context_lower for word in ['city', 'город']):
            return f"{display_name}? Is it a city?"
        else:
            # Generic question - Leo will learn from the answer
            return f"{display_name}? What is that for you: a city, a country, a person, or something else?"
    
    def _extract_entities(self, text: str) -> List[tuple]:
        """Extract known entities from text (for last_seen updates)."""
        # Simple: check if capitalized words exist in DB
        words = re.findall(r'\b[A-Z][a-z]+\b', text)
        entities = []
        
        try:
            conn = sqlite3.connect(self.db_path)
            cur = conn.cursor()
            
            for word in words:
                cur.execute("SELECT kind FROM school_entities WHERE name = ?", (word.lower(),))
                row = cur.fetchone()
                if row:
                    entities.append((word.lower(), row[0]))
            
            conn.close()
        except Exception:
            pass
        
        return entities
    
    def _parse_answer(self, answer: str, trigger_token: str) -> Optional[Dict[str, Any]]:
        """
        Parse human answer to extract entity kind and relations.
        
        Patterns:
        - "X is the capital of Y"
        - "X — столица Y"
        - "It is a city"
        """
        answer_lower = answer.lower()
        trigger_lower = trigger_token.lower()
        
        # Pattern: "X is the capital of Y"
        capital_pattern = rf'{trigger_lower}\s+is\s+the\s+capital\s+of\s+([a-z]+)'
        match = re.search(capital_pattern, answer_lower)
        if match:
            country_name = match.group(1)
            return {
                'subject_kind': 'city',
                'relation': 'capital_of',
                'object_name': country_name,
                'object_kind': 'country',
            }
        
        # Pattern: "It is a city" / "It is a country"
        kind_pattern = r'it\s+is\s+a\s+(city|country|planet)'
        match = re.search(kind_pattern, answer_lower)
        if match:
            kind = match.group(1)
            return {
                'subject_kind': kind,
            }
        
        # Russian pattern: "X — столица Y"
        ru_pattern = rf'{trigger_lower}\s*—\s*столица\s+([а-я]+)'
        match = re.search(ru_pattern, answer_lower)
        if match:
            country_name = match.group(1)
            return {
                'subject_kind': 'city',
                'relation': 'capital_of',
                'object_name': country_name,
                'object_kind': 'country',
            }
        
        return None
    
    def _get_or_create_entity(
        self, cur: sqlite3.Cursor, name: str, kind: str, display_name: str, now: float
    ) -> int:
        """Get or create entity, return ID."""
        cur.execute("""
            SELECT id FROM school_entities WHERE name = ? AND kind = ?
        """, (name.lower(), kind))
        row = cur.fetchone()
        
        if row:
            return row[0]
        
        # Create new
        cur.execute("""
            INSERT INTO school_entities (name, kind, display_name, created_at, last_seen_at, weight)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (name.lower(), kind, display_name, now, now, 1.0))
        
        return cur.lastrowid
    
    def _log_question(self, question: str, trigger_token: str, now: float) -> None:
        """Log question to DB."""
        try:
            conn = sqlite3.connect(self.db_path)
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO school_questions (asked_at, question, trigger_token, answered)
                VALUES (?, ?, ?, ?)
            """, (now, question, trigger_token, 0))
            conn.commit()
            conn.close()
        except Exception:
            pass
    
    def _mark_question_answered(self, trigger_token: str, answer: str, now: float) -> None:
        """Mark question as answered."""
        try:
            conn = sqlite3.connect(self.db_path)
            cur = conn.cursor()
            cur.execute("""
                UPDATE school_questions
                SET answered = 1, answer = ?
                WHERE trigger_token = ? AND answered = 0
                ORDER BY asked_at DESC LIMIT 1
            """, (answer, trigger_token))
            conn.commit()
            conn.close()
        except Exception:
            pass

