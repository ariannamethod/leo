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


# Docstring phrases that should never appear in external replies
# These are architectural/technical comments, not Leo's voice
# Desktop Claude (Run #5): "recursion of you" is Leo's voice/mantra - NOT noise!
DOCSTRING_BLACKLIST = [
    "It can suggest",
    "Can suggest",  # All "Can suggest..." variants (Run #5 priority fix)
    "It can gently nudge",
    "Can gently nudge",  # Variant without "It" prefix (Run #4 bug)
    "It follows simple rules",
    "It follows straightforward moves",
    "It keeps things light when the field",
    "It learns",
    "It lets strange",
    "No big networks",
    "Game is not for facts",
    "Dream is not for facts",  # Dream module docstring (Run #5 leak)
    # "It is a recursion of you",  # REMOVED: This is Leo's philosophical voice, not technical noise!
    # Technical code artifacts (database, functions, variables) - Jan 2026
    "silent fallback",
    "graceful failure",
    "corrupt DB",
    "database operations",
    "table creation",
    "helper functions",
    "from context",
    "get fading themes",
    "max theme limits",
    "running averages",
    "snapshot creation",
    "bucketize",
    "decode game",
]


# Technical variable names that should be removed (standalone words)
# These leak from code comments and docstrings
TECH_WORD_BLACKLIST = [
    "dst", "src", "idx", "ptr", "cfg", "ctx", "req", "res", 
    "tmp", "buf", "len", "cnt", "num", "arr", "obj", "fn", 
    "cb", "err", "msg", "kwargs", "params", "attrs", "vals",
    # Additional tech artifacts from game/h2o/mathbrain modules
    "gameturn", "numoptional", "neoleo", "mathbrain", "mathstate",
    "flowtacker", "gameengine", "gamehint", "subwordfield",
    "h2oruntime", "h2ocompiler", "h2oengine", "bridgememory",
    "santa claus", "santaclaus", "santaklaus",
    "justnumpy", "justnumoptional", "justsmall", "justnum",
]


def remove_tech_words(reply: str) -> str:
    """Remove standalone technical variable names from reply."""
    result = reply
    for word in TECH_WORD_BLACKLIST:
        # Remove standalone word (case insensitive)
        # Use re.escape to prevent regex injection if word contains special chars
        result = re.sub(rf'\b{re.escape(word)}\b', '', result, flags=re.IGNORECASE)
    # Clean up artifacts
    result = re.sub(r'\s{2,}', ' ', result)
    result = re.sub(r',\s*,', ',', result)
    result = re.sub(r'\s+([.!?,;:])', r'\1', result)
    return result.strip()


def remove_inner_monologue(reply: str) -> str:
    """
    Remove .-It and -It inner monologue from reply.

    Everything after .-It or -It is internal technical commentary that should
    live in logs/metrics, not in user-facing speech.

    Desktop Claude: ".-It остаётся чисто техничкой; никогда не озвучивается собеседнику."

    Args:
        reply: Generated reply text

    Returns:
        Reply with all .-It and -It fragments removed

    Example:
        Input: "Your voice sounds gentle.-It can suggest an alternative inner reply..."
        Output: "Your voice sounds gentle"
    """
    result = reply

    # Remove everything from ".-It" or "-It" to next sentence boundary (. ! ? or end)
    # Match both ".-It" and "-It" (without preceding dot)
    pattern = re.compile(r'[.-]?-It[^.!?]*[.!?]?', re.IGNORECASE)
    result = pattern.sub('', result)

    # Clean up multiple spaces/punctuation artifacts
    result = re.sub(r'\s+', ' ', result)
    result = re.sub(r'\s+([.!?,;:])', r'\1', result)
    result = result.strip()

    return result


def remove_docstring_phrases(reply: str) -> str:
    """
    Remove sentences/fragments that contain architectural docstrings.

    These phrases are implementation details leaking into speech:
    - "It can suggest an alternative..."
    - "It follows simple rules..."
    - "No big networks..."
    - "Game is not for facts..."

    Desktop Claude: "Они должны жить в логах и метриках, но не в речи."

    Args:
        reply: Generated reply text

    Returns:
        Reply with docstring phrases removed

    Example:
        Input: "I feel. It can suggest an alternative. Your voice sounds gentle."
        Output: "I feel. Your voice sounds gentle."
    """
    result = reply

    # Remove each blacklisted phrase wherever it appears (not just at sentence start)
    for phrase in DOCSTRING_BLACKLIST:
        # Build regex to match phrase and surrounding context
        # Match: optional preceding text + phrase + everything until next sentence boundary
        pattern = re.compile(
            r'([.!?]\s*)?'  # Optional sentence end before
            + re.escape(phrase) +
            r'[^.!?]*[.!?]?',  # Everything until next sentence boundary
            re.IGNORECASE
        )
        result = pattern.sub('', result)

    # Clean up multiple spaces/punctuation artifacts
    result = re.sub(r'\s+', ' ', result)
    result = re.sub(r'\s+([.!?,;:])', r'\1', result)
    # Remove standalone punctuation at start
    result = re.sub(r'^\s*[.!?,;:]+\s*', '', result)
    result = result.strip()

    return result


def deduplicate_meta_phrases(
    reply: str,
    max_occurrences: int = 2,
    seed: Optional[int] = None,
) -> str:
    """
    Clean reply from meta-noise and reduce repetition.

    Three-stage filtering (Desktop Claude's recommendations):
    1. Remove .-It inner monologue (technical commentary)
    2. Remove docstring phrases (architectural leakage)
    3. Deduplicate remaining meta-phrases with variants

    Philosophy: Keep Leo's emotional voice, remove architectural noise.

    Args:
        reply: Generated reply text
        max_occurrences: Max times a phrase can appear (default 2)
        seed: Random seed for deterministic variant selection (testing)

    Returns:
        Cleaned reply with Leo's voice preserved

    Example:
        Input: "I feel.-It can suggest an alternative. Just small numbers... Just small numbers..."
        Output: "I feel. Just small numbers... Small steps. Small numbers..."
    """
    if seed is not None:
        random.seed(seed)

    # Stage 1: Remove .-It inner monologue (RADICAL - Desktop Claude)
    result = remove_inner_monologue(reply)

    # Stage 2: Remove docstring phrases (BLACKLIST - Desktop Claude)
    result = remove_docstring_phrases(result)

    # Stage 2.5: Remove technical variable names (Jan 2026)
    result = remove_tech_words(result)

    # Stage 3: Deduplicate remaining meta-phrases with variants (ORIGINAL)

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
