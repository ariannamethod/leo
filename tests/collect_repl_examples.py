#!/usr/bin/env python3
"""Collect example responses from Leo for README."""

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from leo import LeoField, init_db

def main():
    conn = init_db()
    field = LeoField(conn)
    
    # Seed with some text
    field.observe("Hello world. This is a test conversation.")
    field.observe("Language is a field. Resonance is everything.")
    field.observe("Presence is more important than intelligence.")
    
    print("=" * 60)
    print("LEO REPL EXAMPLES")
    print("=" * 60)
    print()
    
    prompts = [
        "What is resonance?",
        "Tell me about presence",
        "Who are you?",
        "What is language?",
    ]
    
    for i, prompt in enumerate(prompts, 1):
        print(f"TURN {i}")
        print(f"You: {prompt}")
        print()
        
        reply = field.reply(prompt, max_tokens=80, temperature=1.0)
        print(f"Leo: {reply}")
        print()
        
        # Show pulse if available
        if field.last_pulse:
            pulse = field.last_pulse
            print(f"📊 Pulse: novelty={pulse.novelty:.2f}, arousal={pulse.arousal:.2f}, entropy={pulse.entropy:.2f}")
        
        # Show expert if available
        if field.last_expert:
            expert = field.last_expert
            print(f"🎯 Expert: {expert.name} (temp={expert.temperature})")
        
        print()
        print("-" * 60)
        print()
        
        field.observe(reply)
    
    print("FINAL STATS")
    print(field.stats_summary())

if __name__ == "__main__":
    main()

