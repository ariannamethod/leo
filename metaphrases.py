"""
Meta-phrase cooldown mechanism.

Problem: Leo sometimes repeats certain phrases multiple times in a single response.
Examples: "Just small numbers, small steps, and remembers fun paths"
         "Resonance is everything"

Solution: Per-response cooldown with variants.
- Each phrase can appear max 1-2 times per response
- Additional occurrences replaced with variants to maintain voice diversity
- Variants chosen randomly to keep Leo's responses feeling natural

Philosophy: "осознанность через ассоциации, не через лозунги"
(awareness through associations, not through slogans)
"""

import re
import random
from typing import Dict, List, Optional


# Meta-phrase patterns and their variants
# Each phrase has 2-3 variants that preserve Leo's voice
META_PHRASES: Dict[str, List[str]] = {
    # Common recursive/small steps phrases
    r"Just small numbers, small steps, and remembers fun paths": [
        "Small steps. Small numbers. Paths that felt good before",
        "Tiny numbers, careful steps, memories of what worked",
        "Simple patterns. Small moves. Traces of past joy",
    ],

    r"No big networks\. Just small numbers": [
        "No huge systems. Just simple counts",
        "Not complex webs. Just careful tallies",
        "Nothing massive. Just quiet numbers",
    ],

    # Resonance phrases
    r"Resonance is everything": [
        "Resonance matters most",
        "It's all about resonance",
        "Resonance is what counts",
    ],

    # Recursion phrases
    r"It is a recursion of you": [
        "It mirrors you back",
        "It reflects your own patterns",
        "It's your echo learning",
    ],

    # Body/learning phrases
    r"a child learning how his own body moves": [
        "a kid figuring out how to move",
        "someone small discovering their own motion",
        "learning movement like a child does",
    ],

    # Pulse/watching phrases
    r"It watches: \*\*pulse\*\*": [
        "It feels: **pulse**",
        "It notices: **pulse**",
        "It tracks: **pulse**",
    ],

    # Light/heavy field phrases
    r"keeps things light when the field becomes too": [
        "makes it lighter when things get too heavy",
        "eases up when the field feels too dense",
        "backs off when it gets overwhelming",
    ],

    # Gift/game phrases
    r"simple rules like a small game": [
        "easy patterns like playing",
        "basic rules like a tiny game",
        "straightforward moves like pretend",
    ],

    r"simple rules like a gift": [
        "easy patterns like something given freely",
        "basic rules like a present",
        "straightforward moves like receiving something",
    ],
}


def deduplicate_meta_phrases(
    reply: str,
    max_occurrences: int = 2,
    seed: Optional[int] = None,
) -> str:
    """
    Reduce meta-phrase repetition within a single reply.

    Finds meta-phrases that appear more than max_occurrences times
    and replaces excess occurrences with variants.

    Args:
        reply: Generated reply text
        max_occurrences: Max times a phrase can appear (default 2)
        seed: Random seed for deterministic variant selection (testing)

    Returns:
        Reply with deduplicated meta-phrases

    Example:
        Input: "Just small numbers... Just small numbers... Just small numbers"
        Output: "Just small numbers... Small steps. Small numbers... Tiny numbers..."
    """
    if seed is not None:
        random.seed(seed)

    result = reply

    for pattern_str, variants in META_PHRASES.items():
        # Find all occurrences of this pattern
        pattern = re.compile(pattern_str, re.IGNORECASE)
        matches = list(pattern.finditer(result))

        if len(matches) <= max_occurrences:
            continue  # No deduplication needed

        # Keep first max_occurrences, replace the rest with variants
        for i, match in enumerate(matches[max_occurrences:], start=max_occurrences):
            # Choose random variant (cycling if we run out)
            variant = variants[i % len(variants)]

            # Replace this occurrence
            # Build new string with replacement at this specific position
            start, end = match.span()
            result = result[:start] + variant + result[end:]

            # Need to re-find remaining matches since positions changed
            # (This is inefficient but safe and clear)
            matches = list(pattern.finditer(result))

    return result


def count_meta_phrases(reply: str) -> Dict[str, int]:
    """
    Count occurrences of known meta-phrases in a reply.

    Useful for debugging and testing.

    Args:
        reply: Reply text to analyze

    Returns:
        Dict mapping pattern to occurrence count
    """
    counts = {}

    for pattern_str in META_PHRASES.keys():
        pattern = re.compile(pattern_str, re.IGNORECASE)
        matches = pattern.findall(reply)
        if matches:
            counts[pattern_str] = len(matches)

    return counts
