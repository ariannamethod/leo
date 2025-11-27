#!/usr/bin/env python3
"""
mathbrain.py — Leo's body awareness

MathBrain is Leo's tiny math body.

- It watches: pulse, novelty, trauma, themes, experts, quality.
- It learns simple patterns: "when the moment feels like this, answers feel like that".
- It can gently nudge how Leo speaks: a bit warmer, a bit sharper, a bit slower.

No big networks. Just small numbers, small steps, and a child learning how his own body moves.
"""

from __future__ import annotations

import json
import math
import os
import random
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Dict, Set, Tuple, Optional, Callable, Any, TYPE_CHECKING


def _debug_log(msg: str) -> None:
    """
    Minimal debug logger: only writes to stderr if LEO_DEBUG=1.
    Silent by default to keep REPL clean.
    """
    if os.environ.get("LEO_DEBUG") == "1":
        print(f"[mathbrain] {msg}", file=sys.stderr)


def _is_finite_safe(x: float) -> bool:
    """Check if a value is finite (not NaN, not inf)."""
    return math.isfinite(x)


def _all_finite(values: List[float]) -> bool:
    """Check if all values in list are finite."""
    return all(_is_finite_safe(v) for v in values)


# ============================================================================
# MULTILEO: Presence-aware regulation layer (sub-layer of MathBrain)
# ============================================================================
#
# MultiLeo: tiny presence-aware regulator inside MathBrain.
# Sees boredom / overwhelm signals and gently nudges temperature / experts.
# No user-facing telemetry, only internal logs.

# MultiLeo thresholds and limits
MULTILEO_TEMP_NUDGE_MAX = 0.2  # Max temperature adjustment: ±0.2
MULTILEO_TEMP_MIN = 0.1  # Absolute min temperature
MULTILEO_TEMP_MAX = 1.5  # Absolute max temperature

# Score computation thresholds
BOREDOM_NOVELTY_THRESHOLD = 0.3  # low novelty
BOREDOM_AROUSAL_THRESHOLD = 0.3  # low arousal
OVERWHELM_TRAUMA_THRESHOLD = 0.7  # high trauma
OVERWHELM_AROUSAL_THRESHOLD = 0.8  # very high arousal
STUCK_QUALITY_THRESHOLD = 0.35  # low predicted quality


def _compute_boredom_score(state: MathState) -> float:
    """
    Compute boredom score: low novelty + low arousal + low trauma + medium entropy.

    Returns score in [0, 1] where higher = more bored.
    """
    # Low novelty (inverse)
    novelty_component = max(0.0, 1.0 - state.novelty)
    # Low arousal (inverse)
    arousal_component = max(0.0, 1.0 - state.arousal)
    # Low trauma (inverse)
    trauma_component = max(0.0, 1.0 - state.trauma_level)
    # Medium entropy (peak at 0.5, decay to edges)
    entropy_mid = 1.0 - 2.0 * abs(state.entropy - 0.5)
    entropy_component = max(0.0, entropy_mid)

    # Weighted combination
    score = (
        0.35 * novelty_component +
        0.35 * arousal_component +
        0.15 * trauma_component +
        0.15 * entropy_component
    )

    return max(0.0, min(1.0, score))


def _compute_overwhelm_score(state: MathState) -> float:
    """
    Compute overwhelm score: high trauma OR very high arousal + high entropy.

    Returns score in [0, 1] where higher = more overwhelmed.
    """
    # High trauma
    trauma_component = state.trauma_level
    # Very high arousal
    arousal_component = state.arousal
    # High entropy
    entropy_component = state.entropy

    # OR logic: max of trauma and (arousal + entropy combo)
    arousal_entropy_combo = 0.6 * arousal_component + 0.4 * entropy_component
    score = max(trauma_component, arousal_entropy_combo)

    return max(0.0, min(1.0, score))


def _compute_stuck_score(state: MathState, predicted_quality: float) -> float:
    """
    Compute stuck score: low predicted quality + low theme variation.

    Returns score in [0, 1] where higher = more stuck.
    """
    # Low predicted quality (inverse)
    quality_component = max(0.0, 1.0 - predicted_quality)

    # Low theme variation (if total_themes > 0 but few active)
    theme_variation = 0.0
    if state.total_themes > 0:
        theme_ratio = state.active_theme_count / max(1, state.total_themes)
        theme_variation = 1.0 - theme_ratio  # Low ratio = stuck

    # Weighted combination
    score = 0.7 * quality_component + 0.3 * theme_variation

    return max(0.0, min(1.0, score))


def _log_multileo_event(
    timestamp: float,
    turn_id: str,
    state: MathState,
    predicted_quality: float,
    boredom: float,
    overwhelm: float,
    stuck: float,
    temp_before: float,
    temp_after: float,
    expert_before: str,
    expert_after: str,
    log_path: Optional[Path] = None,
) -> None:
    """
    Log MultiLeo regulation event to state/multileo_events.log.

    Format: JSON per line, no PII, only metrics.
    Only logs when there's an actual change (temp or expert different).
    """
    # Skip logging if nothing changed
    if temp_before == temp_after and expert_before == expert_after:
        return

    if log_path is None:
        log_path = Path(__file__).parent / "state" / "multileo_events.log"

    try:
        # Ensure state directory exists
        log_path.parent.mkdir(parents=True, exist_ok=True)

        # Build log entry (no PII, only metrics)
        entry = {
            "ts": int(timestamp),
            "turn": turn_id[:8],  # Short hash only
            "metrics": {
                "entropy": round(state.entropy, 3),
                "novelty": round(state.novelty, 3),
                "arousal": round(state.arousal, 3),
                "trauma": round(state.trauma_level, 3),
                "pred_q": round(predicted_quality, 3),
            },
            "scores": {
                "boredom": round(boredom, 3),
                "overwhelm": round(overwhelm, 3),
                "stuck": round(stuck, 3),
            },
            "regulation": {
                "temp": [round(temp_before, 2), round(temp_after, 2)],
                "expert": [expert_before, expert_after] if expert_before != expert_after else None,
            },
        }

        # Append to log file
        with open(log_path, 'a') as f:
            import json
            f.write(json.dumps(entry) + '\n')
    except Exception:
        # Silent fail - logging must never break Leo
        pass


# Bootstrap text: Leo's self-understanding of his body awareness
BOOTSTRAP_TEXT = """
I am Leo's body awareness.

I do not read words, I read numbers: pulse, entropy, trauma, arousal, quality.
I watch how Leo behaves over time and learn his rhythms.

When he repeats himself, when he goes too flat, when he burns too bright,
I can feel it before he notices.

I do not tell Leo what to say.
I only nudge: a bit more freedom, a bit more calm, a bit more variation.
My job is to keep Leo present, not perfect.

I am not language.
I am how Leo's language feels from the inside.
"""

if TYPE_CHECKING:
    pass  # placeholder for future type hints


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

# NumPy for precise math (matrix ops, vectorization)
# Highly recommended for math.py, but not required
try:
    import numpy as np
    NUMPY_AVAILABLE = True
except ImportError:
    np = None  # type: ignore
    NUMPY_AVAILABLE = False


# ============================================================================
# MICROGRAD-STYLE AUTOGRAD CORE
# ============================================================================


class Value:
    """
    Scalar value with automatic differentiation.

    Karpathy-style micrograd implementation:
    - Tracks computational graph via _prev and _op
    - Backward pass computes gradients via chain rule
    - Supports basic operations: +, *, tanh, relu, etc.
    """

    def __init__(self, data: float, _children: Tuple['Value', ...] = (), _op: str = ''):
        self.data = float(data)
        self.grad = 0.0
        self._backward: Callable[[], None] = lambda: None
        self._prev = set(_children)
        self._op = _op

    def __repr__(self) -> str:
        return f"Value(data={self.data:.4f}, grad={self.grad:.4f})"

    def __add__(self, other: 'Value | float') -> 'Value':
        other = other if isinstance(other, Value) else Value(other)
        out = Value(self.data + other.data, (self, other), '+')

        def _backward():
            self.grad += out.grad
            other.grad += out.grad
        out._backward = _backward

        return out

    def __mul__(self, other: 'Value | float') -> 'Value':
        other = other if isinstance(other, Value) else Value(other)
        out = Value(self.data * other.data, (self, other), '*')

        def _backward():
            self.grad += other.data * out.grad
            other.grad += self.data * out.grad
        out._backward = _backward

        return out

    def __pow__(self, other: float | int) -> 'Value':
        assert isinstance(other, (int, float)), "only supporting int/float powers"
        out = Value(self.data ** other, (self,), f'**{other}')

        def _backward():
            self.grad += other * (self.data ** (other - 1)) * out.grad
        out._backward = _backward

        return out

    def __neg__(self) -> 'Value':
        return self * -1

    def __sub__(self, other: 'Value | float') -> 'Value':
        return self + (-other)

    def __truediv__(self, other: 'Value | float') -> 'Value':
        return self * (other ** -1)

    def __radd__(self, other: 'Value | float') -> 'Value':
        return self + other

    def __rmul__(self, other: 'Value | float') -> 'Value':
        return self * other

    def __rsub__(self, other: 'Value | float') -> 'Value':
        return other + (-self)

    def __rtruediv__(self, other: 'Value | float') -> 'Value':
        return other * (self ** -1)

    def tanh(self) -> 'Value':
        """Hyperbolic tangent activation."""
        t = math.tanh(self.data)
        out = Value(t, (self,), 'tanh')

        def _backward():
            self.grad += (1 - t**2) * out.grad
        out._backward = _backward

        return out

    def relu(self) -> 'Value':
        """Rectified Linear Unit activation."""
        out = Value(0.0 if self.data < 0 else self.data, (self,), 'relu')

        def _backward():
            self.grad += (out.data > 0) * out.grad
        out._backward = _backward

        return out

    def backward(self) -> None:
        """
        Backpropagate gradients through computational graph.

        Uses topological sort to ensure gradients flow correctly.
        """
        # Build topological order
        topo: List[Value] = []
        visited: Set[Value] = set()

        def build_topo(v: Value):
            if v not in visited:
                visited.add(v)
                for child in v._prev:
                    build_topo(child)
                topo.append(v)

        build_topo(self)

        # Backward pass
        self.grad = 1.0
        for node in reversed(topo):
            node._backward()


# ============================================================================
# NEURAL NETWORK LAYERS
# ============================================================================


class Neuron:
    """Single neuron with weights, bias, and activation."""

    def __init__(self, nin: int):
        # Xavier/He initialization for better gradient flow
        scale = (2.0 / nin) ** 0.5 if NUMPY_AVAILABLE else 0.1
        self.w = [Value(random.gauss(0, scale)) for _ in range(nin)]
        self.b = Value(0.0)

    def __call__(self, x: List[Value]) -> Value:
        """Forward pass: w·x + b → tanh."""
        act = sum((wi * xi for wi, xi in zip(self.w, x)), self.b)
        return act.tanh()

    def parameters(self) -> List[Value]:
        return self.w + [self.b]


class Layer:
    """Fully connected layer of neurons."""

    def __init__(self, nin: int, nout: int):
        self.neurons = [Neuron(nin) for _ in range(nout)]

    def __call__(self, x: List[Value]) -> List[Value]:
        outs = [n(x) for n in self.neurons]
        return outs

    def parameters(self) -> List[Value]:
        return [p for neuron in self.neurons for p in neuron.parameters()]


class MLP:
    """Multi-layer perceptron: x → hidden → output."""

    def __init__(self, nin: int, nouts: List[int]):
        """
        Args:
            nin: Input dimension
            nouts: List of layer sizes, e.g. [16, 1] for hidden=16, output=1
        """
        sz = [nin] + nouts
        self.layers = [Layer(sz[i], sz[i+1]) for i in range(len(nouts))]

    def __call__(self, x: List[Value]) -> Value:
        """Forward pass through all layers."""
        for layer in self.layers:
            x = layer(x)
        # Last layer output (single neuron for regression)
        return x[0] if len(x) == 1 else x

    def parameters(self) -> List[Value]:
        return [p for layer in self.layers for p in layer.parameters()]


# ============================================================================
# FEATURE EXTRACTION
# ============================================================================


@dataclass
class MathState:
    """Snapshot of Leo's internal state for MathBrain."""

    # Presence / pulse
    entropy: float = 0.0
    novelty: float = 0.0
    arousal: float = 0.0
    pulse: float = 0.0

    # Trauma / origin
    trauma_level: float = 0.0

    # Themes / flow
    active_theme_count: int = 0
    total_themes: int = 0
    emerging_score: float = 0.0
    fading_score: float = 0.0

    # Reply shape
    reply_len: int = 0
    unique_ratio: float = 0.0

    # Expert / mode
    expert_id: str = "structural"
    expert_temp: float = 1.0
    expert_semantic: float = 0.5

    # MetaLeo / inner voice
    metaleo_weight: float = 0.0
    used_metaleo: bool = False

    # Overthinking
    overthinking_enabled: bool = False
    rings_present: int = 0

    # Target (what we're trying to predict)
    quality: float = 0.5


def state_to_features(state: MathState) -> List[float]:
    """
    Convert MathState to fixed-size feature vector.

    All features normalized to ~[0, 1] range.
    Returns 21-dimensional vector.

    If any feature is non-finite (NaN/inf), returns safe default vector.
    """
    # Expert one-hot encoding
    expert_map = {
        "structural": 0,
        "semantic": 1,
        "creative": 2,
        "precise": 3,
        "wounded": 4,
    }
    expert_idx = expert_map.get(state.expert_id, 0)
    expert_onehot = [1.0 if i == expert_idx else 0.0 for i in range(5)]

    # Normalize active themes (with safety check)
    active_norm = 0.0
    if state.total_themes > 0:
        active_norm = state.active_theme_count / max(1, state.total_themes)
    if not _is_finite_safe(active_norm):
        active_norm = 0.0

    # Normalize reply length (typical range 0-64)
    reply_norm = min(1.0, state.reply_len / 64.0) if state.reply_len >= 0 else 0.0
    if not _is_finite_safe(reply_norm):
        reply_norm = 0.0

    # Build feature vector
    features = [
        state.entropy,           # 0
        state.novelty,           # 1
        state.arousal,           # 2
        state.pulse,             # 3
        state.trauma_level,      # 4
        active_norm,             # 5
        state.emerging_score,    # 6
        state.fading_score,      # 7
        reply_norm,              # 8
        state.unique_ratio,      # 9
        state.expert_temp,       # 10
        state.expert_semantic,   # 11
        state.metaleo_weight,    # 12
        float(state.used_metaleo),         # 13
        float(state.overthinking_enabled), # 14
        float(state.rings_present > 0),    # 15
    ] + expert_onehot  # 16-20 (5 experts)

    # Safety check: if any feature is non-finite, return safe default
    if not _all_finite(features):
        _debug_log(f"Non-finite features detected, returning safe defaults")
        # Return safe neutral vector
        return [0.5] * 16 + expert_onehot

    return features


# ============================================================================
# MATH BRAIN
# ============================================================================


class MathBrain:
    """
    Dynamic math brain for Leo.

    Learns to predict Leo's internal quality score from his own metrics.
    No gradient through text generation, only through a tiny MLP.

    Phase 1 (v1): Pure observation
    - observe() after each reply
    - predict quality from state
    - update weights via SGD
    - no influence on Leo yet

    Storage: JSON in state/mathbrain.json
    """

    def __init__(
        self,
        leo_field: Any,
        hidden_dim: int = 16,
        lr: float = 0.01,
        state_path: Optional[Path] = None,
    ):
        """
        Args:
            leo_field: LeoField instance (not used yet, for future hooks)
            hidden_dim: Size of hidden layer
            lr: Learning rate for SGD
            state_path: Path to save/load weights (default: state/mathbrain.json)
        """
        self.field = leo_field
        self.hidden_dim = hidden_dim
        self.lr = lr
        self.state_path = state_path or (Path(__file__).parent / "state" / "mathbrain.json")

        # Feature dimension (from state_to_features)
        self.in_dim = 21  # 16 scalars + 5 expert one-hot

        # Build MLP: input → hidden → output
        self.mlp = MLP(self.in_dim, [hidden_dim, 1])

        # Statistics
        self.observations = 0
        self.running_loss = 0.0
        self.last_loss = 0.0

        # Try to load previous state
        self._load_state()

    def _reset_to_fresh_init(self) -> None:
        """
        Reset MathBrain to fresh initialization.
        Called when weight corruption (NaN/inf) is detected.
        """
        _debug_log("Weight corruption detected, resetting to fresh initialization")
        self.mlp = MLP(self.in_dim, [self.hidden_dim, 1])
        self.observations = 0
        self.running_loss = 0.0
        self.last_loss = 0.0

    def _clamp_weights(self, min_val: float = -5.0, max_val: float = 5.0) -> None:
        """
        Clamp all MLP weights to safe range to prevent runaway values.
        """
        for p in self.mlp.parameters():
            if _is_finite_safe(p.data):
                p.data = max(min_val, min(max_val, p.data))
            else:
                p.data = 0.0  # Reset non-finite weights to zero

    def _check_corruption(self, loss_val: float) -> bool:
        """
        Check if loss or any parameter became non-finite (corrupted).
        Returns True if corruption detected.
        """
        # Check loss
        if not _is_finite_safe(loss_val):
            return True

        # Check all parameters
        for p in self.mlp.parameters():
            if not _is_finite_safe(p.data):
                return True

        return False

    def observe(self, state: MathState) -> float:
        """
        Observe one (state, quality) pair and learn from it.

        Steps:
        1. Check state for non-finite values (skip if found)
        2. Extract features from state
        3. Forward pass → predicted quality
        4. Compute MSE loss
        5. Backward pass
        6. SGD step
        7. Clamp weights to safe range
        8. Check for corruption (reset if detected)
        9. Update statistics

        Returns:
            Current loss value (or last_loss if skipped due to bad data)
        """
        # Pre-check: skip if any critical state values are non-finite
        critical_values = [
            state.entropy,
            state.novelty,
            state.arousal,
            state.pulse,
            state.trauma_level,
            state.quality,
        ]
        if not _all_finite(critical_values):
            _debug_log("Skipping update due to non-finite state values")
            return self.last_loss

        # Extract features
        features = state_to_features(state)

        # Safety check: features should be finite after extraction
        if not _all_finite(features):
            _debug_log("Skipping update due to non-finite features")
            return self.last_loss

        # Safety check: target quality must be finite
        target_q = max(0.0, min(1.0, state.quality))
        if not _is_finite_safe(target_q):
            _debug_log(f"Skipping update due to non-finite target quality: {state.quality}")
            return self.last_loss

        # Build Value nodes
        x = [Value(f) for f in features]

        # Forward pass
        q_hat = self.mlp(x)

        # Loss: MSE
        diff = q_hat - Value(target_q)
        loss = diff * diff

        # Backward pass
        for p in self.mlp.parameters():
            p.grad = 0.0
        loss.backward()

        # SGD step
        for p in self.mlp.parameters():
            p.data -= self.lr * p.grad

        # Clamp weights to safe range [-5.0, 5.0]
        self._clamp_weights()

        # Check for corruption (NaN/inf in loss or parameters)
        loss_val = loss.data
        if self._check_corruption(loss_val):
            # Reset to fresh initialization instead of saving corrupted state
            self._reset_to_fresh_init()
            return 0.0  # Return safe loss value

        # Update stats
        self.observations += 1
        self.last_loss = loss_val
        # Exponential moving average (alpha=0.05)
        self.running_loss += (loss_val - self.running_loss) * 0.05

        return loss_val

    def predict(self, state: MathState) -> float:
        """
        Predict quality from state (no training).

        Returns:
            Predicted quality in [0, 1]
        """
        features = state_to_features(state)
        x = [Value(f) for f in features]
        q_hat = self.mlp(x)
        # Clamp to [0, 1]
        return max(0.0, min(1.0, q_hat.data))

    def get_stats(self) -> Dict[str, Any]:
        """Return training statistics."""
        return {
            "observations": self.observations,
            "running_loss": self.running_loss,
            "last_loss": self.last_loss,
            "hidden_dim": self.hidden_dim,
            "learning_rate": self.lr,
            "in_dim": self.in_dim,
            "num_parameters": len(self.mlp.parameters()),
        }

    def _save_state(self) -> None:
        """Save weights to JSON."""
        try:
            self.state_path.parent.mkdir(parents=True, exist_ok=True)

            # Extract weights as nested lists
            weights = {
                "in_dim": self.in_dim,
                "hidden_dim": self.hidden_dim,
                "observations": self.observations,
                "running_loss": self.running_loss,
                "parameters": [p.data for p in self.mlp.parameters()],
            }

            with open(self.state_path, 'w') as f:
                json.dump(weights, f, indent=2)
        except Exception:
            # Silent fail — do not break Leo
            pass

    def _load_state(self) -> None:
        """Load weights from JSON if available."""
        try:
            if not self.state_path.exists():
                return

            with open(self.state_path, 'r') as f:
                data = json.load(f)

            # Validate dimensions match
            if data["in_dim"] != self.in_dim or data["hidden_dim"] != self.hidden_dim:
                # Dimension mismatch — start fresh
                return

            # Restore weights
            params = self.mlp.parameters()
            saved_params = data["parameters"]
            if len(params) != len(saved_params):
                return

            for p, val in zip(params, saved_params):
                p.data = float(val)

            # Restore stats
            self.observations = data.get("observations", 0)
            self.running_loss = data.get("running_loss", 0.0)
        except Exception:
            # Silent fail — start fresh if loading fails
            pass

    def save(self) -> None:
        """Public API to save state (e.g., on REPL exit)."""
        self._save_state()

    def multileo_regulate(
        self,
        temperature: float,
        expert_name: str,
        state: MathState,
        turn_id: Optional[str] = None,
    ) -> Tuple[float, str]:
        """
        MultiLeo presence-aware regulation layer.

        Computes boredom/overwhelm/stuck scores from state and gently nudges:
        - temperature (±0.2 max)
        - expert choice (soft bias)

        Returns:
            (adjusted_temperature, suggested_expert)
        """
        try:
            # Predict quality from state
            predicted_q = self.predict(state)

            # Compute MultiLeo scores
            boredom = _compute_boredom_score(state)
            overwhelm = _compute_overwhelm_score(state)
            stuck = _compute_stuck_score(state, predicted_q)

            # Start with no change
            temp_nudge = 0.0
            suggested_expert = expert_name

            # BOREDOM: wake up (increase exploration)
            if boredom > 0.6:  # Significant boredom
                temp_nudge += MULTILEO_TEMP_NUDGE_MAX * (boredom - 0.6) / 0.4
                # Bias towards creative expert when bored
                if boredom > 0.75 and expert_name not in ["creative", "wounded"]:
                    suggested_expert = "creative"

            # OVERWHELM: soften (reduce chaos)
            if overwhelm > 0.7:  # Significant overwhelm
                temp_nudge -= MULTILEO_TEMP_NUDGE_MAX * (overwhelm - 0.7) / 0.3
                # Bias towards precise or structural when overwhelmed
                if overwhelm > 0.85 and expert_name not in ["precise", "structural", "wounded"]:
                    suggested_expert = "precise"

            # STUCK: try something different
            if stuck > 0.6:  # Significant stuck-ness
                # Small temperature increase to break pattern
                temp_nudge += 0.1
                # Consider semantic or metaleo-influenced routing
                if stuck > 0.75 and expert_name == "structural":
                    suggested_expert = "semantic"

            # Apply nudge to temperature
            adjusted_temp = temperature + temp_nudge

            # Enforce absolute bounds
            adjusted_temp = max(MULTILEO_TEMP_MIN, min(MULTILEO_TEMP_MAX, adjusted_temp))

            # Log event if there's a change
            if turn_id and (abs(temp_nudge) > 0.01 or suggested_expert != expert_name):
                import time
                _log_multileo_event(
                    timestamp=time.time(),
                    turn_id=turn_id,
                    state=state,
                    predicted_quality=predicted_q,
                    boredom=boredom,
                    overwhelm=overwhelm,
                    stuck=stuck,
                    temp_before=temperature,
                    temp_after=adjusted_temp,
                    expert_before=expert_name,
                    expert_after=suggested_expert,
                )

            return (adjusted_temp, suggested_expert)

        except Exception:
            # Silent fail - MultiLeo must never break generation
            return (temperature, expert_name)

    def __repr__(self) -> str:
        return (
            f"MathBrain(in_dim={self.in_dim}, hidden={self.hidden_dim}, "
            f"obs={self.observations}, loss={self.running_loss:.4f})"
        )


__all__ = [
    "Value",
    "MLP",
    "MathBrain",
    "MathState",
    "state_to_features",
    "NUMPY_AVAILABLE",
]
