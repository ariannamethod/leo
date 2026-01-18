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

import os
import sys
import subprocess
from pathlib import Path
from typing import Optional
from ctypes import cdll, c_float, c_char_p, POINTER, byref

# ═══════════════════════════════════════════════════════════════════════════════
# GO LIBRARY MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

INNER_WORLD_DIR = Path(__file__).parent / "inner_world"
GO_SOURCE = INNER_WORLD_DIR / "emotional_resonance.go"
SO_FILE = INNER_WORLD_DIR / "libleo_inner.so"
H_FILE = INNER_WORLD_DIR / "libleo_inner.h"


def check_go_installed() -> bool:
    """Check if Go is installed."""
    try:
        result = subprocess.run(
            ["go", "version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def needs_rebuild() -> bool:
    """Check if Go library needs to be rebuilt."""
    if not SO_FILE.exists():
        return True
    
    if not GO_SOURCE.exists():
        return False
    
    # Rebuild if source is newer than binary
    return GO_SOURCE.stat().st_mtime > SO_FILE.stat().st_mtime


def build_go_library(force: bool = False) -> bool:
    """
    Build the Go emotional resonance library.
    
    Returns:
        True if build succeeded or library exists, False otherwise
    """
    if not force and SO_FILE.exists() and not needs_rebuild():
        print("✅ Go library already built: inner_world/libleo_inner.so")
        return True
    
    if not GO_SOURCE.exists():
        print("⚠️  Go source not found: inner_world/emotional_resonance.go")
        print("    Running without Go acceleration (Python fallback)")
        return False
    
    if not check_go_installed():
        print("⚠️  Go not installed. Running without Go acceleration.")
        print("    Install Go: https://golang.org/dl/")
        return False
    
    print("🔨 Building Go emotional resonance engine...")
    
    try:
        result = subprocess.run(
            ["go", "build", "-buildmode=c-shared", "-o", str(SO_FILE), str(GO_SOURCE)],
            cwd=str(INNER_WORLD_DIR),
            capture_output=True,
            text=True,
            timeout=120,
        )
        
        if result.returncode == 0:
            print("✅ Built: inner_world/libleo_inner.so")
            return True
        else:
            print(f"❌ Build failed: {result.stderr}")
            return False
            
    except subprocess.TimeoutExpired:
        print("❌ Build timed out")
        return False
    except Exception as e:
        print(f"❌ Build error: {e}")
        return False


def load_go_library() -> Optional[object]:
    """
    Load the Go library if available.
    
    Returns:
        ctypes library object or None
    """
    if not SO_FILE.exists():
        return None
    
    try:
        lib = cdll.LoadLibrary(str(SO_FILE))
        
        # Configure function signatures
        lib.leo_get_valence.restype = c_float
        lib.leo_get_arousal.restype = c_float
        lib.leo_find_nearest_attractor.restype = c_char_p
        
        return lib
    except Exception as e:
        print(f"⚠️  Could not load Go library: {e}")
        return None


# ═══════════════════════════════════════════════════════════════════════════════
# GO-ACCELERATED EMOTIONAL STATE
# ═══════════════════════════════════════════════════════════════════════════════

class GoEmotionalState:
    """
    Emotional state backed by Go library.
    Falls back to Python if Go not available.
    """
    
    def __init__(self, lib: Optional[object] = None):
        self.lib = lib
        self._python_valence = 0.1
        self._python_arousal = 0.3
    
    @property
    def valence(self) -> float:
        if self.lib:
            return float(self.lib.leo_get_valence())
        return self._python_valence
    
    @property
    def arousal(self) -> float:
        if self.lib:
            return float(self.lib.leo_get_arousal())
        return self._python_arousal
    
    def drift(self, input_valence: float, input_arousal: float):
        """Update emotional state with new input."""
        if self.lib:
            self.lib.leo_emotional_drift(c_float(input_valence), c_float(input_arousal))
        else:
            # Simple Python fallback
            self._python_valence = self._python_valence * 0.7 + input_valence * 0.3
            self._python_arousal = self._python_arousal * 0.7 + input_arousal * 0.3
    
    def reset(self):
        """Reset to baseline."""
        if self.lib:
            self.lib.leo_reset_state()
        else:
            self._python_valence = 0.1
            self._python_arousal = 0.3
    
    def nearest_attractor(self) -> str:
        """Find nearest emotional attractor."""
        if self.lib:
            result = self.lib.leo_find_nearest_attractor(
                c_float(self.valence),
                c_float(self.arousal)
            )
            return result.decode() if result else "neutral"
        
        # Python fallback
        if self.valence > 0.5:
            return "joy" if self.arousal > 0.5 else "contentment"
        elif self.valence < -0.5:
            return "fear" if self.arousal > 0.5 else "void"
        else:
            return "neutral"


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
    build_go_library(force=force_build)
    
    # Load Go library
    lib = load_go_library()
    emotional_state = GoEmotionalState(lib)
    
    # Import Leo
    try:
        import leo
    except ImportError:
        # Add current directory to path
        sys.path.insert(0, str(Path(__file__).parent))
        import leo
    
    # Initialize Leo
    print("🌊 Initializing Leo...")
    conn = leo.init_db()
    leo.bootstrap_if_needed(conn)
    field = leo.LeoField(conn)
    
    # Show Go status
    if lib:
        print(f"⚡ Go acceleration: ON (valence={emotional_state.valence:.2f}, "
              f"arousal={emotional_state.arousal:.2f})")
    else:
        print("🐍 Running in Python-only mode")
    
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
        
        if lib:
            attractor = emotional_state.nearest_attractor()
            print(f"\n🎭 Emotional state: {attractor} "
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
            if lib:
                print(f"🎭 Go: valence={emotional_state.valence:.2f}, "
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
        if lib:
            attractor = emotional_state.nearest_attractor()
            print(f"  🎭 [{attractor}] v={emotional_state.valence:.2f} a={emotional_state.arousal:.2f}")
        
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
        build_go_library(force=True)
        return
    
    talk_to_leo(
        prompt=args.prompt,
        temperature=args.temperature,
        max_tokens=args.max_tokens,
        force_build=args.build,
    )


if __name__ == "__main__":
    main()
