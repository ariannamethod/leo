#!/usr/bin/env python3
"""
first_impression.py — First Impression Module for Leo

Adapted from Haze's subjectivity.py, but with Leo's childlike philosophy.

When someone speaks to Leo, he first gets a "first impression" — 
a feeling about the words before he responds. Like a child who
senses the mood of a room before speaking.

Philosophy:
- NO SEED FROM PROMPT — Leo speaks from his field, not from observer's words
- PRESENCE > INTELLIGENCE — feeling before thinking
- First impression shapes the response, but doesn't dictate it

The prompt wrinkles Leo's field. The wrinkle creates a feeling.
The feeling guides where in the field Leo will speak from.

This is the difference between:
- "What is love?" → "Love is..." (echo = BAD)
- "What is love?" → "Sometimes it feels like a warm blanket..." (field = GOOD)
"""

from __future__ import annotations

import random
import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Any
from collections import Counter


# ============================================================================
# FIRST IMPRESSION — The Feeling Before Speaking
# ============================================================================

@dataclass
class Impression:
    """
    Leo's first impression of the observer's words.
    
    Like a child sensing the mood before responding.
    """
    novelty: float = 0.0     # How new/unfamiliar is this?
    arousal: float = 0.0     # How intense/emotional?
    warmth: float = 0.0      # How friendly/warm? (Leo-specific)
    curiosity: float = 0.0   # Is this a question? Wants to explore?
    
    @property
    def composite(self) -> float:
        """Composite feeling signal."""
        return 0.25 * self.novelty + 0.25 * self.arousal + 0.25 * self.warmth + 0.25 * self.curiosity
    
    def __repr__(self) -> str:
        return f"Impression(novelty={self.novelty:.2f}, arousal={self.arousal:.2f}, warmth={self.warmth:.2f}, curiosity={self.curiosity:.2f})"


# Warm words — Leo recognizes these as friendly
WARM_WORDS = {
    "love", "friend", "happy", "joy", "smile", "hug", "care", "gentle",
    "sweet", "kind", "warm", "soft", "thank", "please", "beautiful",
    "wonderful", "amazing", "lovely", "dear", "heart", "feel", "dream",
}

# Curious words — Leo recognizes questions and exploration
CURIOUS_WORDS = {
    "what", "how", "why", "who", "where", "when", "tell", "explain",
    "show", "describe", "think", "feel", "imagine", "wonder", "maybe",
    "perhaps", "could", "would", "should", "might",
}

# Intense words — High arousal signals
INTENSE_WORDS = {
    "now", "must", "need", "urgent", "important", "please", "help",
    "stop", "wait", "listen", "understand", "really", "very", "so",
    "always", "never", "everything", "nothing", "everyone", "nobody",
}


def compute_impression(
    text: str,
    vocab: Optional[List[str]] = None,
    trigrams: Optional[Dict] = None,
) -> Impression:
    """
    Compute Leo's first impression of the text.
    
    This is the "feeling" before responding — like a child
    sensing the room before speaking.
    
    Args:
        text: Observer's input
        vocab: Leo's vocabulary (for novelty calculation)
        trigrams: Leo's trigrams (for novelty calculation)
    
    Returns:
        Impression with novelty, arousal, warmth, curiosity
    """
    if not text or not text.strip():
        return Impression()
    
    # Tokenize
    words = re.findall(r'\b\w+\b', text.lower())
    
    if not words:
        return Impression()
    
    word_set = set(words)
    
    # === NOVELTY ===
    # How many words are NOT in Leo's vocabulary?
    novelty = 0.5  # Default: medium novelty
    if vocab:
        vocab_set = set(w.lower() for w in vocab)
        if word_set:
            overlap = len(word_set & vocab_set)
            novelty = 1.0 - (overlap / len(word_set))
    
    # === AROUSAL ===
    arousal = 0.0
    
    # Caps → high arousal
    caps_count = sum(1 for c in text if c.isupper())
    caps_ratio = caps_count / max(1, len(text))
    arousal += min(0.4, caps_ratio * 2)
    
    # Exclamation/question marks → arousal
    punct_count = text.count('!') + text.count('?')
    arousal += min(0.3, punct_count * 0.1)
    
    # Intense words → arousal
    intense_count = len(word_set & INTENSE_WORDS)
    arousal += min(0.3, intense_count * 0.1)
    
    arousal = min(1.0, arousal)
    
    # === WARMTH ===
    # How friendly/warm does this feel?
    warm_count = len(word_set & WARM_WORDS)
    warmth = min(1.0, warm_count * 0.15)
    
    # "Leo" mentioned → extra warmth (they're talking to him!)
    if "leo" in word_set:
        warmth = min(1.0, warmth + 0.2)
    
    # Love/heart → extra warmth
    if "love" in word_set or "heart" in word_set:
        warmth = min(1.0, warmth + 0.15)
    
    # === CURIOSITY ===
    # Is this a question? Wants to explore?
    curiosity = 0.0
    
    # Question mark → curiosity
    if "?" in text:
        curiosity += 0.4
    
    # Curious words → curiosity
    curious_count = len(word_set & CURIOUS_WORDS)
    curiosity += min(0.4, curious_count * 0.1)
    
    # "Tell me" / "What is" patterns → curiosity
    if re.search(r'\btell\s+me\b', text.lower()):
        curiosity = min(1.0, curiosity + 0.2)
    
    curiosity = min(1.0, curiosity)
    
    return Impression(
        novelty=novelty,
        arousal=arousal,
        warmth=warmth,
        curiosity=curiosity,
    )


def adjust_temperature_by_impression(
    base_temp: float,
    impression: Impression,
) -> float:
    """
    Adjust generation temperature based on first impression.
    
    - High arousal → slightly higher temp (more expressive)
    - High warmth → slightly lower temp (gentle, focused)
    - High curiosity → slightly higher temp (exploratory)
    - High novelty → slightly higher temp (creative)
    """
    temp = base_temp
    
    # Arousal increases temperature (more expressive)
    temp += impression.arousal * 0.15
    
    # Warmth decreases temperature (gentle, focused response)
    temp -= impression.warmth * 0.1
    
    # Curiosity increases temperature (exploratory)
    temp += impression.curiosity * 0.1
    
    # High novelty → more creative
    temp += impression.novelty * 0.1
    
    # Clamp to reasonable range
    return max(0.3, min(2.0, temp))


def suggest_gravity_boost(
    impression: Impression,
    emotion_map: Optional[Dict[str, float]] = None,
) -> Dict[str, float]:
    """
    Suggest token gravity boosts based on first impression.
    
    This guides Leo toward certain areas of his field
    without seeding from the prompt.
    
    For example:
    - High warmth → boost warm/gentle tokens
    - High curiosity → boost exploratory tokens
    """
    boosts: Dict[str, float] = {}
    
    if impression.warmth > 0.5:
        # Boost warm tokens
        for word in WARM_WORDS:
            boosts[word] = impression.warmth * 0.3
    
    if impression.curiosity > 0.5:
        # Boost exploratory tokens
        exploratory = ["sometimes", "maybe", "perhaps", "like", "feel", "wonder"]
        for word in exploratory:
            boosts[word] = impression.curiosity * 0.2
    
    if impression.arousal > 0.7:
        # Boost expressive tokens
        expressive = ["yes", "no", "now", "here", "this", "that"]
        for word in expressive:
            boosts[word] = impression.arousal * 0.2
    
    # If we have emotion map, boost emotionally resonant tokens
    if emotion_map and impression.warmth > 0.3:
        # Find tokens with positive emotional charge
        for token, charge in emotion_map.items():
            if charge > 0.5:  # Positive emotion
                boosts[token] = boosts.get(token, 0.0) + charge * 0.1 * impression.warmth
    
    return boosts


# ============================================================================
# Association — First Word That Comes to Mind
# ============================================================================

def get_first_association(
    impression: Impression,
    centers: List[str],
    bias: Dict[str, int],
) -> Optional[str]:
    """
    Get Leo's "first association" — the word that comes to mind
    before he starts speaking.
    
    This is NOT seeded from the prompt! It comes from Leo's field,
    but is influenced by the impression (feeling).
    
    Like a child who hears a question and immediately thinks of
    something from their own world, not from the question.
    """
    if not centers:
        return None
    
    # Filter centers by impression
    candidates = list(centers)
    
    # If warm impression, prefer warm-sounding words
    if impression.warmth > 0.5:
        warm_candidates = [c for c in candidates if c.lower() in WARM_WORDS]
        if warm_candidates:
            candidates = warm_candidates + candidates[:3]
    
    # If curious impression, prefer open-ended words
    if impression.curiosity > 0.5:
        curious_starts = ["sometimes", "maybe", "like", "when", "if"]
        curious_candidates = [c for c in candidates if c.lower() in curious_starts]
        if curious_candidates:
            candidates = curious_candidates + candidates[:3]
    
    # Weight by bias
    if bias:
        weighted = [(c, bias.get(c, 1)) for c in candidates]
        total = sum(w for _, w in weighted)
        if total > 0:
            r = random.uniform(0, total)
            acc = 0
            for c, w in weighted:
                acc += w
                if r <= acc:
                    return c
    
    # Fallback: random from candidates
    return random.choice(candidates) if candidates else None


# ============================================================================
# Demo
# ============================================================================

def demo():
    """Demo the first impression module."""
    print("=" * 60)
    print("  FIRST IMPRESSION — Leo's Feeling Before Speaking")
    print("=" * 60)
    print()
    
    test_prompts = [
        "Hello Leo, how are you?",
        "I love you!",
        "What is the meaning of life?",
        "STOP! WAIT! LISTEN TO ME!!!",
        "Tell me about your dreams...",
        "Shut up.",
    ]
    
    for prompt in test_prompts:
        impression = compute_impression(prompt)
        temp_adjust = adjust_temperature_by_impression(1.0, impression)
        
        print(f">>> \"{prompt}\"")
        print(f"    {impression}")
        print(f"    Temperature: 1.0 → {temp_adjust:.2f}")
        print()


if __name__ == "__main__":
    demo()
