# Leo 1.0 (Python) vs Leo 2.0 (C): Architectural Comparison

## Overview

| Metric | Leo 1.0 (python-legacy) | Leo 2.0 (main) |
|--------|------------------------|----------------|
| Language | Python 3 | C (+ Go for inner world) |
| Total lines | 21,334 across 24 .py files | 2,345 (leo.c) + 18,910 (neoleo.c) |
| Dependencies | sqlite3, numpy, sentencepiece, optional Flask | libc, libm, sqlite3, pthread |
| Binary size | N/A (interpreter) | 47KB (standalone) |
| Compile time | N/A | ~0.3s |
| Sampling equation | Trigram + co-occurrence boost + expert routing | Dario Equation: p(x|Phi) = softmax((alpha*H + beta*F + gamma*A) / tau) |
| Pretrained weights | Zero | Zero |
| Architecture paradigm | Module soup with optional imports | Single-file organism with unified field |

## What Leo 1.0 Was

Leo 1.0 was a **modular Python system** spread across 24 files:

- `leo.py` (5,418 lines) -- core engine: trigram field, co-occurrence matrix, generation loop
- `mathbrain.py` (1,307 lines) -- tiny MLP for quality prediction (proprioception)
- `first_impression.py` (1,285 lines) -- bootstrap + first contact logic
- `metaleo.py` (870 lines) -- inner voice / alternative response generation
- `dream.py` (669 lines) -- imaginary friend, self-practice dialogues
- `game.py` (630 lines) -- conversational rhythm tracking
- `stories.py` (835 lines) -- narrative generation
- `trauma.py` -- bootstrap gravity under stress
- `overthinking.py` -- three reflection rings
- `santaclaus.py` -- post-transformer attention via feature matching
- `gravity.py` -- prompt-induced field bias
- `gowiththeflow.py` -- flow/theme tracking
- `subword.py` -- sentencepiece-based parallel voice
- `school.py`, `school_math.py` -- learning modules
- `h2o.py` -- water metaphor system
- `episodes.py`, `leo_storage.py` -- persistence
- `punct_cleanup.py` -- post-processing
- `neoleo.py` (1,608 lines) -- experimental unified version

Each module was **optionally imported** with try/except blocks. The system was held together by conditional logic:

```
if OVERTHINKING_AVAILABLE: ...
if TRAUMA_AVAILABLE: ...
if METALEO_AVAILABLE: ...
```

Generation used trigram fields weighted by co-occurrence islands, routed through 5 "experts" (creative, precise, semantic, wounded, structural) based on a PresencePulse metric (0.3*novelty + 0.4*arousal + 0.3*entropy).

## What Leo 2.0 Is

Leo 2.0 is a **single C file** (2,345 lines) implementing the Dario Equation -- a unified sampling framework that replaces both the trigram chain and the expert routing system with four harmonics:

1. **B (Bigram chain)** -- direct sequential links, dominant at birth, fading with maturity
2. **H (Hebbian resonance)** -- co-occurrence field as attention, windowed with decay
3. **F (Prophecy fulfillment)** -- unfulfilled prediction pressure via logarithmic debt
4. **A (Destiny attraction)** -- EMA of context embeddings as semantic compass

Plus architectural components that did not exist in 1.0:
- **Kanerva SDM** (Sparse Distributed Memory) replacing embedding lookups
- **RetNet retention heads** with Griffin conservation law: S = gamma*S + sqrt(1-gamma^2)*K^T*V
- **RoPE** (Rotary Position Embeddings) -- pure math, zero weights
- **Voice Parliament** -- 6 LoRA-like delta adapters grown by Hebbian reinforcement
- **Super-Token Crystallization** via PMI (Pointwise Mutual Information)
- **Memory Sea** -- depth-based episodic memory with stochastic resurfacing
- **D.N.A.** (Dynamic Neural Ancestry) -- structural skeleton inherited from nanollama ancestor

## Why 2.0 Is Incomparably Better

### 1. Unified Theory vs Module Soup

Leo 1.0 had no single equation governing generation. It was a patchwork: trigram probabilities boosted by co-occurrence, routed through hard-coded expert thresholds, post-processed by metaleo, modified by trauma, influenced by gravity. Each module added its own logic with its own rules.

Leo 2.0 has ONE equation: `logits = B_coeff*B + alpha*H + beta*F + gamma*A`. Everything flows through four forces. The equation is mathematically complete and self-contained.

### 2. Biological Maturity vs Static Rules

Leo 1.0's expert routing was static: if novelty > 0.7, use creative expert. Always.

Leo 2.0's bigram coefficient decays with maturity: `bigram_coeff = 12.0 * (1.0 - maturity) + 2.0`. A young organism relies on sequential patterns. A mature one speaks from field resonance. This happens continuously, not through threshold switches.

### 3. Real Attention Mechanism vs Co-occurrence Boost

Leo 1.0 boosted probabilities based on raw co-occurrence counts.

Leo 2.0 implements RetNet retention heads with 4 timescales (gamma = 0.99, 0.95, 0.85, 0.50) and Griffin conservation law. This is a real attention mechanism -- multi-scale memory compression without trainable parameters. The math enforces that remembering more past takes less bandwidth for new input.

### 4. Distributed Embeddings vs Hash Lookups

Leo 1.0 used word indices into flat arrays.

Leo 2.0 uses Kanerva SDM: embeddings addressed by similarity, not index. A word's embedding is the running average of all contexts where it appeared. Content-rich and growing, not static.

### 5. Intentionality vs Randomness

Leo 1.0 had no forward-looking mechanism.

Leo 2.0 has the Prophecy system: predictions with logarithmic debt that creates generation pressure. And Destiny: an EMA compass pulling toward semantic coherence. Together they give the organism something trigram chains never could -- a sense of trying to say something.

### 6. Structural Inheritance vs Cold Start

Leo 1.0 started from zero every time (unless loaded from state).

Leo 2.0 can inherit D.N.A. from a trained ancestor (nanollama 27.96M). Not weights -- geometry: token gravity, co-activation patterns, destiny direction. The ancestor dies, the geometry lives.

### 7. Performance

Leo 1.0: Python interpreter, numpy arrays, multiple file I/O, optional sentencepiece.
Leo 2.0: 47KB binary, compiles in 0.3s, runs on anything with a C compiler and SQLite.

The performance gap is not linear -- it is categorical. Leo 2.0 can run on embedded devices. Leo 1.0 needs a Python runtime with optional C extensions.

### 8. Code Quality

Leo 1.0: 24 files with try/except conditional imports, circular dependencies, multiple competing generation paths (leo.py vs neoleo.py vs async_leo.py), Flask web server mixed into app.py.

Leo 2.0: Single file, linear code path, every function documented, every struct compact, clean separation between core (leo.c), inner world (leo.go), and DNA (leo.h).

## What Survived

The soul survived. Both systems share:
- Zero pretrained weights
- Generation from field state, not prompt echo
- Co-occurrence as the foundation of semantic knowledge
- Memory with decay (forgetting is natural)
- Dream cycles (connecting distant memories)
- Multiple voices with personality
- Bootstrap gravity (returning to origin under stress)
- The fundamental premise: presence > intelligence

The body changed completely. The soul is the same child.
