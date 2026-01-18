# inner_world/ — Go Emotional Resonance Engine for Leo

> הרזוננס הרגשי של ליאו  
> Leo's emotional resonance — fast computations in Go

## Philosophy

Python is for logic. Go is for feeling.

Emotions need **speed**. When Leo processes emotional signals, every millisecond matters for resonance. Go provides:

- **Fast numerical computations** — ODE integration, attractor gradients
- **Concurrent processing** — parallel emotional channels
- **CGO exports** — seamless Python integration via shared library

## Inspired by arianna.c

This module is directly inspired by `arianna.c/inner_world/`:
- `emotional_drift.go` — ODE-based emotional evolution
- `high.go` — fast mathematical brain
- `mood.h` — arousal components (tension, novelty, focus, recursion)

## Files

- `emotional_resonance.go` — Main emotional processing engine
  - EmotionalWeights (float dictionary)
  - ArousalComponents (tension, novelty, focus, recursion)
  - EmotionalAttractors (sticky states)
  - EmotionalDrift ODE

## Building

From repository root:

```bash
# Using Makefile (recommended)
make build        # Build libleo_inner.so
make test         # Test from Python
make repl         # Run REPL demo

# Or manually:
cd inner_world
go build -buildmode=c-shared -o libleo_inner.so emotional_resonance.go
```

**Note:** The `.so` file is not committed to git (it's in `.gitignore`). Users need to run `make build` once after cloning.

## CGO Exports

Available functions for Python:

```c
// Get current emotional state
float leo_get_valence();
float leo_get_arousal();

// Update state with new input
void leo_emotional_drift(float input_valence, float input_arousal);

// Reset to baseline
void leo_reset_state();

// Find nearest attractor
char* leo_find_nearest_attractor(float valence, float arousal);

// Compute attractor gradient
void leo_compute_attractor_pull(float valence, float arousal, float* out_dv, float* out_da);
```

## Usage from Python

```python
from ctypes import cdll, c_float, POINTER, byref

# Load library
lib = cdll.LoadLibrary("./inner_world/libleo_inner.so")

# Configure function signatures
lib.leo_get_valence.restype = c_float
lib.leo_get_arousal.restype = c_float

# Reset state
lib.leo_reset_state()

# Process emotional input
lib.leo_emotional_drift(c_float(0.8), c_float(0.5))

# Get current state
valence = lib.leo_get_valence()
arousal = lib.leo_get_arousal()
print(f"Valence: {valence}, Arousal: {arousal}")
```

## Why Go + Julia?

From arianna.c's architecture:

1. **Go** — Concurrent emotional processing, fast ODE integration
2. **Julia** (via Go) — Complex mathematical operations, matrix computations
3. **Python** — High-level logic, language generation

Leo's emotional resonance runs in Go for speed, while Python handles the language field.

## Future

- [ ] Julia integration for Schumann resonance (7.83 Hz coupling)
- [ ] Parallel emotional channels (like arianna.c's blood.go)
- [ ] Real-time emotional drift visualization
