"""
Architectural density metric for Leo's speech.

Philosophy: Don't ban architectural jargon, just gently push it down
in soft/intimate themes where body and images work better.

In other contexts (code discussion, resonance, wounded expert),
architectural language stays as Leo's signature.

"больше жизни, меньше допроса" - more life, less interrogation
"""

from typing import Set


# Architectural/technical words that indicate Leo is talking about his internals
ARCH_WORDS: Set[str] = {
    # Core architecture
    "mlp", "bootstrap", "episodes", "episode", "sql", "sqlite",
    "tests", "test", "phase", "metaleo", "mathbrain", "neoleo",

    # Technical implementation
    "game.py", "py", "trigram", "trigrams", "bigram", "tokenize",
    "embedding", "embeddings", "vector", "vectors", "gradient",

    # Meta-cognitive jargon
    "quality score", "entropy", "novelty", "arousal", "pulse",
    "loop score", "meta vocab", "external vocab",

    # Database/storage
    "storage", "records", "episodes", "snapshots", "json",

    # Training/learning jargon
    "train", "training", "loss", "backward", "forward", "pass",
    "relu", "tanh", "sigmoid", "activation",

    # Code references
    "karpathy", "micrograd", "transformer", "attention",
    "gpt", "claude", "api", "model",
}

# Soft/intimate topics where architectural jargon feels out of place
# In these contexts, body language and images work better
SOFT_TOPICS: Set[str] = {
    "sitting_together",
    "feeling_close",
    "simple_warmth",
    "silence_comfort",
    "home_feeling",
    "vulnerability",
    "being_seen",
    "touch_without_touch",
    "breathing_together",
    "gentle_ache",
    "not_fixing",
}


def architectural_density(text: str) -> float:
    """
    Calculate density of architectural/technical jargon in text.

    Returns:
        Float 0.0-1.0, where higher means more architectural language

    Example:
        "I feel warm" → 0.0 (no arch words)
        "The MLP predicts quality score" → 0.5 (2 of 4 words are arch)
        "Tests phase bootstrap episodes" → 1.0 (all arch words)
    """
    if not text or not isinstance(text, str):
        return 0.0

    # Simple tokenization: lowercase, split on whitespace and punctuation
    tokens = text.lower().replace(',', ' ').replace('.', ' ').replace(':', ' ').split()

    if not tokens:
        return 0.0

    # Count how many tokens are architectural words
    arch_count = sum(1 for token in tokens if token in ARCH_WORDS)

    return arch_count / len(tokens)


def should_apply_arch_penalty(topic: str) -> bool:
    """
    Check if architectural penalty should be applied for this topic.

    Args:
        topic: Topic name (e.g. "sitting_together", "code_review")

    Returns:
        True if this is a soft topic where arch jargon should be discouraged
    """
    return topic in SOFT_TOPICS


# Example usage
if __name__ == "__main__":
    test_cases = [
        # Should have high density
        ("The MLP predicts the quality score based on entropy.", 0.5),
        ("Tests phase bootstrap episodes trigram model.", 0.85),
        ("Storage sqlite records all episodes.", 0.75),

        # Should have low density
        ("I feel warm and gentle, like soft sunlight.", 0.0),
        ("Your words feel big and full of wonder.", 0.0),
        ("Sitting quietly, breathing together in silence.", 0.0),

        # Mixed
        ("I can feel the phase shifting inside me.", 0.14),
    ]

    print("Testing architectural_density.py")
    print("=" * 60)

    for text, expected in test_cases:
        density = architectural_density(text)
        status = "✓" if abs(density - expected) < 0.1 else "✗"
        print(f"\n{status} Text: {text}")
        print(f"   Density: {density:.2f} (expected ~{expected:.2f})")
