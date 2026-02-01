#!/usr/bin/env python3
"""
talkto.py — Talk to Leo with Go emotional resonance engine

This module:
1. Compiles the Go library if needed
2. Loads the emotional resonance engine
3. Starts an interactive chat with Leo

Usage:
    python talkto.py              # Interactive chat
    python talkto.py "Hello Leo"  # One-shot message
    python talkto.py --build      # Force rebuild Go library
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional

from inner_world_bridge import InnerWorld, build_library


# ═══════════════════════════════════════════════════════════════════════════════
# CHAT WITH LEO
# ═══════════════════════════════════════════════════════════════════════════════

def talk_to_leo(
    prompt: Optional[str] = None,
    temperature: float = 1.0,
    max_tokens: int = 60,
    force_build: bool = False,
) -> Optional[str]:
    """
    Talk to Leo with Go-accelerated emotional processing.
    
    Args:
        prompt: Message to send (None for interactive mode)
        temperature: Generation temperature
        max_tokens: Maximum response tokens
        force_build: Force rebuild Go library
    
    Returns:
        Leo's response (or None in interactive mode)
    """
    # Build Go library if needed
    if force_build:
        build_library(force=True)

    # Load emotional engine
    emotional_state = InnerWorld(auto_build=True)

    # Import Leo
    try:
        import leo
    except ImportError:
        # Add current directory to path
        sys.path.insert(0, str(Path(__file__).parent))
        import leo

    # Initialize Leo
    print("Initializing Leo...")
    conn = leo.init_db()
    leo.bootstrap_if_needed(conn)
    field = leo.LeoField(conn)

    # Show Go status
    if emotional_state.go_available:
        print(f"Go acceleration: ON (valence={emotional_state.valence:.2f}, "
              f"arousal={emotional_state.arousal:.2f})")
    else:
        print("Running in Python-only mode")
    
    # One-shot mode
    if prompt:
        field.observe(prompt)
        reply = field.reply(prompt, max_tokens=max_tokens, temperature=temperature)
        
        # Update Go emotional state
        if field.last_pulse:
            emotional_state.drift(
                field.last_pulse.arousal - 0.5,  # Map to [-0.5, 0.5]
                field.last_pulse.arousal
            )
        
        print(f"\nYou: {prompt}")
        print(f"Leo: {reply}")
        
        if emotional_state.go_available:
            attractor = emotional_state.nearest_attractor()
            print(f"\nEmotional state: {attractor} "
                  f"(v={emotional_state.valence:.2f}, a={emotional_state.arousal:.2f})")
        
        return reply
    
    # Interactive mode
    print("\n" + "=" * 60)
    print("💬 Chat with Leo (type /exit to quit)")
    print("=" * 60 + "\n")
    
    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n👋 Goodbye!")
            break
        
        if not user_input:
            continue
        
        if user_input.lower() in ["/exit", "/quit", "/q"]:
            print("👋 Goodbye!")
            break
        
        if user_input.lower() == "/stats":
            print(f"\n📊 {field.stats_summary()}")
            if emotional_state.go_available:
                print(f"Go: valence={emotional_state.valence:.2f}, "
                      f"arousal={emotional_state.arousal:.2f}, "
                      f"attractor={emotional_state.nearest_attractor()}")
            continue
        
        if user_input.lower() == "/reset":
            emotional_state.reset()
            print("🔄 Emotional state reset")
            continue
        
        # Process message
        field.observe(user_input)
        reply = field.reply(user_input, max_tokens=max_tokens, temperature=temperature)
        field.observe(reply)
        
        # Update Go emotional state
        if field.last_pulse:
            emotional_state.drift(
                field.last_pulse.arousal - 0.5,
                field.last_pulse.arousal
            )
        
        print(f"\nLeo: {reply}")
        
        # Show emotional context
        if emotional_state.go_available:
            attractor = emotional_state.nearest_attractor()
            print(f"  [{attractor}] v={emotional_state.valence:.2f} a={emotional_state.arousal:.2f}")
        
        if field.last_pulse:
            print(f"  📊 novelty={field.last_pulse.novelty:.2f} "
                  f"arousal={field.last_pulse.arousal:.2f} "
                  f"entropy={field.last_pulse.entropy:.2f}")
        
        print()
    
    return None


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Talk to Leo with Go-accelerated emotional processing"
    )
    parser.add_argument(
        "prompt",
        nargs="?",
        help="Message to send (omit for interactive mode)"
    )
    parser.add_argument(
        "--build", "-b",
        action="store_true",
        help="Force rebuild Go library"
    )
    parser.add_argument(
        "--temperature", "-t",
        type=float,
        default=1.0,
        help="Generation temperature (default: 1.0)"
    )
    parser.add_argument(
        "--max-tokens", "-m",
        type=int,
        default=60,
        help="Maximum response tokens (default: 60)"
    )
    
    args = parser.parse_args()
    
    # Just build?
    if args.build and not args.prompt:
        build_library(force=True)
        return
    
    talk_to_leo(
        prompt=args.prompt,
        temperature=args.temperature,
        max_tokens=args.max_tokens,
        force_build=args.build,
    )


if __name__ == "__main__":
    main()
