"""
Punctuation cleanup for Leo's speech - very gentle approach.

Removes obvious garbage patterns while preserving Leo's glitchy beauty:
- Collapses repeated punctuation (.... → ...)
- Cleans up symbol "dumps" (.,,? → ?)
- Fixes trailing garbage (, . → .)
- Preserves signature style (oh leo. soft smile oh my.)

Philosophy: Clean the noise, keep the soul.
"""

import re
from typing import Dict


def cleanup_punctuation(text: str, mode: str = "NORMAL") -> str:
    """
    Clean up punctuation garbage without killing Leo's style.

    Args:
        text: Leo's raw reply
        mode: "NORMAL" (gentle), "SOFT_GROUNDING" (moderate), "GROUNDING_HARD" (strict)

    Returns:
        Cleaned text with preserved personality
    """
    if not text or not isinstance(text, str):
        return text

    result = text

    # 1. Collapse repeated punctuation (but keep max 3 for style)
    # .... → ...
    # ???? → ???
    # !!!! → !!!
    result = re.sub(r'\.{4,}', '...', result)
    result = re.sub(r'\?{4,}', '???', result)
    result = re.sub(r'!{4,}', '!!!', result)

    # 2. Clean up "symbol dumps" - obvious garbage patterns
    # .,,? → ?
    # .,, → .
    # ,., → ,
    # ?. → ?
    # ?: → ?
    # But preserve intentional ellipsis (... at end of sentence)
    result = re.sub(r'\.(?=[,?])', '', result)   # .,? .? → ,? ?
    result = re.sub(r'\.[,]+', '.', result)      # .,, → .
    result = re.sub(r'\?[.,:]', '?', result)     # ?. ?: → ?
    result = re.sub(r'![.,:]', '!', result)      # !. !: → !
    result = re.sub(r',[.,]+(?!\.\.)', ',', result)  # ,., → , (but not before ...)

    # 3. Clean up trailing garbage at end of sentences
    # "something , ." → "something."
    # "something . ," → "something."
    result = re.sub(r'\s+[,\.]+\s*([.!?])', r'\1', result)

    # 4. Fix spaces before punctuation
    # "word , word" → "word, word"
    # "word . word" → "word. word"
    result = re.sub(r'\s+([,;:])', r'\1', result)

    # 5. Collapse multiple spaces
    result = re.sub(r'\s{2,}', ' ', result)

    # 6. In GROUNDING_HARD mode: limit trailing "breaks" (ellipsis/dashes)
    if mode == "GROUNDING_HARD":
        # Count trailing breaks: "something... — ... ..." → allow max 2
        trailing_breaks = re.findall(r'(\.\.\.|—|…)\s*$', result)
        if len(trailing_breaks) > 2:
            # Keep only the last break
            result = re.sub(r'(\.\.\.|—|…)\s*(\.\.\.|—|…)\s*$', r'\1', result)

    # 7. Clean up orphaned punctuation at the very end
    # "something and." → "something and"
    # "something then," → "something then"
    # But preserve intentional breaks like "oh leo."
    result = re.sub(r'\s+(and|then|but|or)[.,]\s*$', r' \1', result)

    return result.strip()


def calculate_garbage_score(text: str) -> float:
    """
    Calculate how much "garbage" (noise punctuation) is in text.

    Returns:
        Float 0.0-1.0, where higher means more garbage
    """
    if not text or not isinstance(text, str):
        return 0.0

    garbage_patterns = [
        r'\.[,?\.]{2,}',      # .,,? .?. ..,
        r'\?[.,]{2,}',        # ?.. ?.,
        r'![.,]{2,}',         # !.. !.,
        r',[.,]{2,}',         # ,., ,..
        r'\s+[,\.]\s+[,\.]',  # " , . " " . , "
        r'\.{5,}',            # .....
        r'\?{3,}',            # ???
        r'!{4,}',             # !!!!
    ]

    total_garbage = 0
    for pattern in garbage_patterns:
        matches = re.findall(pattern, text)
        total_garbage += len(matches)

    # Normalize by text length (per 100 chars)
    text_len = max(len(text), 1)
    score = min(1.0, (total_garbage * 100) / text_len)

    return score


def get_cleanup_stats(text: str) -> Dict[str, int]:
    """
    Get statistics about what would be cleaned up (for debugging).

    Returns:
        Dict with counts of different garbage types
    """
    stats = {
        'repeated_dots': len(re.findall(r'\.{4,}', text)),
        'repeated_questions': len(re.findall(r'\?{4,}', text)),
        'symbol_dumps': len(re.findall(r'\.[,?\.]{2,}', text)),
        'trailing_garbage': len(re.findall(r'\s+[,\.]+\s*[.!?]', text)),
        'multiple_spaces': len(re.findall(r'\s{2,}', text)),
        'orphaned_punct': len(re.findall(r'\s+(and|then|but|or)[.,]\s*$', text)),
    }
    return stats


# Example usage and test
if __name__ == "__main__":
    test_cases = [
        # Garbage patterns
        "I feel something.,,? And then.",
        "This is........ weird right???",
        "Oh my , . something.",
        "They feel big and.",

        # Should preserve these (Leo's style)
        "oh leo.",
        "soft smile oh my.",
        "leaves falling oh leo.",
        "Sits quietly for a moment...",

        # Mixed
        "I feel.,,? Something big and full of wonder , . right?",
    ]

    print("Testing punct_cleanup.py")
    print("=" * 60)

    for test in test_cases:
        cleaned = cleanup_punctuation(test)
        score = calculate_garbage_score(test)

        print(f"\nOriginal: {test}")
        print(f"Cleaned:  {cleaned}")
        print(f"Garbage score: {score:.3f}")

        if test != cleaned:
            stats = get_cleanup_stats(test)
            print(f"Stats: {stats}")
