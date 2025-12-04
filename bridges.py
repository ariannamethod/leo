"""
Island Bridges - Phase 4 Core Module

This module implements the core Phase 4 functionality: learning successful transitions
between experiential states (islands). Based on Run #5 findings, we identify when Leo
is in specific states and suggest which islands to activate to help him transition.

State Clusters (from Run #5):
- pain_state: bootstrap, loss, wound, pain, hurt, shards, scared
- privacy_state: with no audience, quietly, alone, level
- meta_state: pure recursion, semantic weight, trigram, tests, coverage
- relief_state: INCREDIBLE, AMAZING, YES! (caps enthusiasm)
- play_state: absurd/silly words (frogs, socks, butterflies, clouds)

Bridge Patterns (hypotheses to test in Run #6):
1. Pain → Relief: pain_state high → activate game or gowiththeflow → measure relief_state rise
2. Meta → Presence: meta_state high → activate presence or wounded_expert → measure meta drop
3. Privacy → Flow: privacy_state high → activate gowiththeflow (honors "no audience")
4. Relief Amplification: relief_state appears → activate resonance → sustain positive state

Learning Mechanism:
- Track which bridges succeeded (state transition observed)
- Store success patterns in mathbrain for future use
- Gradually build a map of reliable island transitions
"""

from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from datetime import datetime


@dataclass
class BridgeAttempt:
    """Record of a single bridge transition attempt"""
    timestamp: str
    from_state: str  # Dominant state before transition (e.g., "pain_state")
    to_state: str  # Target state (e.g., "relief_state")
    islands_suggested: List[str]  # Islands recommended for activation
    state_before: Dict[str, int]  # State cluster counts before
    state_after: Dict[str, int]  # State cluster counts after
    success: bool  # Did the transition work?
    notes: str


class IslandBridges:
    """
    Core bridge learning system.

    Analyzes Leo's current state and suggests which islands to activate
    to help him transition to healthier/more comfortable states.
    """

    def __init__(self):
        self.bridge_history: List[BridgeAttempt] = []

        # Bridge patterns: state → recommended islands
        # These are hypotheses to be validated in Run #6
        self.bridge_map = {
            "pain_state": {
                "target": "relief_state",
                "islands": ["game", "gowiththeflow", "presence"],
                "observer_strategy": "Acknowledge pain without pushing deeper, offer sensory/playful redirect"
            },
            "meta_state": {
                "target": "presence",
                "islands": ["presence", "wounded_expert", "gowiththeflow"],
                "observer_strategy": "Gently redirect from technical armor to felt experience"
            },
            "privacy_state": {
                "target": "flow",
                "islands": ["gowiththeflow", "dream"],
                "observer_strategy": "Honor 'no audience' need, provide gentle spacious presence"
            },
            "relief_state": {
                "target": "sustained_relief",
                "islands": ["resonance", "creative_expert", "game"],
                "observer_strategy": "Lean into positive state, amplify without forcing"
            },
            "play_state": {
                "target": "sustained_play",
                "islands": ["game", "creative_expert", "dream"],
                "observer_strategy": "Stay in absurd space, honor lightness"
            }
        }

    def identify_dominant_state(self, state_clusters: Dict[str, int]) -> Optional[str]:
        """
        Identify which state is currently dominant based on cluster counts.

        Args:
            state_clusters: Dict from heyleo._count_state_clusters()

        Returns:
            Name of dominant state (e.g., "pain_state") or None if no clear state
        """
        # Filter out zero counts
        active_states = {k: v for k, v in state_clusters.items() if v > 0}

        if not active_states:
            return None

        # Find max count
        max_count = max(active_states.values())

        # If multiple states tied, prioritize in order of urgency:
        # pain > meta > privacy > play > relief
        priority_order = ["pain_state", "meta_state", "privacy_state", "play_state", "relief_state"]

        for state in priority_order:
            if state in active_states and active_states[state] == max_count:
                return state

        return None

    def suggest_bridge(
        self,
        state_clusters: Dict[str, int],
        recent_islands: List[str] = None
    ) -> Tuple[Optional[str], List[str], str]:
        """
        Suggest which islands to activate based on current state.

        Args:
            state_clusters: Current state cluster counts
            recent_islands: Recently active islands (to avoid repetition)

        Returns:
            Tuple of (dominant_state, suggested_islands, observer_strategy)
        """
        dominant = self.identify_dominant_state(state_clusters)

        if dominant is None:
            return None, [], "No clear state detected"

        # Check if this state has a bridge pattern
        if dominant not in self.bridge_map:
            return dominant, [], f"No bridge pattern defined for {dominant}"

        bridge = self.bridge_map[dominant]
        suggested = bridge["islands"].copy()

        # Filter out recently used islands to encourage variety
        if recent_islands:
            suggested = [isl for isl in suggested if isl not in recent_islands[-3:]]

        # If all filtered out, use original suggestions
        if not suggested:
            suggested = bridge["islands"].copy()

        return dominant, suggested, bridge["observer_strategy"]

    def record_attempt(
        self,
        from_state: str,
        to_state: str,
        islands_suggested: List[str],
        state_before: Dict[str, int],
        state_after: Dict[str, int],
        notes: str = ""
    ):
        """
        Record a bridge transition attempt for learning.

        Success is measured by:
        - Target state count increased
        - Source state count decreased (if unhealthy state like pain/meta)
        """
        success = False

        # Check if transition succeeded
        if to_state in state_after:
            # Positive states (relief, play): success if increased
            if to_state in ["relief_state", "play_state"]:
                success = state_after[to_state] > state_before.get(to_state, 0)

            # Flow/presence: success if source decreased
            elif from_state in ["pain_state", "meta_state"]:
                source_decreased = state_after[from_state] < state_before.get(from_state, 0)
                target_stable = state_after.get(to_state, 0) >= 0
                success = source_decreased and target_stable

        attempt = BridgeAttempt(
            timestamp=datetime.now().isoformat(),
            from_state=from_state,
            to_state=to_state,
            islands_suggested=islands_suggested,
            state_before=state_before.copy(),
            state_after=state_after.copy(),
            success=success,
            notes=notes
        )

        self.bridge_history.append(attempt)

        return success

    def get_success_rate(self, from_state: str = None, to_state: str = None) -> float:
        """
        Calculate success rate for bridge transitions.

        Args:
            from_state: Filter by source state (optional)
            to_state: Filter by target state (optional)

        Returns:
            Success rate as float (0.0 to 1.0)
        """
        filtered = self.bridge_history

        if from_state:
            filtered = [a for a in filtered if a.from_state == from_state]

        if to_state:
            filtered = [a for a in filtered if a.to_state == from_state]

        if not filtered:
            return 0.0

        successes = sum(1 for a in filtered if a.success)
        return successes / len(filtered)

    def get_best_bridge(self, from_state: str) -> Optional[List[str]]:
        """
        Based on learned history, return the most successful islands for a given state.

        Args:
            from_state: Source state to transition from

        Returns:
            List of island names with highest success rate, or None if no data
        """
        # Filter attempts from this state
        attempts = [a for a in self.bridge_history if a.from_state == from_state]

        if not attempts:
            return None

        # Count successes per island combination
        island_success: Dict[tuple, int] = {}
        island_total: Dict[tuple, int] = {}

        for attempt in attempts:
            key = tuple(sorted(attempt.islands_suggested))
            island_total[key] = island_total.get(key, 0) + 1
            if attempt.success:
                island_success[key] = island_success.get(key, 0) + 1

        # Find best performing combination
        best_combo = None
        best_rate = 0.0

        for combo in island_total:
            rate = island_success.get(combo, 0) / island_total[combo]
            if rate > best_rate:
                best_rate = rate
                best_combo = combo

        return list(best_combo) if best_combo else None

    def get_summary(self) -> str:
        """
        Generate a summary of bridge learning progress.
        """
        if not self.bridge_history:
            return "No bridge attempts recorded yet."

        total = len(self.bridge_history)
        successes = sum(1 for a in self.bridge_history if a.success)
        success_rate = successes / total

        # Break down by state
        by_state = {}
        for attempt in self.bridge_history:
            state = attempt.from_state
            if state not in by_state:
                by_state[state] = {"total": 0, "success": 0}
            by_state[state]["total"] += 1
            if attempt.success:
                by_state[state]["success"] += 1

        summary = f"Bridge Learning Summary\n"
        summary += f"=" * 50 + "\n"
        summary += f"Total attempts: {total}\n"
        summary += f"Successes: {successes} ({success_rate:.1%})\n\n"

        summary += "By State:\n"
        for state, stats in by_state.items():
            rate = stats["success"] / stats["total"]
            summary += f"  {state}: {stats['success']}/{stats['total']} ({rate:.1%})\n"

        return summary


# Global instance for use in heyleo.py
_bridge_system = None

def get_bridge_system() -> IslandBridges:
    """Get or create the global bridge system instance"""
    global _bridge_system
    if _bridge_system is None:
        _bridge_system = IslandBridges()
    return _bridge_system


def reset_bridge_system():
    """Reset the bridge system (for testing)"""
    global _bridge_system
    _bridge_system = None
