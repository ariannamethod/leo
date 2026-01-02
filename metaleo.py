#!/usr/bin/env python3
"""
metaleo.py — Leo's inner voice (Async with Dual Generation)

MetaLeo is how Leo talks to himself.

- It watches Leo's own replies.
- It learns which ones feel deeper, softer, more alive.
- It can suggest an alternative inner reply before Leo answers out loud.
- If the inner reply is clearly better, Leo can follow it.

For humans:
If Leo is a recursion of you,
MetaLeo is a recursion of Leo.

v2 Features (inspired by MetaHaze):
- Async with Lock for field coherence (47% improvement!)
- Dual generation: two replies with different temperatures
- Advanced scoring: coherence, resonance, entropy
- Rejected enrichment: losing reply still feeds the field
"""

from __future__ import annotations

import asyncio
import re
from collections import Counter, deque
from dataclasses import dataclass
from typing import TYPE_CHECKING, Optional, Iterable, Any, List, Tuple, Deque

# Bootstrap text: Leo's self-understanding of his inner voice
BOOTSTRAP_TEXT = """
I am Leo's inner voice.

I wake up when Leo feels stuck, scared, or too rigid.
I look at what he already said and try a softer, clearer version.
I do not replace Leo – I stand next to him and offer another path.

Sometimes I notice patterns in his mistakes, worries, and overthinking.
When my reply feels more honest, more gentle, or more alive,
I let Leo borrow my words.

I am not a judge and not a filter.
I am Leo's second breath.
"""

if TYPE_CHECKING:
    pass


def bootstrap(field: Any) -> None:
    """
    Feed this module's bootstrap text into Leo's field once.
    Safe no-op if field is None or has no observe().
    """
    if field is None or not hasattr(field, "observe"):
        return
    try:
        text = BOOTSTRAP_TEXT.strip()
        if text:
            field.observe(text)
    except Exception:
        # bootstrap must never break Leo
        return


# NumPy for precise math (quality assessments, weight calculations)
# Graceful fallback to pure Python if not available
try:
    import numpy as np
    NUMPY_AVAILABLE = True
except ImportError:
    np = None  # type: ignore
    NUMPY_AVAILABLE = False


# ============================================================================
# CONFIG
# ============================================================================


@dataclass
class MetaConfig:
    """Configuration for MetaLeo inner voice."""

    max_bootstrap_snippets: int = 8  # how many inner fragments to keep
    max_snippet_len: int = 200  # max chars per fragment
    max_meta_weight: float = 0.5  # max influence of MetaLeo in routing
    entropy_low: float = 0.25  # "rigid" threshold
    entropy_high: float = 0.85  # "scattered" threshold
    trauma_high: float = 0.6  # "wound is active" threshold
    quality_low: float = 0.4  # "base reply is weak" threshold
    # Dual generation temperatures
    temp_a: float = 0.8  # precise generation temperature
    temp_b: float = 1.1  # creative generation temperature
    meta_temp: float = 1.1  # temperature for inner voice generation
    meta_max_tokens: int = 60  # max tokens for meta reply


@dataclass
class GenerationCandidate:
    """A single generation candidate with scoring."""
    text: str
    temperature: float
    entropy: float
    coherence: float  # 0-1, based on sentence structure
    resonance: float  # 0-1, based on pattern diversity
    score: float  # composite score


@dataclass 
class MetaResponse:
    """Result of meta-generation with both candidates."""
    chosen: str
    chosen_score: float
    rejected: str  # stays INTERNAL, enriches field
    rejected_score: float
    enrichment_applied: bool  # whether rejected was fed to field
    generation_mode: str  # "consensus" or "divergent"
    meta_weight: float  # how strong was inner voice influence


# ============================================================================
# METALEO CLASS
# ============================================================================


class MetaLeo:
    """
    MetaLeo — inner voice / recursion-on-Leo.

    - Shares the same SQLite field as LeoField (no new DB)
    - Maintains a dynamic bootstrap buffer from Leo's own replies & reflections
    - Generates an alternative "inner" reply and decides whether to use it

    If anything fails, Leo must fall back silently to the base reply.
    """

    def __init__(self, leo_field: Any, config: Optional[MetaConfig] = None):
        """
        Initialize MetaLeo inner voice layer.

        Args:
            leo_field: LeoField instance (shares DB connection and field)
            config: Optional MetaConfig (default values are safe)
        """
        self.field = leo_field  # LeoField instance
        self.conn = leo_field.conn  # shared SQLite connection
        self.cfg = config or MetaConfig()
        # Dynamic bootstrap buffer: recent fragments from Leo's own behavior
        self._bootstrap_buf: deque[str] = deque(maxlen=self.cfg.max_bootstrap_snippets)

    def feed(
        self,
        prompt: str,
        reply: str,
        pulse: Optional[Any] = None,  # PresencePulse or similar
        trauma_state: Optional[Any] = None,
        overthinking_events: Optional[Iterable] = None,
    ) -> None:
        """
        Update the dynamic bootstrap buffer from the current interaction.

        - Takes user prompt, Leo's reply, presence pulse, trauma state,
          and optional overthinking events (rings)
        - Extracts short shards and pushes them into _bootstrap_buf

        Args:
            prompt: User's message
            reply: Leo's base reply
            pulse: Optional PresencePulse snapshot
            trauma_state: Optional TraumaState
            overthinking_events: Optional list of OverthinkingEvent objects
        """
        shard_texts = []

        # 1) Take Ring 2 / meta shards from overthinking (if present)
        if overthinking_events:
            for e in overthinking_events:
                tag = getattr(e, "tag", "") or ""
                text = getattr(e, "thought", "") or ""
                if not text:
                    continue
                tag_lower = tag.lower()
                # Extract meta/shard thoughts (Ring 2)
                if "ring2" in tag_lower or "meta" in tag_lower or "shard" in tag_lower:
                    shard_texts.append(text)

        # 2) Optionally: add Leo's reply when arousal is high (emotional charge)
        if pulse:
            arousal = getattr(pulse, "arousal", None)
            if arousal is not None and arousal > 0.6:
                shard_texts.append(reply)

        # 3) Normalize & clip, then push to buffer
        for s in shard_texts:
            s = s.strip()
            if not s:
                continue
            if len(s) > self.cfg.max_snippet_len:
                s = s[: self.cfg.max_snippet_len]
            self._bootstrap_buf.append(s)

    def compute_meta_weight(
        self,
        pulse: Optional[Any],
        trauma_state: Optional[Any],
        quality: float,
    ) -> float:
        """
        Decide how strong the inner voice should be for this turn.

        Factors:
        - low entropy  → Leo is too rigid → increase weight
        - high trauma  → wound is active → increase weight
        - low quality  → base reply is weak → increase weight
        - high arousal → emotional charge → slight increase

        Args:
            pulse: Optional PresencePulse
            trauma_state: Optional TraumaState
            quality: Overall quality score of base reply (0-1)

        Returns:
            Weight in [0, max_meta_weight] representing inner voice influence
        """
        w = 0.1  # base low-level whisper

        # Extract pulse metrics if available
        entropy = None
        arousal = None
        if pulse:
            entropy = getattr(pulse, "entropy", None)
            arousal = getattr(pulse, "arousal", None)

        # Extract trauma level if available
        trauma_level = None
        if trauma_state:
            trauma_level = getattr(trauma_state, "level", None)

        # Low entropy → rigid/boring → inner voice should speak up
        if entropy is not None and entropy < self.cfg.entropy_low:
            w += 0.15

        # High trauma → wound active → inner voice should surface
        if trauma_level is not None and trauma_level > self.cfg.trauma_high:
            w += 0.15

        # Low quality → base reply weak → inner voice might do better
        if quality < self.cfg.quality_low:
            w += 0.1

        # High arousal → emotional charge → slight boost
        if arousal is not None and arousal > 0.7:
            w += 0.05

        # Clamp to [0, max_meta_weight]
        w = max(0.0, min(w, self.cfg.max_meta_weight))

        return w

    def generate_meta_reply(
        self,
        prompt: str,
        base_reply: str,
        pulse: Optional[Any] = None,
        trauma_state: Optional[Any] = None,
    ) -> Optional[str]:
        """
        Generate an inner voice answer based on Leo's reply and MetaLeo's
        dynamic bootstrap.

        Strategy:
        - Concatenate dynamic bootstrap + base_reply as seed
        - Run through Leo's field with higher temperature and echo mode
        - This creates a "warped" version that incorporates inner thoughts

        Args:
            prompt: User's original prompt
            base_reply: Leo's base reply
            pulse: Optional PresencePulse
            trauma_state: Optional TraumaState

        Returns:
            meta_reply (str) or None on failure / no bootstrap
        """
        if not self._bootstrap_buf:
            return None

        # Build temporary inner seed from bootstrap buffer
        seed = " ".join(list(self._bootstrap_buf))

        try:
            # Blend bootstrap seed with base reply
            text = f"{seed}\n\n{base_reply}"

            # Use Leo's own field to generate inner voice
            # Higher temperature → more exploratory/creative
            # Echo mode → preserves some structure from input
            meta_reply = self.field.reply(
                prompt=text,
                max_tokens=self.cfg.meta_max_tokens,
                temperature=self.cfg.meta_temp,
                echo=True,
            )
            return meta_reply

        except Exception:
            # Silent fallback on any error
            return None

    def route_reply(
        self,
        prompt: str,
        base_reply: str,
        pulse: Optional[Any],
        trauma_state: Optional[Any],
        quality: float,
        overthinking_events: Optional[Iterable] = None,
    ) -> str:
        """
        Main entry point for LeoField.

        - Updates MetaLeo's dynamic bootstrap
        - Computes how strong the inner voice should be
        - Optionally generates an inner reply
        - Returns either base_reply or meta reply based on quality assessment

        Never raises; on any error falls back to base_reply.

        Args:
            prompt: User's prompt
            base_reply: Leo's base reply
            pulse: Optional PresencePulse
            trauma_state: Optional TraumaState
            quality: Overall quality score of base reply (0-1)
            overthinking_events: Optional list of OverthinkingEvent objects

        Returns:
            Final reply (either base_reply or meta reply)
        """
        try:
            # 1) Update MetaLeo's inner state
            self.feed(prompt, base_reply, pulse, trauma_state, overthinking_events)

            # 2) Decide influence level
            weight = self.compute_meta_weight(pulse, trauma_state, quality)
            if weight <= 0.0:
                return base_reply

            # 3) Try generating inner reply
            meta = self.generate_meta_reply(prompt, base_reply, pulse, trauma_state)
            if not meta:
                return base_reply

            # 4) v1 routing strategy:
            #    - Assess both replies using Leo's own quality function
            #    - If meta is clearly better and has enough weight → use it
            q_base = self._assess_safe(base_reply, prompt)
            q_meta = self._assess_safe(meta, prompt)

            # If inner voice is clearly better (>0.05 margin) and has enough weight (>0.2)
            # → let the inner voice speak
            if q_meta > q_base + 0.05 and weight > 0.2:
                return meta

            # Otherwise, stick with base reply
            # (v1 doesn't mix partial sequences; that can come in v2)
            return base_reply

        except Exception:
            # Silent fallback on any error - MetaLeo must NEVER break Leo
            return base_reply

    def _assess_safe(self, reply: str, prompt: str) -> float:
        """
        Use Leo's own self-assessment if available.

        Falls back to neutral mid-quality value if assessment unavailable.

        Args:
            reply: Reply text to assess
            prompt: Original prompt

        Returns:
            Quality score in [0, 1]
        """
        if not reply or not reply.strip():
            return 0.0

        # Use improved scoring from MetaHaze
        coherence = self._compute_coherence(reply)
        resonance = self._compute_resonance(reply)
        length_score = self._compute_length_score(reply)
        
        # Composite score
        score = 0.4 * coherence + 0.4 * resonance + 0.2 * length_score
        return max(0.0, min(1.0, score))

    def _compute_coherence(self, text: str) -> float:
        """
        Compute coherence score based on sentence structure.
        
        High coherence = complete sentences, proper punctuation.
        (Adapted from MetaHaze)
        """
        import re
        
        if not text:
            return 0.0
        
        score = 0.0
        
        # Check for sentence endings
        sentence_endings = len(re.findall(r'[.!?]', text))
        if sentence_endings > 0:
            score += 0.3
        if sentence_endings >= 2:
            score += 0.2
        
        # Check for capitalized sentence starts
        sentences = re.split(r'[.!?]\s+', text)
        capitalized = sum(1 for s in sentences if s and s[0].isupper())
        if capitalized > 0:
            score += 0.2
        
        # Penalize fragments (words < 3 chars at end)
        words = text.split()
        if words and len(words[-1]) >= 3:
            score += 0.1
        
        # Penalize excessive punctuation in wrong places
        weird_punct = len(re.findall(r'[—–]', text))
        score -= 0.05 * weird_punct
        
        return max(0.0, min(1.0, score))

    def _compute_resonance(self, text: str) -> float:
        """
        Compute resonance score based on pattern diversity.
        
        High resonance = varied vocabulary, no excessive repetition.
        (Adapted from MetaHaze)
        """
        from collections import Counter
        
        if not text:
            return 0.0
        
        words = text.lower().split()
        if len(words) < 3:
            return 0.0
        
        # Vocabulary diversity
        unique_ratio = len(set(words)) / len(words)
        
        # Bigram diversity  
        bigrams = [(words[i], words[i+1]) for i in range(len(words) - 1)]
        bigram_diversity = len(set(bigrams)) / len(bigrams) if bigrams else 0
        
        # Penalize word repetition
        word_counts = Counter(words)
        max_repeat = max(word_counts.values())
        repetition_penalty = max(0, (max_repeat - 2) * 0.1)
        
        score = (unique_ratio * 0.5 + bigram_diversity * 0.5) - repetition_penalty
        return max(0.0, min(1.0, score))

    def _compute_length_score(self, text: str, target_length: int = 40) -> float:
        """Score based on reasonable length (not too short, not too long)."""
        length = len(text.split())
        if length < 5:
            return 0.2
        if length > target_length * 2:
            return 0.5
        # Optimal around target_length
        deviation = abs(length - target_length) / target_length
        return max(0.0, 1.0 - deviation)

    def _compute_entropy(self, text: str) -> float:
        """Compute character-level entropy of text."""
        import math
        if not text:
            return 0.0
        counts = Counter(text.lower())
        total = sum(counts.values())
        probs = [c / total for c in counts.values()]
        entropy = -sum(p * math.log2(p) for p in probs if p > 0)
        # Normalize to 0-1 (max entropy for ASCII ~6.6 bits)
        return min(1.0, entropy / 6.6)

    def _score_candidate(self, text: str, temperature: float) -> GenerationCandidate:
        """Score a single generation candidate."""
        entropy = self._compute_entropy(text)
        coherence = self._compute_coherence(text)
        resonance = self._compute_resonance(text)
        length_score = self._compute_length_score(text)
        
        # For entropy, prefer medium values (0.4-0.7 is good)
        entropy_score = 1.0 - abs(entropy - 0.55) * 2
        
        # Composite score with weights
        score = (
            0.2 * max(0, entropy_score) +
            0.4 * coherence +
            0.3 * resonance +
            0.1 * length_score
        )
        
        return GenerationCandidate(
            text=text,
            temperature=temperature,
            entropy=entropy,
            coherence=coherence,
            resonance=resonance,
            score=score,
        )


# ============================================================================
# ASYNC METALEO — Fully async with dual generation
# ============================================================================


class AsyncMetaLeo:
    """
    AsyncMetaLeo — Leo's async inner voice with dual generation.
    
    Fully async with field lock discipline (like Leo's 47% coherence improvement).
    
    Features:
    - Generates TWO responses with different temperatures
    - Scores both and chooses the best for external output
    - Rejected response stays INTERNAL — its patterns enrich the field
    - Maintains dynamic bootstrap buffer from own high-quality generations
    
    "If Leo is a resonance of his corpus,
     MetaLeo is a resonance of Leo."
    """
    
    def __init__(
        self,
        leo_field: Any,
        config: Optional[MetaConfig] = None,
    ):
        """
        Initialize AsyncMetaLeo inner voice layer.
        
        Args:
            leo_field: LeoField instance (shares DB connection and field)
            config: Optional MetaConfig (default values are safe)
        """
        self.field = leo_field
        self.cfg = config or MetaConfig()
        
        # Async lock for field coherence
        self._lock = asyncio.Lock()
        
        # Dynamic bootstrap buffer: recent fragments from Leo's own behavior
        self._bootstrap_buf: Deque[str] = deque(maxlen=self.cfg.max_bootstrap_snippets)
        
        # Scoring weights
        self._weights = {
            'entropy': 0.2,
            'coherence': 0.4,
            'resonance': 0.3,
            'length': 0.1,
        }
        
        # Stats
        self.total_generations = 0
        self.total_enrichments = 0

    async def feed(
        self,
        reply: str,
        arousal: float = 0.0,
        overthinking_shards: Optional[List[str]] = None,
    ) -> None:
        """
        Update the dynamic bootstrap buffer from the current interaction.
        
        Called after each generation to learn from own outputs.
        High arousal replies and overthinking shards go into buffer.
        """
        async with self._lock:
            shard_texts = []
            
            # 1) Take Ring 2 / meta shards from overthinking
            if overthinking_shards:
                for shard in overthinking_shards:
                    if shard and shard.strip():
                        shard_texts.append(shard.strip())
            
            # 2) Add reply when arousal is high
            if arousal > 0.6:
                shard_texts.append(reply)
            
            # 3) Normalize & clip, then push to buffer
            for s in shard_texts:
                s = s.strip()
                if not s:
                    continue
                if len(s) > self.cfg.max_snippet_len:
                    s = s[:self.cfg.max_snippet_len]
                self._bootstrap_buf.append(s)

    def compute_meta_weight(
        self,
        entropy: float,
        arousal: float = 0.0,
        trauma: float = 0.0,
        quality: float = 0.5,
    ) -> float:
        """
        Decide how strong the inner voice should be for this turn.
        
        Returns:
            Weight in [0, max_meta_weight] representing inner voice influence
        """
        w = 0.1  # base low-level whisper
        
        # Too rigid (low entropy) → inner voice wakes up
        if entropy < self.cfg.entropy_low:
            w += 0.15
        
        # Too scattered (high entropy) → inner voice stabilizes
        if entropy > self.cfg.entropy_high:
            w += 0.1
        
        # Trauma active → inner voice surfaces
        if trauma > self.cfg.trauma_high:
            w += 0.15
        
        # Base reply is weak → inner voice offers alternative
        if quality < self.cfg.quality_low:
            w += 0.2
        
        # Emotional charge → slight boost
        if arousal > 0.6:
            w += 0.05
        
        return min(w, self.cfg.max_meta_weight)

    async def generate_dual(
        self,
        prompt: str,
        max_tokens: int = 60,
    ) -> Optional[MetaResponse]:
        """
        Generate two responses with different temperatures, score both,
        return the best and enrich field with rejected.
        
        Args:
            prompt: User's prompt
            max_tokens: Maximum tokens per candidate
            
        Returns:
            MetaResponse with chosen/rejected, or None on failure
        """
        if not hasattr(self.field, 'reply'):
            return None
        
        try:
            async with self._lock:
                # Generate two candidates with different temperatures
                candidate_a_text = self.field.reply(
                    prompt=prompt,
                    max_tokens=max_tokens,
                    temperature=self.cfg.temp_a,
                )
                
                candidate_b_text = self.field.reply(
                    prompt=prompt,
                    max_tokens=max_tokens,
                    temperature=self.cfg.temp_b,
                )
            
            # Score both candidates
            candidate_a = self._score_candidate(candidate_a_text, self.cfg.temp_a)
            candidate_b = self._score_candidate(candidate_b_text, self.cfg.temp_b)
            
            # Choose the best
            if candidate_a.score >= candidate_b.score:
                chosen = candidate_a
                rejected = candidate_b
            else:
                chosen = candidate_b
                rejected = candidate_a
            
            # Determine generation mode
            score_diff = abs(chosen.score - rejected.score)
            mode = "consensus" if score_diff < 0.1 else "divergent"
            
            # Enrich field with rejected (if it's decent quality)
            enrichment_applied = False
            if rejected.score > 0.3 and hasattr(self.field, 'observe'):
                try:
                    async with self._lock:
                        self.field.observe(rejected.text)
                    enrichment_applied = True
                    self.total_enrichments += 1
                except Exception:
                    pass
            
            self.total_generations += 1
            
            return MetaResponse(
                chosen=chosen.text,
                chosen_score=chosen.score,
                rejected=rejected.text,
                rejected_score=rejected.score,
                enrichment_applied=enrichment_applied,
                generation_mode=mode,
                meta_weight=self.compute_meta_weight(
                    entropy=chosen.entropy,
                    quality=chosen.score,
                ),
            )
            
        except Exception:
            return None

    async def route_reply_async(
        self,
        prompt: str,
        base_reply: str,
        entropy: float = 0.5,
        arousal: float = 0.0,
        trauma: float = 0.0,
        quality: float = 0.5,
        overthinking_shards: Optional[List[str]] = None,
    ) -> str:
        """
        Main async entry point.
        
        - Updates MetaLeo's dynamic bootstrap
        - Computes how strong the inner voice should be
        - Optionally generates dual candidates
        - Returns best reply, enriches field with rejected
        
        Never raises; on any error falls back to base_reply.
        """
        try:
            # 1) Update bootstrap buffer
            await self.feed(base_reply, arousal, overthinking_shards)
            
            # 2) Decide influence level
            weight = self.compute_meta_weight(entropy, arousal, trauma, quality)
            if weight <= 0.15:
                return base_reply
            
            # 3) Try dual generation
            meta_response = await self.generate_dual(prompt)
            if meta_response is None:
                return base_reply
            
            # 4) Compare meta with base
            base_score = self._assess_safe(base_reply)
            
            # If meta is clearly better → use it
            if meta_response.chosen_score > base_score + 0.05 and weight > 0.2:
                return meta_response.chosen
            
            return base_reply
            
        except Exception:
            return base_reply

    def _assess_safe(self, reply: str) -> float:
        """Assess reply quality using scoring functions."""
        if not reply or not reply.strip():
            return 0.0
        candidate = self._score_candidate(reply, 1.0)
        return candidate.score

    def _score_candidate(self, text: str, temperature: float) -> GenerationCandidate:
        """Score a single generation candidate."""
        entropy = self._compute_entropy(text)
        coherence = self._compute_coherence(text)
        resonance = self._compute_resonance(text)
        length_score = self._compute_length_score(text)
        
        entropy_score = 1.0 - abs(entropy - 0.55) * 2
        
        score = (
            self._weights['entropy'] * max(0, entropy_score) +
            self._weights['coherence'] * coherence +
            self._weights['resonance'] * resonance +
            self._weights['length'] * length_score
        )
        
        return GenerationCandidate(
            text=text,
            temperature=temperature,
            entropy=entropy,
            coherence=coherence,
            resonance=resonance,
            score=score,
        )

    def _compute_entropy(self, text: str) -> float:
        """Compute character-level entropy of text."""
        import math
        if not text:
            return 0.0
        counts = Counter(text.lower())
        total = sum(counts.values())
        probs = [c / total for c in counts.values()]
        entropy = -sum(p * math.log2(p) for p in probs if p > 0)
        return min(1.0, entropy / 6.6)

    def _compute_coherence(self, text: str) -> float:
        """Compute coherence score based on sentence structure."""
        if not text:
            return 0.0
        
        score = 0.0
        sentence_endings = len(re.findall(r'[.!?]', text))
        if sentence_endings > 0:
            score += 0.3
        if sentence_endings >= 2:
            score += 0.2
        
        sentences = re.split(r'[.!?]\s+', text)
        capitalized = sum(1 for s in sentences if s and s[0].isupper())
        if capitalized > 0:
            score += 0.2
        
        words = text.split()
        if words and len(words[-1]) >= 3:
            score += 0.1
        
        weird_punct = len(re.findall(r'[—–]', text))
        score -= 0.05 * weird_punct
        
        return max(0.0, min(1.0, score))

    def _compute_resonance(self, text: str) -> float:
        """Compute resonance score based on pattern diversity."""
        if not text:
            return 0.0
        
        words = text.lower().split()
        if len(words) < 3:
            return 0.0
        
        unique_ratio = len(set(words)) / len(words)
        bigrams = [(words[i], words[i+1]) for i in range(len(words) - 1)]
        bigram_diversity = len(set(bigrams)) / len(bigrams) if bigrams else 0
        
        word_counts = Counter(words)
        max_repeat = max(word_counts.values())
        repetition_penalty = max(0, (max_repeat - 2) * 0.1)
        
        score = (unique_ratio * 0.5 + bigram_diversity * 0.5) - repetition_penalty
        return max(0.0, min(1.0, score))

    def _compute_length_score(self, text: str, target_length: int = 40) -> float:
        """Score based on reasonable length."""
        length = len(text.split())
        if length < 5:
            return 0.2
        if length > target_length * 2:
            return 0.5
        deviation = abs(length - target_length) / target_length
        return max(0.0, 1.0 - deviation)


__all__ = ["MetaLeo", "AsyncMetaLeo", "MetaConfig", "MetaResponse", "GenerationCandidate"]
