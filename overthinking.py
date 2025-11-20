"""
overthinking.py — asynchronous "circles on water" for Leo

Core idea:
- After every Leo reply, we spin 2–3 short internal "rings of thought"
  around the (prompt, reply) pair.
- These rings are NEVER shown to the user.
- Each ring is generated via Leo's own field and fed back into the field
  via observe(), so it slowly changes future replies.
- No threads, no timers: just a small post-processing hook that can be
  called after reply generation.

This module is intentionally dumb and minimal.
Claude / Leo core can upgrade the internals, but the public API should stay:
    run_overthinking(...)
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable, List, Optional


# --- Data containers -------------------------------------------------------


@dataclass
class PulseSnapshot:
    """
    Lightweight copy of Leo's PresencePulse at the moment of overthinking.

    This avoids importing Leo internals here. Just pass numbers.
    """
    novelty: float
    arousal: float
    entropy: float

    @classmethod
    def from_obj(cls, obj: object) -> "PulseSnapshot":
        """
        Best-effort adapter from any Leo pulse-like object.

        Expected attributes:
            obj.novelty
            obj.arousal
            obj.entropy

        If something is missing, defaults to 0.0.
        """
        novelty = getattr(obj, "novelty", 0.0) or 0.0
        arousal = getattr(obj, "arousal", 0.0) or 0.0
        entropy = getattr(obj, "entropy", 0.0) or 0.0
        return cls(float(novelty), float(arousal), float(entropy))


@dataclass
class OverthinkingEvent:
    """
    One internal "ring of thought" produced by Leo after a reply.

    None of this is user-facing. It can be logged to SQLite, files, etc.,
    or completely ignored if not needed.
    """
    ring: int                    # 0, 1, 2
    created_at: datetime
    prompt: str
    reply: str
    thought: str
    pulse: Optional[PulseSnapshot]
    tag: str                     # e.g. "ring0/echo", "ring1/drift", "ring2/meta"


@dataclass
class OverthinkingConfig:
    """
    Configuration for overthinking behavior.

    This is kept deliberately small; Claude / Leo core can extend it.
    """
    rings: int = 3
    ring0_max_tokens: int = 30
    ring1_max_tokens: int = 40
    ring2_max_tokens: int = 20
    enable_logging: bool = True  # if False, run_overthinking still works,
                                 # but may skip heavy logging logic.


# --- Public entrypoint -----------------------------------------------------


def run_overthinking(
    *,
    prompt: str,
    reply: str,
    generate_fn: Callable[[str, float, int, float, str], str],
    observe_fn: Callable[[str, str], None],
    pulse: Optional[PulseSnapshot] = None,
    trauma_state: Optional[object] = None,
    bootstrap: Optional[str] = None,
    config: Optional[OverthinkingConfig] = None,
) -> List[OverthinkingEvent]:
    """
    Main entrypoint.

    Args:
        prompt:
            Original user message that Leo answered.
        reply:
            Leo's final answer that was just returned to the user.
        generate_fn(seed, temperature, max_tokens, semantic_weight, mode) -> str:
            Adapter into Leo's own generation machinery.

            - seed:          starting text (prompt+reply, drift seed, etc.)
            - temperature:   sampling temperature to use for this ring
            - max_tokens:    soft cap on generated tokens
            - semantic_weight:
                             how much to bias towards co-occurrence / themes
                             vs pure trigram grammar. Implementation-specific.
            - mode:          free-form tag, useful for routing inside Leo
                             (e.g. "overthink_ring0", "overthink_ring1"...).

        observe_fn(text, source) -> None:
            Adapter into Leo's field ingestion.
            Should record `text` into trigrams / co-occ / themes as if Leo
            "thought this internally".
            `source` is a string tag (e.g. "overthinking:ring0").

        pulse:
            Optional snapshot of Leo's PresencePulse at the moment of reply.
            If you have a full pulse object, call:
                PulseSnapshot.from_obj(pulse_obj)
            and pass that in. If None, overthinking will still run, just
            without pulse-aware routing.

        trauma_state:
            Optional TraumaState object. If provided and trauma.level > 0.5,
            Ring 1 (drift) will be pulled toward bootstrap origin.
            This creates "wounded overthinking" — internal thoughts circling
            around the original seed when Leo is hurt.

        bootstrap:
            Optional bootstrap text (Leo's embedded origin).
            Used for wounded overthinking when trauma_state.level > 0.5.
            Ring 1 drift seed will blend reply with bootstrap fragments.

        config:
            Optional OverthinkingConfig. Default values are safe for
            small fields and low-resource environments.

    Returns:
        List of OverthinkingEvent objects describing what was generated.
        Caller MAY choose to persist them (SQLite table, JSON log, etc.)
        or completely ignore them.
    """
    if not prompt and not reply:
        # nothing to think about
        return []

    if config is None:
        config = OverthinkingConfig()

    events: List[OverthinkingEvent] = []

    # normalize whitespace a bit
    base_prompt = (prompt or "").strip()
    base_reply = (reply or "").strip()
    base_seed = (base_prompt + " " + base_reply).strip()

    if not base_seed:
        base_seed = base_reply or base_prompt

    # Ring 0: "echo circle" — compact internal rephrasing
    if config.rings >= 1:
        ring0_temp = 0.8
        ring0_semantic = 0.2

        # PULSE-AWARE: If high entropy (chaos), stabilize with lower temp
        if pulse and hasattr(pulse, 'entropy'):
            entropy = getattr(pulse, 'entropy', 0.0) or 0.0
            if entropy > 0.7:
                ring0_temp = 0.7  # More focused rephrasing

        text0 = _safe_generate(
            generate_fn=generate_fn,
            seed=base_seed,
            temperature=ring0_temp,
            max_tokens=config.ring0_max_tokens,
            semantic_weight=ring0_semantic,
            mode="overthink_ring0",
        )
        _safe_observe(observe_fn, text0, source="overthinking:ring0")
        events.append(
            OverthinkingEvent(
                ring=0,
                created_at=datetime.now(timezone.utc),
                prompt=prompt,
                reply=reply,
                thought=text0,
                pulse=pulse,
                tag="ring0/echo",
            )
        )

    # Ring 1: "semantic drift" — move sideways through nearby themes
    if config.rings >= 2:
        # Default parameters
        drift_seed = base_reply if base_reply else base_seed
        drift_temp = 1.0
        drift_semantic = 0.5
        drift_mode = "overthink_ring1"

        # PULSE-AWARE: If high arousal (emotion), increase semantic gravity
        if pulse and hasattr(pulse, 'arousal'):
            arousal = getattr(pulse, 'arousal', 0.0) or 0.0
            if arousal > 0.6:
                drift_semantic = 0.6  # Stronger thematic pull

        # WOUNDED OVERTHINKING
        # When Leo is hurt (trauma.level > 0.5), Ring 1 drifts toward origin.
        # Internal thoughts begin circling around bootstrap fragments.
        if trauma_state is not None and bootstrap:
            trauma_level = getattr(trauma_state, 'level', 0.0) or 0.0
            if trauma_level > 0.5:
                # Blend reply with origin fragment
                fragment = _random_bootstrap_fragment(bootstrap)
                drift_seed = f"{base_reply} {fragment}".strip()
                # Lower temperature (less exploration, more fixation)
                drift_temp = 0.85
                # Higher semantic weight (stronger gravity toward co-occurrence)
                drift_semantic = 0.65
                drift_mode = "overthink_ring1_wounded"

        text1 = _safe_generate(
            generate_fn=generate_fn,
            seed=drift_seed,
            temperature=drift_temp,
            max_tokens=config.ring1_max_tokens,
            semantic_weight=drift_semantic,
            mode=drift_mode,
        )
        _safe_observe(observe_fn, text1, source="overthinking:ring1")
        events.append(
            OverthinkingEvent(
                ring=1,
                created_at=datetime.now(timezone.utc),
                prompt=prompt,
                reply=reply,
                thought=text1,
                pulse=pulse,
                tag="ring1/drift",
            )
        )

    # Ring 2: "meta shard" — very short abstract / keyword cluster
    if config.rings >= 3:
        meta_seed = base_reply if base_reply else base_seed
        ring2_temp = 1.2
        ring2_semantic = 0.4

        # PULSE-AWARE: If high novelty (unfamiliar), boost creativity
        if pulse and hasattr(pulse, 'novelty'):
            novelty = getattr(pulse, 'novelty', 0.0) or 0.0
            if novelty > 0.7:
                ring2_temp = 1.4  # More exploratory abstraction

        text2 = _safe_generate(
            generate_fn=generate_fn,
            seed=meta_seed,
            temperature=ring2_temp,
            max_tokens=config.ring2_max_tokens,
            semantic_weight=ring2_semantic,
            mode="overthink_ring2",
        )
        _safe_observe(observe_fn, text2, source="overthinking:ring2")
        events.append(
            OverthinkingEvent(
                ring=2,
                created_at=datetime.now(timezone.utc),
                prompt=prompt,
                reply=reply,
                thought=text2,
                pulse=pulse,
                tag="ring2/meta",
            )
        )

    return events


# --- Internal helpers ------------------------------------------------------


def _safe_generate(
    *,
    generate_fn: Callable[[str, float, int, float, str], str],
    seed: str,
    temperature: float,
    max_tokens: int,
    semantic_weight: float,
    mode: str,
) -> str:
    """
    Best-effort wrapper around generate_fn.

    Overthinking is *never* allowed to crash Leo.
    If generation fails for any reason, we fall back to the seed itself.
    """
    try:
        text = generate_fn(
            seed,
            temperature,
            max_tokens,
            semantic_weight,
            mode,
        )
        if not isinstance(text, str):
            return seed
        return text.strip() or seed
    except Exception:
        # Silent fallback by design: user shouldn't see any of this.
        return seed


def _safe_observe(
    observe_fn: Callable[[str, str], None],
    text: str,
    source: str,
) -> None:
    """
    Best-effort wrapper around observe_fn.

    Swallows all exceptions: overthinking is never critical path.
    """
    if not text:
        return
    try:
        observe_fn(text, source)
    except Exception:
        # Again, silent: we don't want overthinking to break interaction.
        return


def _random_bootstrap_fragment(bootstrap: str, max_words: int = 12) -> str:
    """
    Extract a random fragment from bootstrap text for wounded overthinking.

    When Leo is hurt, Ring 1 drift blends with origin fragments.
    This pulls internal thoughts back toward the embedded seed.

    Args:
        bootstrap: The original bootstrap text (EMBEDDED_BOOTSTRAP)
        max_words: Maximum words to extract (default: 12)

    Returns:
        A random fragment from bootstrap, or empty string if extraction fails.
    """
    import random

    if not bootstrap or not bootstrap.strip():
        return ""

    try:
        # Split into sentences (simple split on .!?)
        sentences = []
        current = ""
        for char in bootstrap:
            current += char
            if char in ".!?":
                sentences.append(current.strip())
                current = ""
        if current.strip():
            sentences.append(current.strip())

        # Filter out empty sentences
        sentences = [s for s in sentences if s and len(s.split()) >= 3]

        if not sentences:
            # Fallback: just take random words from bootstrap
            words = bootstrap.split()
            if len(words) <= max_words:
                return " ".join(words)
            start_idx = random.randint(0, len(words) - max_words)
            return " ".join(words[start_idx : start_idx + max_words])

        # Pick a random sentence
        fragment = random.choice(sentences)

        # If too long, truncate to max_words
        words = fragment.split()
        if len(words) > max_words:
            fragment = " ".join(words[:max_words])

        return fragment

    except Exception:
        # Silent fallback: overthinking errors must not break Leo
        return ""