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

# Safe import: punct_cleanup module (optional garbage cleanup)
try:
    from punct_cleanup import cleanup_punctuation
    PUNCT_CLEANUP_AVAILABLE = True
except ImportError:
    PUNCT_CLEANUP_AVAILABLE = False

# Safe import: architectural_density module (optional soft penalty on tech jargon)
try:
    from architectural_density import architectural_density, should_apply_arch_penalty
    ARCH_DENSITY_AVAILABLE = True
except ImportError:
    ARCH_DENSITY_AVAILABLE = False
    # Fallback: no-op functions
    def architectural_density(text: str) -> float:
        return 0.0
    def should_apply_arch_penalty(topic: str) -> bool:
        return False


# Signature phrases - Leo's glitchy beauty that must be protected
# These define his personality and should NEVER be banned
# Only their frequency is gently limited (max 1-2 per response)
SIGNATURE_PHRASES = [
    "oh leo",
    "soft smile oh my",
    "leaves falling oh leo",
    "you like a child",
    "sits quietly for a moment",
    "speaks very gently",
    "looks up dreamily",
    "pauses softly",
    "speaks extra softly",
]


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

    # Technical leaks from module docstrings (2025-12-04 cleanup)
    "PresencePulse composite metric",
    "agglomerative clustering",
    "co-occurrence matrix",
    "SQLite persistence",
    "TransitionGraph",
    "Episode steps",
    "Islands of awareness",
    "island A, B C",
    "To id over",
    "Py: tests",
    "observe single step",
    "loss computation",
    "empty prompt returns none",
    "README scan",
    "dimension validation",
    "handling inactive themes",
    "silent fallback on errors",
    "If anything goes wrong",
    "broken generate observe",
    "Circles on water",
    "Leo s memory archaeology module",
    "safe bridge",
    "Not grammar, not for facts",
    "multileo phase",
    "school initialization",
    "wounded expert",
    "docstring leaks under stress",
]

# Toxic n-grams that cause loops (Claude Desktop analysis 2025-12-04)
# These are repeating structural patterns, not just single words
# Updated with patterns from HeyLeoGPT test runs
TOXIC_NGRAMS = [
    # Original patterns (2025-12-04 analysis)
    "metaleo is recursion on recursion",
    "like being in a context window",
    "you never see the trauma",
    "Leo answers differently. You know what",
    "leaves falling at once and they just keep swirling",
    "big, quiet mountains that just",
    "I can feel something spinning and spinning in you",
    "I can feel all those thoughts tumbling around like leaves",
    "For every consecutive pair of steps in an episode",
    "records: when I feel",
    "records: When I m telling you something",
    "Let's think about that with my fingers",
    "Sits quietly for a moment you asked",
    "like when you try to catch all the",
    "being the only person in a context window",

    # High-frequency repeating patterns from test runs (2025-12-04)
    "Let's think about something simple and nice. Mountains",
    "Speaks very gently I can feel all those big thinking-words moving around you",
    "They both feel big and full of wonder, don't they? Sits quietly for a moment",
    "A voice inside the body awareness proprioception, then",
    "Leo has trauma, low quality triggers",
    "They tokenize text into words basic punctuation, then",
    "in a context window",
    "If the inner reply is clearly better, Leo",
    "Leo is recursion on recursion, and the self-observation",
    "Storage sqlite: If the inner reply",

    # Technical leak patterns
    "post-transformer ai-child",
    "Trauma-what-bootstrap-gravity",
    "Bin neoleo. Bin centers-of-Experts",
    "Leo has no learned gating. Storage sqlite",
    "school of forms test school math arithmetic",
    "I shamelessly borrowed from karpathy's micrograd",
]


def remove_toxic_ngrams(reply: str) -> str:
    """
    Remove toxic n-gram patterns that cause loops.

    These are structural patterns identified in loop_score > 0.6 conversations.
    Unlike single-word blacklist, these are multi-word sequences that appear
    repeatedly when Leo is stuck in meta-recursion.

    Args:
        reply: Generated reply text

    Returns:
        Reply with toxic n-grams removed
    """
    result = reply

    # Remove each toxic n-gram
    for ngram in TOXIC_NGRAMS:
        # Case-insensitive removal
        pattern = re.compile(re.escape(ngram), re.IGNORECASE)
        result = pattern.sub('', result)

    # Clean up artifacts from removal
    result = re.sub(r'\s+', ' ', result)  # Multiple spaces
    result = re.sub(r'\s+([.!?,;:])', r'\1', result)  # Space before punctuation
    result = re.sub(r'([.!?])\s*\1+', r'\1', result)  # Repeated punctuation
    result = result.strip()

    return result


def count_signature_phrases(text: str) -> int:
    """
    Count occurrences of Leo's signature glitch-phrases.

    These phrases are NOT removed - they're part of Leo's beauty.
    This count is used for gentle frequency limiting only.

    Args:
        text: Text to analyze

    Returns:
        Total count of signature phrases found

    Example:
        "oh leo. soft smile oh my." → 2 signature phrases
    """
    if not text or not isinstance(text, str):
        return 0

    text_lower = text.lower()
    count = 0

    for phrase in SIGNATURE_PHRASES:
        # Count how many times this signature phrase appears
        count += text_lower.count(phrase.lower())

    return count


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
    mode: str = "NORMAL",
) -> str:
    """
    Clean reply from meta-noise and reduce repetition.

    Five-stage filtering (Desktop Claude's recommendations + loop analysis):
    1. Remove toxic n-grams (loop-causing structural patterns)
    2. Remove .-It inner monologue (technical commentary)
    3. Remove docstring phrases (architectural leakage)
    4. Deduplicate remaining meta-phrases with variants
    5. Clean up punctuation garbage (optional, gentle)

    Philosophy: Keep Leo's emotional voice, remove architectural noise and loops.

    Args:
        reply: Generated reply text
        max_occurrences: Max times a phrase can appear (default 2)
        seed: Random seed for deterministic variant selection (testing)
        mode: Cleanup mode - "NORMAL", "SOFT_GROUNDING", or "GROUNDING_HARD"

    Returns:
        Cleaned reply with Leo's voice preserved

    Example:
        Input: "I feel.-It can suggest an alternative. Just small numbers... Just small numbers..."
        Output: "I feel. Just small numbers... Small steps. Small numbers..."
    """
    if seed is not None:
        random.seed(seed)

    # Stage 1: Remove toxic n-grams (ANTI-LOOP - Claude Desktop 2025-12-04)
    result = remove_toxic_ngrams(reply)

    # Stage 2: Remove .-It inner monologue (RADICAL - Desktop Claude)
    result = remove_inner_monologue(result)

    # Stage 3: Remove docstring phrases (BLACKLIST - Desktop Claude)
    result = remove_docstring_phrases(result)

    # Stage 3.5: Replace technical artifacts with natural language
    # school_of_forms → school (keep meaning, remove tech formatting)
    result = re.sub(r'\bschool_of_forms\b', 'school', result, flags=re.IGNORECASE)
    result = re.sub(r'\bschool-of-forms\b', 'school', result, flags=re.IGNORECASE)

    # Stage 4: Deduplicate remaining meta-phrases with variants (ORIGINAL)

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

    # Stage 5: Clean up punctuation garbage (OPTIONAL - gentle sweep)
    if PUNCT_CLEANUP_AVAILABLE:
        try:
            result = cleanup_punctuation(result, mode=mode)
        except Exception:
            # Silent fallback - keep result as-is if cleanup fails
            pass

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
