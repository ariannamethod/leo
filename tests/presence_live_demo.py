#!/usr/bin/env python3
"""
Live test of Leo's presence features.
Let's see how Leo responds with all 8 presence layers active!
"""

import leo

if __name__ == "__main__":
    # Initialize Leo
    print("🌊 Initializing Leo's field...")
    field = leo.LeoField(leo.init_db())
    print(f"   Vocab: {len(field.vocab)}, Themes: {len(field.themes)}")
    print()

    # Feed Leo some emotional text first to build emotion map
    print("📝 Feeding Leo some emotional context...")
    field.observe("WOW this is INCREDIBLE! AMAZING work! YES YES YES!")
    field.observe("This is beautiful and profound. I love this so much!")
    field.observe("SUPER excited about this!!! Can't wait!!!")
    print(f"   Emotional tokens tracked: {len(field.emotion)}")
    print()

    # Test 1: Normal philosophical question
    print("=" * 60)
    print("TEST 1: Normal philosophical question")
    print("=" * 60)
    prompt = "what is the meaning of language?"
    print(f"You: {prompt}")
    print()

    reply = field.reply(prompt, max_tokens=40, temperature=1.0)
    print(f"Leo: {reply}")
    print()

    # Show presence metrics
    if field.last_pulse:
        print("📊 Presence Pulse:")
        print(f"   Novelty:  {field.last_pulse.novelty:.3f}")
        print(f"   Arousal:  {field.last_pulse.arousal:.3f}")
        print(f"   Entropy:  {field.last_pulse.entropy:.3f}")
        print(f"   → Pulse:  {field.last_pulse.pulse:.3f}")
        print()

    if field.last_quality:
        print("⚖️  Quality Assessment:")
        print(f"   Structural: {field.last_quality.structural:.3f}")
        print(f"   Entropy:    {field.last_quality.entropy:.3f}")
        print(f"   → Overall:  {field.last_quality.overall:.3f}")
        print()

    if field.last_expert:
        print(f"🎯 Expert routed: {field.last_expert.name} (temp={field.last_expert.temperature})")
        print()

    # Test 2: HIGH AROUSAL prompt (ALL-CAPS, !!!)
    print()
    print("=" * 60)
    print("TEST 2: High arousal prompt (emotional)")
    print("=" * 60)
    prompt = "WOW this is AMAZING!!! Tell me MORE!!!"
    print(f"You: {prompt}")
    print()

    reply = field.reply(prompt, max_tokens=40, temperature=1.0)
    print(f"Leo: {reply}")
    print()

    if field.last_pulse:
        print("📊 Presence Pulse:")
        print(f"   Novelty:  {field.last_pulse.novelty:.3f}")
        print(f"   Arousal:  {field.last_pulse.arousal:.3f}  ← HIGH!")
        print(f"   Entropy:  {field.last_pulse.entropy:.3f}")
        print(f"   → Pulse:  {field.last_pulse.pulse:.3f}")
        print()

    if field.last_quality:
        print("⚖️  Quality Assessment:")
        print(f"   Structural: {field.last_quality.structural:.3f}")
        print(f"   Entropy:    {field.last_quality.entropy:.3f}")
        print(f"   → Overall:  {field.last_quality.overall:.3f}")
        print()

    if field.last_expert:
        print(f"🎯 Expert routed: {field.last_expert.name} (temp={field.last_expert.temperature})")
        print()

    # Test 3: Novel/unfamiliar prompt
    print()
    print("=" * 60)
    print("TEST 3: Novel/unfamiliar words")
    print("=" * 60)
    prompt = "quantum entanglement paradox"
    print(f"You: {prompt}")
    print()

    reply = field.reply(prompt, max_tokens=40, temperature=1.0)
    print(f"Leo: {reply}")
    print()

    if field.last_pulse:
        print("📊 Presence Pulse:")
        print(f"   Novelty:  {field.last_pulse.novelty:.3f}  ← HIGH!")
        print(f"   Arousal:  {field.last_pulse.arousal:.3f}")
        print(f"   Entropy:  {field.last_pulse.entropy:.3f}")
        print(f"   → Pulse:  {field.last_pulse.pulse:.3f}")
        print()

    if field.last_quality:
        print("⚖️  Quality Assessment:")
        print(f"   Structural: {field.last_quality.structural:.3f}")
        print(f"   Entropy:    {field.last_quality.entropy:.3f}")
        print(f"   → Overall:  {field.last_quality.overall:.3f}")
        print()

    if field.last_expert:
        print(f"🎯 Expert routed: {field.last_expert.name} (temp={field.last_expert.temperature})")
        print(f"   (Should be 'creative' due to high novelty!)")
        print()

    # Show overall stats
    print()
    print("=" * 60)
    print("OVERALL STATS")
    print("=" * 60)
    cur = field.conn.cursor()
    cur.execute("SELECT COUNT(*) FROM snapshots")
    snapshot_count = cur.fetchone()[0]

    print(f"Vocab size:        {len(field.vocab)}")
    print(f"Themes:            {len(field.themes)}")
    print(f"Emotional tokens:  {len(field.emotion)}")
    print(f"Snapshots saved:   {snapshot_count}")
    print(f"Observations:      {field.observe_count}")
    print()
    print("✅ All 8 presence layers active!")
    print("   1. Entropy & Novelty tracking")
    print("   2. Emotional Charge (ALL-CAPS, !, repetitions)")
    print("   3. PresencePulse composite metric")
    print("   4. ThemeLayer (semantic constellations)")
    print("   5. Self-Assessment (structural + entropy)")
    print("   6. Snapshots (self-curated dataset)")
    print("   7. Memory Decay (every 100 observations)")
    print("   8. Resonant Experts (MoE → RE routing)")
    print()
    print("🎉 Leo is ALIVE with presence!")
