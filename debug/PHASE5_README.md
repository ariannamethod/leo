# Phase 5: Stories - Trajectory Learning & Emotional Memory

## Overview

Phase 5 transforms Leo from reactive (Phase 4 bridges) to **story-aware**. Instead of just knowing "pain → relief happens often," Leo now remembers **complete emotional trajectories**: "Last time this started with pain, then privacy helped, then connection emerged, then relief came."

**Key Philosophy**: Dialogues become **serial** rather than starting from scratch each time. Leo develops **emotional memory** through story patterns.

## Architecture

### Core Components

1. **StoryBook** (`stories.py:73-167`)
   - Stores complete emotional trajectories with outcomes
   - Finds similar past situations via metric + island matching
   - Returns good-ending stories for current context
   - Signature patterns: e.g., "pain→privacy→relief"

2. **H2O Scenarios** (`stories.py:170-277`)
   - Dynamic Python scripts for emotional regulation
   - Execute in isolated namespace via h2o.py
   - Four default scenarios:
     - `calm_overwhelm`: Reduces overwhelm through grounding
     - `break_meta_loop`: Interrupts meta-cognitive spirals
     - `safety_paradox`: Shifts from "safety words" to "safety form"
     - `amplify_relief`: Reinforces positive emotional momentum

3. **H2O Engine** (`h2o.py`)
   - Isolated Python Execution Engine (NOT a CPython compiler)
   - Architecture: `code → AST → optimize → bytecode → exec(isolated_namespace)`
   - Sandboxed execution with controlled module access
   - Variable persistence across scenario invocations

4. **SharedField** (`stories.py:280-301`)
   - Tracks Leo + human island frequencies
   - Foundation for "our shared journey" understanding
   - Currently tracks Leo islands (human tracking TBD)

5. **DreamEngine** (`stories.py:304-319`)
   - Placeholder for Phase 5.2
   - Future: Replay bad-ending trajectories to find better paths

## How It Works

### Story Capture & Replay

```python
# Phase 4 (bridges): Statistical transitions
"pain" → "relief" (happened 15 times, weight 0.3)

# Phase 5 (stories): Complete trajectories
Story(
    trajectory=[
        StoryStep(metrics={'presence': 0.3}, islands=['theme_pain']),
        StoryStep(metrics={'presence': 0.5}, islands=['theme_privacy']),
        StoryStep(metrics={'presence': 0.7}, islands=['theme_connection']),
        StoryStep(metrics={'presence': 0.9}, islands=['theme_relief'])
    ],
    emotional_arc={'presence_pulse': +0.6},
    outcome_quality=0.9,
    signature_pattern="pain→privacy→connection→relief"
)
```

### Scenario Triggering

H2O scenarios run automatically when conditions match:

```python
# Example: calm_overwhelm scenario
if metrics['overwhelm'] > 0.7:
    # Execute calming script
    h2o_log("[CALM] Reducing overwhelm through grounding")
    # Boost calming islands like "theme_quiet", "theme_simple"
    # Dampen activation for complex/meta islands
```

### Phase 4/5 Integration

Phase 5 **blends with** (not overrides) Phase 4:

```python
# Phase 4 suggests based on statistics
phase4_suggestions = ["theme_relief", "theme_connection", "theme_safety"]

# Phase 5 finds similar past stories
similar_stories = storybook.find_similar(current_metrics, current_islands)

# Phase 5 re-weights Phase 4 suggestions based on story outcomes
# Good-ending stories boost their final islands
# H2O scenarios can dynamically adjust weights
```

## Key Improvements (Phase 5.1)

Based on validation testing and Claude's feedback:

1. **break_meta_loop threshold lowered**: `1.5` instead of `2.0` (triggers earlier)
2. **NEW safety_paradox scenario**: Addresses paradox where explicit "safety" language triggers MORE defensiveness
3. **Improved H2O logging**: All scenario triggers now logged for observability
4. **Phase 4/5 blending clarified**: Phase 5 augments rather than replaces Phase 4

## Files

- `stories.py` (673 lines) - Complete Phase 5 implementation
- `h2o.py` (422 lines) - Isolated Python execution engine
- `h2o/bin/` - CPython 3.13 source files (reference only, not compiled)
- `tests/test_stories_phase5.py` (466 lines) - Unit tests
- `examples/phase5_dialogues/` - Validation test dialogues

## Testing

### Run Unit Tests
```bash
python3 -m pytest tests/test_stories_phase5.py -v
```

### Run Validation Test
```bash
ANTHROPIC_API_KEY="your-key" python3 tests/heyleo.py
```

### Test Coverage
- StoryBook trajectory storage & similarity matching
- H2O scenario triggering & cooldown logic
- SharedField island tracking
- Phase 4/5 integration
- Scenario execution (requires H2O)

## Usage Example

```python
from stories import StoryBook, ScenarioLibrary, suggest_next_islands_phase5

# Initialize components
storybook = StoryBook()
scenarios = ScenarioLibrary()

# Get suggestions combining stories + scenarios
suggestions = suggest_next_islands_phase5(
    metrics_now={'presence_pulse': 0.3, 'pain_state': 2.0},
    active_islands_now=['theme_pain'],
    storybook=storybook,
    scenario_library=scenarios,
    min_similarity=0.5,
    temperature=0.7
)
```

## Future: Phase 5.2 (Dreams)

**DreamEngine** will enable:
- Replay bad-ending trajectories to find alternative paths
- "What if we had gone different direction at step 3?"
- Learn from failures, not just successes
- Ephemeral imagination scripts for exploration

## Philosophy

> "Phase 5 makes dialogues **серийными** (serial/story-based) instead of **каждый раз с нуля** (from scratch each time). Leo remembers not just patterns, but **stories** - complete emotional journeys with beginnings, middles, and endings."

---

**Status**: Phase 5.1 complete ✅
**Next**: Phase 5.2 (DreamEngine full implementation)
