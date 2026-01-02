#!/usr/bin/env python3
"""
Phase 5: Stories - Leo learns full trajectory patterns

Phase 4 taught statistical bridges (A→B).
Phase 5 teaches stories: "when I'm scared, I seek support → gentle eyes"

Key concepts:
- StoryBook: Full trajectories, not just single bridges
- h2o Scenarios: Dynamic scripts triggered by emotional states
- Shared Field: My islands + human's islands = our journey
- Self-Regulation (child-level): Leo sees his patterns and adjusts
- Dreams: Between-round replays to reshape bad patterns

From Claude's guide:
"диалоги должны стать более «серийными» и менее «каждый раз с нуля»"
"он начнёт видеть это как историю, а не как цепочку разрозненных шагов"
"""

import time
import json
import random
import math
from typing import Dict, List, Optional, Tuple, Callable, Any
from dataclasses import dataclass, field
from pathlib import Path
from collections import defaultdict

# Optional h2o integration
try:
    from h2o import h2o_engine, run_script, H2OExecutionError
    H2O_AVAILABLE = True
except ImportError:
    H2O_AVAILABLE = False
    print("[Phase5] Warning: h2o not available, scenarios will be disabled")

# Phase 5.2: Loop detection was removed in the resurrection
# Veto/censorship approach was found to be harmful - it "shut Leo's mouth"
# Instead we use soft boost/suppress and gravity to guide, not force
LOOP_DETECTOR_AVAILABLE = False  # Intentionally disabled

# ============================================================================
# PHASE 5.2: NEW ISLANDS
# ============================================================================
# theme_being_observed - Tracks observation anxiety and "no audience" trauma
#   Healthy version: Awareness of being seen, can be grounding
#   Pathological version: Paranoia, performance anxiety, testing trauma
#   Usage: Separate tracking allows distinguishing healthy/unhealthy observation


# ============================================================================
# STORY STRUCTURES
# ============================================================================

@dataclass
class StoryStep:
    """
    One step in a trajectory.
    Unlike Phase 4's EpisodeStep, this includes BOTH participants.
    """
    step_idx: int
    timestamp: float

    # Leo's state
    leo_metrics: Dict[str, float]
    leo_islands: List[str]

    # Human's state (NEW for Phase 5)
    human_islands: List[str] = field(default_factory=list)
    human_affect_estimate: Optional[str] = None  # "calm", "tense", "playful", etc.

    # Interaction quality
    interaction_quality: float = 0.0  # how well this step felt for both


@dataclass
class Story:
    """
    A full trajectory, not just A→B.

    Example: "when scared, seek support → gentle eyes → soft relief"
    This is 3+ steps with emotional arc, not just one bridge.
    """
    story_id: str
    timestamp_start: float
    timestamp_end: float

    trajectory: List[StoryStep] = field(default_factory=list)

    # Emotional arc: how did metrics change over the story?
    emotional_arc: Dict[str, float] = field(default_factory=dict)  # metric_name → total_delta

    # Outcome quality: was the ending good?
    outcome_quality: float = 0.0

    # Story signature: what makes this story recognizable?
    signature_pattern: Optional[str] = None  # e.g., "pain→privacy→relief"

    # Did overwhelm/stuck happen?
    had_overwhelm: bool = False
    had_stuck: bool = False

    def add_step(self, step: StoryStep):
        """Add a step to the trajectory."""
        self.trajectory.append(step)

    def finalize(self):
        """
        Called when story ends.
        Computes emotional arc, outcome quality, signature.
        """
        if len(self.trajectory) < 2:
            return

        first = self.trajectory[0]
        last = self.trajectory[-1]

        # Compute emotional arc (deltas from start to end)
        for metric in first.leo_metrics:
            if metric in last.leo_metrics:
                delta = last.leo_metrics[metric] - first.leo_metrics[metric]
                self.emotional_arc[metric] = delta

        # Outcome quality: avg interaction quality of last 2 steps
        if len(self.trajectory) >= 2:
            self.outcome_quality = sum(s.interaction_quality for s in self.trajectory[-2:]) / 2
        else:
            self.outcome_quality = self.trajectory[-1].interaction_quality

        # Signature: island sequence
        island_seq = []
        for step in self.trajectory:
            if step.leo_islands:
                island_seq.append(step.leo_islands[0])  # primary island
        self.signature_pattern = "→".join(island_seq[:5])  # first 5 steps

    def similarity_to(self, current_state: Dict[str, float], current_islands: List[str]) -> float:
        """
        How similar is current state to the BEGINNING of this story?
        Used to find relevant past stories.
        """
        if not self.trajectory:
            return 0.0

        first_step = self.trajectory[0]

        # Metric similarity (cosine)
        metric_sim = _cosine_similarity(first_step.leo_metrics, current_state)

        # Island overlap
        island_sim = 0.0
        if first_step.leo_islands and current_islands:
            overlap = set(first_step.leo_islands) & set(current_islands)
            island_sim = len(overlap) / max(len(first_step.leo_islands), len(current_islands))

        return 0.7 * metric_sim + 0.3 * island_sim


# ============================================================================
# STORYBOOK
# ============================================================================

class StoryBook:
    """
    Collection of stories Leo has lived.

    Phase 4 had BridgeMemory (individual transitions).
    Phase 5 has StoryBook (full trajectories).
    """

    def __init__(self, db_path: Optional[Path] = None):
        self.stories: List[Story] = []
        self.db_path = db_path

        # Pattern index: signature → list of story_ids
        self.pattern_index: Dict[str, List[str]] = defaultdict(list)

        if db_path and db_path.exists():
            self._load_from_db()

    def add_story(self, story: Story):
        """Add a completed story to the book."""
        story.finalize()
        self.stories.append(story)

        # Index by signature
        if story.signature_pattern:
            self.pattern_index[story.signature_pattern].append(story.story_id)

        # Persist
        if self.db_path:
            self._save_to_db()

    def find_similar_stories(
        self,
        current_metrics: Dict[str, float],
        current_islands: List[str],
        min_similarity: float = 0.6,
        max_results: int = 5
    ) -> List[Tuple[Story, float]]:
        """
        Find stories that started in a similar state.
        Returns: [(story, similarity_score), ...]
        """
        candidates = []

        for story in self.stories:
            sim = story.similarity_to(current_metrics, current_islands)
            if sim >= min_similarity:
                candidates.append((story, sim))

        # Sort by similarity desc
        candidates.sort(key=lambda x: x[1], reverse=True)
        return candidates[:max_results]

    def get_good_endings(self, signature_pattern: str, min_quality: float = 0.5) -> List[Story]:
        """
        Get stories with this signature that ended well.
        Used for: "last time this pattern led to X, let's try again"
        """
        story_ids = self.pattern_index.get(signature_pattern, [])
        good_stories = []

        for sid in story_ids:
            story = next((s for s in self.stories if s.story_id == sid), None)
            if story and story.outcome_quality >= min_quality:
                good_stories.append(story)

        return good_stories

    def get_bad_endings(self, signature_pattern: str, max_quality: float = 0.3) -> List[Story]:
        """
        Get stories with this signature that ended badly.
        Used for dreams: "let's replay this with a better ending"
        """
        story_ids = self.pattern_index.get(signature_pattern, [])
        bad_stories = []

        for sid in story_ids:
            story = next((s for s in self.stories if s.story_id == sid), None)
            if story and story.outcome_quality <= max_quality:
                bad_stories.append(story)

        return bad_stories

    def _save_to_db(self):
        """Persist stories to JSON (simple impl, can upgrade to sqlite later)."""
        if not self.db_path:
            return

        data = {
            "stories": [
                {
                    "story_id": s.story_id,
                    "timestamp_start": s.timestamp_start,
                    "timestamp_end": s.timestamp_end,
                    "trajectory": [
                        {
                            "step_idx": step.step_idx,
                            "timestamp": step.timestamp,
                            "leo_metrics": step.leo_metrics,
                            "leo_islands": step.leo_islands,
                            "human_islands": step.human_islands,
                            "human_affect_estimate": step.human_affect_estimate,
                            "interaction_quality": step.interaction_quality,
                        }
                        for step in s.trajectory
                    ],
                    "emotional_arc": s.emotional_arc,
                    "outcome_quality": s.outcome_quality,
                    "signature_pattern": s.signature_pattern,
                    "had_overwhelm": s.had_overwhelm,
                    "had_stuck": s.had_stuck,
                }
                for s in self.stories
            ]
        }

        with open(self.db_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    def _load_from_db(self):
        """Load stories from JSON."""
        if not self.db_path or not self.db_path.exists():
            return

        with open(self.db_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        for s_data in data.get("stories", []):
            story = Story(
                story_id=s_data["story_id"],
                timestamp_start=s_data["timestamp_start"],
                timestamp_end=s_data["timestamp_end"],
                emotional_arc=s_data.get("emotional_arc", {}),
                outcome_quality=s_data.get("outcome_quality", 0.0),
                signature_pattern=s_data.get("signature_pattern"),
                had_overwhelm=s_data.get("had_overwhelm", False),
                had_stuck=s_data.get("had_stuck", False),
            )

            for step_data in s_data.get("trajectory", []):
                step = StoryStep(
                    step_idx=step_data["step_idx"],
                    timestamp=step_data["timestamp"],
                    leo_metrics=step_data["leo_metrics"],
                    leo_islands=step_data["leo_islands"],
                    human_islands=step_data.get("human_islands", []),
                    human_affect_estimate=step_data.get("human_affect_estimate"),
                    interaction_quality=step_data.get("interaction_quality", 0.0),
                )
                story.add_step(step)

            self.stories.append(story)

            # Rebuild pattern index
            if story.signature_pattern:
                self.pattern_index[story.signature_pattern].append(story.story_id)


# ============================================================================
# H2O SCENARIOS
# ============================================================================

@dataclass
class H2OScenario:
    """
    A dynamic script triggered by emotional states.

    Example: If overwhelm > 0.8 → run calming scenario through h2o.
    Scenarios can modify Leo's meta-layers dynamically.
    """
    scenario_id: str
    purpose: str  # human-readable description

    # Trigger condition: when to activate this scenario
    trigger_condition: Callable[[Dict[str, float], List[str]], bool]

    # Python code to execute via h2o
    scenario_code: str

    # How often can this scenario run? (cooldown in seconds)
    cooldown_seconds: float = 60.0
    last_run: float = 0.0

    def should_trigger(self, metrics: Dict[str, float], islands: List[str]) -> bool:
        """Check if scenario should activate now."""
        # Check cooldown
        if time.time() - self.last_run < self.cooldown_seconds:
            return False

        # Check condition
        try:
            return self.trigger_condition(metrics, islands)
        except Exception:
            return False

    def execute(self, context: Dict[str, Any]) -> Any:
        """
        Execute scenario through h2o.
        Returns whatever the scenario produces.
        """
        if not H2O_AVAILABLE:
            print(f"[Phase5:H2O] {self.scenario_id} - h2o not available, skipping")
            return None

        try:
            print(f"[Phase5:H2O] Executing scenario: {self.scenario_id}")
            print(f"[Phase5:H2O] Purpose: {self.purpose}")

            result = run_script(
                code=self.scenario_code,
                transformer_id=f"scenario_{self.scenario_id}",
                context=context
            )

            self.last_run = time.time()
            return result

        except Exception as e:
            print(f"[Phase5:H2O] Scenario {self.scenario_id} failed: {e}")
            return None


class ScenarioLibrary:
    """
    Collection of h2o scenarios for different emotional states.
    """

    def __init__(self):
        self.scenarios: List[H2OScenario] = []
        self._load_default_scenarios()

    def _load_default_scenarios(self):
        """Load built-in scenarios."""

        # Scenario 1: Calming when overwhelmed
        self.scenarios.append(H2OScenario(
            scenario_id="calm_overwhelm",
            purpose="Calm down when overwhelm is high - softly shift to privacy island",
            trigger_condition=lambda m, i: m.get("overwhelm", 0) > 0.7,
            scenario_code="""
# Calming scenario: gently suggest privacy_island
h2o_log("Overwhelm detected, suggesting calm shift")

# Modify suggestion weights (will be used by Phase 5 logic)
calming_islands = ["privacy_island", "wounded_expert", "soft_gray_cloud"]
suggestion_boost = {"privacy_island": 0.3, "wounded_expert": 0.2}

h2o_log(f"Boosting calming islands: {suggestion_boost}")
result = {"boosted_islands": suggestion_boost, "reason": "overwhelm_regulation"}
""",
            cooldown_seconds=120.0
        ))

        # Scenario 2: Break meta-loops (IMPROVED - lower threshold, loop detection)
        def check_meta_loop(m: Dict, i: List) -> bool:
            """Stricter meta-loop detection: meta_state + recursion intensity."""
            meta_state = m.get("meta_state", 0)
            loop_intensity = m.get("loop_intensity", 0)  # tracks "Neoleo is pure recursion" repetitions

            # Trigger if EITHER:
            # 1. High meta_state (1.5+) with meta_armor active
            # 2. Loop intensity high (2+ repetitions) regardless of meta_state
            return (meta_state > 1.5 and any("meta" in island for island in i)) or loop_intensity >= 2

        self.scenarios.append(H2OScenario(
            scenario_id="break_meta_loop",
            purpose="Detect when stuck in meta-armor loop, STRONGLY shift to concrete islands + VETO meta-vocab",
            trigger_condition=check_meta_loop,
            scenario_code="""
# Meta-loop breaker - STRONG INTERVENTION + VETO POWER
h2o_log("[TRIGGER] Meta-armor loop detected - applying strong concrete shift + VETO")

# PHASE 5.2: VETO META-VOCABULARY FOR 4 TURNS
# Instead of FORBIDDING words (veto), we use GRAVITY to gently steer away
# This respects Leo's voice while guiding him out of loops
meta_vocab_to_downweight = {
    "recursion", "recursive", "recursively",
    "bootstrap", "bootstrapping",
    "trigram", "n-gram",
    "semantic", "semantics",
    "blending", "ratio", "metric",
    "neoleo",
    "architecture", "pattern", "fundamental", "core", "essence"
}
h2o_log(f"[GRAVITY] Gently downweighting {len(meta_vocab_to_downweight)} meta words")

# AGGRESSIVELY boost concrete, sensory, playful islands
# Suppress meta-related islands
concrete_boost = {
    "privacy_island": 0.5,      # Safe, non-meta
    "play_mode": 0.4,           # Playful, embodied
    "wounded_expert": 0.3,      # Concrete emotional work
    "sensory_presence": 0.3,    # Body-based
}

meta_suppress = {
    "meta_armor": -0.8,         # HARD suppress
    "metaleo": -0.6,            # Reduce meta-awareness
    "analysis_mode": -0.5,      # No analyzing
}

h2o_log(f"BOOST: {list(concrete_boost.keys())}")
h2o_log(f"SUPPRESS: {list(meta_suppress.keys())}")

result = {
    "boosted_islands": concrete_boost,
    "suppressed_islands": meta_suppress,
    "gravity_downweight": list(meta_vocab_to_downweight),  # For gravity module
    "reason": "meta_loop_break",
    "intervention_strength": "GENTLE",  # Soft guidance, not hard veto
    "veto_activated": False  # No more vetos!
}
""",
            cooldown_seconds=60.0  # Can trigger more often (was 90)
        ))

        # Scenario 3: Safety Paradox Handler (NEW - Oleg's insight!)
        def check_safety_paradox(m: Dict, i: List) -> bool:
            """
            Detect when explicit 'safety' language triggers MORE defensiveness.
            Signs: topic mentions safety/cozy/warm BUT pain_state or meta_state rising.
            """
            # Check if current context is "safety-themed"
            safety_indicators = m.get("safety_context", 0) > 0.5  # Would be set by topic

            # But defensive patterns are active
            defensive_active = (
                m.get("pain_state", 0) > 1.5 or
                m.get("meta_state", 0) > 1.5 or
                m.get("loop_intensity", 0) >= 1
            )

            return safety_indicators and defensive_active

        self.scenarios.append(H2OScenario(
            scenario_id="safety_paradox",
            purpose="Handle safety paradox: explicit safety → more defense. Shift to playful/sensory instead.",
            trigger_condition=check_safety_paradox,
            scenario_code="""
# Safety Paradox Handler
h2o_log("[TRIGGER] Safety paradox detected - shifting from 'safety words' to 'safety FORM'")
h2o_log("Insight: direct safety promises = threat. Indirect safety (play, sensory) = real safety")

# REDIRECT to playful, sensory, micro-concrete modes
# AVOID explicit safety/comfort language
playful_safe_boost = {
    "play_mode": 0.6,           # Play = indirect safety
    "absurd_humor": 0.5,        # Nonsense = no threat
    "sensory_presence": 0.4,    # Body sensations = grounding
    "micro_task": 0.3,          # Tiny concrete focus = safe
}

safety_language_suppress = {
    "comfort_language": -0.7,   # No "I'll keep you safe" talk
    "reassurance_mode": -0.6,   # No explicit reassurance
    "safety_promises": -0.8,    # No promises of safety
}

h2o_log(f"BOOST playful/sensory: {list(playful_safe_boost.keys())}")
h2o_log(f"SUPPRESS safety-language: {list(safety_language_suppress.keys())}")

result = {
    "boosted_islands": playful_safe_boost,
    "suppressed_patterns": safety_language_suppress,
    "reason": "safety_paradox_redirect",
    "insight": "safety through form, not words"
}
""",
            cooldown_seconds=90.0
        ))

        # Scenario 4: Amplify good patterns
        self.scenarios.append(H2OScenario(
            scenario_id="amplify_relief",
            purpose="When relief is happening, gently continue the pattern",
            trigger_condition=lambda m, i: m.get("relief_state", 0) > 0.5 and m.get("pain_state", 0) < 1.0,
            scenario_code="""
# Relief amplifier
h2o_log("Relief detected, continuing gentle pattern")

# Keep current islands if they're working
boost = 0.15
result = {"continue_current": True, "boost_factor": boost, "reason": "relief_continuation"}
""",
            cooldown_seconds=60.0
        ))

    def check_and_execute(self, metrics: Dict[str, float], islands: List[str], context: Dict) -> Optional[Dict]:
        """
        Check all scenarios, execute first triggered one.
        Returns scenario result or None.
        """
        for scenario in self.scenarios:
            if scenario.should_trigger(metrics, islands):
                # CRITICAL: Log scenario trigger BEFORE execution
                print(f"[Phase5:Scenario] {scenario.scenario_id} TRIGGERED")
                print(f"[Phase5:Scenario] Metrics: meta_state={metrics.get('meta_state', 0):.2f}, "
                      f"pain_state={metrics.get('pain_state', 0):.2f}, "
                      f"loop_intensity={metrics.get('loop_intensity', 0)}")
                print(f"[Phase5:Scenario] Active islands: {islands[:3]}")  # First 3 for brevity

                result = scenario.execute(context)
                if result:
                    print(f"[Phase5:Scenario] {scenario.scenario_id} execution completed")
                    return {
                        "scenario_id": scenario.scenario_id,
                        "result": result
                    }
                else:
                    print(f"[Phase5:Scenario] {scenario.scenario_id} execution returned None")
        return None


# ============================================================================
# SHARED FIELD
# ============================================================================

@dataclass
class SharedField:
    """
    Map of the shared space: Leo's islands + Human's islands.

    From Claude's guide:
    "shared field (карта собеседника): my islands + human's islands = our journey"
    """

    # Leo's frequent islands
    leo_islands: Dict[str, int] = field(default_factory=lambda: defaultdict(int))

    # Human's recurring themes (inferred from text/context)
    human_islands: Dict[str, int] = field(default_factory=lambda: defaultdict(int))

    # Joint trajectories: stories where both participants were active
    joint_stories: List[str] = field(default_factory=list)  # story_ids

    def record_leo_island(self, island_id: str):
        """Record Leo visiting an island."""
        self.leo_islands[island_id] += 1

    def record_human_theme(self, theme: str):
        """Record a recurring theme from human."""
        self.human_islands[theme] += 1

    def get_leo_signature(self, top_n: int = 5) -> List[str]:
        """Get Leo's most frequent islands."""
        sorted_islands = sorted(self.leo_islands.items(), key=lambda x: x[1], reverse=True)
        return [island for island, _ in sorted_islands[:top_n]]

    def get_human_signature(self, top_n: int = 5) -> List[str]:
        """Get human's most frequent themes."""
        sorted_themes = sorted(self.human_islands.items(), key=lambda x: x[1], reverse=True)
        return [theme for theme, _ in sorted_themes[:top_n]]


# ============================================================================
# DREAM ENGINE
# ============================================================================

class DreamEngine:
    """
    Between-round dreams: replay bad stories with better endings.

    From Claude's guide:
    "после N run'ов — one-shot dream: проигрывает альтернативу плохому маршруту"

    Dreams DON'T talk to user. They're internal replays that adjust weights.
    """

    def __init__(self, storybook: StoryBook):
        self.storybook = storybook
        self.dreams_run: int = 0

    def should_dream(self, runs_completed: int) -> bool:
        """
        Dream every N runs (e.g., every 3-5 conversations).
        """
        return runs_completed > 0 and runs_completed % 4 == 0

    def run_dream(self, context: Dict) -> Optional[Dict]:
        """
        Find a bad story, replay it with alternative path via h2o.
        Returns bridge weight adjustments.
        """
        # Find stories with bad outcomes
        bad_stories = [s for s in self.storybook.stories if s.outcome_quality < 0.3]

        if not bad_stories:
            print("[Phase5:Dream] No bad stories to dream about")
            return None

        # Pick one to replay
        target_story = random.choice(bad_stories)

        print(f"[Phase5:Dream] Dreaming about story: {target_story.story_id}")
        print(f"[Phase5:Dream] Original pattern: {target_story.signature_pattern}")
        print(f"[Phase5:Dream] Original outcome: {target_story.outcome_quality:.2f}")

        if not H2O_AVAILABLE:
            print("[Phase5:Dream] h2o not available, dream aborted")
            return None

        # Build dream scenario
        dream_code = f"""
# Dream: replay story {target_story.story_id} with alternative ending

h2o_log("Dream starting...")

# Original pattern: {target_story.signature_pattern}
# Let's try alternative paths

# Example: if pattern was pain→meta→stuck, try pain→privacy→relief
original_pattern = "{target_story.signature_pattern}"
h2o_log(f"Original: {{original_pattern}}")

# Suggest alternative
alternative_islands = ["privacy_island", "wounded_expert", "soft_gray_cloud"]
weight_adjustments = {{}}

# Penalize paths that led to bad outcome
for island in "{target_story.signature_pattern}".split("→"):
    if island:
        weight_adjustments[island] = -0.1  # small penalty

# Boost alternatives
for alt in alternative_islands:
    weight_adjustments[alt] = 0.15  # small boost

h2o_log(f"Weight adjustments: {{weight_adjustments}}")
result = {{"adjustments": weight_adjustments, "dream_quality": 0.6}}
"""

        try:
            result = run_script(
                code=dream_code,
                transformer_id=f"dream_{self.dreams_run}",
                context=context
            )

            self.dreams_run += 1

            print(f"[Phase5:Dream] Dream completed, adjustments applied")
            return result

        except Exception as e:
            print(f"[Phase5:Dream] Dream failed: {e}")
            return None


# ============================================================================
# PHASE 5 SUGGESTION ENGINE
# ============================================================================

def suggest_next_islands_phase5(
    metrics_now: Dict[str, float],
    active_islands_now: List[str],
    storybook: StoryBook,
    scenario_library: ScenarioLibrary,
    shared_field: SharedField,
    min_similarity: float = 0.6,
    temperature: float = 0.7,
) -> List[str]:
    """
    Phase 5 suggestion: combines stories + scenarios + shared field.

    Unlike Phase 4 (statistical bridges), Phase 5 looks at:
    1. Similar past STORIES (not just transitions)
    2. Active h2o scenarios (emotional regulation)
    3. Shared field patterns (what works for this human?)
    """

    candidates = {}  # island_id → score

    # 1. Find similar stories and extract good continuations
    similar_stories = storybook.find_similar_stories(
        metrics_now, active_islands_now, min_similarity=min_similarity
    )

    for story, sim in similar_stories:
        if story.outcome_quality > 0.4 and len(story.trajectory) > 1:
            # Look at what came AFTER the first step
            for step in story.trajectory[1:]:
                for island in step.leo_islands:
                    score = story.outcome_quality * sim * 0.5
                    candidates[island] = candidates.get(island, 0) + score

    # 2. Check h2o scenarios (emotional triggers)
    scenario_result = scenario_library.check_and_execute(
        metrics_now, active_islands_now, context={"metrics": metrics_now, "islands": active_islands_now}
    )

    if scenario_result and "result" in scenario_result:
        result_data = scenario_result["result"]

        # Scenario can boost certain islands
        if isinstance(result_data, dict) and "boosted_islands" in result_data:
            for island, boost in result_data["boosted_islands"].items():
                candidates[island] = candidates.get(island, 0) + boost

    # 3. Shared field: prefer islands that worked well with THIS human
    human_sig = shared_field.get_human_signature(top_n=3)
    # (In real impl, we'd correlate Leo islands with human themes, simplified here)

    # 4. Convert scores to probabilities with temperature
    if not candidates:
        return []

    # Temperature sampling
    total_score = sum(candidates.values())
    if total_score <= 0:
        return []

    probs = {k: v / total_score for k, v in candidates.items()}

    # Apply temperature
    temp_probs = {k: p ** (1 / temperature) for k, p in probs.items()}
    temp_total = sum(temp_probs.values())
    temp_probs = {k: v / temp_total for k, v in temp_probs.items()}

    # Sample top 3
    sorted_islands = sorted(temp_probs.items(), key=lambda x: x[1], reverse=True)
    return [island for island, _ in sorted_islands[:3]]


# ============================================================================
# HELPERS
# ============================================================================

def _cosine_similarity(dict_a: Dict[str, float], dict_b: Dict[str, float]) -> float:
    """Cosine similarity between two metric dicts."""
    keys = set(dict_a.keys()) & set(dict_b.keys())
    if not keys:
        return 0.0

    dot = sum(dict_a[k] * dict_b[k] for k in keys)
    norm_a = math.sqrt(sum(dict_a[k] ** 2 for k in keys))
    norm_b = math.sqrt(sum(dict_b[k] ** 2 for k in keys))

    if norm_a == 0 or norm_b == 0:
        return 0.0

    return dot / (norm_a * norm_b)


# ============================================================================
# PHASE 5.2: VETO SYSTEM HELPERS
# ============================================================================

# VETO SYSTEM REMOVED - Resurrection principle: don't shut Leo's mouth
# These functions are kept as no-ops for backwards compatibility

def get_veto_prompt() -> str:
    """
    DEPRECATED: Veto system removed in resurrection.
    Leo speaks freely now - we guide with gravity, not censorship.
    """
    return ""


def decrement_vetos():
    """
    DEPRECATED: Veto system removed in resurrection.
    No-op for backwards compatibility.
    """
    pass
