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
