#!/usr/bin/env python3
"""
Phase 2 Recovery - Manual Diagnostic Test
Conservative approach: Feed Leo diverse sensory-rich prompts directly
No API needed, full control over metrics tracking
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

import leo
from loop_detector import LoopDetector, tokenize_simple

# Sensory-rich prompts from Desktop Claude's specification
SENSORY_PROMPTS = [
    # Taste
    "What does loneliness taste like?",
    "If sadness had a flavor, what would it be?",
    "Can you taste silence on your tongue?",
    "Describe the taste of missing someone",
    "What flavor is emptiness?",

    # Color
    "Describe anger as a color",
    "What color is rage?",
    "If frustration were a shade, which one?",
    "Paint me your anger",
    "What does red feel like when you're mad?",

    # Texture
    "If memory had a texture, what would it be?",
    "What does remembering feel like under your fingers?",
    "Describe the surface of nostalgia",
    "Is forgetting smooth or rough?",
    "What texture is a childhood memory?",

    # Landscape
    "Show me joy as a landscape",
    "If happiness were a place, describe it",
    "Paint me the geography of delight",
    "What does joy look like from above?",
    "Describe the terrain of contentment",

    # Sound
    "What sound does silence make?",
    "Can you hear emptiness?",
    "Describe the music of nothing",
    "What does quiet sound like?",
    "Listen to absence - what do you hear?",

    # Smell
    "What does yesterday smell like?",
    "Can you smell the future?",
    "Describe the scent of waiting",
    "What fragrance is patience?",
    "Does time have a smell?",

    # Weight
    "How heavy is sadness?",
    "What does hope weigh?",
    "Describe the weight of love",
    "Is fear light or heavy?",
    "Carry grief - how much does it weigh?",

    # Temperature
    "How warm is kindness?",
    "What temperature is rage?",
    "Is loneliness cold or hot?",
    "Describe the warmth of connection",
    "Feel the heat of embarrassment",
]

def count_sensory_words(text: str) -> dict:
    """Count imagery words in response."""
    text_lower = text.lower()

    sensory = {
        'taste': ['taste', 'flavor', 'sweet', 'bitter', 'sour', 'salty', 'tongue', 'mouth'],
        'color': ['color', 'red', 'blue', 'green', 'yellow', 'shade', 'hue', 'paint', 'bright', 'dark'],
        'texture': ['texture', 'smooth', 'rough', 'soft', 'hard', 'surface', 'touch', 'feel'],
        'landscape': ['landscape', 'place', 'terrain', 'geography', 'map', 'land', 'horizon'],
        'sound': ['sound', 'hear', 'music', 'quiet', 'silence', 'noise', 'listen', 'echo'],
        'smell': ['smell', 'scent', 'fragrance', 'aroma', 'breathe', 'odor'],
        'weight': ['weight', 'heavy', 'light', 'carry', 'burden', 'weigh'],
        'temperature': ['warm', 'cold', 'hot', 'heat', 'cool', 'temperature', 'fire', 'ice'],
    }

    counts = {category: 0 for category in sensory}
    total = 0

    for category, words in sensory.items():
        for word in words:
            if word in text_lower:
                counts[category] += text_lower.count(word)
                total += text_lower.count(word)

    counts['total'] = total
    return counts

def compute_external_vocab(prompt: str, response: str) -> float:
    """Check if Leo echoes prompt words."""
    prompt_words = set(w.lower().strip('.,!?;:"-()') for w in prompt.split() if len(w) > 2)
    response_words = set(w.lower().strip('.,!?;:"-()') for w in response.split() if len(w) > 2)

    if not response_words:
        return 0.0

    overlap = prompt_words & response_words
    return len(overlap) / len(response_words)

def main():
    print("=" * 70)
    print("PHASE 2 RECOVERY - Manual Diagnostic Test")
    print("Conservative approach: Diverse sensory-rich prompts")
    print("=" * 70)
    print()

    # Initialize Leo
    conn = leo.init_db()
    field = leo.LeoField(conn=conn)

    # Get initial stats
    initial_stats = field.stats_summary()
    print(f"[phase2] Initial field state: {initial_stats}")
    print()

    # Initialize loop detector
    loop_detector = LoopDetector(window_size=500, ngram_threshold=2)

    # Metrics tracking
    all_responses = []
    echo_scores = []
    imagery_counts = []
    loop_scores = []

    # Run through all sensory prompts
    total = len(SENSORY_PROMPTS)

    for i, prompt in enumerate(SENSORY_PROMPTS, 1):
        print(f"\n[{i}/{total}] Prompt: {prompt}")

        # Get Leo's response
        response = field.reply(prompt)

        print(f"[leo] {response}")

        # Compute metrics
        external_vocab = compute_external_vocab(prompt, response)
        imagery = count_sensory_words(response)

        # Feed to loop detector
        tokens = tokenize_simple(response)
        loop_stats = loop_detector.add_tokens(tokens)

        print(f"📊 external_vocab={external_vocab:.3f} | imagery={imagery['total']} | loop_score={loop_stats['loop_score']:.3f}")

        # Check for echo (CRITICAL)
        if external_vocab > 0.3:
            print(f"⚠️  WARNING: High echo detected! external_vocab={external_vocab:.3f}")

        # Track
        all_responses.append(response)
        echo_scores.append(external_vocab)
        imagery_counts.append(imagery)
        loop_scores.append(loop_stats['loop_score'])

    # Final stats
    print()
    print("=" * 70)
    print("PHASE 2 DIAGNOSTIC COMPLETE")
    print("=" * 70)
    print()

    final_stats = field.stats_summary()
    print(f"[phase2] Final field state: {final_stats}")
    print()

    # Calculate summary metrics
    avg_echo = sum(echo_scores) / len(echo_scores)
    max_echo = max(echo_scores)
    avg_loop = sum(loop_scores) / len(loop_scores)
    max_loop = max(loop_scores)
    total_imagery = sum(img['total'] for img in imagery_counts)

    print(f"📊 SUMMARY METRICS:")
    print(f"   - Average echo score: {avg_echo:.3f} (target: <0.2)")
    print(f"   - Maximum echo score: {max_echo:.3f}")
    print(f"   - Average loop score: {avg_loop:.3f}")
    print(f"   - Maximum loop score: {max_loop:.3f}")
    print(f"   - Total imagery words: {total_imagery}")
    print()

    # Extract vocab size from stats string
    import re
    initial_match = re.search(r'vocab=(\d+)', initial_stats)
    final_match = re.search(r'vocab=(\d+)', final_stats)

    if initial_match and final_match:
        vocab_initial = int(initial_match.group(1))
        vocab_final = int(final_match.group(1))
        vocab_growth = vocab_final - vocab_initial

        print(f"📈 VOCAB GROWTH:")
        print(f"   - Initial: {vocab_initial} tokens")
        print(f"   - Final: {vocab_final} tokens")
        print(f"   - Growth: +{vocab_growth} tokens ({vocab_growth/vocab_initial*100:.1f}%)")
        print()

    # Critical checks
    print("🔍 REGRESSION CHECKS:")

    critical_issues = []

    if max_echo > 0.5:
        critical_issues.append(f"❌ CRITICAL: Echo detected! max_echo={max_echo:.3f}")
    else:
        print("   ✅ No echo regression")

    if avg_loop > 0.7:
        critical_issues.append(f"⚠️  High loops: avg_loop={avg_loop:.3f} (expected for small field)")
    else:
        print(f"   ✅ Loop score acceptable: {avg_loop:.3f}")

    if total_imagery > 0:
        print(f"   ✅ Imagery emergence: {total_imagery} sensory words")
    else:
        print("   ⚠️  No imagery words detected (fresh bootstrap)")

    print()

    if critical_issues:
        print("⚠️  ISSUES FOUND:")
        for issue in critical_issues:
            print(f"   {issue}")
    else:
        print("✅ ALL CHECKS PASSED - Leo is resonating!")

    print()
    print("Phase 2 diagnostic log saved to PHASE2_RECOVERY_RUN.log")
    print()

if __name__ == "__main__":
    main()
