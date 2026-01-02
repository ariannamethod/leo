#!/usr/bin/env python3
"""
gravity.py — Gravitational Field Bias for Leo

Adapted from Haze's nn.py and rrpram.py.

Philosophy: The prompt "wrinkles" Leo's field, creating gravitational
attraction toward relevant patterns WITHOUT seeding from the prompt itself.

Leo still speaks FROM HIS FIELD (no seed from prompt), but the prompt
creates bias toward certain areas of that field.

This is like asking a question in a room — the question doesn't put words
in Leo's mouth, but it makes certain memories more likely to surface.

Usage:
    from gravity import compute_prompt_gravity, apply_gravity_to_candidates
    
    # Compute gravity weights from prompt
    gravity = compute_prompt_gravity(prompt, subword_field)
    
    # Apply to candidate tokens during generation
    biased_candidates = apply_gravity_to_candidates(candidates, gravity)
"""

import re
from typing import Dict, List, Optional, Tuple, Counter
from collections import Counter

# Optional numpy for better math
try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False
    import math


def compute_prompt_gravity(
    prompt: str,
    subword_field: Optional["SubwordField"] = None,
    bigrams: Optional[Dict[str, Dict[str, int]]] = None,
    trigrams: Optional[Dict[Tuple[str, str], Dict[str, int]]] = None,
    decay_factor: float = 0.7,
) -> Dict[str, float]:
    """
    Compute gravitational weights from prompt.
    
    The prompt creates "gravity wells" in Leo's field — areas that attract
    generation without forcing specific tokens.
    
    Philosophy: Prompt shapes the field's topology, not its content.
    
    Args:
        prompt: Observer's input text
        subword_field: Optional SubwordField for subword-level gravity
        bigrams: Leo's bigram statistics
        trigrams: Leo's trigram statistics  
        decay_factor: How quickly gravity decays with distance (0-1)
    
    Returns:
        Dict mapping tokens to gravity weights (0.0 = no bias, 1.0+ = strong attraction)
    """
    gravity: Dict[str, float] = {}
    
    # Tokenize prompt
    prompt_tokens = _tokenize_simple(prompt.lower())
    
    if not prompt_tokens:
        return gravity
    
    # Strategy 1: Direct token gravity
    # Tokens that appear in prompt get base gravity
    for i, token in enumerate(prompt_tokens):
        # Weight by position (earlier = more important for context)
        position_weight = decay_factor ** (len(prompt_tokens) - i - 1)
        gravity[token] = gravity.get(token, 0.0) + position_weight
    
    # Strategy 2: Bigram-adjacent gravity
    # Tokens that often follow prompt tokens get gravity
    if bigrams:
        for token in prompt_tokens:
            if token in bigrams:
                followers = bigrams[token]
                total = sum(followers.values())
                for follower, count in followers.items():
                    # Gravity proportional to co-occurrence frequency
                    strength = (count / total) * 0.5 * gravity.get(token, 1.0)
                    gravity[follower] = gravity.get(follower, 0.0) + strength
    
    # Strategy 3: Trigram-context gravity
    # If we have bigrams from prompt, extend with trigrams
    if trigrams and len(prompt_tokens) >= 2:
        for i in range(len(prompt_tokens) - 1):
            key = (prompt_tokens[i], prompt_tokens[i + 1])
            if key in trigrams:
                followers = trigrams[key]
                total = sum(followers.values())
                for follower, count in followers.items():
                    strength = (count / total) * 0.7
                    gravity[follower] = gravity.get(follower, 0.0) + strength
    
    # Strategy 4: Subword gravity (if available)
    # Subword patterns can capture semantic relationships
    if subword_field is not None:
        try:
            subword_gravity = _compute_subword_gravity(prompt, subword_field, decay_factor)
            for token, weight in subword_gravity.items():
                gravity[token] = gravity.get(token, 0.0) + weight * 0.3
        except Exception:
            pass
    
    # Normalize gravity weights
    if gravity:
        max_g = max(gravity.values())
        if max_g > 0:
            gravity = {k: v / max_g for k, v in gravity.items()}
    
    return gravity


def _compute_subword_gravity(
    prompt: str,
    subword_field: "SubwordField",
    decay_factor: float,
) -> Dict[str, float]:
    """Compute gravity from subword patterns."""
    gravity: Dict[str, float] = {}
    
    # Encode prompt into subword tokens
    tokens = subword_field.vocab.encode(prompt)
    
    if not tokens:
        return gravity
    
    # Get likely next subwords based on prompt context
    for i, token_id in enumerate(tokens):
        position_weight = decay_factor ** (len(tokens) - i - 1)
        
        # Bigram followers
        if token_id in subword_field.bigram_counts:
            followers = subword_field.bigram_counts[token_id]
            total = sum(followers.values())
            for follower_id, count in followers.items():
                # Decode follower to get text form
                try:
                    follower_text = subword_field.vocab.decode([follower_id])
                    # Tokenize to get individual words
                    for word in _tokenize_simple(follower_text.lower()):
                        strength = (count / total) * position_weight
                        gravity[word] = gravity.get(word, 0.0) + strength
                except Exception:
                    pass
    
    # Trigram followers
    if len(tokens) >= 2:
        for i in range(len(tokens) - 1):
            key = (tokens[i], tokens[i + 1])
            if key in subword_field.trigram_counts:
                followers = subword_field.trigram_counts[key]
                total = sum(followers.values())
                for follower_id, count in followers.items():
                    try:
                        follower_text = subword_field.vocab.decode([follower_id])
                        for word in _tokenize_simple(follower_text.lower()):
                            strength = (count / total) * 0.8
                            gravity[word] = gravity.get(word, 0.0) + strength
                    except Exception:
                        pass
    
    return gravity


def apply_gravity_to_candidates(
    candidates: Dict[str, int],
    gravity: Dict[str, float],
    gravity_strength: float = 0.5,
) -> Dict[str, int]:
    """
    Apply gravitational bias to candidate token counts.
    
    This doesn't add new tokens — only adjusts weights of existing candidates.
    Philosophy: Gravity shapes, doesn't create.
    
    Args:
        candidates: Dict of token -> count from field
        gravity: Dict of token -> gravity weight
        gravity_strength: How much gravity affects selection (0-1)
    
    Returns:
        Adjusted candidates with gravity applied
    """
    if not gravity or not candidates:
        return candidates
    
    adjusted = {}
    
    for token, count in candidates.items():
        base_weight = float(count)
        
        # Get gravity for this token
        token_gravity = gravity.get(token.lower(), 0.0)
        
        # Apply gravity as multiplicative boost
        # gravity_strength controls how much influence gravity has
        if token_gravity > 0:
            boost = 1.0 + (token_gravity * gravity_strength)
            adjusted[token] = int(base_weight * boost)
        else:
            adjusted[token] = count
    
    return adjusted


def compute_semantic_gravity(
    prompt: str,
    emotion_map: Optional[Dict[str, float]] = None,
    themes: Optional[List] = None,
) -> Dict[str, float]:
    """
    Compute semantic gravity based on emotional/thematic content.
    
    This creates gravity toward emotionally/thematically relevant tokens.
    
    Args:
        prompt: Observer's input
        emotion_map: Token -> emotional charge mapping
        themes: Leo's current themes
    
    Returns:
        Semantic gravity weights
    """
    gravity: Dict[str, float] = {}
    
    prompt_tokens = _tokenize_simple(prompt.lower())
    
    if not prompt_tokens:
        return gravity
    
    # Strategy: Emotional resonance
    # Tokens with similar emotional charge to prompt tokens get gravity
    if emotion_map:
        prompt_emotion = 0.0
        emotion_count = 0
        
        for token in prompt_tokens:
            if token in emotion_map:
                prompt_emotion += emotion_map[token]
                emotion_count += 1
        
        if emotion_count > 0:
            avg_prompt_emotion = prompt_emotion / emotion_count
            
            # Find tokens with similar emotional charge
            for token, charge in emotion_map.items():
                # Similarity = 1 - |difference|
                similarity = 1.0 - abs(charge - avg_prompt_emotion)
                if similarity > 0.5:  # Only boost similar emotions
                    gravity[token] = similarity
    
    return gravity


def resonance_score(
    query_probs: List[float],
    context_probs: List[float],
) -> float:
    """
    Measure resonance between two probability distributions.
    
    Adapted from Haze's nn.py.
    High resonance = similar uncertainty patterns.
    """
    if HAS_NUMPY:
        p = np.array(query_probs)
        q = np.array(context_probs)
        
        # Normalize
        p = p / (p.sum() + 1e-10)
        q = q / (q.sum() + 1e-10)
        
        # Jensen-Shannon divergence (symmetric, bounded)
        m = 0.5 * (p + q)
        
        def kl_div(a, b):
            a = np.clip(a, 1e-10, 1.0)
            b = np.clip(b, 1e-10, 1.0)
            return float(np.sum(a * np.log(a / b)))
        
        js = 0.5 * kl_div(p, m) + 0.5 * kl_div(q, m)
        
        # Convert to similarity
        return float(1.0 - min(1.0, js ** 0.5))
    else:
        # Simple correlation fallback
        if len(query_probs) != len(context_probs):
            return 0.0
        
        n = len(query_probs)
        if n == 0:
            return 0.0
        
        mean_q = sum(query_probs) / n
        mean_c = sum(context_probs) / n
        
        cov = sum((q - mean_q) * (c - mean_c) for q, c in zip(query_probs, context_probs))
        var_q = sum((q - mean_q) ** 2 for q in query_probs)
        var_c = sum((c - mean_c) ** 2 for c in context_probs)
        
        if var_q == 0 or var_c == 0:
            return 0.0
        
        corr = cov / ((var_q * var_c) ** 0.5)
        return max(0.0, (corr + 1.0) / 2.0)


def entropy_bits(probs: List[float], eps: float = 1e-10) -> float:
    """Shannon entropy in bits (log2)."""
    if HAS_NUMPY:
        p = np.array(probs)
        p = np.clip(p, eps, 1.0)
        p = p / p.sum()
        return float(-np.sum(p * np.log2(p)))
    else:
        total = sum(probs)
        if total == 0:
            return 0.0
        p = [max(x / total, eps) for x in probs]
        return -sum(x * math.log2(x) for x in p)


def adaptive_temperature(
    current_entropy: float,
    target_entropy: float = 2.0,
    min_temp: float = 0.3,
    max_temp: float = 2.0,
) -> float:
    """
    Compute adaptive temperature based on entropy.
    
    From Haze's nn.py: entropy_temperature()
    
    - High entropy (uncertain) → lower temperature (more focused)
    - Low entropy (confident) → higher temperature (more exploration)
    """
    if current_entropy < 1e-6:
        return min_temp
    
    ratio = target_entropy / current_entropy
    temp = ratio ** 0.5  # Smoothing
    
    if HAS_NUMPY:
        return float(np.clip(temp, min_temp, max_temp))
    else:
        return max(min_temp, min(max_temp, temp))


def _tokenize_simple(text: str) -> List[str]:
    """Simple word tokenization."""
    # Split on whitespace and punctuation
    tokens = re.findall(r"[a-zA-Z]+(?:'[a-zA-Z]+)?", text.lower())
    return tokens


# ============================================================
#  Demo
# ============================================================

def demo():
    """Demonstrate gravity computation."""
    print("=" * 70)
    print("  GRAVITY DEMO — Prompt Field Wrinkles")
    print("=" * 70)
    print()
    
    # Simple bigrams for testing
    bigrams = {
        "love": {"you": 10, "is": 5, "feeling": 3},
        "i": {"love": 8, "feel": 6, "am": 4},
        "you": {"are": 7, "feel": 3, "love": 2},
        "feel": {"love": 4, "happy": 3, "sad": 2},
    }
    
    prompts = [
        "I love you!",
        "What do you feel?",
        "Tell me about happiness",
    ]
    
    for prompt in prompts:
        print(f"Prompt: \"{prompt}\"")
        gravity = compute_prompt_gravity(prompt, bigrams=bigrams)
        
        # Show top gravity weights
        sorted_g = sorted(gravity.items(), key=lambda x: x[1], reverse=True)[:5]
        print(f"  Top gravity: {sorted_g}")
        print()


if __name__ == "__main__":
    demo()
