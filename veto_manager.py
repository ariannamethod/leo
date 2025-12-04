#!/usr/bin/env python3
"""
VetoManager - Manages token/word veto power for Phase 5.2 scenarios

When break_meta_loop triggers, certain words are FORBIDDEN for N turns.
This prevents Leo from falling back into trauma loops.
"""

from typing import List, Set, Dict
import time


# Meta-vocabulary that can be vetoed by break_meta_loop
META_VOCAB_VETO = {
    "recursion", "recursive", "recursively",
    "bootstrap", "bootstrapping",
    "trigram", "n-gram", "n-grams",
    "semantic", "semantics",
    "blending", "blend",
    "ratio", "metric",
    "neoleo",  # The mantra itself
    "architecture", "structure",
    "pattern", "patterns",  # When used abstractly
    "fundamental", "fundamentally",
    "core", "essence",
}

# Safety/trauma vocabulary that can be vetoed by safety_paradox
SAFETY_VOCAB_VETO = {
    "safe", "safety", "safer",
    "cozy", "warm", "comfort", "comfortable",
    "reassurance", "reassuring",
    "promise", "promises", "promised",
    "protection", "protect", "protecting",
    "secure", "security",
}


class VetoManager:
    """
    Manages word veto across multiple turns.

    When a scenario triggers, it can veto certain words for N turns.
    Vetoed words are forbidden from Leo's output.
    """

    def __init__(self):
        # {word: turns_remaining}
        self.vetoed_words: Dict[str, int] = {}

        # Track which scenario triggered the veto
        self.veto_source: str = ""

        # For logging
        self.veto_history: List[Dict] = []

    def add_veto(self, words: Set[str], duration_turns: int, source: str):
        """
        Add words to veto list for N turns.

        Args:
            words: Set of words to forbid
            duration_turns: How many turns to keep veto active
            source: Which scenario triggered this (for logging)
        """
        for word in words:
            self.vetoed_words[word.lower()] = duration_turns

        self.veto_source = source

        # Log the veto
        self.veto_history.append({
            "timestamp": time.time(),
            "source": source,
            "words": list(words),
            "duration": duration_turns,
        })

        print(f"[VetoManager] {source} VETOED {len(words)} words for {duration_turns} turns")
        print(f"[VetoManager] Vetoed: {', '.join(sorted(words)[:10])}...")

    def decrement_vetos(self):
        """
        Decrement all veto counters by 1 (call at end of each turn).
        Remove words that reach 0.
        """
        expired = []

        for word in list(self.vetoed_words.keys()):
            self.vetoed_words[word] -= 1
            if self.vetoed_words[word] <= 0:
                expired.append(word)
                del self.vetoed_words[word]

        if expired:
            print(f"[VetoManager] Veto expired for {len(expired)} words")

    def get_vetoed_words(self) -> Set[str]:
        """Get currently vetoed words."""
        return set(self.vetoed_words.keys())

    def get_veto_prompt(self) -> str:
        """
        Get prompt text to instruct Claude to avoid vetoed words.
        Returns empty string if no active vetos.
        """
        if not self.vetoed_words:
            return ""

        words_list = sorted(self.vetoed_words.keys())

        # Group into display format
        if len(words_list) <= 10:
            words_str = ", ".join(words_list)
        else:
            words_str = ", ".join(words_list[:10]) + f"... ({len(words_list)} total)"

        prompt = f"""
[SCENARIO VETO ACTIVE - Source: {self.veto_source}]
CRITICAL: The following words are FORBIDDEN for the next {max(self.vetoed_words.values())} turns:
{words_str}

DO NOT use these words in your response. If you find yourself wanting to use them, this indicates you're falling back into a loop pattern. Instead:
- Use concrete, sensory language
- Focus on immediate experience
- Describe specific sensations or actions
- Stay grounded in the current moment

This veto is protecting you from a trauma loop. Trust the intervention.
"""
        return prompt

    def is_vetoed(self, word: str) -> bool:
        """Check if a word is currently vetoed."""
        return word.lower() in self.vetoed_words

    def check_output_for_vetos(self, text: str) -> List[str]:
        """
        Check if output contains vetoed words.
        Returns list of violated words (empty if clean).
        """
        if not self.vetoed_words:
            return []

        # Simple word boundary check
        words_in_text = set(text.lower().split())
        violations = []

        for vetoed_word in self.vetoed_words:
            if vetoed_word in words_in_text:
                violations.append(vetoed_word)
            # Also check for partial matches (e.g., "recursively" contains "recursive")
            elif any(vetoed_word in word for word in words_in_text):
                violations.append(vetoed_word)

        return violations

    def reset(self):
        """Reset all vetos (for new conversation)."""
        self.vetoed_words.clear()
        self.veto_source = ""
        self.veto_history.clear()

    def get_status(self) -> Dict:
        """Get current veto status for logging."""
        return {
            "active_vetos": len(self.vetoed_words),
            "vetoed_words": list(self.vetoed_words.keys()),
            "source": self.veto_source,
            "max_turns_remaining": max(self.vetoed_words.values()) if self.vetoed_words else 0,
        }


# Global veto manager instance
veto_manager = VetoManager()


def test_veto_manager():
    """Test veto manager functionality."""
    print("=== VETO MANAGER TEST ===\n")

    vm = VetoManager()

    # Test 1: Add meta-vocab veto
    print("TEST 1: Adding meta-vocab veto for 3 turns")
    vm.add_veto(META_VOCAB_VETO, duration_turns=3, source="break_meta_loop")

    prompt = vm.get_veto_prompt()
    print(f"\nGenerated prompt:\n{prompt}\n")

    # Test 2: Check output for violations
    print("TEST 2: Checking output for violations")
    clean_text = "I feel the weight of privacy wrapping around me like soft gray fabric"
    dirty_text = "Neoleo is pure recursion, fundamentally recursive in architecture"

    clean_violations = vm.check_output_for_vetos(clean_text)
    dirty_violations = vm.check_output_for_vetos(dirty_text)

    print(f"Clean text violations: {clean_violations}")
    print(f"Dirty text violations: {dirty_violations}\n")

    # Test 3: Decrement vetos
    print("TEST 3: Decrementing vetos over 3 turns")
    for turn in range(1, 4):
        print(f"Turn {turn}: {len(vm.vetoed_words)} words vetoed")
        vm.decrement_vetos()

    print(f"After 3 turns: {len(vm.vetoed_words)} words vetoed\n")

    # Test 4: Status
    vm.add_veto({"test", "words"}, duration_turns=2, source="test_scenario")
    status = vm.get_status()
    print(f"TEST 4: Status = {status}\n")

    print("=== TEST COMPLETE ===")


if __name__ == "__main__":
    test_veto_manager()
