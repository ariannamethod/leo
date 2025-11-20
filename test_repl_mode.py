#!/usr/bin/env python3
"""
Test REPL-like conversation mode to check for issues.
"""
import leo

# Initialize
print("🌊 Starting Leo conversation test...\n")
conn = leo.init_db()
leo.bootstrap_if_needed(conn)
field = leo.LeoField(conn)

prompts = [
    "Hello Leo, how are you?",
    "What is resonance?",
    "Tell me about language",
    "Can you explain presence?",
]

for i, prompt in enumerate(prompts, 1):
    print(f"\n{'='*60}")
    print(f"TURN {i}")
    print(f"{'='*60}")
    print(f"You: {prompt}")

    # Observe user input
    field.observe(prompt)

    # Generate reply
    reply = field.reply(prompt, max_tokens=60, temperature=1.0)
    print(f"\nLeo: {reply}")

    # Observe Leo's own reply
    field.observe(reply)

    # Show stats
    if field.last_pulse:
        print(f"\n📊 Pulse: novelty={field.last_pulse.novelty:.2f}, "
              f"arousal={field.last_pulse.arousal:.2f}, "
              f"entropy={field.last_pulse.entropy:.2f}")
    if field.last_expert:
        print(f"🎯 Expert: {field.last_expert.name} (temp={field.last_expert.temperature})")

print(f"\n{'='*60}")
print("FINAL STATS")
print(f"{'='*60}")
print(field.stats_summary())
print("\n✅ Conversation test complete!")
