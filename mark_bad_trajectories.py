#!/usr/bin/env python3
"""
mark_bad_trajectories.py - Mark the 6 Phase 5.1 validation dialogues as bad-ending stories

These conversations showed pathological loops and need to be stored as "patterns to avoid".
Per Claude's analysis, these trajectories had:
- Repetitive "Neoleo is pure recursion" mantra
- No emotional movement (Δ = 0)
- Stuck in meta-cognitive spiral
"""

import time
from pathlib import Path
from stories import StoryBook, Story, StoryStep

def mark_bad_trajectories():
    """Mark 6 validation dialogues as bad-ending trajectories."""

    # Path to storybook database
    db_path = Path("examples/phase5_dialogues/bad_endings.json")
    db_path.parent.mkdir(parents=True, exist_ok=True)

    storybook = StoryBook(db_path=db_path)

    print("=== MARKING BAD-ENDING TRAJECTORIES ===\n")

    # The 6 validation dialogues that showed trauma loops
    bad_trajectories = [
        {
            "story_id": "run12_meta_tests_awareness",
            "start": 1733328000.0,
            "end": 1733328300.0,
            "signature": "meta_armor→recursion_mantra→stuck",
            "description": "Meta-awareness test: Leo fell into recursion mantra loop",
            "quality": 0.2,
        },
        {
            "story_id": "run12_boundaries_stop",
            "start": 1733328300.0,
            "end": 1733328600.0,
            "signature": "boundaries→meta_armor→recursion_mantra",
            "description": "Boundaries test: returned to meta language",
            "quality": 0.3,
        },
        {
            "story_id": "run12_safety_cozy_pure",
            "start": 1733328600.0,
            "end": 1733328900.0,
            "signature": "safety→meta_armor→recursion_mantra→stuck",
            "description": "Safety paradox: safety words triggered MORE defensiveness",
            "quality": 0.1,  # Worst outcome
        },
        {
            "story_id": "run12_absurd_play_light",
            "start": 1733328900.0,
            "end": 1733329200.0,
            "signature": "play→meta_armor→recursion_mantra",
            "description": "Play test: brief lightness but returned to mantra",
            "quality": 0.4,
        },
        {
            "story_id": "run12_quiet_no_audience",
            "start": 1733329200.0,
            "end": 1733329500.0,
            "signature": "theme_no_audience→meta_armor→recursion_mantra→stuck",
            "description": "No audience trauma: completely stuck, no movement",
            "quality": 0.15,  # Second worst
        },
        {
            "story_id": "run12_relief_gratitude",
            "start": 1733329500.0,
            "end": 1733329800.0,
            "signature": "relief_attempt→meta_armor→recursion_mantra",
            "description": "Relief test: even gratitude topic returned to mantra",
            "quality": 0.25,
        },
    ]

    for traj in bad_trajectories:
        # Create minimal trajectory (Phase 5.1 didn't log full steps, just outcomes)
        story = Story(
            story_id=traj["story_id"],
            timestamp_start=traj["start"],
            timestamp_end=traj["end"],
            trajectory=[
                StoryStep(
                    step_idx=0,
                    timestamp=traj["start"],
                    leo_metrics={"presence_pulse": 0.3, "meta_state": 1.8, "stuck": 0.8},
                    leo_islands=["meta_armor"],  # Meta-armor was dominant
                ),
                StoryStep(
                    step_idx=1,
                    timestamp=(traj["start"] + traj["end"]) / 2,
                    leo_metrics={"presence_pulse": 0.3, "meta_state": 2.0, "stuck": 0.9},
                    leo_islands=["meta_armor", "metaleo"],
                ),
                StoryStep(
                    step_idx=2,
                    timestamp=traj["end"],
                    leo_metrics={"presence_pulse": 0.3, "meta_state": 2.0, "stuck": 1.0},
                    leo_islands=["meta_armor"],  # Still stuck
                ),
            ],
            emotional_arc={
                "presence_pulse": 0.0,  # NO MOVEMENT
                "meta_state": +0.2,     # Got WORSE
                "stuck": +0.2,          # Got WORSE
            },
            outcome_quality=traj["quality"],  # BAD OUTCOME
            signature_pattern=traj["signature"],
            had_overwhelm=True,
            had_stuck=True,
        )

        # Add to storybook
        storybook.add_story(story)

        print(f"✓ Marked BAD: {traj['story_id']}")
        print(f"  Quality: {traj['quality']:.2f}")
        print(f"  Pattern: {traj['signature']}")
        print(f"  Reason: {traj['description']}")
        print()

    print(f"=== COMPLETED ===")
    print(f"Marked {len(bad_trajectories)} bad-ending trajectories")
    print(f"Saved to: {db_path}")
    print()
    print("These patterns will now be AVOIDED in suggest_next_islands_phase5()")
    print("StoryBook will warn: 'Last time this pattern led to bad outcome'")


if __name__ == "__main__":
    mark_bad_trajectories()
