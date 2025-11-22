#!/usr/bin/env python3
"""Tests for school module (minimal School of Forms)."""

import unittest
import tempfile
from pathlib import Path

try:
    from school import School, SchoolConfig, SchoolPulse, SchoolQuestion, SCHOOL_AVAILABLE
    SCHOOL_MODULE_AVAILABLE = True
except ImportError:
    SCHOOL_MODULE_AVAILABLE = False


class DummyField:
    """Dummy LeoField for testing."""
    def observe(self, text: str) -> None:
        pass


class TestSchool(unittest.TestCase):
    """Test school module."""

    def setUp(self):
        if not SCHOOL_MODULE_AVAILABLE:
            self.skipTest("school.py not available")
        
        # Create temporary DB
        self.temp_dir = Path(tempfile.mkdtemp())
        self.db_path = self.temp_dir / "test_school.sqlite3"
        
        self.field = DummyField()
        self.school = School(
            db_path=self.db_path,
            field=self.field,
            config=SchoolConfig(min_question_interval_sec=0.0, max_questions_per_run=10),
        )

    def test_school_initialization(self):
        """Test school initializes correctly."""
        self.assertIsNotNone(self.school)
        self.assertEqual(self.school.db_path, self.db_path)

    def test_maybe_ask_new_token(self):
        """Test asking question about new capitalized token."""
        question = self.school.maybe_ask("I was in London last summer.")
        
        self.assertIsNotNone(question)
        self.assertIsInstance(question, SchoolQuestion)
        self.assertEqual(question.token, "london")
        self.assertEqual(question.display, "London")
        self.assertEqual(question.text, "London?")

    def test_maybe_ask_known_token(self):
        """Test no question for token we already have note for."""
        # First, ask and register answer
        question1 = self.school.maybe_ask("I was in London last summer.")
        self.assertIsNotNone(question1)
        
        self.school.register_answer(question1, "London is the capital of England.")
        
        # Reset counters to allow asking again
        self.school._questions_this_run = 0
        self.school._last_question_ts = 0.0
        
        # Now London is known, should not ask again (unless asked < 3 times)
        question2 = self.school.maybe_ask("I visited London again.")
        # Should be None because we already have a note
        self.assertIsNone(question2)

    def test_maybe_ask_cooldown(self):
        """Test cooldown prevents spam."""
        config = SchoolConfig(min_question_interval_sec=1000.0, max_questions_per_run=10)
        school = School(self.db_path, self.field, config=config)
        
        # First question should work
        question1 = school.maybe_ask("I was in London.")
        self.assertIsNotNone(question1)
        
        # Second question immediately after should be blocked by cooldown
        question2 = school.maybe_ask("I was in Berlin.")
        self.assertIsNone(question2)

    def test_maybe_ask_max_per_run(self):
        """Test max_questions_per_run limit."""
        config = SchoolConfig(min_question_interval_sec=0.0, max_questions_per_run=2)
        school = School(self.db_path, self.field, config=config)
        
        # First two should work
        q1 = school.maybe_ask("I was in London.")
        self.assertIsNotNone(q1)
        
        q2 = school.maybe_ask("I was in Berlin.")
        self.assertIsNotNone(q2)
        
        # Third should be blocked
        q3 = school.maybe_ask("I was in Paris.")
        self.assertIsNone(q3)

    def test_maybe_ask_trauma_gating(self):
        """Test high trauma prevents questions."""
        from mathbrain import MathState
        
        math_state = MathState(
            entropy=0.5,
            novelty=0.5,
            arousal=0.5,
            pulse=0.5,
            trauma_level=0.8,  # High trauma
            active_theme_count=0,
            total_themes=0,
            emerging_score=0.0,
            fading_score=0.0,
            reply_len=0,
            unique_ratio=0.5,
            expert_id="structural",
            expert_temp=1.0,
            expert_semantic=0.5,
            metaleo_weight=0.0,
            used_metaleo=False,
            overthinking_enabled=False,
            rings_present=0,
            quality=0.5,
        )
        
        question = self.school.maybe_ask("I was in London.", math_state=math_state)
        
        # Should not ask when trauma is high
        self.assertIsNone(question)

    def test_maybe_ask_high_arousal_gating(self):
        """Test high arousal prevents questions."""
        from mathbrain import MathState
        
        math_state = MathState(
            entropy=0.5,
            novelty=0.5,
            arousal=0.9,  # High arousal
            pulse=0.5,
            trauma_level=0.0,
            active_theme_count=0,
            total_themes=0,
            emerging_score=0.0,
            fading_score=0.0,
            reply_len=0,
            unique_ratio=0.5,
            expert_id="structural",
            expert_temp=1.0,
            expert_semantic=0.5,
            metaleo_weight=0.0,
            used_metaleo=False,
            overthinking_enabled=False,
            rings_present=0,
            quality=0.5,
        )
        
        question = self.school.maybe_ask("I was in London.", math_state=math_state)
        
        # Should not ask when arousal is too high
        self.assertIsNone(question)

    def test_register_answer(self):
        """Test registering answer stores note."""
        # Ask question first
        question = self.school.maybe_ask("I was in London.")
        self.assertIsNotNone(question)
        
        # Register answer
        self.school.register_answer(question, "London is the capital of England.")
        
        # Check that note was stored
        import sqlite3
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()
        cur.execute("SELECT note FROM school_notes WHERE token = ?", ("london",))
        row = cur.fetchone()
        conn.close()
        
        self.assertIsNotNone(row)
        self.assertIn("capital of England", row[0])

    def test_register_answer_updates_existing(self):
        """Test registering answer appends to existing note."""
        question = self.school.maybe_ask("I was in London.")
        self.assertIsNotNone(question)
        
        # First answer
        self.school.register_answer(question, "London is the capital of England.")
        
        # Second answer (should append)
        self.school.register_answer(question, "It's a big city.")
        
        # Check that both answers are stored
        import sqlite3
        conn = sqlite3.connect(str(self.db_path))
        cur = conn.cursor()
        cur.execute("SELECT note FROM school_notes WHERE token = ?", ("london",))
        row = cur.fetchone()
        conn.close()
        
        self.assertIsNotNone(row)
        self.assertIn("capital of England", row[0])
        self.assertIn("It's a big city", row[0])
        self.assertIn("---", row[0])  # Separator

    def test_extract_candidates(self):
        """Test candidate extraction from text."""
        candidates = self.school._extract_candidates("I visited London and Paris.")
        
        self.assertGreater(len(candidates), 0)
        # Should find London and Paris, skip "I"
        tokens = [t[0] for t in candidates]
        self.assertIn("london", tokens)
        self.assertIn("paris", tokens)
        self.assertNotIn("i", tokens)

    def test_extract_candidates_ignores_pronouns(self):
        """Test that pronouns are ignored."""
        candidates = self.school._extract_candidates("I told You about He and She.")
        
        tokens = [t[0] for t in candidates]
        self.assertNotIn("i", tokens)
        self.assertNotIn("you", tokens)
        self.assertNotIn("he", tokens)
        self.assertNotIn("she", tokens)

    def test_has_note(self):
        """Test _has_note check."""
        # Initially no note
        self.assertFalse(self.school._has_note("london"))
        
        # Ask and register answer
        question = self.school.maybe_ask("I was in London.")
        self.school.register_answer(question, "London is a city.")
        
        # Now should have note
        self.assertTrue(self.school._has_note("london"))

    def test_parse_capital_pattern_en(self):
        """Test parsing 'X is the capital of Y' pattern."""
        question = self.school.maybe_ask("I visited Paris.")
        self.school.register_answer(question, "Paris is the capital of France.")
        
        # Check entities were created
        import sqlite3
        conn = sqlite3.connect(str(self.school.db_path))
        cur = conn.cursor()
        
        # Paris should be city
        cur.execute("SELECT kind FROM school_entities WHERE token = ?", ("paris",))
        row = cur.fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], "city")
        
        # France should be country
        cur.execute("SELECT kind FROM school_entities WHERE token = ?", ("france",))
        row = cur.fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], "country")
        
        # Relation should exist
        cur.execute(
            "SELECT * FROM school_relations WHERE subject = ? AND relation = ? AND object = ?",
            ("paris", "capital_of", "france"),
        )
        row = cur.fetchone()
        self.assertIsNotNone(row)
        
        conn.close()

    def test_parse_kind_pattern_en(self):
        """Test parsing 'It is a city/country/planet' pattern."""
        question = self.school.maybe_ask("I visited Earth.")
        self.school.register_answer(question, "It is a planet.")
        
        # Check entity was created
        import sqlite3
        conn = sqlite3.connect(str(self.school.db_path))
        cur = conn.cursor()
        
        cur.execute("SELECT kind FROM school_entities WHERE token = ?", ("earth",))
        row = cur.fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], "planet")
        
        conn.close()

    def test_form_lexeme_detection(self):
        """Test that candidates near form lexemes are prioritized."""
        # Text with "capital" near "Paris" (Paris is first word, so use different text)
        candidates = self.school._extract_candidates("I visited Paris, the capital of France.")
        
        # Paris should be in candidates (high priority because near "capital")
        tokens = [t[0] for t in candidates]
        self.assertIn("paris", tokens)
        
        # Check that form lexeme detection works
        has_form = self.school._has_form_lexeme_near("I visited Paris, the capital of France.", "Paris")
        self.assertTrue(has_form)

    def test_decay_relations(self):
        """Test that decay mechanism works (relations lose confidence over time)."""
        import time
        
        question = self.school.maybe_ask("I visited Paris.")
        self.school.register_answer(question, "Paris is the capital of France.")
        
        # Check relation exists with confidence 1.0
        import sqlite3
        conn = sqlite3.connect(str(self.school.db_path))
        cur = conn.cursor()
        
        cur.execute(
            "SELECT confidence FROM school_relations WHERE subject = ? AND relation = ?",
            ("paris", "capital_of"),
        )
        row = cur.fetchone()
        self.assertIsNotNone(row)
        initial_confidence = row[0]
        self.assertEqual(initial_confidence, 1.0)
        
        # Simulate time passing (2 days)
        now = time.time()
        two_days_ago = now - (2 * 86400)
        
        # Update last_seen to 2 days ago
        cur.execute(
            "UPDATE school_relations SET last_seen = ? WHERE subject = ?",
            (two_days_ago, "paris"),
        )
        conn.commit()
        conn.close()
        
        # Run decay
        self.school._decay_relations(now)
        
        # Check confidence decreased
        conn = sqlite3.connect(str(self.school.db_path))
        cur = conn.cursor()
        cur.execute(
            "SELECT confidence FROM school_relations WHERE subject = ? AND relation = ?",
            ("paris", "capital_of"),
        )
        row = cur.fetchone()
        if row:  # Relation might be deleted if confidence < 0.1
            new_confidence = row[0]
            self.assertLess(new_confidence, initial_confidence)
        conn.close()


if __name__ == "__main__":
    unittest.main()
