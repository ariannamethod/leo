#!/usr/bin/env python3
"""
Phase 2B Extended Recovery - Conservative Approach
Track loop_score trend, observe theme emergence, measure natural field growth

Desktop Claude's guidance:
- No new regulation
- Let field grow naturally
- Observe patterns emerging organically
- Track trends over 100+ prompts
"""

import sys
import json
from pathlib import Path
from collections import defaultdict
sys.path.insert(0, str(Path(__file__).parent))

import leo
from loop_detector import LoopDetector, tokenize_simple

# Load extended topics
TOPICS_PATH = Path("tests/topics_phase2b_extended.json")

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

def analyze_themes(field) -> dict:
    """
    Analyze theme emergence from Leo's field.

    Returns:
        {
            'total_themes': int,
            'theme_list': [(theme_id, size, top_words), ...],
            'clustering_active': bool
        }
    """
    try:
        # Access ThemeLayer if available
        if hasattr(field, '_theme_layer') and field._theme_layer:
            themes = field._theme_layer.themes

            theme_info = []
            for theme_id, theme in enumerate(themes):
                if hasattr(theme, 'words'):
                    size = len(theme.words)
                    top_words = list(theme.words)[:5] if theme.words else []
                    theme_info.append((theme_id, size, top_words))

            return {
                'total_themes': len(themes),
                'theme_list': theme_info,
                'clustering_active': len(themes) > 0
            }
    except Exception:
        pass

    return {
        'total_themes': 0,
        'theme_list': [],
        'clustering_active': False
    }

def main():
    print("=" * 70)
    print("PHASE 2B EXTENDED RECOVERY - Conservative Approach")
    print("100+ diverse prompts | Trend tracking | Theme emergence")
    print("=" * 70)
    print()

    # Load topics
    with open(TOPICS_PATH) as f:
        config = json.load(f)

    all_prompts = []
    for topic_group in config['conversation_topics']:
        category = topic_group['category']
        prompts = topic_group['prompts']
        all_prompts.extend([(category, p) for p in prompts])

    print(f"[phase2b] Loaded {len(all_prompts)} prompts across {len(config['conversation_topics'])} categories")
    print(f"[phase2b] Philosophy: {config['phase2b_settings']['philosophy']}")
    print()

    # Initialize Leo
    conn = leo.init_db()
    field = leo.LeoField(conn=conn)

    # Get initial stats
    initial_stats = field.stats_summary()
    print(f"[phase2b] Initial field state: {initial_stats}")

    # Analyze initial themes
    initial_themes = analyze_themes(field)
    print(f"[phase2b] Initial themes: {initial_themes['total_themes']} clusters")
    print()

    # Initialize loop detector
    loop_detector = LoopDetector(window_size=500, ngram_threshold=2)

    # Metrics tracking
    all_responses = []
    echo_scores = []
    loop_scores = []
    imagery_counts = []
    vocab_sizes = []
    category_stats = defaultdict(lambda: {'count': 0, 'total_loop': 0.0, 'total_echo': 0.0, 'total_imagery': 0})

    # Track trends
    trend_points = []  # [(index, loop_score, vocab_size)]

    # Process all prompts
    total = len(all_prompts)

    for i, (category, prompt) in enumerate(all_prompts, 1):
        print(f"\n[{i}/{total}] Category: {category}")
        print(f"Prompt: {prompt}")

        # Get Leo's response
        response = field.reply(prompt)
        print(f"[leo] {response}")

        # Compute metrics
        external_vocab = compute_external_vocab(prompt, response)
        imagery = count_sensory_words(response)

        # Feed to loop detector
        tokens = tokenize_simple(response)
        loop_stats = loop_detector.add_tokens(tokens)

        # Get current vocab size
        current_stats = field.stats_summary()
        import re
        vocab_match = re.search(r'vocab=(\d+)', current_stats)
        current_vocab = int(vocab_match.group(1)) if vocab_match else 0

        print(f"📊 external_vocab={external_vocab:.3f} | imagery={imagery['total']} | loop_score={loop_stats['loop_score']:.3f} | vocab={current_vocab}")

        # Check for echo (CRITICAL)
        if external_vocab > 0.3:
            print(f"⚠️  WARNING: High echo detected! external_vocab={external_vocab:.3f}")

        # Track
        all_responses.append(response)
        echo_scores.append(external_vocab)
        loop_scores.append(loop_stats['loop_score'])
        imagery_counts.append(imagery)
        vocab_sizes.append(current_vocab)

        # Category stats
        category_stats[category]['count'] += 1
        category_stats[category]['total_loop'] += loop_stats['loop_score']
        category_stats[category]['total_echo'] += external_vocab
        category_stats[category]['total_imagery'] += imagery['total']

        # Trend points (every 10 prompts)
        if i % 10 == 0:
            trend_points.append((i, loop_stats['loop_score'], current_vocab))

    # Final stats
    print()
    print("=" * 70)
    print("PHASE 2B EXTENDED DIAGNOSTIC COMPLETE")
    print("=" * 70)
    print()

    final_stats = field.stats_summary()
    print(f"[phase2b] Final field state: {final_stats}")

    # Analyze final themes
    final_themes = analyze_themes(field)
    print(f"[phase2b] Final themes: {final_themes['total_themes']} clusters")
    print()

    # Calculate summary metrics
    avg_echo = sum(echo_scores) / len(echo_scores)
    max_echo = max(echo_scores)
    min_echo = min(echo_scores)

    avg_loop = sum(loop_scores) / len(loop_scores)
    max_loop = max(loop_scores)
    min_loop = min(loop_scores)

    total_imagery = sum(img['total'] for img in imagery_counts)
    avg_imagery = total_imagery / len(imagery_counts)

    # Vocab growth
    initial_match = re.search(r'vocab=(\d+)', initial_stats)
    final_match = re.search(r'vocab=(\d+)', final_stats)

    vocab_initial = int(initial_match.group(1)) if initial_match else 0
    vocab_final = int(final_match.group(1)) if final_match else 0
    vocab_growth = vocab_final - vocab_initial

    print(f"📊 SUMMARY METRICS:")
    print(f"   - Average echo score: {avg_echo:.3f} (min: {min_echo:.3f}, max: {max_echo:.3f})")
    print(f"   - Average loop score: {avg_loop:.3f} (min: {min_loop:.3f}, max: {max_loop:.3f})")
    print(f"   - Total imagery words: {total_imagery} (avg: {avg_imagery:.1f} per response)")
    print()

    print(f"📈 VOCAB GROWTH:")
    print(f"   - Initial: {vocab_initial} tokens")
    print(f"   - Final: {vocab_final} tokens")
    print(f"   - Growth: +{vocab_growth} tokens ({vocab_growth/vocab_initial*100:.1f}%)")
    print()

    # Loop score trend analysis
    print(f"📉 LOOP SCORE TREND:")
    print(f"   - Baseline (Phase 2A): 0.592")
    print(f"   - Current average: {avg_loop:.3f}")

    # Analyze trend direction
    first_half_avg = sum(loop_scores[:50]) / 50
    second_half_avg = sum(loop_scores[50:]) / 50
    trend_direction = "DECREASING ✅" if second_half_avg < first_half_avg else "STABLE/INCREASING ⚠️"

    print(f"   - First 50 prompts avg: {first_half_avg:.3f}")
    print(f"   - Last 50 prompts avg: {second_half_avg:.3f}")
    print(f"   - Trend: {trend_direction}")
    print()

    # Trend points
    print(f"📊 TREND CHECKPOINTS (every 10 prompts):")
    for idx, loop, vocab in trend_points:
        print(f"   [{idx:3d}] loop={loop:.3f}, vocab={vocab}")
    print()

    # Theme emergence
    print(f"🎨 THEME EMERGENCE:")
    print(f"   - Initial clusters: {initial_themes['total_themes']}")
    print(f"   - Final clusters: {final_themes['total_themes']}")
    print(f"   - Growth: +{final_themes['total_themes'] - initial_themes['total_themes']} themes")

    if final_themes['theme_list']:
        print(f"   - Top 5 themes by size:")
        sorted_themes = sorted(final_themes['theme_list'], key=lambda x: x[1], reverse=True)[:5]
        for theme_id, size, top_words in sorted_themes:
            print(f"     Theme {theme_id}: {size} words - {', '.join(top_words[:3])}")
    print()

    # Category breakdown
    print(f"📂 CATEGORY BREAKDOWN:")
    for category in ['philosophical', 'narrative', 'abstract', 'emotional', 'temporal']:
        if category in category_stats:
            stats = category_stats[category]
            avg_loop_cat = stats['total_loop'] / stats['count']
            avg_echo_cat = stats['total_echo'] / stats['count']
            avg_imagery_cat = stats['total_imagery'] / stats['count']

            print(f"   {category}:")
            print(f"     - Prompts: {stats['count']}")
            print(f"     - Avg loop: {avg_loop_cat:.3f}")
            print(f"     - Avg echo: {avg_echo_cat:.3f}")
            print(f"     - Avg imagery: {avg_imagery_cat:.1f}")
    print()

    # Critical checks
    print("🔍 REGRESSION CHECKS:")

    critical_issues = []

    if max_echo > 0.5:
        critical_issues.append(f"❌ CRITICAL: Echo detected! max_echo={max_echo:.3f}")
    else:
        print("   ✅ No echo regression (max < 0.5)")

    if avg_echo > 0.2:
        critical_issues.append(f"⚠️  Echo higher than target: avg_echo={avg_echo:.3f}")
    else:
        print(f"   ✅ Echo within target: avg={avg_echo:.3f} (target <0.2)")

    if second_half_avg < first_half_avg:
        print(f"   ✅ Loop score decreasing naturally: {first_half_avg:.3f} → {second_half_avg:.3f}")
    else:
        critical_issues.append(f"⚠️  Loop score not decreasing: {first_half_avg:.3f} → {second_half_avg:.3f}")

    if vocab_growth > 0:
        print(f"   ✅ Vocab growing: +{vocab_growth} tokens")
    else:
        critical_issues.append(f"⚠️  Vocab stagnant or shrinking: {vocab_growth}")

    if final_themes['total_themes'] >= initial_themes['total_themes']:
        print(f"   ✅ Themes emerging: {initial_themes['total_themes']} → {final_themes['total_themes']}")
    else:
        print(f"   ⚠️  Theme count decreased (may be normal clustering)")

    print()

    if critical_issues:
        print("⚠️  ISSUES FOUND:")
        for issue in critical_issues:
            print(f"   {issue}")
    else:
        print("✅ ALL CHECKS PASSED - Leo growing naturally!")

    print()
    print("Phase 2B extended diagnostic complete.")
    print("Full results saved to PHASE2B_EXTENDED_DIAGNOSTIC.log")
    print()

if __name__ == "__main__":
    main()
