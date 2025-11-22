"""
Test #141-150: GameEngine — conversational rhythm awareness

GameEngine learns sequential patterns in dialogue:
- GameTurn abstraction (role, mode, arousal, trauma, entropy, expert, theme, quality)
- Transition graph: (A,B) -> C with counts
- GameHint suggestions (mode, expert, length, tension)
- SQLite persistence
- Silent fallback on all errors

Tests cover:
- GameTurn creation and serialization (to_id, from_context)
- Helper functions (bucketize, decode_game_id, detect_mode)
- GameEngine initialization and persistence
- observe_turn() (learning transitions)
- suggest_next() (generating hints)
- Confidence modulation with MathState
- Growth heuristic (max_trail_length)
"""

import unittest
import tempfile
from pathlib import Path

# Import game module
try:
    from game import (
        GameTurn, GameHint, GameEngine,
        bucketize, decode_game_id, detect_mode_from_text,
        get_last_turns, GAME_AVAILABLE
    )
    GAME_TEST_AVAILABLE = True
except ImportError:
    GAME_TEST_AVAILABLE = False

# Import mathbrain for MathState (optional)
try:
    from mathbrain import MathState
    MATH_AVAILABLE = True
except ImportError:
    MATH_AVAILABLE = False


class TestGameTurn(unittest.TestCase):
    """Test #141: GameTurn creation and serialization."""

    def setUp(self):
        if not GAME_TEST_AVAILABLE:
            self.skipTest("game.py not available")

    def test_gameturn_creation(self):
        """Test GameTurn basic creation."""
        turn = GameTurn(
            role="human",
            mode="q",
            arousal="mid",
            trauma="low",
            entropy="high",
            expert="structural",
            theme_id=5,
            quality="mid",
        )

        self.assertEqual(turn.role, "human")
        self.assertEqual(turn.mode, "q")
        self.assertEqual(turn.arousal, "mid")
        self.assertEqual(turn.theme_id, 5)

    def test_gameturn_to_id(self):
        """Test GameTurn.to_id() serialization."""
        turn = GameTurn(
            role="leo",
            mode="a",
            arousal="high",
            trauma="mid",
            entropy="low",
            expert="semantic",
            theme_id=-1,
            quality="high",
        )

        turn_id = turn.to_id()

        # Should be parseable string
        self.assertIsInstance(turn_id, str)
        self.assertIn("L:", turn_id)  # Leo
        self.assertIn("A:", turn_id)  # Answer mode
        self.assertIn("A_HIGH", turn_id)  # Arousal
        self.assertIn("semantic", turn_id)  # Expert

    def test_gameturn_from_context(self):
        """Test GameTurn.from_context() with MathState."""
        if not MATH_AVAILABLE:
            self.skipTest("mathbrain not available for from_context")

        state = MathState(
            arousal=0.8,
            trauma_level=0.2,
            entropy=0.5,
            quality=0.7,
        )

        turn = GameTurn.from_context(
            role="leo",
            mode="a",
            math_state=state,
            theme_id=3,
            expert="creative",
            quality_value=0.7,
        )

        self.assertEqual(turn.role, "leo")
        self.assertEqual(turn.mode, "a")
        self.assertEqual(turn.arousal, "high")  # 0.8 -> high
        self.assertEqual(turn.trauma, "low")  # 0.2 -> low
        self.assertEqual(turn.entropy, "mid")  # 0.5 -> mid
        self.assertEqual(turn.quality, "high")  # 0.7 -> high
        self.assertEqual(turn.expert, "creative")
        self.assertEqual(turn.theme_id, 3)

    def test_gameturn_from_context_no_quality(self):
        """Test from_context with None quality."""
        if not MATH_AVAILABLE:
            self.skipTest("mathbrain not available")

        state = MathState()
        turn = GameTurn.from_context(
            role="human",
            mode="q",
            math_state=state,
            theme_id=-1,
            expert="structural",
            quality_value=None,
        )

        self.assertEqual(turn.quality, "mid")  # Default for None


class TestHelperFunctions(unittest.TestCase):
    """Test #142: Helper functions — bucketize, decode, detect."""

    def setUp(self):
        if not GAME_TEST_AVAILABLE:
            self.skipTest("game.py not available")

    def test_bucketize_low(self):
        """Test bucketize for low values."""
        self.assertEqual(bucketize(0.0), "low")
        self.assertEqual(bucketize(0.2), "low")
        self.assertEqual(bucketize(0.32), "low")

    def test_bucketize_mid(self):
        """Test bucketize for mid values."""
        self.assertEqual(bucketize(0.33), "mid")
        self.assertEqual(bucketize(0.5), "mid")
        self.assertEqual(bucketize(0.66), "mid")

    def test_bucketize_high(self):
        """Test bucketize for high values."""
        self.assertEqual(bucketize(0.67), "high")
        self.assertEqual(bucketize(0.8), "high")
        self.assertEqual(bucketize(1.0), "high")

    def test_bucketize_custom_thresholds(self):
        """Test bucketize with custom thresholds."""
        self.assertEqual(bucketize(0.4, low=0.5, high=0.7), "low")
        self.assertEqual(bucketize(0.6, low=0.5, high=0.7), "mid")
        self.assertEqual(bucketize(0.8, low=0.5, high=0.7), "high")

    def test_decode_game_id_valid(self):
        """Test decode_game_id with valid input."""
        turn_id = "L:A:A_HIGH:T_MID:E_LOW:TH_5:EX_semantic:Q_HIGH"
        decoded = decode_game_id(turn_id)

        self.assertIsNotNone(decoded)
        self.assertEqual(decoded["role"], "leo")
        self.assertEqual(decoded["mode"], "a")
        self.assertEqual(decoded["arousal"], "high")
        self.assertEqual(decoded["trauma"], "mid")
        self.assertEqual(decoded["entropy"], "low")
        self.assertEqual(decoded["theme_id"], 5)
        self.assertEqual(decoded["expert"], "semantic")
        self.assertEqual(decoded["quality"], "high")

    def test_decode_game_id_invalid(self):
        """Test decode_game_id with invalid input."""
        self.assertIsNone(decode_game_id("invalid"))
        self.assertIsNone(decode_game_id(""))
        self.assertIsNone(decode_game_id("H:Q:A_LOW"))  # Too short

    def test_detect_mode_question(self):
        """Test detect_mode for questions."""
        self.assertEqual(detect_mode_from_text("What is this?"), "q")
        self.assertEqual(detect_mode_from_text("How are you doing?"), "q")
        self.assertEqual(detect_mode_from_text("Why did that happen?"), "q")

    def test_detect_mode_ack(self):
        """Test detect_mode for short acknowledgments."""
        self.assertEqual(detect_mode_from_text("ok"), "ack")
        self.assertEqual(detect_mode_from_text("thanks"), "ack")
        self.assertEqual(detect_mode_from_text("yes"), "ack")

    def test_detect_mode_meta(self):
        """Test detect_mode for meta/identity questions."""
        self.assertEqual(detect_mode_from_text("who are you?"), "meta")
        self.assertEqual(detect_mode_from_text("what is leo?"), "meta")
        self.assertEqual(detect_mode_from_text("tell me about yourself"), "meta")

    def test_detect_mode_story(self):
        """Test detect_mode for long narratives."""
        long_text = "This is a long story with multiple sentences. It goes on and on. " * 5
        self.assertEqual(detect_mode_from_text(long_text), "story")

    def test_detect_mode_answer(self):
        """Test detect_mode default (answer)."""
        self.assertEqual(detect_mode_from_text("This is a normal statement."), "a")


class TestGameEngineInit(unittest.TestCase):
    """Test #143: GameEngine initialization and basic operations."""

    def setUp(self):
        if not GAME_TEST_AVAILABLE:
            self.skipTest("game.py not available")

        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_game.sqlite3"

    def tearDown(self):
        if self.db_path.exists():
            self.db_path.unlink()
        Path(self.temp_dir).rmdir()

    def test_engine_initialization(self):
        """Test GameEngine basic initialization."""
        engine = GameEngine(db_path=self.db_path)

        self.assertEqual(engine._episode_count, 0)
        self.assertEqual(len(engine._transitions), 0)
        self.assertEqual(len(engine._single), 0)
        self.assertEqual(len(engine._last_turns), 0)

    def test_engine_stats_empty(self):
        """Test stats() on empty engine."""
        engine = GameEngine(db_path=self.db_path)
        stats = engine.stats()

        self.assertEqual(stats["episode_count"], 0.0)
        self.assertEqual(stats["num_pairs"], 0.0)
        self.assertEqual(stats["max_trail_length"], 2.0)  # min value

    def test_max_trail_length_growth(self):
        """Test max_trail_length grows with episodes."""
        engine = GameEngine(db_path=self.db_path)

        # Empty: 2
        self.assertEqual(engine.max_trail_length(), 2)

        # 10 episodes: 2 + log10(11) ≈ 3
        engine._episode_count = 10
        self.assertGreaterEqual(engine.max_trail_length(), 2)

        # 1000 episodes: 2 + log10(1001) ≈ 5
        engine._episode_count = 1000
        self.assertGreaterEqual(engine.max_trail_length(), 4)

        # Should cap at 6
        engine._episode_count = 1000000
        self.assertEqual(engine.max_trail_length(), 6)


class TestGameEngineObserve(unittest.TestCase):
    """Test #144: GameEngine.observe_turn() — learning transitions."""

    def setUp(self):
        if not GAME_TEST_AVAILABLE:
            self.skipTest("game.py not available")

        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_game.sqlite3"
        self.engine = GameEngine(db_path=self.db_path)

    def tearDown(self):
        if self.db_path.exists():
            self.db_path.unlink()
        Path(self.temp_dir).rmdir()

    def test_observe_single_turn(self):
        """Test observing single turn."""
        turn = GameTurn(
            role="human",
            mode="q",
            arousal="mid",
            trauma="low",
            entropy="mid",
            expert="structural",
            theme_id=-1,
            quality="mid",
        )

        self.engine.observe_turn("conv1", turn)

        # Should update episode count
        self.assertEqual(self.engine._episode_count, 1)

        # Should have 1 turn in history
        history = self.engine._last_turns.get("conv1", [])
        self.assertEqual(len(history), 1)

        # No transitions yet (need 3 turns)
        self.assertEqual(len(self.engine._transitions), 0)

    def test_observe_three_turns_creates_transition(self):
        """Test that 3 turns create a transition."""
        turns = [
            GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid"),
            GameTurn("leo", "a", "high", "low", "mid", "semantic", 2, "high"),
            GameTurn("human", "ack", "low", "low", "low", "structural", -1, "mid"),
        ]

        for turn in turns:
            self.engine.observe_turn("conv1", turn)

        # Should have recorded transition (t0,t1)->t2
        self.assertEqual(len(self.engine._transitions), 1)

        # Should have updated single counter
        self.assertGreater(len(self.engine._single), 0)

    def test_observe_sliding_window(self):
        """Test that history keeps only last 3 turns."""
        for i in range(10):
            turn = GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid")
            self.engine.observe_turn("conv1", turn)

        history = self.engine._last_turns.get("conv1", [])
        self.assertEqual(len(history), 3)  # Max 3 turns

    def test_observe_multiple_conversations(self):
        """Test observing turns in different conversations."""
        turn1 = GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid")
        turn2 = GameTurn("leo", "a", "high", "low", "mid", "creative", 3, "high")

        self.engine.observe_turn("conv1", turn1)
        self.engine.observe_turn("conv2", turn2)

        self.assertEqual(len(self.engine._last_turns), 2)
        self.assertIn("conv1", self.engine._last_turns)
        self.assertIn("conv2", self.engine._last_turns)


class TestGameEngineSuggest(unittest.TestCase):
    """Test #145: GameEngine.suggest_next() — generating hints."""

    def setUp(self):
        if not GAME_TEST_AVAILABLE:
            self.skipTest("game.py not available")

        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_game.sqlite3"
        self.engine = GameEngine(db_path=self.db_path)

    def tearDown(self):
        if self.db_path.exists():
            self.db_path.unlink()
        Path(self.temp_dir).rmdir()

    def test_suggest_no_history(self):
        """Test suggest_next with no history."""
        hint = self.engine.suggest_next("conv1")
        self.assertIsNone(hint)  # Not enough turns

    def test_suggest_insufficient_turns(self):
        """Test suggest_next with only 1 turn."""
        turn = GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid")
        self.engine.observe_turn("conv1", turn)

        hint = self.engine.suggest_next("conv1")
        self.assertIsNone(hint)  # Need at least 2

    def test_suggest_fallback_to_global(self):
        """Test fallback to global most common when no transition exists."""
        # Train with some pattern
        for i in range(5):
            self.engine.observe_turn("conv1", GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid"))
            self.engine.observe_turn("conv1", GameTurn("leo", "a", "mid", "low", "mid", "semantic", -1, "mid"))
            self.engine.observe_turn("conv1", GameTurn("human", "ack", "low", "low", "low", "structural", -1, "mid"))

        # New conversation with different pattern
        self.engine.observe_turn("conv2", GameTurn("human", "meta", "high", "mid", "high", "structural", -1, "mid"))
        self.engine.observe_turn("conv2", GameTurn("leo", "story", "high", "high", "mid", "wounded", 7, "mid"))

        # Should get hint (fallback to global)
        hint = self.engine.suggest_next("conv2")
        self.assertIsNotNone(hint)
        self.assertIsInstance(hint.confidence, float)

    def test_suggest_with_trained_pattern(self):
        """Test suggestion with learned pattern."""
        # Train consistent pattern: Q -> A -> ACK
        pattern = [
            GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid"),
            GameTurn("leo", "a", "mid", "low", "mid", "semantic", -1, "high"),
            GameTurn("human", "ack", "low", "low", "low", "structural", -1, "mid"),
        ]

        # Repeat pattern 5 times
        for _ in range(5):
            for turn in pattern:
                self.engine.observe_turn("conv1", turn)

        # Now give it Q -> A and ask for next
        self.engine._last_turns["conv_test"] = pattern[:2]
        hint = self.engine.suggest_next("conv_test", last_turns=pattern[:2])

        # Should suggest something
        self.assertIsNotNone(hint)
        self.assertIsInstance(hint, GameHint)
        self.assertGreater(hint.confidence, 0.0)

    def test_suggest_hint_structure(self):
        """Test that GameHint has expected structure."""
        # Train minimal pattern
        for _ in range(3):
            self.engine.observe_turn("conv1", GameTurn("human", "q", "high", "low", "mid", "structural", -1, "mid"))
            self.engine.observe_turn("conv1", GameTurn("leo", "a", "mid", "low", "low", "creative", 2, "high"))

        # Get hint
        last_turns = self.engine._last_turns.get("conv1", [])[-2:]
        hint = self.engine.suggest_next("conv1", last_turns=last_turns)

        if hint is not None:
            # Check fields exist
            self.assertTrue(hasattr(hint, "mode"))
            self.assertTrue(hasattr(hint, "preferred_expert"))
            self.assertTrue(hasattr(hint, "target_length"))
            self.assertTrue(hasattr(hint, "tension_shift"))
            self.assertTrue(hasattr(hint, "confidence"))

            # Confidence should be in [0, 1]
            self.assertGreaterEqual(hint.confidence, 0.0)
            self.assertLessEqual(hint.confidence, 1.0)


class TestGameEnginePersistence(unittest.TestCase):
    """Test #146: GameEngine save/load persistence."""

    def setUp(self):
        if not GAME_TEST_AVAILABLE:
            self.skipTest("game.py not available")

        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_persist.sqlite3"

    def tearDown(self):
        if self.db_path.exists():
            self.db_path.unlink()
        Path(self.temp_dir).rmdir()

    def test_save_creates_database(self):
        """Test that save() creates SQLite file."""
        engine = GameEngine(db_path=self.db_path)

        # Observe some turns
        for _ in range(5):
            turn = GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid")
            engine.observe_turn("conv1", turn)

        # Explicit save
        engine.save()

        # DB should exist
        self.assertTrue(self.db_path.exists())

    def test_load_restores_state(self):
        """Test that load restores episode count and transitions."""
        # Create and train first engine
        engine1 = GameEngine(db_path=self.db_path)

        pattern = [
            GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid"),
            GameTurn("leo", "a", "high", "low", "mid", "semantic", 2, "high"),
            GameTurn("human", "ack", "low", "low", "low", "structural", -1, "mid"),
        ]

        for _ in range(3):
            for turn in pattern:
                engine1.observe_turn("conv1", turn)

        engine1.save()

        stats1 = engine1.stats()

        # Create new engine (should load)
        engine2 = GameEngine(db_path=self.db_path)
        stats2 = engine2.stats()

        # Should have same episode count
        self.assertEqual(stats2["episode_count"], stats1["episode_count"])

        # Should have transitions
        self.assertGreater(stats2["num_pairs"], 0.0)

    def test_multiple_save_load_cycles(self):
        """Test multiple save/load cycles."""
        engine1 = GameEngine(db_path=self.db_path)
        engine1.observe_turn("conv1", GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid"))
        engine1.save()

        engine2 = GameEngine(db_path=self.db_path)
        self.assertEqual(engine2._episode_count, 1)

        engine2.observe_turn("conv1", GameTurn("leo", "a", "mid", "low", "mid", "semantic", -1, "high"))
        engine2.save()

        engine3 = GameEngine(db_path=self.db_path)
        self.assertEqual(engine3._episode_count, 2)


class TestGameHintMapping(unittest.TestCase):
    """Test #147: _build_hint_from_key() mapping logic."""

    def setUp(self):
        if not GAME_TEST_AVAILABLE:
            self.skipTest("game.py not available")

        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_hint.sqlite3"
        self.engine = GameEngine(db_path=self.db_path)

    def tearDown(self):
        if self.db_path.exists():
            self.db_path.unlink()
        Path(self.temp_dir).rmdir()

    def test_hint_short_length_for_ack(self):
        """Test that 'ack' mode maps to short length."""
        c_key = {
            "mode": "ack",
            "arousal": "low",
            "trauma": "low",
            "quality": "mid",
            "expert": "structural",
        }

        hint = self.engine._build_hint_from_key(c_key, None, 0.5)
        self.assertEqual(hint.target_length, "short")

    def test_hint_long_length_for_story(self):
        """Test that 'story' mode maps to long length."""
        c_key = {
            "mode": "story",
            "arousal": "high",
            "trauma": "mid",
            "quality": "high",
            "expert": "creative",
        }

        hint = self.engine._build_hint_from_key(c_key, None, 0.7)
        self.assertEqual(hint.target_length, "long")

    def test_hint_tension_softer(self):
        """Test tension_shift 'softer' for low arousal + high trauma."""
        c_key = {
            "mode": "a",
            "arousal": "low",
            "trauma": "high",
            "quality": "mid",
            "expert": "wounded",
        }

        hint = self.engine._build_hint_from_key(c_key, None, 0.5)
        self.assertEqual(hint.tension_shift, "softer")

    def test_hint_tension_stronger(self):
        """Test tension_shift 'stronger' for high arousal."""
        c_key = {
            "mode": "a",
            "arousal": "high",
            "trauma": "mid",
            "quality": "high",
            "expert": "creative",
        }

        hint = self.engine._build_hint_from_key(c_key, None, 0.6)
        self.assertEqual(hint.tension_shift, "stronger")

    def test_hint_confidence_modulation_with_mathstate(self):
        """Test confidence modulation with MathState quality."""
        if not MATH_AVAILABLE:
            self.skipTest("mathbrain not available")

        c_key = {
            "mode": "a",
            "arousal": "mid",
            "trauma": "low",
            "quality": "mid",
            "expert": "semantic",
        }

        # Low quality state -> reduce confidence
        low_state = MathState(quality=0.2)
        hint_low = self.engine._build_hint_from_key(c_key, low_state, 0.6)
        self.assertLess(hint_low.confidence, 0.6)

        # High quality state -> boost confidence
        high_state = MathState(quality=0.8)
        hint_high = self.engine._build_hint_from_key(c_key, high_state, 0.6)
        self.assertGreater(hint_high.confidence, 0.6)


class TestGameStandalone(unittest.TestCase):
    """Test #148: Standalone helper functions."""

    def setUp(self):
        if not GAME_TEST_AVAILABLE:
            self.skipTest("game.py not available")

        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_standalone.sqlite3"
        self.engine = GameEngine(db_path=self.db_path)

    def tearDown(self):
        if self.db_path.exists():
            self.db_path.unlink()
        Path(self.temp_dir).rmdir()

    def test_get_last_turns(self):
        """Test get_last_turns() helper."""
        turn1 = GameTurn("human", "q", "mid", "low", "mid", "structural", -1, "mid")
        turn2 = GameTurn("leo", "a", "mid", "low", "mid", "semantic", -1, "high")

        self.engine.observe_turn("conv1", turn1)
        self.engine.observe_turn("conv1", turn2)

        last_turns = get_last_turns(self.engine, "conv1")
        self.assertEqual(len(last_turns), 2)
        self.assertEqual(last_turns[0].role, "human")
        self.assertEqual(last_turns[1].role, "leo")

    def test_get_last_turns_empty(self):
        """Test get_last_turns() for unknown conversation."""
        last_turns = get_last_turns(self.engine, "unknown")
        self.assertEqual(len(last_turns), 0)


if __name__ == "__main__":
    unittest.main()
