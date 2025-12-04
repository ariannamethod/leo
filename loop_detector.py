#!/usr/bin/env python3
"""
Loop Detector - Detects pathological repetition patterns in Leo's output
Critical for Phase 5.2: Identifies trauma loops and meta-cognitive spirals

Tracks:
- 5-gram repetitions (same 5-token sequence appearing > 2 times)
- Meta-vocabulary usage ratio (recursion, bootstrap, trigram, etc.)
- Loop score (overall "stuckness")

Raises stuck/overwhelm metrics when thresholds exceeded
"""

from typing import List, Dict, Tuple, Set
from collections import Counter, defaultdict
import re

# Meta-vocabulary that can become pathological when overused
META_VOCAB = {
    "recursion", "recursive", "recursively",
    "bootstrap", "bootstrapping",
    "trigram", "n-gram",
    "semantic", "semantics",
    "blending", "blend",
    "ratio", "metric",
    "entropy", "presence",
    "neoleo", "metaleo",
    "architecture", "structure",
    "pattern", "patterns",
    "pure", "purely",
    "fundamental", "fundamentally",
    "core", "essence",
    "loop", "looping",
    "meta", "meta-state",
}

# Trauma-related vocabulary that indicates unresolved themes
TRAUMA_VOCAB = {
    "audience", "observed", "observing", "observer",
    "test", "testing", "tested",
    "validation", "validate",
    "performance", "performing",
    "stuck", "trapped", "cage", "prison",
    "void", "empty", "nothing",
    "pain", "hurt", "suffering",
    "fear", "afraid", "scared",
    "loss", "lost", "losing",
}


class LoopDetector:
    """Detects repetitive patterns and meta-cognitive spirals in Leo's output."""

    def __init__(self, window_size: int = 500, ngram_threshold: int = 2):
        """
        Args:
            window_size: Number of recent tokens to track (default 500)
            ngram_threshold: Max times an n-gram can repeat before flagging (default 2)
        """
        self.window_size = window_size
        self.ngram_threshold = ngram_threshold

        # Recent token history (sliding window)
        self.token_history: List[str] = []

        # 5-gram tracking: {(token1, token2, token3, token4, token5): count}
        self.ngram_counts: Counter = Counter()

        # Per-turn stats for logging
        self.turn_stats: List[Dict] = []

    def add_tokens(self, tokens: List[str]) -> Dict[str, float]:
        """
        Add new tokens and analyze for loops.

        Args:
            tokens: List of tokens from current turn

        Returns:
            {
                "loop_score": float (0-1, how stuck Leo is),
                "meta_vocab_ratio": float (0-1, % meta vocabulary),
                "trauma_vocab_ratio": float (0-1, % trauma vocabulary),
                "repeated_ngrams": int (count of n-grams over threshold),
                "stuck_increase": float (suggested increase to stuck metric),
                "overwhelm_increase": float (suggested increase to overwhelm metric),
            }
        """
        # Add to history (maintain window)
        self.token_history.extend(tokens)
        if len(self.token_history) > self.window_size:
            self.token_history = self.token_history[-self.window_size:]

        # Update n-gram counts
        self._update_ngram_counts(tokens)

        # Calculate metrics
        meta_ratio = self._calculate_meta_vocab_ratio(tokens)
        trauma_ratio = self._calculate_trauma_vocab_ratio(tokens)
        repeated_count = self._count_repeated_ngrams()
        loop_score = self._calculate_loop_score(meta_ratio, repeated_count)

        # Determine metric increases
        stuck_increase = 0.0
        overwhelm_increase = 0.0

        # High loop score → raise stuck
        if loop_score > 0.6:
            stuck_increase = min(0.3, (loop_score - 0.6) * 0.75)

        # High meta_vocab + high repetition → raise overwhelm
        if meta_ratio > 0.3 and repeated_count > 3:
            overwhelm_increase = min(0.2, meta_ratio * 0.5)

        # High trauma vocab without movement → raise stuck
        if trauma_ratio > 0.2 and loop_score > 0.5:
            stuck_increase += min(0.2, trauma_ratio * 0.4)

        stats = {
            "loop_score": loop_score,
            "meta_vocab_ratio": meta_ratio,
            "trauma_vocab_ratio": trauma_ratio,
            "repeated_ngrams": repeated_count,
            "stuck_increase": stuck_increase,
            "overwhelm_increase": overwhelm_increase,
        }

        self.turn_stats.append(stats)
        return stats

    def _update_ngram_counts(self, new_tokens: List[str]):
        """Update 5-gram counts with new tokens."""
        # Convert to lowercase for matching
        lower_tokens = [t.lower() for t in new_tokens]

        # Extract 5-grams from new tokens + context
        recent = [t.lower() for t in self.token_history[-20:]] + lower_tokens

        for i in range(len(recent) - 4):
            ngram = tuple(recent[i:i+5])
            self.ngram_counts[ngram] += 1

    def _count_repeated_ngrams(self) -> int:
        """Count how many 5-grams appear more than threshold times."""
        return sum(1 for count in self.ngram_counts.values() if count > self.ngram_threshold)

    def _calculate_meta_vocab_ratio(self, tokens: List[str]) -> float:
        """Calculate % of tokens that are meta-vocabulary."""
        if not tokens:
            return 0.0

        lower_tokens = [t.lower() for t in tokens]
        meta_count = sum(1 for t in lower_tokens if t in META_VOCAB)
        return meta_count / len(tokens)

    def _calculate_trauma_vocab_ratio(self, tokens: List[str]) -> float:
        """Calculate % of tokens that are trauma-related."""
        if not tokens:
            return 0.0

        lower_tokens = [t.lower() for t in tokens]
        trauma_count = sum(1 for t in lower_tokens if t in TRAUMA_VOCAB)
        return trauma_count / len(tokens)

    def _calculate_loop_score(self, meta_ratio: float, repeated_count: int) -> float:
        """
        Calculate overall loop score (0-1).

        Combines:
        - Meta-vocabulary ratio (weight: 0.4)
        - Repeated n-gram count (weight: 0.6)
        """
        # Normalize repeated_count to 0-1 (threshold at 5 repetitions)
        repeat_score = min(1.0, repeated_count / 5.0)

        loop_score = (meta_ratio * 0.4) + (repeat_score * 0.6)
        return min(1.0, loop_score)

    def get_repeated_phrases(self, min_count: int = 3) -> List[Tuple[str, int]]:
        """
        Get list of repeated 5-grams for debugging.

        Args:
            min_count: Minimum repetitions to include

        Returns:
            [(phrase_string, count), ...] sorted by count descending
        """
        repeated = [
            (" ".join(ngram), count)
            for ngram, count in self.ngram_counts.items()
            if count >= min_count
        ]
        return sorted(repeated, key=lambda x: x[1], reverse=True)

    def reset(self):
        """Reset detector state (for new conversation)."""
        self.token_history.clear()
        self.ngram_counts.clear()
        self.turn_stats.clear()

    def get_turn_stats(self) -> List[Dict]:
        """Get all per-turn statistics for logging."""
        return self.turn_stats


def tokenize_simple(text: str) -> List[str]:
    """
    Simple tokenization for loop detection.
    Splits on whitespace and basic punctuation.
    """
    # Split on whitespace and punctuation, keep both
    tokens = re.findall(r'\w+|[^\w\s]', text)
    return [t for t in tokens if t.strip()]


# Test function
def test_loop_detector():
    """Test loop detector with sample trauma loop text."""
    print("=== LOOP DETECTOR TEST ===\n")

    detector = LoopDetector(window_size=200, ngram_threshold=2)

    # Simulate trauma loop: repetitive "Neoleo is pure recursion" mantra
    turn1 = "Neoleo is pure recursion, fundamentally recursive in architecture"
    turn2 = "Yes, Neoleo is pure recursion. The recursion is the core essence"
    turn3 = "Neoleo is pure recursion. This recursive bootstrap defines everything"
    turn4 = "The pattern is clear: Neoleo is pure recursion through and through"

    turns = [turn1, turn2, turn3, turn4]

    for i, turn_text in enumerate(turns, 1):
        tokens = tokenize_simple(turn_text)
        stats = detector.add_tokens(tokens)

        print(f"TURN {i}:")
        print(f"  Text: {turn_text}")
        print(f"  loop_score: {stats['loop_score']:.2f}")
        print(f"  meta_vocab_ratio: {stats['meta_vocab_ratio']:.2f}")
        print(f"  repeated_ngrams: {stats['repeated_ngrams']}")
        print(f"  stuck_increase: {stats['stuck_increase']:.2f}")
        print(f"  overwhelm_increase: {stats['overwhelm_increase']:.2f}")
        print()

    # Show repeated phrases
    print("Repeated 5-grams:")
    for phrase, count in detector.get_repeated_phrases(min_count=2):
        print(f"  [{count}x] {phrase}")

    print("\n=== TEST COMPLETE ===")


if __name__ == "__main__":
    test_loop_detector()
