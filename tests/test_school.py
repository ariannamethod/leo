#!/usr/bin/env python3
"""Tests for school module."""

import unittest
import tempfile
import json
from pathlib import Path

try:
    from school import School, SchoolConfig, SchoolPulse, SchoolSuggestion, SCHOOL_AVAILABLE
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
        self.bootstrap_path = self.temp_dir / "school_bootstrap.json"
        
        # Create minimal bootstrap
        bootstrap = {
            "entities": [
                {"id": 1, "name": "France", "kind": "country", "display_name": "France"},
                {"id": 2, "name": "Paris", "kind": "city", "display_name": "Paris"},
            ],
            "relations": [
                {"subject": "Paris", "relation": "capital_of", "object": "France"},
            ],
            "examples": [
                "France is a country.",
                "Paris is the capital of France.",
            ],
        }
        with open(self.bootstrap_path, 'w', encoding='utf-8') as f:
            json.dump(bootstrap, f)
        
        # Move bootstrap to state/ for school to find it
        state_dir = self.temp_dir / "state"
        state_dir.mkdir()
        bootstrap_dest = state_dir / "school_bootstrap.json"
        bootstrap_dest.write_bytes(self.bootstrap_path.read_bytes())
        
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

    def test_entity_exists(self):
        """Test entity existence check."""
        # France should exist (from bootstrap)
        self.assertTrue(self.school._entity_exists("france"))
        self.assertTrue(self.school._entity_exists("France"))
        # London should not exist
        self.assertFalse(self.school._entity_exists("london"))

    def test_maybe_ask_question_unknown_entity(self):
        """Test asking question about unknown entity."""
        pulse = SchoolPulse(novelty=0.5, arousal=0.5, entropy=0.5, trauma=0.0)
        suggestion = self.school.maybe_ask_question("I was in London last summer.", pulse=pulse)
        
        self.assertIsNotNone(suggestion)
        self.assertIsInstance(suggestion, SchoolSuggestion)
        self.assertEqual(suggestion.trigger_token, "london")
        self.assertIn("London", suggestion.question)

    def test_maybe_ask_question_known_entity(self):
        """Test no question for known entity."""
        pulse = SchoolPulse(novelty=0.5, arousal=0.5, entropy=0.5, trauma=0.0)
        suggestion = self.school.maybe_ask_question("I was in Paris last summer.", pulse=pulse)
        
        # Paris is known, should not ask
        self.assertIsNone(suggestion)

    def test_maybe_ask_question_cooldown(self):
        """Test cooldown prevents spam."""
        config = SchoolConfig(min_question_interval_sec=1000.0, max_questions_per_run=10)
        school = School(self.db_path, self.field, config=config)
        
        pulse = SchoolPulse(novelty=0.5, arousal=0.5, entropy=0.5, trauma=0.0)
        
        # First question should work
        suggestion1 = school.maybe_ask_question("I was in London.", pulse=pulse)
        self.assertIsNotNone(suggestion1)
        
        # Second question immediately after should be blocked by cooldown
        suggestion2 = school.maybe_ask_question("I was in Berlin.", pulse=pulse)
        self.assertIsNone(suggestion2)

    def test_maybe_ask_question_trauma_gating(self):
        """Test high trauma prevents questions."""
        pulse = SchoolPulse(novelty=0.5, arousal=0.5, entropy=0.5, trauma=0.8)  # High trauma
        suggestion = self.school.maybe_ask_question("I was in London.", pulse=pulse)
        
        # Should not ask when trauma is high
        self.assertIsNone(suggestion)

    def test_register_answer(self):
        """Test registering answer updates entities."""
        # Ask question first
        pulse = SchoolPulse(novelty=0.5, arousal=0.5, entropy=0.5, trauma=0.0)
        suggestion = self.school.maybe_ask_question("I was in London.", pulse=pulse)
        self.assertIsNotNone(suggestion)
        
        # Register answer
        self.school.register_answer(suggestion, "London is the capital of England.")
        
        # London should now exist
        self.assertTrue(self.school._entity_exists("london"))

    def test_observe_turn(self):
        """Test observe_turn updates last_seen."""
        # This should not raise
        self.school.observe_turn(
            prompt="I was in Paris.",
            reply="Paris is beautiful.",
            pulse=SchoolPulse(),
        )

    def test_generate_question_context_aware(self):
        """Test question generation is context-aware."""
        # Question about capital
        question = self.school._generate_question("London", "What is the capital of UK?")
        self.assertIn("capital", question.lower())
        
        # Question about country
        question = self.school._generate_question("Germany", "I visited a country.")
        self.assertIn("country", question.lower())


if __name__ == "__main__":
    unittest.main()

