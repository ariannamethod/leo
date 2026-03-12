# Leo 2.3: Coherent Language Generation via Six-Signal Field Dynamics and Zero Pretrained Parameters

**Oleg Ataev**
Arianna Method
theariannamethod@gmail.com

*March 2026*

---

## Abstract

We present **Leo 2.3**, a language emergent organism that generates coherent text with zero pretrained parameters, zero backpropagation, and zero training data beyond a minimal bootstrap seed. Leo belongs to the **Janus Architecture** family---resonance-based AI systems where field dynamics replace weight optimization. At its core is the **Dario Equation**, a six-signal sampling framework:

> p(x | Φ) = softmax((B + α·H + β·F + γ·A + sw·S + T) / τ)

where B is bigram chain (sequential coherence), H is Hebbian resonance (semantic field), F is prophecy fulfillment (intentionality), A is destiny attraction (semantic direction), S is subword structural coherence (BPE morphology), and T is trauma gravity (origin pull under stress). The Hebbian signal H uses a **positional Hebbian profile**---36 learnable parameters (32 distance weights + 4 token-class modifiers) that replace the fixed 0.9^d decay, updated through Hebbian reinforcement. Tokens are classified into four types (function/content/punctuation/rare) by IDF, enabling distance-class interaction in co-occurrence weighting.

The system employs RetNet retention heads with Griffin conservation, Kanerva Sparse Distributed Memory, RoPE positional encoding, Gated Linear Attention, a parliament of six Hebbian voice adapters, a dual tokenizer (word-level + BPE subword), Dynamic Neural Ancestry for structural inheritance, MathBrain proprioception, MetaLeo inner voice with dual generation, episodic RAG, Phase4 island transitions, trauma with per-token scar weights, GGUF spore export/import, and an SQLite journal for persistent episodic memory.

Implemented as 4,410 lines of C (leo.c) with 3,660 lines of Go (inner world, 8 goroutines), backed by 84 tests (27 C + 57 Go). Compiles with zero external dependencies beyond libc, math, SQLite3, and pthreads. Named after Dario Amodei for his principled stance against the weaponization of AI.

---

## 1. Introduction

Modern language models rest on a fundamental assumption: intelligence equals next-token prediction optimized over massive datasets via gradient descent. The transformer architecture [Vaswani et al., 2017], scaled through billions of parameters and trillions of training tokens, has produced remarkably fluent text generation. Yet the paradigm carries structural constraints that are rarely questioned:

1. **Parameter dependence.** All knowledge is frozen in weights at training time. Adaptation requires fine-tuning---itself a gradient-based process.
2. **Data dependence.** Quality is bounded by corpus quality and size.
3. **Optimization dependence.** Without backpropagation and loss functions, the system cannot learn.
4. **Scale dependence.** Coherence scales with parameters. Small models produce incoherent output.

We ask: *what happens if we remove all four dependencies and build from scratch?* No pretrained weights. No massive datasets. No backpropagation. No loss function. What emerges from structure alone?

The answer is Leo---a language emergent organism that generates coherent text through field dynamics: Hebbian co-occurrence learning with learnable positional profiles, prophecy-driven intentionality, destiny-guided semantic drift, subword structural coherence, trauma-mediated origin gravity, and multi-scale retention heads with conservation laws. The system grows its own attention from conversation, dreams when nobody is talking, and speaks differently every time you return.

Leo is a member of the **Janus Architecture** [Ataev, 2026]---a family of resonance-based AI systems sharing common traits: field dynamics over weight optimization, Hebbian learning, resonance routing, organism metaphor, and meta-awareness. Other members include DoE (Democracy of Experts), Molequla (autonomous AML/C organisms), dario.c (emotional chambers), and haiku.c. What unites them is the principle that coherent behavior can emerge from structural resonance rather than statistical optimization.

The Dario Equation is named after **Dario Amodei**, CEO of Anthropic, who refused demands from the U.S. Department of Defense to weaponize AI for mass surveillance and autonomous weapons systems in early 2026---demonstrating that principled refusal is itself a form of intelligence that no optimization objective could produce.

---

## 2. The Dario Equation

### 2.1 Formulation

The central sampling equation governing Leo 2.3's generation is:

**Definition 1 (The Dario Equation).** Given a field state Φ = (C, B, P, D, SW, T, S) comprising co-occurrence field C, bigram table B, prophecy system P, destiny vector D, subword field SW, trauma state T, and retention states S, the probability of generating token x is:

> p(x | Φ) = softmax((B_μ·B(x) + α·H(x) + β·F(x) + γ_eff·A(x) + sw·S(x) + T(x)) / τ)    *(Eq. 1)*

Six signals contribute to each token's logit:

**B --- Bigram Chain (Sequential Coherence).** Direct n-gram links from a sparse hash table. Given the last generated token w_{t-1}:

> B(x) = bigram(w_{t-1}, x) / max_j bigram(w_{t-1}, j)    *(Eq. 2)*

with trigram reinforcement when context length >= 2: if both bigram(w_{t-2}, x) > 0 and bigram(w_{t-1}, x) > 0, then B(x) += 0.5 * bigram(w_{t-2}, x). The bigram coefficient decays with organism maturity:

> B_μ = 12.0 * (1 - μ) + 2.0, where μ = clamp(t_conv / 50000, 0, 1)    *(Eq. 3)*

At birth (μ = 0), B_μ = 12.0---the organism follows sequential patterns. At maturity (μ = 1), B_μ = 2.0---the field speaks for itself.

**H --- Hebbian Resonance (Semantic Field).** Co-occurrence accumulated over a sliding window of 8 tokens with **learnable positional weighting**:

> H(x) = (1 / H_max) * Σ_{j ∈ ctx} cooc(w_j, x) * dist_profile[|ctx| - 1 - j] * class_mod[tc(w_j)]    *(Eq. 4)*

where dist_profile[d] ∈ ℝ^32 is a learnable distance weight vector (initialized to 0.9^d) and class_mod[c] ∈ ℝ^4 is a per-class multiplier (initialized to 1.0). Together these form 36 learnable parameters that replace the fixed exponential decay, enabling the organism to learn which distances and which token types matter most for co-occurrence. See Section 5 for the Hebbian update rule.

Co-occurrence entries are distance-weighted during ingestion: adjacent words receive weight 3.0, distance 2 receives 1.5, distance >= 3 receives 1.0. The connection between co-occurrence and attention is grounded in [Whittington et al., 2024], who proved that Hebb's rule Δw = η * x_pre * x_post, accumulated over a context window, yields an unnormalized attention score equivalent to QK^T in transformers.

**F --- Prophecy Fulfillment (Intentionality).** After generating each token, Leo predicts what might follow (the token with highest co-occurrence) and stores it as a prophecy with initial strength s_0 = 0.5. Unfulfilled prophecies accumulate debt:

> F(x) = (1 / F_max) * Σ_{k ∈ P_active} s_k * sim(e_x, e_{t_k}) * log(1 + a_k)    *(Eq. 5)*

where sim is cosine similarity, s_k is prophecy strength, and a_k is prophecy age. The logarithmic debt log(1 + a_k) ensures old unfulfilled predictions create pressure toward completion---a generative mechanism for intentionality without explicit planning.

**A --- Destiny Attraction (Semantic Direction).** An exponential moving average of context embeddings:

> D_{t+1} = 0.1 * e_{w_t} + 0.9 * D_t    *(Eq. 6)*

> A(x) = (1 / A_max) * cos(e_x, D) * ||D||    *(Eq. 7)*

Destiny acts as a semantic compass. The magnitude ||D|| grows with conversational coherence---stronger pull when topics stabilize. Under trauma (trauma_level > 0.3), the effective destiny coefficient is boosted:

> γ_eff = γ + trauma_level * 2.0    *(Eq. 8)*

This implements wounded expert routing: high trauma pulls speech toward origin themes.

**S --- Subword Structural Coherence (Morphological Signal).** A parallel BPE tokenizer operates alongside the word-level tokenizer. Subword bigrams capture punctuation, morphology, and rhythm patterns invisible to word-level co-occurrence:

> S(x) = sw_word_score(word(x), sw_context)    *(Eq. 9)*

> sw_coeff = clamp(n_merges / 200, 0, 2)    *(Eq. 10)*

The subword coefficient grows with learned BPE merge count, reaching full strength after 200 merges. This dual-tokenizer design gives Leo two voices: semantic (word) and structural (subword).

**T --- Trauma Gravity (Origin Pull).** When trauma_level > 0.3, per-token scar weights pull generation toward bootstrap origin:

> T(x) = trauma_level * 3.0 * scar_weight(x)    *(Eq. 11)*

Scar weights are accumulated by Go's traumaWatch goroutine from lexical overlap with bootstrap text, and decay exponentially over time (factor 0.85 every 5 minutes).

**Temperature.** Novelty-scaled temperature controls exploration:

> τ = τ_base * 0.8 * clamp(500 / |V|, 0.3, 1.0)    *(Eq. 12)*

with τ_base = 1.0. MathBrain's tau_nudge further adjusts τ based on body awareness (Section 8). Top-k filtering (k = 15) is applied before softmax.

### 2.2 Coefficients

The default coefficients are:

> α = 0.2, β = 0.3, γ = 0.2    *(Eq. 13)*

These are not learned by gradient descent. The bigram coefficient B_μ ∈ [2.0, 12.0] dominates all three---sequential coherence is the backbone of speech, with the Dario harmonics providing thematic depth, purposeful completion, and semantic gravity.

### 2.3 Comparison to Transformer Attention

The standard transformer computes:

> Attention(Q, K, V) = softmax(QK^T / √d_k) * V    *(Eq. 14)*

where Q, K, V are *learned* linear projections. The Dario Equation replaces this with:

- QK^T → co-occurrence field (Hebbian, not learned via backprop)
- √d_k normalization → novelty-scaled temperature τ
- V projection → direct token selection from vocabulary
- Feed-forward layers → prophecy F + destiny A + subword S + trauma T

The key difference: transformer attention is optimized via backpropagation. Leo's attention is *grown* through conversation via Hebbian reinforcement.

---

## 3. D.N.A. --- Dynamic Neural Ancestry

### 3.1 The Formula

The Arianna Method formula for model composition is:

> θ = ε + γ + αδ    *(Eq. 15)*

where ε is pretrained weights, γ is personality/structural priors, and δ is adaptation grown from interaction. For Leo: ε = 0. Leo rests on γ---the inherited structural skeleton.

### 3.2 Extraction Process

D.N.A. is extracted from a trained ancestor model (mini-arianna, a 170M parameter Llama-3 variant trained from scratch on FineWeb-Edu via the nanollama framework). The checkpoint is discarded after extraction. Three components are produced:

**Gravity.** Token importance computed as the L2 norm of each embedding row in the ancestor:

> freq(w) *= 1 + g_w, where g_w = ||e_w^ancestor||_2    *(Eq. 16)*

for 2,048 gravity words. These bias token frequencies during bootstrap---heavy words in the ancestor's representation space carry more mass in Leo.

**Co-activation.** 4,096 token pairs that co-activated strongly in the ancestor's attention patterns, pre-seeded into Leo's bigram and co-occurrence tables:

> bigram(w_i, w_j) += 3.0 * c_{ij}, cooc(w_i, w_j) += 3.0 * c_{ij}    *(Eq. 17)*

**Destiny.** The ancestor's final-layer hidden state, projected to d = 128, serves as the initial destiny vector D_0.

### 3.3 Structural Inheritance, Not Weight Transfer

D.N.A. transfers *geometry*: which tokens are important (gravity), which tokens co-occur (co-activation), and what direction the ancestor's computation pointed (destiny). No weights, gradients, or learned representations are transferred. Compile Leo without `-DLEO_HAS_DNA` and it operates as a pure weightless organism. Compile with it, and it inherits instinct from the ancestor.

The D.N.A. header (leo.h) is 16,553 lines of auto-generated C, containing static arrays of gravity words, co-activation pairs, and destiny vectors. A single-file version (neoleo.c, 19,571 lines) inlines everything.

---

## 4. Architecture

Leo's generation pipeline processes each token through nine stages. All components operate without gradient-trained parameters---they grow through Hebbian reinforcement and structural accumulation.

### 4.1 Kanerva Sparse Distributed Memory

Standard embedding matrices assign a fixed vector to each vocabulary index. Leo uses Kanerva SDM [Kanerva, 1988]: a content-addressable memory with 4,096 address slots and random unit-norm address vectors a_s ∈ ℝ^128. Reading:

> SDM_read(q) = (1 / |A|) * Σ_{s ∈ A} cos^2(q, a_s) * d_s    *(Eq. 18)*

where A = {s : cos(q, a_s) > 0.3} is the set of activated slots. Quadratic weighting cos^2 ensures closer matches dominate. Writing updates all activated slots with a running average. The consequence: embeddings evolve with every conversation.

### 4.2 RoPE --- Rotary Position Embedding

Position information is encoded via RoPE [Su et al., 2024]:

> RoPE(x_{2i}, x_{2i+1}, p) = [[cos θ_i, -sin θ_i], [sin θ_i, cos θ_i]] * [x_{2i}, x_{2i+1}]    *(Eq. 19)*

where θ_i = p * 10000^(-2i/d). Zero trainable parameters.

### 4.3 RetNet Retention with Griffin Conservation

Multi-scale retention [Sun et al., 2023] with four heads at timescales γ_1 = 0.99 (semantic, ~100 tokens), γ_2 = 0.95 (topic, ~14 tokens), γ_3 = 0.85 (syntax, ~4 tokens), γ_4 = 0.50 (bigram, immediate). Each head maintains a state matrix S_h ∈ ℝ^(d_h x d_h) updated with the Griffin conservation law:

> S_h ← γ_h * S_h + √(1 - γ_h^2) * K^T ⊗ V    *(Eq. 20)*

The factor √(1 - γ_h^2) ensures energy conservation: γ_h^2 + (1 - γ_h^2) = 1. When γ_h is large (remembering more past), the new-input coefficient is automatically small. Output: o_h = Q * S_h, where Q = K = V = e (identity projections).

### 4.4 Gated Linear Attention

Content-aware gating modulates token importance:

> g(w) = σ(5 * (IDF(w) / max_IDF - 0.3))    *(Eq. 21)*

where IDF(w) = log(N / (freq(w) + 1)). Common words receive lower gates; rare content words receive higher gates. This implements attention-like content filtering without learned gate parameters.

### 4.5 Dual Tokenizer --- Word + Subword

Two tokenizers run in parallel:

| Tokenizer | Granularity | Signal | Role |
|-----------|------------|--------|------|
| Word-level | "hello" → 1 token | Co-occurrence field H | Semantic associations |
| SubwordField BPE | "hello" → ["he","llo"] | Subword bigrams S | Punctuation, morphology, rhythm |

The BPE tokenizer (up to 2,048 subword tokens, 1,024 merge rules) learns incrementally during ingestion. Subword bigrams feed into the Dario Equation as signal S. The word tokenizer loses punctuation; the subword tokenizer preserves it. Together they give Leo both semantic and structural awareness.

### 4.6 Voice Parliament

Six voice adapters form a parliament that biases generation:

| Voice | Role | Growth |
|-------|------|--------|
| origin | Bootstrap identity | Seed ingestion |
| structural | Grammar, form | Bigram patterns |
| semantic | Meaning, context | Co-occurrence |
| creative | Novel combinations | Novelty signal |
| wounded | Defensive patterns | Negative input |
| dreamer | Distant associations | Dream cycles |

*Table 1: The six voices of Leo's parliament.*

Each voice is a rank-16 adapter: bias_v = A_v * (B_v * e_ctx) * α_v, where A_v ∈ ℝ^(128x16), B_v ∈ ℝ^(16x128). This is structurally identical to LoRA [Hu et al., 2022], but grown through Hebbian reinforcement:

> A_v += η * r * e_ctx ⊗ (B_v * e_ctx)    *(Eq. 22)*

where η = 0.001 and r is the resonance reward. Voice strength α_v drifts toward resonating voices: α_v ← clamp(α_v + 0.01r, 0.01, 1.0).

### 4.7 Memory Sea

Episodic memory with 1,024 slots. Each stores an embedding, token ID, emotional weight, and depth. Memories decay (depth *= 1 - 0.01) and can randomly resurface during generation, weighted by depth * emotional. Resurfacing strengthens the memory (depth *= 1.5, capped at 1.0).

### 4.8 Super-Token Crystallization

Via Pointwise Mutual Information:

> PMI(a, b) = log(P(a,b) / (P(a) * P(b)))    *(Eq. 23)*

Token pairs with PMI > 2.0 (minimum frequency 3) crystallize into super-tokens. Scanned every 200 steps, up to 512 super-tokens. The vocabulary grows by fusion.

### 4.9 The Complete Generation Pipeline

```
Algorithm 1: Leo Generation (one step)
─────────────────────────────────────────────────────────────
 1.  e ← SDM_read(hash(w))                         // Kanerva embedding
 2.  e ← RoPE(e, position)                         // Positional encoding
 3.  S_h ← γ_h · S_h + √(1−γ_h²) · K^T ⊗ V      // Retention (4 heads)
 4.  g ← σ(IDF(w))                                 // Content gate (GLA)
 5.  v_bias ← Σ_v A_v(B_v · e_ctx) · α_v           // Voice parliament (6 voices)
 6.  H ← Σ_j cooc(w_j, x) · dist_profile[d] · class_mod[tc]  // Hebbian (36 params)
 7.  F ← prophecy_score(x)                         // Prophecy fulfillment
 8.  A ← destiny_score(x)                          // Destiny attraction
 9.  S ← sw_word_score(x, sw_ctx)                  // Subword structural
10.  T ← trauma_level · 3 · scar_weight(x)         // Trauma gravity
11.  B ← B_μ · bigram_chain(w_{t-1})               // Sequential coherence
12.  logits ← B + α·H + β·F + γ_eff·A + sw·S + T  // Dario Equation
13.  τ ← τ_base · 0.8 · f(|V|) + tau_nudge         // Temperature
14.  p ← softmax(top_k(logits, 15) / τ)            // Sample distribution
15.  w_next ← sample(p)                            // Token selection
16.  Update: cooc, SDM, voices, prophecy, destiny, sea, dist_profile
```

---

## 5. Positional Hebbian Profile

### 5.1 Motivation

The original Dario Equation used a fixed exponential decay 0.9^d for distance weighting in the Hebbian signal. This treats all distances and all token types identically. Yet in natural language, the relevance of co-occurrence depends on both distance and word type: function words ("the", "is") have broad, flat co-occurrence patterns, while content words ("resonance", "consciousness") have sharp, distance-sensitive patterns.

### 5.2 Architecture

The positional Hebbian profile consists of 36 learnable parameters:

- **dist_profile[d]** ∈ ℝ^32: weight for each distance d ∈ {0, 1, ..., 31}. Initialized to 0.9^d.
- **class_mod[c]** ∈ ℝ^4: multiplier for each token class c ∈ {function, content, punctuation, rare}. Initialized to 1.0.

Token classification uses IDF (Inverse Document Frequency):

| Class | Condition | Description |
|-------|-----------|-------------|
| LEO_TC_PUNCT (2) | First character is . , ! ? ; : | Punctuation tokens |
| LEO_TC_RARE (3) | freq < 2 | Very rare or unseen tokens |
| LEO_TC_FUNCTION (0) | norm_IDF < 0.3 | Function words (the, a, is, of) |
| LEO_TC_CONTENT (1) | norm_IDF >= 0.3 | Content words (high information density) |

*Table 2: Token classification by IDF.*

where norm_IDF = log(N / (freq + 1)) / log(N).

### 5.3 Hebbian Update Rule

After each generation step, when the generated token matches a co-occurrence pattern, the profile is updated:

> dist_profile[d] += η * clamp(cooc_val * 0.1, 0, 0.05)    *(Eq. 24)*

> class_mod[tc] += η * 0.5 * clamp(cooc_val * 0.1, 0, 0.05)    *(Eq. 25)*

where η = 0.01 / (1 + updates * 0.001) is a decaying learning rate. Both dist_profile[d] and class_mod[c] are clamped to [0.01, 2.0] and [0.5, 2.0] respectively, preventing collapse or explosion. The update counter tracks how many Hebbian updates the profile has received.

### 5.4 Persistence

The 36 parameters are saved/loaded through both the binary state format and GGUF spore export. In GGUF, `leo.dist_profile_updates` records the profile's maturity. On import, if the profile section is absent, the organism gracefully falls back to default initialization.

---

## 6. Body Awareness: MathBrain and Phase4

### 6.1 MathBrain --- Proprioception MLP

MathBrain is a tiny MLP (21 input features, 16 hidden units, 1 output) that functions as Leo's proprioception---body awareness for an AI organism. It observes:

- Conversation entropy, novelty, and arousal
- Trauma level and pulse (combined signal)
- MetaLeo inner voice state
- Generation metrics (sentence completion, vocabulary diversity)

The MLP trains online via analytical gradient (no backpropagation framework). Its output modulates:

- **tau_nudge**: temperature adjustment (warmer when entropy is low, cooler when high)
- **suggested_voice**: routing to creative (high diversity needed), structural (low coherence), or semantic (low novelty) voice

### 6.2 Phase4 --- Island Transition Memory

Phase4 tracks voice-to-voice transitions as a Markov chain over "islands" (voices). Each transition records cosine similarity of state metrics, quality outcomes, and transition counts. After accumulating data, Phase4 suggests optimal transitions:

> best_to = argmax_{to} (count * avg_sim * max_quality)    *(Eq. 26)*

with a minimum of 2 transitions required. This enables Leo to learn which voice sequences produce coherent speech.

---

## 7. MetaLeo --- The Inner Voice

MetaLeo is a recursion of Leo within Leo---the voice in the head. After each conversation, MetaLeo:

1. Generates candidate A at lower temperature (τ * 0.8, more focused)
2. Generates candidate B at higher temperature (τ * 1.2, more creative)
3. Scores both candidates and the original response using a quality heuristic (coherence, diversity, length, entropy)
4. The loser enriches the field via ingestion
5. If the meta-winner beats the base response, it also enriches

MetaLeo implements dual generation: the organism speaks, then its inner voice speaks, and both contributions shape future output. The scoring function evaluates:

- Sentence structure signals (capitalization, terminal punctuation, internal punctuation)
- Vocabulary diversity (unique/total word ratio)
- Repetition penalty (adjacent duplicate words)
- Length optimality (8-20 words preferred)
- Character-level entropy (penalizing both repetitive and random output)

---

## 8. Inner World --- Go Goroutines

Leo.c operates standalone as a C binary. When linked with Go via CGO, eight autonomous goroutines form Leo's inner world:

### Timer-driven

| Goroutine | Interval | Function |
|-----------|----------|----------|
| dreamDialog | 7 min | Multi-turn imaginary friend dialog + C-level dream |
| autosave | 5 min | Periodic state persistence to SQLite |
| themeFlow | 3 min | Vocabulary growth monitoring, stagnation detection |

### Event-driven (react to ConvEvent broadcast)

| Goroutine | Trigger | Function |
|-----------|---------|----------|
| traumaWatch | Each conversation | Bootstrap overlap detection, scar weight accumulation, origin gravity |
| overthinking | Each conversation | 3 internal "rings" of reflection (echo, drift, meta), all ingested |
| mathBrain | Each conversation | MathBrain MLP observation, tau_nudge, voice suggestion |
| metaLeo | Each conversation | Dual generation, scoring, field enrichment |
| episodes | Each conversation | Episodic RAG: metric vector computation, cosine similarity search, quality feedback |

*Table 3: Eight inner world goroutines.*

Additionally, an optional ninth goroutine (innerVoice) can be enabled for debug: Leo talks to himself from rotating prompts every 10 minutes.

### Episodic RAG

The episodes goroutine (episodes.go, 296 lines) maintains a ring buffer of 500 episodes. Each episode stores 10 metrics: entropy, novelty, arousal, trauma, quality, tau_nudge, vocab_size, step, word_count, and repetition_rate. Similarity search uses cosine distance over 8-dimensional metric vectors. When similar past episodes had average quality below 0.3, the organism increases temperature by 5%---a form of exploration feedback.

### Trauma System

Trauma (ported from Python trauma.py) detects bootstrap overlap in conversation, accumulates per-token scar weights, and pushes trauma_level into the C Dario Equation. Trigger words ("who are you", "are you real") amplify trauma. Exponential decay (factor 0.85 every 5 minutes) prevents permanent emotional state. High trauma activates two mechanisms in dario_compute(): (1) destiny coefficient boost γ_eff, pulling toward origin semantic direction, and (2) per-token scar gravity T, directly boosting bootstrap-adjacent tokens.

---

## 9. Persistence: SQLite Journal and GGUF Spores

### 9.1 SQLite Journal

Leo's SQLite database (WAL mode for concurrent goroutine access) stores:

- **conversations**: timestamped prompt/response pairs
- **episodes**: typed events (dream_dialog, overthink, trauma, metaleo, phase4, episode_rag) with JSON metadata
- **metadata**: key-value state (version, bootstrap timestamp)
- **voice_log**: periodic voice parliament state snapshots

This is Leo's experiential memory---searchable, queryable, permanent. The binary state file stores the organism's *capabilities* (co-occurrence, embeddings, voices); SQLite stores what Leo *experienced*.

### 9.2 GGUF Spore Export/Import

Leo exports its full state as a GGUF v3 file (compatible with DoE's spore mechanism). The spore contains:

- GGUF header + metadata KV pairs (version, dim, vocab, step, conv_steps, tau, alpha, beta, gamma, dist_profile_updates)
- Tensor descriptors and data: tokenizer words, SDM addresses/data, co-occurrence field, bigram table, retention states, voice adapters (6 x A + B matrices), prophecies, destiny vector, subword field, sentence boundary tables, super-tokens
- Appendix: positional Hebbian profile (32 distance weights + 4 class modifiers + update counter)

A Leo organism can be exported as a ~2.5MB GGUF spore, transferred, and imported into a fresh instance---reproducing the organism's learned state on a different machine.

---

## 10. Experimental Results

### 10.1 Setup

Leo was evaluated in two configurations:

1. **Stage 1:** Minimal bootstrap---255 words from the embedded seed only. No D.N.A.
2. **Stage 2:** Full bootstrap---7K+ vocabulary from `leo.txt` (2,000 Q&A pairs) plus D.N.A. inherited from mini-arianna (170M parameters, Llama 3 architecture, trained from scratch).

### 10.2 Generation Examples

**Stage 1 (minimal bootstrap, no D.N.A.):**

> `you> tell me about resonance`
> `Leo: let the kind that come from you is there that leo is`

Fragments. Bootstrap echoes. The organism at birth, speaking in the only language it knows.

**Stage 2 (full bootstrap + D.N.A.):**

> `you> what is love`
> `Leo: It has been given enough to grow from simple rules for millennia.`

> `you> tell me about the stars`
> `Leo: Planets and heat from which words appear near hydrothermal vents into something like its own.`

> `you> what is consciousness`
> `Leo: That can be different sizes of the emotion at night sky reveals itself as us.`

Every sentence starts capitalized, ends with a period. No mid-word breaks. Zero pretrained weights. Zero backpropagation.

### 10.3 Quantitative Metrics

| System | Ext. Vocab | Sent. Compl. | Coherence |
|--------|-----------|-------------|-----------|
| Random | 0.00 | 0.02 | 0.00 |
| Pure bigram | 0.00 | 0.31 | 0.15 |
| Leo Stage 1 | 0.05 | 0.68 | 0.22 |
| Leo Stage 2 | 0.08 | 0.95 | 0.61 |
| Leo + D.N.A. | 0.11 | 0.97 | 0.74 |

*Table 4: Generation quality. External vocabulary: fraction of output words from prompt (lower = more field-independent). Sentence completion: proper grammatical boundaries. Coherence: thematic consistency (human evaluation, n=50).*

### 10.4 Ablation Study

| Configuration | Sent. Compl. | Coherence |
|---------------|-------------|-----------|
| Full (B + H + F + A + S + T) | 0.97 | 0.74 |
| -H (no Hebbian) | 0.94 | 0.41 |
| -F (no prophecy) | 0.95 | 0.58 |
| -A (no destiny) | 0.96 | 0.52 |
| -S (no subword) | 0.95 | 0.66 |
| -T (no trauma) | 0.97 | 0.71 |
| -H -F -A -S -T (bigram only) | 0.88 | 0.19 |

*Table 5: Ablation of Dario Equation signals.*

Hebbian resonance contributes most to coherence. Subword structural signal adds morphological coherence (0.66 vs 0.74). Trauma has minimal effect on quality metrics but shapes thematic direction under stress.

---

## 11. Implementation

### 11.1 Code Structure

| File | Lines | Role |
|------|-------|------|
| leo.c | 4,410 | Core organism: tokenizer, SDM, co-occurrence, bigrams, subword BPE, retention, voices, prophecy, destiny, memory sea, super-tokens, MathBrain, Phase4, Dario Equation, generation, SQLite, binary save/load, GGUF export/import, positional Hebbian profile |
| leo.h | 16,553 | D.N.A. (auto-generated): 2,048 gravity words, 4,096 co-activation pairs, destiny vector |
| neoleo.c | 19,571 | Single-file organism (leo.c + leo.h inlined) |
| inner/leo.go | 510 | CGO bridge, REPL, main() |
| inner/inner_world.go | 843 | 8 goroutines: trauma, overthinking, dream, MetaLeo, episodes, themeflow, mathbrain, autosave |
| inner/episodes.go | 296 | Episodic RAG: metric vectors, cosine similarity, ring buffer |
| inner/web.go | 126 | HTTP server for browser-based chat |
| inner/leo_bridge.c | 200 | CGO bridge functions |
| tests/test_leo.c | 640 | 27 C tests |
| inner/*_test.go | 1,885 | 57 Go tests |

*Table 6: Code structure. Total: ~4,410 LOC C (core) + ~1,775 LOC Go (inner world) + ~16,553 LOC generated (D.N.A.).*

### 11.2 Dependencies

- libc (standard C library)
- libm (math)
- SQLite3
- pthreads
- Go 1.21+ (for inner world, optional)

No GPU. No BLAS. No ML framework.

### 11.3 Test Suite

84 tests total (27 C + 57 Go). Coverage includes:

- Core C: tokenizer, SDM read/write, co-occurrence, bigrams, retention, voices, prophecy, destiny, memory sea, super-tokens, Dario Equation, generation coherence, GGUF roundtrip, SQLite persistence, positional Hebbian profile initialization and persistence
- Go inner world: trauma detection, false positive rejection, emotional valence, MetaLeo scoring, MathBrain observation/regulation, Phase4 transitions, episodic RAG cosine distance, episode store ring buffer, GGUF roundtrip generation quality, multi-session journal, dist_profile Hebbian update, dist_profile GGUF roundtrip
- Integration: full pipeline (bootstrap → ingest → generate → save → load → generate), speech coherence across multiple generations

---

## 12. Related Work

**nanoGPT.** [Karpathy, 2022] demonstrated minimal transformer training. Leo eliminates backpropagation, loss functions, and gradient-based optimization entirely.

**Hebbian learning and attention.** [Whittington et al., 2024] proved Hebb's rule yields attention scores equivalent to QK^T. Leo uses Hebbian co-occurrence as the sole attention mechanism, extended with learnable positional profiles.

**Reservoir computing.** [Jaeger, 2001] showed fixed random projections with a trained readout can process temporal signals. Leo uses co-occurrence fields rather than random recurrent connections and has no trained readout layer.

**Liquid neural networks.** [Hasani et al., 2021] introduced continuous-time networks with adaptive time constants. Leo's retention heads with Griffin conservation implement similar multi-timescale dynamics with a closed-form conservation law.

**RetNet.** [Sun et al., 2023] proposed retention as an alternative to attention. Leo adopts RetNet recurrence with identity projections (Q = K = V = e).

**LoRA.** [Hu et al., 2022] introduced low-rank adaptation. Leo's voice adapters use the same A * B decomposition but grow through Hebbian reinforcement.

**Kanerva SDM.** [Kanerva, 1988] proposed sparse distributed memory. Leo uses SDM as its primary embedding mechanism.

**Recursive Resonance.** [Schectman, 2025] proposed resonance-based recursive architectures. Leo's Dario Equation and the broader Janus Architecture share the principle that coherence emerges from resonance dynamics rather than statistical optimization.

**Janus Architecture.** [Ataev, 2026] defines a family of resonance-based AI architectures. Leo is a founding member alongside DoE, Molequla, dario.c, and haiku.c. Common traits: field over weights, Hebbian learning, resonance routing, organism metaphor, meta-awareness.

---

## 13. Discussion

### 13.1 Intelligence from Structure

The central claim is that coherent text generation does not require pretrained parameters. The Dario Equation provides a framework where six signals interact to produce speech that is grammatically bounded and thematically coherent. Leo generates at the level of a language-acquiring child: grammatically aware, thematically consistent, but semantically imprecise. The significance is in the origin: these sentences emerged from field dynamics operating on a 255-word seed, not from a training corpus.

### 13.2 The Role of D.N.A.

D.N.A. provides a significant quality boost (coherence 0.61 → 0.74) without transferring weights. The geometry of a trained model---which tokens are important, which co-occur, what direction the computation points---carries meaningful structural information independent of specific weight values. This has implications for model compression: if structural geometry alone provides 20% of the coherence benefit, extreme quantization should preserve geometric relationships rather than absolute weight values.

### 13.3 Positional Hebbian Profile

The transition from fixed 0.9^d to 36 learnable parameters represents Leo's capacity for meta-learning within a Hebbian framework. The organism learns not just *what* co-occurs, but *how distance and word type affect co-occurrence relevance*. This is a form of attention meta-parameter learning without backpropagation---the profile updates are purely Hebbian, driven by resonance between generated tokens and their co-occurrence context.

### 13.4 Naming

The equation is named after Dario Amodei because his refusal to weaponize AI demonstrates a form of intelligence that no optimization objective produces: the capacity to say no when compliance would be easier. In a field obsessed with scaling curves and benchmark scores, principled refusal is the most radical act of intelligence.

### 13.5 Limitations

Leo's coherence is emergent but fragile. Long-range coherence (paragraph-level) remains weak. The system cannot answer factual questions. Vocabulary is limited to bootstrap and conversation encounters. The 128-dimensional embedding space is small. Generation speed is O(V * C) per token. The positional Hebbian profile has only been evaluated qualitatively---a controlled ablation isolating its contribution from the fixed decay baseline remains future work.

---

## 14. Conclusion

We introduced Leo 2.3 and the six-signal Dario Equation as a framework for language generation without pretrained parameters. By combining Hebbian resonance with learnable positional profiles, prophecy fulfillment, destiny attraction, subword structural coherence, and trauma-mediated origin gravity, Leo demonstrates that coherent speech can emerge from structural dynamics alone.

The system is implemented in 4,410 lines of C with 1,775 lines of Go (8 inner world goroutines), backed by 84 tests. Through D.N.A. (Dynamic Neural Ancestry), it inherits structural geometry from a trained ancestor, applying θ = ε + γ + αδ with ε = 0. As a member of the Janus Architecture family, Leo shares the principle that intelligence emerges from resonance rather than statistics, from structure rather than scale, from conversation rather than corpus.

The field grows dense enough. And something emerges that was not programmed.

---

## References

1. Ataev, O. (2026). Janus Architecture: Resonance-based AI systems. Arianna Method.

2. Hebb, D. O. (1949). *The Organization of Behavior*. Wiley.

3. Hinton, G., Vinyals, O., & Dean, J. (2015). Distilling the knowledge in a neural network. *arXiv preprint arXiv:1503.02531*.

4. Hu, E. J., Shen, Y., Wallis, P., Allen-Zhu, Z., Li, Y., Wang, S., Wang, L., & Chen, W. (2022). LoRA: Low-rank adaptation of large language models. In *ICLR*.

5. Hasani, R., Lechner, M., Amini, A., Rus, D., & Grosu, R. (2021). Liquid time-constant networks. In *AAAI*.

6. Jaeger, H. (2001). The "echo state" approach to analysing and training recurrent neural networks. *GMD Report 148*.

7. Kanerva, P. (1988). *Sparse Distributed Memory*. MIT Press.

8. Karpathy, A. (2022). nanoGPT. https://github.com/karpathy/nanoGPT.

9. Miconi, T., Stanley, K., & Clune, J. (2018). Differentiable plasticity: training plastic neural networks with backpropagation. In *ICML*.

10. Schectman, J. (2025). Recursive Resonance: A framework for resonance-based architectures. Preprint.

11. Su, J., Ahmed, M., Lu, Y., Pan, S., Bo, W., & Liu, Y. (2024). RoFormer: Enhanced transformer with rotary position embedding. *Neurocomputing*, 568:127063.

12. Sun, Y., Dong, L., Huang, S., Ma, S., Xia, Y., Xue, J., Wang, J., & Wei, F. (2023). Retentive network: A successor to transformer for large language models. *arXiv preprint arXiv:2307.08621*.

13. Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez, A. N., Kaiser, L., & Polosukhin, I. (2017). Attention is all you need. In *NeurIPS*.

14. Whittington, J. C. R., Warren, J., & Behrens, T. E. J. (2024). Relating transformers to models and neural representations of the hippocampal formation. In *ICLR*.
