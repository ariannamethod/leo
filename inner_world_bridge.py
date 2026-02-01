#!/usr/bin/env python3
"""
inner_world_bridge.py — Python bridge to Go emotional resonance engine

Loads inner_world/libleo_inner.so (or .dylib on macOS) via ctypes.
Falls back to pure Python when Go library is unavailable.

Usage:
    from inner_world_bridge import InnerWorld

    iw = InnerWorld()
    iw.drift(0.8, 0.5)
    print(iw.valence, iw.arousal, iw.nearest_attractor())
    print(iw.entropy("I love you so much"))
    print(iw.semantic_distance("hello world", "goodbye moon"))
"""

from __future__ import annotations

import math
import subprocess
import sys
from collections import Counter
from ctypes import POINTER, byref, c_char_p, c_float, cdll
from pathlib import Path
from typing import Optional, Tuple

# ═══════════════════════════════════════════════════════════════════════════════
# LIBRARY DISCOVERY
# ═══════════════════════════════════════════════════════════════════════════════

INNER_WORLD_DIR = Path(__file__).parent / "inner_world"
GO_SOURCE = INNER_WORLD_DIR / "emotional_resonance.go"

# Platform-specific shared library name
if sys.platform == "darwin":
    SO_NAME = "libleo_inner.dylib"
    _ALT_NAME = "libleo_inner.so"
else:
    SO_NAME = "libleo_inner.so"
    _ALT_NAME = "libleo_inner.dylib"

SO_FILE = INNER_WORLD_DIR / SO_NAME
_ALT_FILE = INNER_WORLD_DIR / _ALT_NAME


def _find_library() -> Optional[Path]:
    """Find the compiled shared library."""
    if SO_FILE.exists():
        return SO_FILE
    if _ALT_FILE.exists():
        return _ALT_FILE
    return None


def build_library(force: bool = False) -> bool:
    """
    Build the Go shared library if needed.

    Returns True if library is available after this call.
    """
    lib_path = _find_library()
    if not force and lib_path is not None:
        if not GO_SOURCE.exists():
            return True
        if GO_SOURCE.stat().st_mtime <= lib_path.stat().st_mtime:
            return True

    if not GO_SOURCE.exists():
        return False

    try:
        result = subprocess.run(
            ["go", "version"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode != 0:
            return False
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False

    try:
        result = subprocess.run(
            ["go", "build", "-buildmode=c-shared", "-o", str(SO_FILE), str(GO_SOURCE)],
            cwd=str(INNER_WORLD_DIR),
            capture_output=True, text=True, timeout=120,
        )
        return result.returncode == 0
    except Exception:
        return False


def _load_library() -> Optional[object]:
    """Load the Go shared library and configure function signatures."""
    lib_path = _find_library()
    if lib_path is None:
        return None

    try:
        lib = cdll.LoadLibrary(str(lib_path))

        # Emotional state
        lib.leo_get_valence.restype = c_float
        lib.leo_get_valence.argtypes = []
        lib.leo_get_arousal.restype = c_float
        lib.leo_get_arousal.argtypes = []
        lib.leo_emotional_drift.restype = None
        lib.leo_emotional_drift.argtypes = [c_float, c_float]
        lib.leo_reset_state.restype = None
        lib.leo_reset_state.argtypes = []
        lib.leo_find_nearest_attractor.restype = c_char_p
        lib.leo_find_nearest_attractor.argtypes = [c_float, c_float]
        lib.leo_compute_attractor_pull.restype = None
        lib.leo_compute_attractor_pull.argtypes = [c_float, c_float, POINTER(c_float), POINTER(c_float)]

        # High math
        lib.leo_entropy.restype = c_float
        lib.leo_entropy.argtypes = [c_char_p]
        lib.leo_emotional_score.restype = c_float
        lib.leo_emotional_score.argtypes = [c_char_p]
        lib.leo_perplexity.restype = c_float
        lib.leo_perplexity.argtypes = [c_char_p]
        lib.leo_semantic_distance.restype = c_float
        lib.leo_semantic_distance.argtypes = [c_char_p, c_char_p]

        return lib
    except Exception:
        return None


# ═══════════════════════════════════════════════════════════════════════════════
# PYTHON FALLBACKS (when Go is unavailable)
# ═══════════════════════════════════════════════════════════════════════════════

# Subset of EmotionalWeights from emotional_resonance.go
_PY_EMOTIONAL_WEIGHTS = {
    "love": 0.95, "adore": 0.9, "cherish": 0.85, "devotion": 0.8,
    "affection": 0.8, "tenderness": 0.75, "care": 0.7, "warm": 0.7,
    "wonderful": 0.8, "amazing": 0.75, "beautiful": 0.8, "lovely": 0.75,
    "happy": 0.7, "joy": 0.8, "delighted": 0.75, "pleased": 0.6,
    "smile": 0.6, "hug": 0.7, "gentle": 0.6, "sweet": 0.65,
    "kind": 0.6, "soft": 0.5, "thank": 0.5, "grateful": 0.7,
    "play": 0.7, "fun": 0.7, "game": 0.6, "silly": 0.65,
    "laugh": 0.75, "giggle": 0.7, "joke": 0.6, "funny": 0.65,
    "magic": 0.7, "pretend": 0.5, "surprise": 0.5, "candy": 0.5,
    "fear": -0.7, "afraid": -0.7, "scared": -0.75, "terrified": -0.9,
    "anxious": -0.6, "worry": -0.5, "panic": -0.8, "dread": -0.75,
    "horror": -0.85, "nervous": -0.5, "terror": -0.9, "danger": -0.7,
    "empty": -0.5, "nothing": -0.55, "numb": -0.6, "hollow": -0.55,
    "void": -0.6, "alone": -0.6, "lonely": -0.7, "isolated": -0.65,
    "meaningless": -0.7, "pointless": -0.65, "dead": -0.8,
    "hate": -0.9, "terrible": -0.8, "awful": -0.7, "horrible": -0.8,
    "sad": -0.6, "angry": -0.7, "hurt": -0.7, "pain": -0.8,
    "suffer": -0.8, "worthless": -0.85,
}

# Attractors from emotional_resonance.go
_PY_ATTRACTORS = [
    {"name": "joy", "valence": 0.7, "arousal": 0.6, "strength": 0.3, "sticky": 0.3},
    {"name": "contentment", "valence": 0.5, "arousal": 0.2, "strength": 0.4, "sticky": 0.5},
    {"name": "excitement", "valence": 0.8, "arousal": 0.8, "strength": 0.2, "sticky": 0.2},
    {"name": "warmth", "valence": 0.6, "arousal": 0.3, "strength": 0.3, "sticky": 0.4},
    {"name": "sadness", "valence": -0.6, "arousal": 0.2, "strength": 0.4, "sticky": 0.6},
    {"name": "fear", "valence": -0.7, "arousal": 0.8, "strength": 0.3, "sticky": 0.3},
    {"name": "rage", "valence": -0.8, "arousal": 0.9, "strength": 0.25, "sticky": 0.2},
    {"name": "void", "valence": -0.4, "arousal": 0.1, "strength": 0.5, "sticky": 0.7},
    {"name": "flow", "valence": 0.1, "arousal": 0.4, "strength": 0.35, "sticky": 0.4},
    {"name": "neutral", "valence": 0.0, "arousal": 0.3, "strength": 0.3, "sticky": 0.3},
    {"name": "curiosity", "valence": 0.2, "arousal": 0.5, "strength": 0.25, "sticky": 0.35},
    {"name": "playful", "valence": 0.5, "arousal": 0.7, "strength": 0.3, "sticky": 0.25},
]


def _py_tokenize(text: str) -> list:
    """Simple word tokenizer matching Go's tokenize()."""
    words = []
    current = []
    for ch in text.lower():
        if ch.isalpha() or ch.isdigit():
            current.append(ch)
        elif current:
            words.append("".join(current))
            current = []
    if current:
        words.append("".join(current))
    return words


def _py_entropy(text: str) -> float:
    """Shannon entropy with emotional modulation (Python fallback)."""
    words = _py_tokenize(text)
    if not words:
        return 0.0
    counts = Counter(words)
    total = len(words)
    ent = 0.0
    for c in counts.values():
        p = c / total
        if p > 0:
            ent -= p * math.log2(p)
    emotional_sum = sum(_PY_EMOTIONAL_WEIGHTS.get(w, 0.0) for w in words)
    emotional_score = emotional_sum / total
    ent *= 1.0 + abs(emotional_score) * 0.2
    return ent


def _py_emotional_score(text: str) -> float:
    """Average emotional valence of words (Python fallback)."""
    words = _py_tokenize(text)
    if not words:
        return 0.0
    total = sum(_PY_EMOTIONAL_WEIGHTS.get(w, 0.0) for w in words)
    return total / len(words)


def _py_perplexity(text: str) -> float:
    """Character bigram perplexity (Python fallback)."""
    if len(text) < 2:
        return 1.0
    bigram_counts: dict = {}
    unigram_counts: dict = {}
    for i in range(len(text) - 1):
        bg = text[i:i + 2]
        bigram_counts[bg] = bigram_counts.get(bg, 0) + 1
        unigram_counts[text[i]] = unigram_counts.get(text[i], 0) + 1
    unigram_counts[text[-1]] = unigram_counts.get(text[-1], 0) + 1

    log_prob = 0.0
    count = 0
    for i in range(len(text) - 1):
        bg = text[i:i + 2]
        bc = bigram_counts.get(bg, 0)
        uc = unigram_counts.get(text[i], 0)
        if bc > 0 and uc > 0:
            log_prob += math.log2(bc / uc)
            count += 1
    if count == 0:
        return 1.0
    return 2 ** (-log_prob / count)


def _py_semantic_distance(text1: str, text2: str) -> float:
    """Cosine distance between word frequency vectors (Python fallback)."""
    words1 = _py_tokenize(text1)
    words2 = _py_tokenize(text2)
    if not words1 or not words2:
        return 1.0
    vocab: dict = {}
    idx = 0
    for w in words1 + words2:
        if w not in vocab:
            vocab[w] = idx
            idx += 1
    vec1 = [0.0] * len(vocab)
    vec2 = [0.0] * len(vocab)
    for w in words1:
        vec1[vocab[w]] += 1.0
    for w in words2:
        vec2[vocab[w]] += 1.0
    dot = sum(a * b for a, b in zip(vec1, vec2))
    n1 = math.sqrt(sum(a * a for a in vec1))
    n2 = math.sqrt(sum(b * b for b in vec2))
    if n1 == 0 or n2 == 0:
        return 1.0
    return 1.0 - dot / (n1 * n2)


def _py_find_nearest_attractor(valence: float, arousal: float) -> str:
    """Find closest attractor (Python fallback)."""
    best = "neutral"
    best_dist = 100.0
    for a in _PY_ATTRACTORS:
        dv = a["valence"] - valence
        da = a["arousal"] - arousal
        d = math.sqrt(dv * dv + da * da)
        if d < best_dist:
            best_dist = d
            best = a["name"]
    return best


def _py_compute_attractor_pull(valence: float, arousal: float) -> Tuple[float, float]:
    """Compute attractor gradient (Python fallback)."""
    total_dv = 0.0
    total_da = 0.0
    total_weight = 0.0
    for a in _PY_ATTRACTORS:
        dv = a["valence"] - valence
        da = a["arousal"] - arousal
        dist = math.sqrt(dv * dv + da * da)
        if dist < 0.01:
            continue
        pull = a["strength"] / (dist + 0.5)
        if dist < 0.2:
            pull *= (1 - a["sticky"])
        total_dv += (dv / dist) * pull
        total_da += (da / dist) * pull
        total_weight += pull
    if total_weight > 0:
        return total_dv / total_weight, total_da / total_weight
    return 0.0, 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# INNER WORLD — MAIN API
# ═══════════════════════════════════════════════════════════════════════════════

class InnerWorld:
    """
    Bridge to Go emotional resonance engine with Python fallback.

    All methods work identically whether Go is available or not.
    Go gives ~10-100x speed on numerical functions.
    """

    def __init__(self, auto_build: bool = False):
        """
        Args:
            auto_build: If True, try to compile Go library if missing.
        """
        if auto_build:
            build_library()
        self._lib = _load_library()
        # Python fallback state
        self._py_valence = 0.1
        self._py_arousal = 0.3
        self._py_prediction = 0.1
        self._py_momentum = 0.0

    @property
    def go_available(self) -> bool:
        """Whether Go library is loaded."""
        return self._lib is not None

    # --- Emotional state ---

    @property
    def valence(self) -> float:
        if self._lib:
            return float(self._lib.leo_get_valence())
        return self._py_valence

    @property
    def arousal(self) -> float:
        if self._lib:
            return float(self._lib.leo_get_arousal())
        return self._py_arousal

    def drift(self, input_valence: float, input_arousal: float) -> None:
        """Update emotional state via ODE integration."""
        if self._lib:
            self._lib.leo_emotional_drift(c_float(input_valence), c_float(input_arousal))
        else:
            # Python ODE fallback (matches Go DefaultParams)
            decay = 0.15
            surprise_gain = 0.5
            input_pull = 0.3
            attractor_gravity = 0.1
            momentum_decay = 0.3
            baseline_v = 0.1
            baseline_a = 0.3

            surprise = input_valence - self._py_prediction
            attr_dv, attr_da = _py_compute_attractor_pull(self._py_valence, self._py_arousal)

            dv = (-decay * (self._py_valence - baseline_v)
                  + surprise * surprise_gain
                  + (input_valence - self._py_valence) * input_pull
                  + attr_dv * attractor_gravity
                  + self._py_momentum * 0.3)

            da = (-decay * (self._py_arousal - baseline_a)
                  + abs(surprise) * surprise_gain
                  + input_arousal * 0.2
                  + attr_da * attractor_gravity)

            self._py_momentum = self._py_momentum * momentum_decay + dv * (1 - momentum_decay)
            self._py_valence = max(-1.0, min(1.0, self._py_valence + dv))
            self._py_arousal = max(0.0, min(1.0, self._py_arousal + da))
            self._py_prediction = self._py_valence + dv * 0.5

    def reset(self) -> None:
        """Reset emotional state to baseline."""
        if self._lib:
            self._lib.leo_reset_state()
        self._py_valence = 0.1
        self._py_arousal = 0.3
        self._py_prediction = 0.1
        self._py_momentum = 0.0

    def nearest_attractor(self) -> str:
        """Find the closest emotional attractor to current state."""
        if self._lib:
            result = self._lib.leo_find_nearest_attractor(
                c_float(self.valence), c_float(self.arousal))
            return result.decode() if result else "neutral"
        return _py_find_nearest_attractor(self._py_valence, self._py_arousal)

    def attractor_pull(self) -> Tuple[float, float]:
        """Compute attractor gradient (dV, dA) at current state."""
        if self._lib:
            dv = c_float()
            da = c_float()
            self._lib.leo_compute_attractor_pull(
                c_float(self.valence), c_float(self.arousal),
                byref(dv), byref(da))
            return float(dv.value), float(da.value)
        return _py_compute_attractor_pull(self._py_valence, self._py_arousal)

    # --- High math ---

    def entropy(self, text: str) -> float:
        """Shannon entropy with emotional modulation."""
        if self._lib:
            return float(self._lib.leo_entropy(text.encode("utf-8")))
        return _py_entropy(text)

    def emotional_score(self, text: str) -> float:
        """Average emotional valence of words in text."""
        if self._lib:
            return float(self._lib.leo_emotional_score(text.encode("utf-8")))
        return _py_emotional_score(text)

    def perplexity(self, text: str) -> float:
        """Character bigram perplexity."""
        if self._lib:
            return float(self._lib.leo_perplexity(text.encode("utf-8")))
        return _py_perplexity(text)

    def semantic_distance(self, text1: str, text2: str) -> float:
        """Cosine distance between two texts (0 = identical, 1 = orthogonal)."""
        if self._lib:
            return float(self._lib.leo_semantic_distance(
                text1.encode("utf-8"), text2.encode("utf-8")))
        return _py_semantic_distance(text1, text2)

    # --- Convenience ---

    def analyze(self, text: str) -> dict:
        """Full emotional analysis of text."""
        return {
            "entropy": self.entropy(text),
            "emotional_score": self.emotional_score(text),
            "perplexity": self.perplexity(text),
            "valence": self.valence,
            "arousal": self.arousal,
            "attractor": self.nearest_attractor(),
        }

    def __repr__(self) -> str:
        backend = "Go" if self.go_available else "Python"
        return (f"InnerWorld({backend}, v={self.valence:.2f}, "
                f"a={self.arousal:.2f}, attr={self.nearest_attractor()})")
