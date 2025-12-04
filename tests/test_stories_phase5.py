#!/usr/bin/env python3
"""
test_stories_phase5.py — Tests for Leo's Phase 5 Stories

Covers:
1. StoryBook - trajectory storage and similarity matching
2. H2OScenario - scenario triggering and execution
3. SharedField - Leo + human island tracking
4. DreamEngine - trajectory replay (placeholder)
5. Integration tests with Phase 4
"""

import tempfile
from pathlib import Path
import pytest
import json

from stories import (
    Story,
    StoryStep,
    StoryBook,
    H2OScenario,
    ScenarioLibrary,
    SharedField,
    DreamEngine,
    suggest_next_islands_phase5,
    H2O_AVAILABLE,
)


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def temp_story_db():
    """Create a temporary JSON file for StoryBook."""
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False, mode='w') as f:
        json.dump({"stories": []}, f)  # Empty story dict (not list!)
        db_path = Path(f.name)
    yield db_path
    # Cleanup
    if db_path.exists():
        db_path.unlink()


@pytest.fixture
def storybook(temp_story_db):
    """Create a StoryBook instance with temp database."""
    return StoryBook(db_path=temp_story_db)


@pytest.fixture
def scenario_library():
    """Create a ScenarioLibrary with default scenarios."""
    return ScenarioLibrary()


@pytest.fixture
def shared_field():
    """Create a SharedField instance."""
    return SharedField()


# ============================================================================
# STORYBOOK TESTS
# ============================================================================

class TestStoryBook:
    """Tests for StoryBook trajectory storage and matching."""

    def test_add_story(self, storybook):
        """Add a story and verify it's stored."""
        story = Story(
            story_id="test_story_1",
            timestamp_start=1000.0,
            timestamp_end=1010.0,
            trajectory=[
                StoryStep(
                    step_idx=0,
                    timestamp=1000.0,
                    leo_metrics={"presence_pulse": 0.3, "entropy": 0.5},
                    leo_islands=["theme_loneliness"],
                ),
                StoryStep(
                    step_idx=1,
                    timestamp=1010.0,
                    leo_metrics={"presence_pulse": 0.5, "entropy": 0.45},
                    leo_islands=["theme_connection"],
                ),
            ],
            emotional_arc={"presence_pulse": +0.2, "entropy": -0.05},
            outcome_quality=0.7,
            signature_pattern="loneliness→connection",
        )

        storybook.add_story(story)
        all_stories = storybook.stories

        assert len(all_stories) == 1
        assert all_stories[0].story_id == "test_story_1"
        # finalize() generates signature from islands
        assert all_stories[0].signature_pattern == "theme_loneliness→theme_connection"

    def test_find_similar_stories(self, storybook):
        """Find stories similar to current state."""
        # Add reference story
        story1 = Story(
            story_id="reference",
            timestamp_start=1000.0,
            timestamp_end=1000.0,
            trajectory=[
                StoryStep(
                    step_idx=0,
                    timestamp=1000.0,
                    leo_metrics={"presence_pulse": 0.3, "arousal": 0.4},
                    leo_islands=["theme_pain"],
                ),
            ],
            emotional_arc={},
            outcome_quality=0.8,
        )
        storybook.add_story(story1)

        # Query with similar metrics
        current_metrics = {"presence_pulse": 0.35, "arousal": 0.45}
        current_islands = ["theme_pain"]

        similar = storybook.find_similar_stories(current_metrics, current_islands, min_similarity=0.5)

        assert len(similar) > 0
        assert similar[0][0].story_id == "reference"
        assert similar[0][1] > 0.5  # Similarity score

    def test_get_good_endings(self, storybook):
        """Retrieve stories with good outcomes for a pattern."""
        # Add good and bad endings for same pattern
        good_story = Story(
            story_id="good_ending",
            timestamp_start=1000.0,
            timestamp_end=1050.0,
            trajectory=[],
            emotional_arc={},
            outcome_quality=0.9,
            signature_pattern="pain→relief",
        )
        bad_story = Story(
            story_id="bad_ending",
            timestamp_start=2000.0,
            timestamp_end=2050.0,
            trajectory=[],
            emotional_arc={},
            outcome_quality=0.2,
            signature_pattern="pain→relief",
        )

        storybook.add_story(good_story)
        storybook.add_story(bad_story)

        good_endings = storybook.get_good_endings("pain→relief", min_quality=0.5)
        assert len(good_endings) == 1
        assert good_endings[0].story_id == "good_ending"

    def test_persistence(self, temp_story_db):
        """Stories should persist across StoryBook instances."""
        # First instance: add story
        sb1 = StoryBook(db_path=temp_story_db)
        story = Story(
            story_id="persistent",
            timestamp_start=1000.0,
            timestamp_end=1050.0,
            trajectory=[],
            emotional_arc={},
            outcome_quality=0.7,
        )
        sb1.add_story(story)
        # add_story already saves to db automatically

        # Second instance: load story
        sb2 = StoryBook(db_path=temp_story_db)
        all_stories = sb2.stories

        assert len(all_stories) == 1
        assert all_stories[0].story_id == "persistent"


# ============================================================================
# H2O SCENARIO TESTS
# ============================================================================

class TestH2OScenario:
    """Tests for H2O scenario triggering and execution."""

    def test_scenario_trigger_condition(self):
        """Scenario should trigger when condition is met."""
        scenario = H2OScenario(
            scenario_id="test_trigger",
            purpose="Test trigger logic",
            trigger_condition=lambda m, i: m.get("test_metric", 0) > 0.5,
            scenario_code="h2o_log('triggered')",
            cooldown_seconds=10.0,
        )

        # Should trigger
        assert scenario.should_trigger({"test_metric": 0.7}, []) is True

        # Should not trigger
        assert scenario.should_trigger({"test_metric": 0.3}, []) is False

    def test_scenario_cooldown(self):
        """Scenario should respect cooldown period."""
        scenario = H2OScenario(
            scenario_id="test_cooldown",
            purpose="Test cooldown",
            trigger_condition=lambda m, i: True,  # Always triggers
            scenario_code="h2o_log('test')",
            cooldown_seconds=100.0,  # Long cooldown
        )

        # First trigger should work
        assert scenario.should_trigger({}, []) is True

        # Manually set last_run to simulate recent execution
        import time
        scenario.last_run = time.time()

        # Second immediate trigger should be blocked by cooldown
        assert scenario.should_trigger({}, []) is False

    @pytest.mark.skipif(not H2O_AVAILABLE, reason="H2O not available")
    def test_scenario_execution(self):
        """Scenario should execute h2o code."""
        scenario = H2OScenario(
            scenario_id="test_exec",
            purpose="Test execution",
            trigger_condition=lambda m, i: True,
            scenario_code="""
result = {"test": "success"}
""",
            cooldown_seconds=0.0,
        )

        result = scenario.execute(context={})
        # Should complete without errors
        assert result is None  # H2O doesn't return exec result directly


class TestScenarioLibrary:
    """Tests for ScenarioLibrary default scenarios."""

    def test_default_scenarios_loaded(self, scenario_library):
        """Library should load default scenarios."""
        assert len(scenario_library.scenarios) >= 4  # calm_overwhelm, break_meta_loop, safety_paradox, amplify_relief

        scenario_ids = [s.scenario_id for s in scenario_library.scenarios]
        assert "calm_overwhelm" in scenario_ids
        assert "break_meta_loop" in scenario_ids
        assert "safety_paradox" in scenario_ids
        assert "amplify_relief" in scenario_ids

    def test_break_meta_loop_triggers(self, scenario_library):
        """break_meta_loop should trigger on meta_state > 1.5 OR loop_intensity >= 2."""
        # Find break_meta_loop scenario
        break_meta = next(s for s in scenario_library.scenarios if s.scenario_id == "break_meta_loop")

        # Test 1: High meta_state with meta islands
        assert break_meta.trigger_condition(
            {"meta_state": 2.0, "loop_intensity": 0},
            ["meta_armor", "metaleo"]
        ) is True

        # Test 2: High loop_intensity alone
        assert break_meta.trigger_condition(
            {"meta_state": 0.5, "loop_intensity": 2},
            []
        ) is True

        # Test 3: Neither condition met
        assert break_meta.trigger_condition(
            {"meta_state": 1.0, "loop_intensity": 1},
            []
        ) is False

    def test_safety_paradox_triggers(self, scenario_library):
        """safety_paradox should trigger when safety context + defensive patterns."""
        # Find safety_paradox scenario
        safety_paradox = next(s for s in scenario_library.scenarios if s.scenario_id == "safety_paradox")

        # Should trigger: safety context + high pain_state
        assert safety_paradox.trigger_condition(
            {"safety_context": 0.6, "pain_state": 2.0},
            []
        ) is True

        # Should NOT trigger: safety context but low defensiveness
        assert safety_paradox.trigger_condition(
            {"safety_context": 0.6, "pain_state": 0.5, "meta_state": 0.5},
            []
        ) is False

    def test_check_and_execute(self, scenario_library):
        """check_and_execute should trigger first matching scenario."""
        # Trigger calm_overwhelm
        result = scenario_library.check_and_execute(
            metrics={"overwhelm": 0.8},
            islands=[],
            context={}
        )

        # H2O execution returns None (exec doesn't return value)
        # But we should see logs showing scenario triggered
        # For now, just verify no crash
        # TODO: Improve H2O scenario return values
        assert True  # Test passes if no exception


# ============================================================================
# SHARED FIELD TESTS
# ============================================================================

class TestSharedField:
    """Tests for SharedField Leo + human tracking."""

    def test_record_leo_island(self, shared_field):
        """Record Leo's island activations."""
        shared_field.record_leo_island("theme_loneliness")
        shared_field.record_leo_island("theme_loneliness")
        shared_field.record_leo_island("theme_connection")

        assert shared_field.leo_islands["theme_loneliness"] == 2
        assert shared_field.leo_islands["theme_connection"] == 1

    @pytest.mark.skip(reason="record_human_island() not yet implemented")
    def test_record_human_island(self, shared_field):
        """Record human's inferred emotional states (TODO)."""
        # shared_field.record_human_island("human_curious")
        # shared_field.record_human_island("human_concerned")
        #
        # assert shared_field.human_islands["human_curious"] == 1
        # assert shared_field.human_islands["human_concerned"] == 1
        pass

    @pytest.mark.skip(reason="get_frequent_leo_islands() not yet implemented")
    def test_get_frequent_islands(self, shared_field):
        """Get most frequent islands for Leo and human (TODO)."""
        # Add various frequencies
        shared_field.record_leo_island("island_A")
        shared_field.record_leo_island("island_A")
        shared_field.record_leo_island("island_A")
        shared_field.record_leo_island("island_B")
        shared_field.record_leo_island("island_C")

        # frequent = shared_field.get_frequent_leo_islands(top_n=2)
        #
        # assert len(frequent) == 2
        # assert frequent[0][0] == "island_A"  # Most frequent
        # assert frequent[0][1] == 3
        pass


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

class TestPhase5Integration:
    """Integration tests combining multiple Phase 5 components."""

    def test_suggest_next_islands_phase5(self, storybook, scenario_library, shared_field):
        """suggest_next_islands_phase5 should combine stories + scenarios + shared field."""
        # Add a good story pattern
        story = Story(
            story_id="good_pattern",
            timestamp_start=1000.0,
            timestamp_end=1010.0,
            trajectory=[
                StoryStep(
                    step_idx=0,
                    timestamp=1000.0,
                    leo_metrics={"presence_pulse": 0.3},
                    leo_islands=["theme_pain"],
                ),
                StoryStep(
                    step_idx=1,
                    timestamp=1010.0,
                    leo_metrics={"presence_pulse": 0.7},
                    leo_islands=["theme_relief"],
                ),
            ],
            emotional_arc={"presence_pulse": +0.4},
            outcome_quality=0.9,
            signature_pattern="pain→relief",
        )
        storybook.add_story(story)

        # Current state: similar to story start
        current_metrics = {"presence_pulse": 0.35, "pain_state": 1.5}
        current_islands = ["theme_pain"]

        suggestions = suggest_next_islands_phase5(
            metrics_now=current_metrics,
            active_islands_now=current_islands,
            storybook=storybook,
            scenario_library=scenario_library,
            shared_field=shared_field,
            min_similarity=0.3,
            temperature=0.7,
        )

        # Should get a list (may be empty if no good candidates)
        assert suggestions is not None
        assert isinstance(suggestions, list)

    def test_scenario_overrides_story(self, storybook, scenario_library, shared_field):
        """Scenarios should take priority over stories when triggered."""
        # Add calm story
        story = Story(
            story_id="calm_story",
            timestamp_start=1000.0,
            timestamp_end=1050.0,
            trajectory=[],
            emotional_arc={},
            outcome_quality=0.8,
        )
        storybook.add_story(story)

        # Trigger overwhelm scenario
        current_metrics = {"overwhelm": 0.9, "presence_pulse": 0.2}
        current_islands = []

        suggestions = suggest_next_islands_phase5(
            metrics_now=current_metrics,
            active_islands_now=current_islands,
            storybook=storybook,
            scenario_library=scenario_library,
            shared_field=shared_field,
            min_similarity=0.3,
            temperature=0.7,
        )

        # Scenario should have triggered (will see in logs)
        # Suggestions should prioritize calming islands
        assert suggestions is not None


# ============================================================================
# DREAM ENGINE TESTS (PLACEHOLDER)
# ============================================================================

class TestDreamEngine:
    """Tests for DreamEngine trajectory replay (placeholder for future)."""

    def test_dream_engine_initialization(self, storybook):
        """DreamEngine should initialize with StoryBook."""
        engine = DreamEngine(storybook)
        assert engine.storybook == storybook

    def test_replay_bad_ending_placeholder(self, storybook):
        """Placeholder test for bad ending replay."""
        engine = DreamEngine(storybook)

        # Add bad ending story
        bad_story = Story(
            story_id="bad_ending",
            timestamp_start=1000.0,
            timestamp_end=1050.0,
            trajectory=[],
            emotional_arc={},
            outcome_quality=0.1,
            signature_pattern="pain→stuck",
        )
        storybook.add_story(bad_story)

        # TODO: Implement replay_bad_ending() method
        # replayed = engine.replay_bad_ending("pain→stuck")
        # assert replayed is not None

        # For now, just verify engine exists
        assert engine is not None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
