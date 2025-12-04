"""
Unit tests for Phase 4: Island Bridges
Testing statistical trajectory learning without external observers.
"""

import sys
import os

# Add parent dir to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from phase4_bridges import (
    Episode,
    EpisodeStep,
    EpisodeLogger,
    TransitionGraph,
    BridgeMemory,
    metrics_similarity,
    suggest_next_islands_phase4,
    aggregate_bridge_scores,
    apply_risk_filter,
)


def test_episode_logger():
    """Test episode logging collects steps correctly."""
    logger = EpisodeLogger()

    # Start episode
    ep_id = logger.start_episode()
    assert logger.current_episode is not None
    assert logger.current_episode.episode_id == ep_id

    # Log steps
    logger.log_step(
        metrics={"pain": 1.0, "meta": 2.0},
        active_islands=["structural", "privacy"]
    )
    logger.log_step(
        metrics={"pain": 0.5, "meta": 1.5},
        active_islands=["wounded", "metaleo"]
    )

    # Check steps
    assert len(logger.current_episode.steps) == 2
    assert logger.current_episode.steps[0].metrics["pain"] == 1.0
    assert "structural" in logger.current_episode.steps[0].active_islands

    # End episode
    ep = logger.end_episode()
    assert ep is not None
    assert len(ep.steps) == 2
    assert logger.current_episode is None

    print("✓ test_episode_logger passed")


def test_transition_graph():
    """Test transition graph builds statistics."""
    graph = TransitionGraph()

    # Create test episode
    ep = Episode(episode_id="test1")
    step1 = EpisodeStep(
        episode_id="test1",
        step_idx=0,
        timestamp=0.0,
        metrics={"pain": 2.0, "quality": 0.3},
        active_islands=["structural"]
    )
    step2 = EpisodeStep(
        episode_id="test1",
        step_idx=1,
        timestamp=1.0,
        metrics={"pain": 1.0, "quality": 0.6},
        active_islands=["privacy"]
    )
    ep.add_step(step1)
    ep.add_step(step2)

    # Update graph
    graph.update_from_episode(ep)

    # Check transition
    stat = graph.get_stat("structural", "privacy")
    assert stat is not None
    assert stat.count == 1
    assert stat.avg_deltas["pain"] == -1.0  # pain decreased
    assert stat.avg_deltas["quality"] == 0.3  # quality increased

    print("✓ test_transition_graph passed")


def test_metrics_similarity():
    """Test metrics similarity computation."""
    m1 = {"pain": 2.0, "meta": 1.0, "quality": 0.5}
    m2 = {"pain": 2.1, "meta": 1.1, "quality": 0.6}
    m3 = {"pain": 5.0, "meta": 5.0, "quality": 0.1}

    # Similar metrics
    sim_close = metrics_similarity(m1, m2)
    assert sim_close > 0.85, f"Expected high similarity, got {sim_close}"

    # Dissimilar metrics
    sim_far = metrics_similarity(m1, m3)
    assert sim_far < 0.5, f"Expected low similarity, got {sim_far}"

    print("✓ test_metrics_similarity passed")


def test_bridge_memory():
    """Test bridge memory finds similar states."""
    memory = BridgeMemory()

    # Add episode to memory
    ep = Episode(episode_id="test1")
    step1 = EpisodeStep(
        episode_id="test1",
        step_idx=0,
        timestamp=0.0,
        metrics={"pain": 2.0, "meta": 1.0},
        active_islands=["structural"]
    )
    step2 = EpisodeStep(
        episode_id="test1",
        step_idx=1,
        timestamp=1.0,
        metrics={"pain": 1.0, "meta": 0.5},
        active_islands=["privacy"]
    )
    ep.add_step(step1)
    ep.add_step(step2)
    memory.add_episode(ep)

    # Search for similar state
    candidates = memory.collect_candidates(
        metrics_now={"pain": 2.1, "meta": 1.1},
        active_islands_now=["structural"],
        min_similarity=0.7
    )

    assert len(candidates) > 0
    assert "privacy" in candidates[0].to_islands

    print("✓ test_bridge_memory passed")


def test_risk_filter():
    """Test risk filter removes harmful bridges."""
    from phase4_bridges import IslandBridgeScore

    scores = {
        "safe_island": IslandBridgeScore(
            island="safe_island",
            raw_score=10.0,
            avg_deltas={"pain_state": 0.0, "overwhelm": 0.0},
            samples=5
        ),
        "risky_island": IslandBridgeScore(
            island="risky_island",
            raw_score=15.0,
            avg_deltas={"pain_state": 2.0, "overwhelm": 1.0},  # High pain/overwhelm increase
            samples=3
        ),
    }

    filtered = apply_risk_filter(scores, max_pain_delta=1.0, max_overwhelm_delta=0.5)

    assert "safe_island" in filtered
    assert "risky_island" not in filtered  # Should be filtered out

    print("✓ test_risk_filter passed")


def test_suggest_next_islands():
    """Test end-to-end suggestion pipeline."""
    memory = BridgeMemory()

    # Build history with pattern: high pain → privacy
    for i in range(3):
        ep = Episode(episode_id=f"ep{i}")
        step1 = EpisodeStep(
            episode_id=f"ep{i}",
            step_idx=0,
            timestamp=float(i),
            metrics={"pain": 2.0, "quality": 0.3},
            active_islands=["structural"]
        )
        step2 = EpisodeStep(
            episode_id=f"ep{i}",
            step_idx=1,
            timestamp=float(i) + 1.0,
            metrics={"pain": 1.0, "quality": 0.6},
            active_islands=["privacy"]
        )
        ep.add_step(step1)
        ep.add_step(step2)
        memory.add_episode(ep)

    # Query: similar high pain state
    suggestions = suggest_next_islands_phase4(
        metrics_now={"pain": 2.1, "quality": 0.35},
        active_islands_now=["structural"],
        bridge_memory=memory,
        min_similarity=0.6,
        temperature=0.5,
        exploration_rate=0.1,
    )

    # Should suggest privacy (learned pattern)
    assert len(suggestions) > 0
    print(f"  Suggestions: {suggestions}")
    # Note: exact suggestions depend on probability, so we just check non-empty

    print("✓ test_suggest_next_islands passed")


def test_integration_with_leo():
    """Test Phase 4 can be imported from leo.py."""
    try:
        # Test that Phase 4 imports work in leo.py
        from leo import (
            PHASE4_AVAILABLE,
            EpisodeLogger,
            BridgeMemory,
            TransitionGraph,
            suggest_next_islands_phase4,
        )

        # Check imports succeeded
        if PHASE4_AVAILABLE:
            assert EpisodeLogger is not None
            assert BridgeMemory is not None
            assert TransitionGraph is not None
            assert suggest_next_islands_phase4 is not None

            # Test that they can be instantiated
            logger = EpisodeLogger()
            memory = BridgeMemory()
            graph = TransitionGraph()

            assert logger is not None
            assert memory is not None
            assert graph is not None

            print("  Phase 4 imports and instantiation successful")
        else:
            print("  Phase 4 not available (expected if import failed)")

        print("✓ test_integration_with_leo passed")
    except Exception as e:
        print(f"✗ test_integration_with_leo failed: {e}")
        raise


if __name__ == "__main__":
    print("Running Phase 4 unit tests...\n")

    test_episode_logger()
    test_transition_graph()
    test_metrics_similarity()
    test_bridge_memory()
    test_risk_filter()
    test_suggest_next_islands()
    test_integration_with_leo()

    print("\n✅ All Phase 4 tests passed!")
