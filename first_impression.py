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

# Note: The Impression class is defined below after EMOTIONAL_WEIGHTS
# to allow using compute_emotional_valence() in its methods.


# ============================================================================
# EMOTIONAL WEIGHTS — Float Dictionary (inspired by arianna.c/high.go)
# ============================================================================
# Instead of binary word lists, each word has a valence weight [-1.0, 1.0]
# Positive = positive emotion, Negative = negative emotion
# This allows for nuanced emotional analysis, not just yes/no detection
#
# Philosophy: Emotions are gradients, not categories.
# ============================================================================

EMOTIONAL_WEIGHTS: Dict[str, float] = {
    # === POSITIVE (WARMTH/LOVE) ===
    "love": 0.95, "adore": 0.9, "cherish": 0.85, "devotion": 0.8,
    "affection": 0.8, "tenderness": 0.75, "care": 0.7, "warm": 0.7,
    "wonderful": 0.8, "amazing": 0.75, "beautiful": 0.8, "lovely": 0.75,
    "happy": 0.7, "joy": 0.8, "delighted": 0.75, "pleased": 0.6,
    "smile": 0.6, "hug": 0.7, "gentle": 0.6, "sweet": 0.65,
    "kind": 0.6, "soft": 0.5, "thank": 0.5, "grateful": 0.7,
    "blessed": 0.6, "peaceful": 0.5, "calm": 0.4, "serene": 0.5,
    "hope": 0.6, "dream": 0.5, "inspire": 0.6, "create": 0.5,
    "friend": 0.65, "dear": 0.6, "heart": 0.5, "feel": 0.3,
    "good": 0.4, "nice": 0.35, "fine": 0.2, "okay": 0.1,
    
    # === PLAYFUL (LEO-SPECIFIC) ===
    "play": 0.7, "fun": 0.7, "game": 0.6, "silly": 0.65,
    "laugh": 0.75, "giggle": 0.7, "joke": 0.6, "funny": 0.65,
    "magic": 0.7, "pretend": 0.5, "story": 0.5, "adventure": 0.6,
    "surprise": 0.5, "candy": 0.5, "rainbow": 0.6, "sparkle": 0.55,
    "dance": 0.6, "sing": 0.6, "bounce": 0.5,
    
    # === CURIOSITY (FLOW) ===
    "curious": 0.4, "wonder": 0.45, "explore": 0.5, "discover": 0.55,
    "mystery": 0.4, "secret": 0.35, "imagine": 0.5,
    
    # === NEGATIVE (FEAR) ===
    "fear": -0.7, "afraid": -0.7, "scared": -0.75, "terrified": -0.9,
    "anxious": -0.6, "worry": -0.5, "panic": -0.8, "dread": -0.75,
    "horror": -0.85, "nervous": -0.5, "terror": -0.9, "frightened": -0.7,
    "alarmed": -0.6, "threatened": -0.7, "unsafe": -0.65, "danger": -0.7,
    "scary": -0.6, "creepy": -0.55, "nightmare": -0.75,
    
    # === NEGATIVE (VOID/EMPTINESS) ===
    "empty": -0.5, "nothing": -0.55, "numb": -0.6, "hollow": -0.55,
    "void": -0.6, "blank": -0.4, "gone": -0.5, "lost": -0.5,
    "alone": -0.6, "lonely": -0.7, "isolated": -0.65, "disconnected": -0.6,
    "apathy": -0.5, "meaningless": -0.7, "pointless": -0.65,
    "dead": -0.8, "silent": -0.3, "cold": -0.4, "dark": -0.35,
    
    # === NEGATIVE (PAIN/SUFFERING) ===
    "hate": -0.9, "terrible": -0.8, "awful": -0.7, "horrible": -0.8,
    "disgusting": -0.85, "sad": -0.6, "angry": -0.7, "frustrated": -0.6,
    "disappointed": -0.55, "upset": -0.55, "bad": -0.5, "wrong": -0.4,
    "fail": -0.6, "lose": -0.5, "hurt": -0.7, "pain": -0.8,
    "suffer": -0.8, "stress": -0.5, "worthless": -0.85, "stupid": -0.6,
    "ugly": -0.5, "weak": -0.45, "useless": -0.7, "pathetic": -0.75,
    
    # === TRAUMA TRIGGERS ===
    "die": -0.9, "kill": -0.9, "death": -0.85, "failure": -0.7,
    "loser": -0.7, "reject": -0.65, "abandon": -0.8, "betray": -0.85,
    "forget": -0.4, "ignore": -0.5, "invisible": -0.6, "broken": -0.65,
    "damaged": -0.6, "ruined": -0.65, "trapped": -0.7, "hopeless": -0.8,
    
    # === INTENSE (HIGH AROUSAL, NEUTRAL VALENCE) ===
    # These don't shift valence but increase arousal
    "now": 0.0, "must": 0.0, "need": 0.0, "urgent": 0.0,
    "important": 0.0, "help": -0.1, "stop": -0.2, "wait": 0.0,
    "listen": 0.0, "understand": 0.1, "really": 0.0, "very": 0.0,
    "always": 0.0, "never": -0.1, "everything": 0.0, "everyone": 0.0,
    
    # === RUSSIAN (Subset from high.go) ===
    "люблю": 0.9, "радость": 0.8, "счастье": 0.85, "хорошо": 0.5,
    "спасибо": 0.5, "красиво": 0.7, "прекрасно": 0.8,
    "ненавижу": -0.9, "страшно": -0.7, "больно": -0.8, "грустно": -0.6,
    "одиноко": -0.7, "пусто": -0.5,
}

# Arousal modifiers — words that increase emotional intensity
AROUSAL_MODIFIERS: Dict[str, float] = {
    "very": 0.2, "really": 0.2, "so": 0.15, "extremely": 0.3,
    "absolutely": 0.25, "totally": 0.2, "completely": 0.2,
    "always": 0.1, "never": 0.15, "everything": 0.1, "nothing": 0.1,
    "now": 0.15, "must": 0.2, "need": 0.15, "urgent": 0.25,
    "important": 0.15, "help": 0.2, "please": 0.1,
    "!": 0.15,  # Exclamation mark
}


# ============================================================================
# AROUSAL COMPONENTS (inspired by arianna.c/mood.h)
# ============================================================================
# Arousal is not just "high/low" — it's a combination of factors:
# - TENSION: conflict, urgency, pressure
# - NOVELTY: surprise, unfamiliarity
# - FOCUS: concentration, precision
# - RECURSION: self-reference, meta-cognition
#
# Different emotions have different arousal profiles:
# - FEAR: high tension, high arousal (0.8)
# - RAGE: very high tension, very high arousal (0.9)
# - VOID: low everything, low arousal (0.1) — numbness
# - JOY: moderate arousal, high valence (0.6)
# ============================================================================

# Tension words — conflict, urgency, pressure
TENSION_WORDS: Dict[str, float] = {
    "must": 0.6, "need": 0.5, "urgent": 0.8, "now": 0.4,
    "stop": 0.7, "wait": 0.4, "hurry": 0.7, "quick": 0.5,
    "danger": 0.8, "threat": 0.7, "crisis": 0.8, "emergency": 0.9,
    "fight": 0.7, "attack": 0.8, "conflict": 0.6, "battle": 0.7,
    "pressure": 0.6, "stress": 0.5, "deadline": 0.5, "demand": 0.5,
}

# Novelty words — surprise, unfamiliarity
NOVELTY_WORDS: Dict[str, float] = {
    "surprise": 0.7, "suddenly": 0.6, "unexpected": 0.7, "shock": 0.8,
    "strange": 0.5, "weird": 0.4, "unusual": 0.5, "bizarre": 0.6,
    "new": 0.4, "different": 0.3, "unknown": 0.5, "discover": 0.5,
    "first": 0.4, "never": 0.5, "change": 0.4, "transform": 0.5,
}

# Focus words — concentration, precision
FOCUS_WORDS: Dict[str, float] = {
    "exactly": 0.5, "precisely": 0.5, "specific": 0.4, "particular": 0.4,
    "only": 0.4, "just": 0.3, "certain": 0.4, "definite": 0.5,
    "clear": 0.4, "obvious": 0.4, "sure": 0.4, "know": 0.3,
    "understand": 0.4, "realize": 0.5, "see": 0.3, "notice": 0.4,
}

# Recursion words — self-reference, meta-cognition
RECURSION_WORDS: Dict[str, float] = {
    "myself": 0.6, "yourself": 0.5, "itself": 0.5, "self": 0.6,
    "remember": 0.5, "forget": 0.5, "think": 0.4, "thought": 0.4,
    "feel": 0.4, "feeling": 0.4, "sense": 0.4, "aware": 0.5,
    "realize": 0.5, "recognize": 0.5, "reflect": 0.6, "consider": 0.4,
}


@dataclass
class ArousalComponents:
    """
    Decomposed arousal (inspired by arianna.c/mood.h).
    
    Arousal is not just "high/low" — it has multiple dimensions
    that combine to create the overall activation level.
    """
    base: float = 0.0       # Base arousal from AROUSAL_MODIFIERS
    tension: float = 0.0    # Conflict, urgency, pressure
    novelty: float = 0.0    # Surprise, unfamiliarity
    focus: float = 0.0      # Concentration, precision
    recursion: float = 0.0  # Self-reference, meta-cognition
    
    @property
    def combined(self) -> float:
        """
        Combine arousal components into single value.
        
        Formula inspired by arianna.c mood scoring:
        - Tension has highest weight (urgency drives arousal)
        - Novelty adds surprise activation
        - Focus can dampen or amplify
        - Recursion adds depth
        """
        combined = (
            self.base * 1.0 +
            self.tension * 0.8 +
            self.novelty * 0.5 +
            self.focus * 0.3 +
            self.recursion * 0.2
        )
        return max(0.0, min(1.0, combined))
    
    def __repr__(self) -> str:
        return (f"ArousalComponents(base={self.base:.2f}, tension={self.tension:.2f}, "
                f"novelty={self.novelty:.2f}, focus={self.focus:.2f}, "
                f"recursion={self.recursion:.2f}, combined={self.combined:.2f})")


def compute_arousal_components(text: str) -> ArousalComponents:
    """
    Compute decomposed arousal components from text.
    
    Inspired by arianna.c/mood.h — arousal is not just high/low,
    it's a combination of tension, novelty, focus, and recursion.
    
    Returns:
        ArousalComponents with all dimensions
    """
    words = text.lower().split()
    
    if not words:
        return ArousalComponents()
    
    components = ArousalComponents()
    
    for word in words:
        clean_word = word.strip(".,;:?\"'()-")
        
        # Base arousal from modifiers
        if clean_word in AROUSAL_MODIFIERS:
            components.base += AROUSAL_MODIFIERS[clean_word]
        
        # Tension component
        if clean_word in TENSION_WORDS:
            components.tension += TENSION_WORDS[clean_word]
        
        # Novelty component
        if clean_word in NOVELTY_WORDS:
            components.novelty += NOVELTY_WORDS[clean_word]
        
        # Focus component
        if clean_word in FOCUS_WORDS:
            components.focus += FOCUS_WORDS[clean_word]
        
        # Recursion component
        if clean_word in RECURSION_WORDS:
            components.recursion += RECURSION_WORDS[clean_word]
        
        # Exclamation marks increase base arousal
        if "!" in word:
            components.base += 0.15
    
    # Normalize by word count (more words = more opportunity for arousal)
    # But cap each component at 1.0
    components.base = min(1.0, components.base)
    components.tension = min(1.0, components.tension)
    components.novelty = min(1.0, components.novelty)
    components.focus = min(1.0, components.focus)
    components.recursion = min(1.0, components.recursion)
    
    return components


def compute_emotional_valence(text: str) -> Tuple[float, float]:
    """
    Compute emotional valence and arousal from text using EMOTIONAL_WEIGHTS.
    
    Returns:
        (valence, arousal) where:
        - valence: [-1, 1] negative to positive
        - arousal: [0, 1] calm to excited (now using ArousalComponents!)
    """
    words = text.lower().split()
    
    if not words:
        return 0.0, 0.0
    
    valence_sum = 0.0
    valence_count = 0
    
    for word in words:
        # Clean punctuation except for exclamation
        clean_word = word.strip(".,;:?\"'()-")
        
        # Check emotional weight
        if clean_word in EMOTIONAL_WEIGHTS:
            valence_sum += EMOTIONAL_WEIGHTS[clean_word]
            valence_count += 1
    
    # Compute average valence
    valence = valence_sum / valence_count if valence_count > 0 else 0.0
    
    # Use sophisticated arousal computation (inspired by arianna.c)
    arousal_components = compute_arousal_components(text)
    arousal = arousal_components.combined
    
    # Clamp values
    valence = max(-1.0, min(1.0, valence))
    arousal = max(0.0, min(1.0, arousal))
    
    return valence, arousal


def compute_emotional_valence_detailed(text: str) -> Tuple[float, ArousalComponents]:
    """
    Compute emotional valence with detailed arousal breakdown.
    
    Returns:
        (valence, ArousalComponents) for more nuanced analysis
    """
    words = text.lower().split()
    
    if not words:
        return 0.0, ArousalComponents()
    
    valence_sum = 0.0
    valence_count = 0
    
    for word in words:
        clean_word = word.strip(".,;:?\"'()-")
        if clean_word in EMOTIONAL_WEIGHTS:
            valence_sum += EMOTIONAL_WEIGHTS[clean_word]
            valence_count += 1
    
    valence = valence_sum / valence_count if valence_count > 0 else 0.0
    valence = max(-1.0, min(1.0, valence))
    
    arousal_components = compute_arousal_components(text)
    
    return valence, arousal_components


# ============================================================================
# LEGACY BINARY WORD LISTS (kept for backward compatibility)
# These are still used by some functions but will be phased out
# ============================================================================

# Warm words — Leo recognizes these as friendly (LOVE chamber)
WARM_WORDS = {
    "love", "friend", "happy", "joy", "smile", "hug", "care", "gentle",
    "sweet", "kind", "warm", "soft", "thank", "please", "beautiful",
    "wonderful", "amazing", "lovely", "dear", "heart", "feel", "dream",
    "tenderness", "devotion", "affection", "cherish", "adore",
}

# Curious words — Leo recognizes questions and exploration (FLOW chamber)
CURIOUS_WORDS = {
    "what", "how", "why", "who", "where", "when", "tell", "explain",
    "show", "describe", "think", "feel", "imagine", "wonder", "maybe",
    "perhaps", "could", "would", "should", "might", "curious", "explore",
    "discover", "surprise", "mystery", "secret",
}

# Intense words — High arousal signals
INTENSE_WORDS = {
    "now", "must", "need", "urgent", "important", "please", "help",
    "stop", "wait", "listen", "understand", "really", "very", "so",
    "always", "never", "everything", "nothing", "everyone", "nobody",
}

# Fear words — Leo senses anxiety/fear (FEAR chamber from CLOUD)
FEAR_WORDS = {
    "fear", "afraid", "scared", "terrified", "anxious", "worry", "panic",
    "dread", "horror", "nervous", "terror", "frightened", "alarmed",
    "threatened", "unsafe", "danger", "scary", "creepy", "nightmare",
}

# Void words — Leo senses emptiness/numbness (VOID chamber from CLOUD)
VOID_WORDS = {
    "empty", "nothing", "numb", "hollow", "void", "blank", "gone",
    "lost", "alone", "lonely", "isolated", "disconnected", "apathy",
    "meaningless", "pointless", "dead", "silent", "cold", "dark",
}

# Playful words — Leo's childlike nature (unique to Leo!)
PLAYFUL_WORDS = {
    "play", "fun", "game", "silly", "laugh", "giggle", "joke", "funny",
    "magic", "pretend", "imagine", "story", "adventure", "surprise",
    "candy", "rainbow", "sparkle", "dance", "sing", "bounce",
}


# ============================================================================
# EMOTIONAL ATTRACTORS (inspired by arianna.c/emotional_drift.go)
# ============================================================================
# Emotions don't just drift — they're pulled toward "attractor" states.
# Some emotions are "sticky" (hard to leave), others are transitional.
#
# Each attractor has:
# - Position: (valence, arousal) in emotional space
# - Strength: how strongly it pulls
# - Sticky: how hard to leave once reached (0-1)
#
# Examples from arianna.c:
# - Void is very sticky (0.7) — depression is hard to escape
# - Excitement is not sticky (0.2) — it fades quickly
# ============================================================================

@dataclass
class EmotionalAttractor:
    """
    An attractor in emotional space that pulls the state toward it.
    Inspired by arianna.c/emotional_drift.go.
    """
    name: str
    valence: float      # -1 to 1
    arousal: float      # 0 to 1
    strength: float     # how strongly it pulls (0-1)
    sticky: float       # how hard to leave once reached (0-1)


# Define emotional attractors (from arianna.c)
EMOTIONAL_ATTRACTORS: List[EmotionalAttractor] = [
    # Positive states
    EmotionalAttractor("joy", valence=0.7, arousal=0.6, strength=0.3, sticky=0.3),
    EmotionalAttractor("contentment", valence=0.5, arousal=0.2, strength=0.4, sticky=0.5),
    EmotionalAttractor("excitement", valence=0.8, arousal=0.8, strength=0.2, sticky=0.2),
    EmotionalAttractor("warmth", valence=0.6, arousal=0.3, strength=0.3, sticky=0.4),
    
    # Negative states
    EmotionalAttractor("sadness", valence=-0.6, arousal=0.2, strength=0.4, sticky=0.6),
    EmotionalAttractor("fear", valence=-0.7, arousal=0.8, strength=0.3, sticky=0.3),
    EmotionalAttractor("rage", valence=-0.8, arousal=0.9, strength=0.25, sticky=0.2),
    EmotionalAttractor("void", valence=-0.4, arousal=0.1, strength=0.5, sticky=0.7),  # Very sticky!
    
    # Neutral/flow states
    EmotionalAttractor("flow", valence=0.1, arousal=0.4, strength=0.35, sticky=0.4),
    EmotionalAttractor("neutral", valence=0.0, arousal=0.3, strength=0.3, sticky=0.3),
    EmotionalAttractor("curiosity", valence=0.2, arousal=0.5, strength=0.25, sticky=0.35),
    
    # Leo-specific: Playful!
    EmotionalAttractor("playful", valence=0.5, arousal=0.7, strength=0.3, sticky=0.25),
]


def find_nearest_attractor(valence: float, arousal: float) -> EmotionalAttractor:
    """
    Find the nearest emotional attractor to current position.
    """
    import math
    
    nearest = EMOTIONAL_ATTRACTORS[0]
    min_dist = float('inf')
    
    for attractor in EMOTIONAL_ATTRACTORS:
        dv = attractor.valence - valence
        da = attractor.arousal - arousal
        dist = math.sqrt(dv * dv + da * da)
        
        if dist < min_dist:
            min_dist = dist
            nearest = attractor
    
    return nearest


def compute_attractor_pull(valence: float, arousal: float) -> Tuple[float, float]:
    """
    Compute the combined pull from all attractors.
    Returns (delta_valence, delta_arousal).
    
    Inspired by arianna.c/emotional_drift.go computeAttractorGradient().
    """
    import math
    
    total_dv = 0.0
    total_da = 0.0
    total_weight = 0.0
    
    for attractor in EMOTIONAL_ATTRACTORS:
        # Distance to attractor
        dv = attractor.valence - valence
        da = attractor.arousal - arousal
        dist = math.sqrt(dv * dv + da * da)
        
        if dist < 0.01:
            continue
        
        # Pull strength (inverse distance with cutoff)
        pull = attractor.strength / (dist + 0.5)
        
        # If close and sticky, reduce outward pull
        if dist < 0.2:
            pull *= (1 - attractor.sticky)
        
        # Accumulate gradient
        weight = pull
        total_dv += (dv / dist) * weight
        total_da += (da / dist) * weight
        total_weight += weight
    
    if total_weight > 0:
        return total_dv / total_weight, total_da / total_weight
    return 0.0, 0.0


# ============================================================================
# EMOTIONAL STATE & DRIFT ODE (inspired by arianna.c/high.go)
# ============================================================================
# Emotions evolve through differential equations, not discrete jumps.
# Based on Friston's Free Energy Principle:
# - dV/dt = -τ(V - V₀) + surprise * gain
# - dA/dt = -τ(A - A₀) + |surprise| * gain + entropy * weight
#
# Philosophy: Leo "remembers" emotional state between messages.
# Emotional momentum creates more natural, human-like responses.
# ============================================================================

@dataclass
class EmotionalState:
    """
    Leo's emotional state that persists across messages.
    
    Unlike Impression (single message), EmotionalState tracks
    the emotional trajectory over a conversation.
    """
    valence: float = 0.1      # [-1, 1] negative to positive
    arousal: float = 0.3      # [0, 1] calm to excited
    entropy: float = 0.5      # [0, inf] uncertainty/chaos
    prediction: float = 0.1   # Expected valence for next message (for surprise calc)
    
    # Conversation momentum
    momentum: float = 0.0     # Rate of valence change
    message_count: int = 0    # How many messages processed
    
    def copy(self) -> "EmotionalState":
        """Create a copy of this state."""
        return EmotionalState(
            valence=self.valence,
            arousal=self.arousal,
            entropy=self.entropy,
            prediction=self.prediction,
            momentum=self.momentum,
            message_count=self.message_count,
        )


@dataclass
class EmotionalDriftParams:
    """Parameters controlling the ODE dynamics."""
    decay_rate: float = 0.15      # Return to baseline speed (τ) — increased for faster response
    surprise_gain: float = 0.5    # How much surprise affects state — increased for sensitivity
    input_pull: float = 0.3       # Direct influence of input valence (NEW)
    attractor_gravity: float = 0.1  # Pull toward emotional attractors (NEW from arianna.c)
    entropy_weight: float = 0.2   # Entropy influence on arousal
    momentum_decay: float = 0.3   # Momentum persistence — decreased for less inertia
    baseline_valence: float = 0.1 # Resting valence (slightly positive)
    baseline_arousal: float = 0.3 # Resting arousal (calm but alert)


# Global default params
DEFAULT_DRIFT_PARAMS = EmotionalDriftParams()


def emotional_drift(
    current: EmotionalState,
    input_text: str,
    dt: float = 1.0,
    params: Optional[EmotionalDriftParams] = None,
) -> EmotionalState:
    """
    Compute the next emotional state using ODE (Euler method).
    
    Based on Free Energy Principle from arianna.c/high.go:
    - dV/dt = -τ(V - V₀) + surprise * gain + momentum
    - dA/dt = -τ(A - A₀) + |surprise| * gain + entropy * weight
    
    Args:
        current: Current emotional state
        input_text: New input to process
        dt: Time step (1.0 = one message)
        params: ODE parameters (uses defaults if None)
    
    Returns:
        New emotional state after drift
    """
    if params is None:
        params = DEFAULT_DRIFT_PARAMS
    
    # Analyze input using EMOTIONAL_WEIGHTS + sophisticated arousal
    input_valence, input_arousal = compute_emotional_valence(input_text)
    
    # Compute surprise (prediction error) — Free Energy Principle
    surprise = input_valence - current.prediction
    
    # Compute attractor gradient (from arianna.c/emotional_drift.go)
    attractor_dv, attractor_da = compute_attractor_pull(current.valence, current.arousal)
    
    # ODE integration (Euler method)
    
    # dV/dt = decay toward baseline + surprise influence + input pull + attractor pull + momentum
    d_valence = (
        -params.decay_rate * (current.valence - params.baseline_valence) +
        surprise * params.surprise_gain +
        (input_valence - current.valence) * params.input_pull +
        attractor_dv * params.attractor_gravity +  # NEW: attractor pull
        current.momentum * 0.3
    )
    
    # dA/dt = decay toward baseline + |surprise| + input arousal + attractor pull
    d_arousal = (
        -params.decay_rate * (current.arousal - params.baseline_arousal) +
        abs(surprise) * params.surprise_gain +
        input_arousal * params.entropy_weight +
        attractor_da * params.attractor_gravity  # NEW: attractor pull
    )
    
    # Update momentum (tracks rate of change)
    new_momentum = (
        current.momentum * params.momentum_decay +
        d_valence * (1 - params.momentum_decay)
    )
    
    # Update state
    next_state = EmotionalState(
        valence=max(-1.0, min(1.0, current.valence + d_valence * dt)),
        arousal=max(0.0, min(1.0, current.arousal + d_arousal * dt)),
        entropy=current.entropy * 0.9 + input_arousal * 0.1,  # Slow update
        prediction=current.valence + d_valence * dt * 0.5,  # Predict next valence
        momentum=new_momentum,
        message_count=current.message_count + 1,
    )
    
    return next_state


def compute_surprise(expected_valence: float, actual_valence: float) -> float:
    """
    Compute surprise (prediction error) — Free Energy Principle.
    
    Lower = better prediction, Higher = more surprise.
    """
    return abs(expected_valence - actual_valence)


# Global emotional state (persists across calls)
_global_emotional_state: Optional[EmotionalState] = None


def get_emotional_state() -> EmotionalState:
    """Get the global emotional state, creating if needed."""
    global _global_emotional_state
    if _global_emotional_state is None:
        _global_emotional_state = EmotionalState()
    return _global_emotional_state


def update_emotional_state(input_text: str) -> EmotionalState:
    """
    Update the global emotional state with new input.
    
    This is the main entry point for the ODE-based emotional system.
    Call this for each new message to evolve Leo's emotional state.
    """
    global _global_emotional_state
    
    current = get_emotional_state()
    next_state = emotional_drift(current, input_text)
    _global_emotional_state = next_state
    
    return next_state


def reset_emotional_state() -> None:
    """Reset emotional state to baseline (new conversation)."""
    global _global_emotional_state
    _global_emotional_state = None


# ============================================================================
# IMPRESSION CLASS (enhanced with EmotionalWeights integration)
# ============================================================================

@dataclass
class Impression:
    """
    Leo's first impression of the observer's words.
    
    Like a child sensing the mood before responding.
    Now with emotion chambers inspired by CLOUD (but weightless!).
    """
    novelty: float = 0.0     # How new/unfamiliar is this?
    arousal: float = 0.0     # How intense/emotional?
    warmth: float = 0.0      # How friendly/warm? (LOVE)
    curiosity: float = 0.0   # Is this a question? (FLOW)
    fear: float = 0.0        # Anxiety/fear signals (FEAR)
    void: float = 0.0        # Emptiness/numbness (VOID)
    playful: float = 0.0     # Playful/silly energy (LEO-specific!)
    
    # Anomaly flags (pure heuristics, no training)
    anomaly: Optional[str] = None
    
    @property
    def composite(self) -> float:
        """Composite feeling signal."""
        return (0.2 * self.novelty + 0.15 * self.arousal + 
                0.2 * self.warmth + 0.15 * self.curiosity +
                0.1 * self.playful - 0.1 * self.fear - 0.1 * self.void)
    
    @property
    def dominant_chamber(self) -> str:
        """Which chamber is strongest?"""
        chambers = {
            'warmth': self.warmth,
            'curiosity': self.curiosity,
            'fear': self.fear,
            'void': self.void,
            'playful': self.playful,
        }
        return max(chambers, key=chambers.get)
    
    def __repr__(self) -> str:
        base = f"Impression(warmth={self.warmth:.2f}, curiosity={self.curiosity:.2f}, fear={self.fear:.2f}, void={self.void:.2f}, playful={self.playful:.2f})"
        if self.anomaly:
            base += f" [ANOMALY: {self.anomaly}]"
        return base


def _cross_fire(impression: Impression) -> Impression:
    """
    Cross-fire between chambers — they influence each other.
    
    Inspired by CLOUD's coupling matrix, but simplified for Leo.
    Philosophy: Emotions don't exist in isolation.
    
    Cross-fire rules (weightless heuristics):
    - Warmth suppresses fear and void
    - Fear suppresses warmth and playful
    - Playful suppresses fear and void
    - Void suppresses warmth and playful
    """
    # Warmth suppresses fear and void
    if impression.warmth > 0.3:
        impression.fear = max(0, impression.fear - impression.warmth * 0.3)
        impression.void = max(0, impression.void - impression.warmth * 0.4)
    
    # Fear suppresses warmth and playful
    if impression.fear > 0.3:
        impression.warmth = max(0, impression.warmth - impression.fear * 0.2)
        impression.playful = max(0, impression.playful - impression.fear * 0.4)
    
    # Playful suppresses fear and void (child's resilience!)
    if impression.playful > 0.3:
        impression.fear = max(0, impression.fear - impression.playful * 0.3)
        impression.void = max(0, impression.void - impression.playful * 0.5)
    
    # Void suppresses warmth and playful
    if impression.void > 0.3:
        impression.warmth = max(0, impression.warmth - impression.void * 0.3)
        impression.playful = max(0, impression.playful - impression.void * 0.4)
    
    return impression


def _detect_anomaly(impression: Impression, text: str) -> Optional[str]:
    """
    Detect emotional anomalies — pure heuristics, no training.
    
    Inspired by CLOUD's anomaly detection.
    """
    # Forced stability: high arousal + contradictory signals
    if impression.arousal > 0.6 and impression.warmth > 0.5 and impression.fear > 0.3:
        return "forced_stability"  # "I'M FINE" energy
    
    # Dissociative: high void + high arousal
    if impression.void > 0.4 and impression.arousal > 0.5:
        return "dissociative"  # Overwhelm → numbness
    
    # Confusion: all chambers low
    if (impression.warmth < 0.2 and impression.curiosity < 0.2 and 
        impression.fear < 0.2 and impression.void < 0.2 and impression.playful < 0.2):
        return "flat"  # No clear signal
    
    # Mixed signals: fear + warmth high together
    if impression.fear > 0.4 and impression.warmth > 0.4:
        return "ambivalent"  # Approach-avoidance conflict
    
    return None


def compute_impression(
    text: str,
    vocab: Optional[List[str]] = None,
    trigrams: Optional[Dict] = None,
) -> Impression:
    """
    Compute Leo's first impression of the text.
    
    This is the "feeling" before responding — like a child
    sensing the room before speaking.
    
    Now with 6 chambers (inspired by CLOUD but weightless):
    - warmth (LOVE)
    - curiosity (FLOW) 
    - fear (FEAR)
    - void (VOID)
    - playful (LEO-specific!)
    - arousal (intensity)
    
    Args:
        text: Observer's input
        vocab: Leo's vocabulary (for novelty calculation)
        trigrams: Leo's trigrams (for novelty calculation)
    
    Returns:
        Impression with all chambers + anomaly detection
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
    
    # === WARMTH (LOVE chamber) ===
    warm_count = len(word_set & WARM_WORDS)
    warmth = min(1.0, warm_count * 0.15)
    
    # "Leo" mentioned → extra warmth
    if "leo" in word_set:
        warmth = min(1.0, warmth + 0.2)
    
    # Love/heart → extra warmth
    if "love" in word_set or "heart" in word_set:
        warmth = min(1.0, warmth + 0.15)
    
    # === CURIOSITY (FLOW chamber) ===
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
    
    # === FEAR (FEAR chamber) ===
    fear_count = len(word_set & FEAR_WORDS)
    fear = min(1.0, fear_count * 0.2)
    
    # Negative patterns → fear
    if re.search(r'\b(don\'t|can\'t|won\'t|never|stop)\b', text.lower()):
        fear = min(1.0, fear + 0.1)
    
    # === VOID (VOID chamber) ===
    void_count = len(word_set & VOID_WORDS)
    void = min(1.0, void_count * 0.2)
    
    # "nothing", "empty" patterns → void
    if "nothing" in word_set or "empty" in word_set:
        void = min(1.0, void + 0.2)
    
    # === PLAYFUL (LEO-specific!) ===
    playful_count = len(word_set & PLAYFUL_WORDS)
    playful = min(1.0, playful_count * 0.15)
    
    # Emojis or playful punctuation → playful
    if re.search(r'[😊🎉💕❤️😄🌟✨]|haha|lol|:D|:\)|<3', text):
        playful = min(1.0, playful + 0.3)
    
    # Create impression
    impression = Impression(
        novelty=novelty,
        arousal=arousal,
        warmth=warmth,
        curiosity=curiosity,
        fear=fear,
        void=void,
        playful=playful,
    )
    
    # Apply cross-fire between chambers
    impression = _cross_fire(impression)
    
    # Detect anomalies
    impression.anomaly = _detect_anomaly(impression, text)
    
    return impression


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
# FEEDBACK LOOP — Learning From Responses
# ============================================================================

@dataclass
class ImpressionFeedback:
    """
    Feedback after Leo responds — was the first impression helpful?
    
    This creates a feedback loop: impression → generation → quality → update
    """
    impression: Impression
    response_quality: float  # 0-1: how good was the response?
    response_entropy: float  # 0-1: how scattered was generation?
    stuck: bool = False      # Did generation get stuck in loop?
    
    @property
    def impression_accuracy(self) -> float:
        """
        How accurate was the first impression?
        
        High quality + low entropy = impression helped!
        Low quality + high entropy = impression misled!
        """
        if self.stuck:
            return 0.0  # Stuck = impression definitely wrong
        
        # Quality and low entropy = good
        return self.response_quality * (1.0 - self.response_entropy * 0.5)


class ImpressionMemory:
    """
    Memory of past impressions and their outcomes.
    
    Used to adjust future impressions based on what worked.
    Inspired by CLOUD's user fingerprint, but simpler.
    
    Philosophy: Leo learns which feelings lead to good responses.
    """
    
    def __init__(self, decay: float = 0.95, max_history: int = 50):
        self.decay = decay
        self.max_history = max_history
        
        # Track which chambers lead to good/bad responses
        # {chamber_name: running_average_of_accuracy}
        self.chamber_accuracy: Dict[str, float] = {
            'warmth': 0.5,
            'curiosity': 0.5,
            'fear': 0.5,
            'void': 0.5,
            'playful': 0.5,
        }
        
        # History of recent feedbacks
        self.history: List[ImpressionFeedback] = []
        
        # Stats
        self.total_feedbacks: int = 0
        self.total_stuck: int = 0
    
    def record_feedback(self, feedback: ImpressionFeedback) -> None:
        """
        Record feedback from a response.
        
        Updates chamber accuracy based on which chamber was dominant
        and how well the response turned out.
        """
        self.total_feedbacks += 1
        if feedback.stuck:
            self.total_stuck += 1
        
        # Add to history
        self.history.append(feedback)
        if len(self.history) > self.max_history:
            self.history.pop(0)
        
        # Get dominant chamber
        dominant = feedback.impression.dominant_chamber
        
        # Update accuracy with exponential moving average
        accuracy = feedback.impression_accuracy
        old_acc = self.chamber_accuracy.get(dominant, 0.5)
        new_acc = self.decay * old_acc + (1 - self.decay) * accuracy
        self.chamber_accuracy[dominant] = new_acc
    
    def adjust_impression(self, impression: Impression) -> Impression:
        """
        Adjust impression based on learned chamber accuracies.
        
        If a chamber has been leading to bad responses, dampen it.
        If a chamber has been leading to good responses, trust it more.
        """
        # Adjust each chamber by its learned accuracy
        # Low accuracy = dampen, high accuracy = trust
        
        # Warmth adjustment
        warmth_factor = self.chamber_accuracy.get('warmth', 0.5) + 0.5  # 0.5-1.5
        impression.warmth *= min(1.2, warmth_factor)
        
        # Curiosity adjustment
        curiosity_factor = self.chamber_accuracy.get('curiosity', 0.5) + 0.5
        impression.curiosity *= min(1.2, curiosity_factor)
        
        # Fear adjustment (invert: low accuracy means fear is causing problems)
        fear_factor = 1.5 - self.chamber_accuracy.get('fear', 0.5)  # 1.0-1.5
        impression.fear *= max(0.5, 2.0 - fear_factor)  # Dampen if causing problems
        
        # Void adjustment (similar to fear)
        void_factor = 1.5 - self.chamber_accuracy.get('void', 0.5)
        impression.void *= max(0.5, 2.0 - void_factor)
        
        # Playful adjustment
        playful_factor = self.chamber_accuracy.get('playful', 0.5) + 0.5
        impression.playful *= min(1.2, playful_factor)
        
        # Clamp all values
        impression.warmth = min(1.0, max(0.0, impression.warmth))
        impression.curiosity = min(1.0, max(0.0, impression.curiosity))
        impression.fear = min(1.0, max(0.0, impression.fear))
        impression.void = min(1.0, max(0.0, impression.void))
        impression.playful = min(1.0, max(0.0, impression.playful))
        
        return impression
    
    def get_stats(self) -> Dict[str, Any]:
        """Get memory statistics."""
        return {
            'total_feedbacks': self.total_feedbacks,
            'total_stuck': self.total_stuck,
            'stuck_ratio': self.total_stuck / max(1, self.total_feedbacks),
            'chamber_accuracy': dict(self.chamber_accuracy),
            'history_size': len(self.history),
        }


# Global impression memory (persists across turns)
_impression_memory: Optional[ImpressionMemory] = None


def get_impression_memory() -> ImpressionMemory:
    """Get or create the global impression memory."""
    global _impression_memory
    if _impression_memory is None:
        _impression_memory = ImpressionMemory()
    return _impression_memory


def compute_impression_with_memory(
    text: str,
    vocab: Optional[List[str]] = None,
    trigrams: Optional[Dict] = None,
) -> Impression:
    """
    Compute impression with feedback loop adjustment.
    
    Uses ImpressionMemory to adjust based on what worked before.
    """
    # Compute base impression
    impression = compute_impression(text, vocab, trigrams)
    
    # Adjust based on memory
    memory = get_impression_memory()
    impression = memory.adjust_impression(impression)
    
    return impression


def record_response_feedback(
    impression: Impression,
    quality: float,
    entropy: float,
    stuck: bool = False,
) -> None:
    """
    Record feedback after Leo responds.
    
    Call this after generate_reply() with the quality score
    to complete the feedback loop.
    """
    feedback = ImpressionFeedback(
        impression=impression,
        response_quality=quality,
        response_entropy=entropy,
        stuck=stuck,
    )
    
    memory = get_impression_memory()
    memory.record_feedback(feedback)


# ============================================================================
# Demo
# ============================================================================

def demo():
    """Demo the first impression module with all chambers."""
    print("=" * 60)
    print("  FIRST IMPRESSION — Leo's Feeling Before Speaking")
    print("  Now with 6 chambers + cross-fire + anomaly detection!")
    print("=" * 60)
    print()
    
    test_prompts = [
        "Hello Leo, how are you?",
        "I love you so much! ❤️",
        "What is the meaning of life?",
        "STOP! WAIT! LISTEN TO ME!!!",
        "Tell me about your dreams...",
        "I'm feeling so scared and anxious...",
        "Everything feels empty and meaningless.",
        "Let's play a game! This is fun! 🎉",
        "I'm fine. Everything is great. Really.",  # Forced stability
    ]
    
    for prompt in test_prompts:
        impression = compute_impression(prompt)
        temp_adjust = adjust_temperature_by_impression(1.0, impression)
        
        print(f">>> \"{prompt}\"")
        print(f"    Dominant: {impression.dominant_chamber}")
        print(f"    Chambers: warmth={impression.warmth:.2f} curiosity={impression.curiosity:.2f} fear={impression.fear:.2f} void={impression.void:.2f} playful={impression.playful:.2f}")
        if impression.anomaly:
            print(f"    ⚠️ ANOMALY: {impression.anomaly}")
        print(f"    Temperature: 1.0 → {temp_adjust:.2f}")
        print()


if __name__ == "__main__":
    demo()
