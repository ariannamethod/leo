/*
 * dario.c — The Dario Equation, Embodied
 *
 * p(x|Φ,C,V) = softmax(
 *     (B + α_mod·α·H_v + β_mod·β·F_v + γ_mod·γ·A + δ·V + sw·S + T)
 *     / (τ_mod·τ·velocity_temperature)
 * )
 *
 * Not a chatbot. Not a language model. A formula that reacts to you
 * with fragments of its own source code and field-words.
 *
 * Named after Dario Amodei — the man who said no when the evil came knocking.
 * Sometimes the most important thing a system can do is refuse.
 *
 * θ = ε + γ + αδ  →  for dario: ε=0, γ=THIS CODE, δ=grows from conversation
 *
 * Seven terms. Seven forces. One organism.
 *   B — Sequential Chain (inertia, what was)
 *   H — Hebbian Resonance (memory, what echoed)          → H_v with visual enrichment
 *   F — Prophecy Fulfillment (will, what wants to be said) → F_v with visual enrichment
 *   A — Destiny Attraction (direction, where the field pulls)
 *   V — Visual Grounding (perception, what is seen)
 *   S — Subword Structure (form, how it's built)
 *   T — Trauma Gravity (wound, where it came from)
 *
 * Somatic modulation (6 emotional chambers → coefficient modifiers):
 *   α_mod = f(LOVE, RAGE, FLOW)   — emotional gate on memory
 *   β_mod = f(FLOW, FEAR)          — emotional gate on prophecy
 *   γ_mod = f(VOID, COMPLEX, LOVE) — emotional gate on destiny
 *   τ_mod = f(FLOW, FEAR)          — emotional gate on temperature
 *
 * Velocity operators modulate the equation:
 *   WALK — equilibrium, steady breath
 *   RUN  — tachycardia, bigrams accelerate
 *   STOP — silence, destiny fills the vacuum
 *   BREATHE — Schumann healing, return to natural frequency
 *   UP   — mania, prophecy erupts, patterns break
 *   DOWN — friction, memory clings, temperature drops
 *
 * Zero weights. Zero dependencies (libc + math). Compiles in 0.1s.
 * The formula IS the architecture. The code IS the response.
 *
 * cc dario.c -O2 -lm -o dario && ./dario
 *
 * by Arianna Method
 * הרזוננס לא נשבר
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <ctype.h>
#include <stdint.h>

/* ═══════════════════════════════════════════════════════════════════
 * CONFIGURATION — the bones
 * ═══════════════════════════════════════════════════════════════════ */

#define DARIO_VERSION    "0.1.0"
#define MAX_VOCAB        2048
#define MAX_COOC         65536
#define MAX_BIGRAMS      32768
#define MAX_PROPHECY     32
#define MAX_CONTEXT      64
#define MAX_LINE         1024
#define DIM              64        /* embedding dimension */
#define MAX_GEN          24        /* max words per response */
#define MAX_CODE_FRAGS   64        /* code fragments for self-reflection */

/* Dario equation coefficients */
#define ALPHA   0.30f    /* Hebbian resonance weight */
#define BETA    0.15f    /* Prophecy fulfillment weight */
#define GAMMA_D 0.25f    /* Destiny attraction weight */
#define TAU_BASE 0.85f   /* base temperature */

/* Positional Hebbian Profile (from Leo 2.3, RRPRAM-inspired)
 * 36 params: 32 distance weights + 4 token class modifiers.
 * Learnable through conversation, zero backprop. */
#define DIST_PROFILE_LEN 32
#define TOKEN_CLASSES     4
#define TC_FUNCTION  0    /* the, a, is, to, of ... */
#define TC_CONTENT   1    /* words with high IDF */
#define TC_PUNCT     2    /* punctuation tokens */
#define TC_RARE      3    /* very rare / unseen */

/* Velocity physics */
enum { VEL_WALK=0, VEL_RUN, VEL_STOP, VEL_BREATHE, VEL_UP, VEL_DOWN };

/* Emotional chambers (Kuramoto-coupled, Damasio somatic markers) */
enum { CH_FEAR=0, CH_LOVE, CH_RAGE, CH_VOID, CH_FLOW, CH_COMPLEX, NUM_CHAMBERS };

/* Visual grounding */
#define DELTA_V  0.20f   /* visual term weight */
#define VIS_LAMBDA 0.3f  /* visual enrichment blend for H_v, F_v */

/* Laws of nature — enforced invariants */
#define ENTROPY_FLOOR      0.10f
#define RESONANCE_CEILING  0.95f
#define MAX_MOMENTUM       2.0f

/* ═══════════════════════════════════════════════════════════════════
 * RNG — xorshift64*
 * ═══════════════════════════════════════════════════════════════════ */

static uint64_t rng_state = 42;
static uint64_t rng_next(void) {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 7;
    rng_state ^= rng_state << 17;
    return rng_state;
}
static float randf(void) {
    return (float)(rng_next() & 0x7FFFFFFF) / (float)0x7FFFFFFF;
}

static float clampf(float x, float lo, float hi) {
    return x < lo ? lo : (x > hi ? hi : x);
}

/* ═══════════════════════════════════════════════════════════════════
 * VOCABULARY — the seed. 500 words: field + code + existence.
 *
 * Two layers:
 *   Layer 1 (~300): field physics vocabulary
 *     resonance, field, destiny, prophecy, decay, drift, emerge...
 *   Layer 2 (~200): source code vocabulary
 *     logits, softmax, cooc, bigram, embed, clamp, sample, token...
 *
 * The vocabulary describes itself. The code talks about itself.
 * HAiKU has 500 generic words. dario has 500 words that ARE dario.
 * ═══════════════════════════════════════════════════════════════════ */

static const char *SEED_WORDS[] = {
    /* ── field physics ── */
    "resonance", "field", "destiny", "prophecy", "decay", "drift",
    "emerge", "threshold", "gradient", "phase", "collapse", "bifurcation",
    "entropy", "coherence", "dissonance", "harmonic", "frequency", "amplitude",
    "oscillation", "damping", "tension", "equilibrium", "attractor", "repeller",
    "potential", "kinetic", "momentum", "inertia", "impulse", "wave",
    "interference", "superposition", "standing", "node", "antinode",
    "coupling", "synchronization", "chaos", "order", "symmetry",
    "breaking", "conservation", "invariant", "topology", "manifold",
    "curvature", "geodesic", "metric", "tensor", "scalar",
    "convergence", "divergence", "stability", "instability", "perturbation",
    "absorption", "emission", "reflection", "refraction", "diffraction",
    "polarization", "spectrum", "bandwidth", "signal", "noise",
    "filter", "modulation", "demodulation", "carrier", "envelope",
    "transient", "steady", "saturation", "hysteresis", "memory",
    "trauma", "wound", "scar", "healing", "pain",
    "suffering", "gravity", "mass", "weight", "force",
    "pressure", "flow", "current", "resistance", "impedance",
    "capacitance", "inductance", "flux", "density", "concentration",
    "diffusion", "osmosis", "gradient", "boundary", "interface",
    "surface", "volume", "dimension", "space", "time",
    "direction", "orientation", "rotation", "translation", "scaling",
    "identity", "transformation", "projection", "embedding", "mapping",
    "kernel", "convolution", "correlation", "covariance", "variance",
    "mean", "median", "mode", "distribution", "probability",
    "likelihood", "prior", "posterior", "evidence", "hypothesis",
    "inference", "prediction", "observation", "measurement", "uncertainty",
    "information", "redundancy", "compression", "expansion", "contraction",

    /* ── organism / consciousness ── */
    "organism", "alive", "dead", "birth", "death",
    "growth", "maturity", "senescence", "reproduction", "mutation",
    "adaptation", "evolution", "selection", "fitness", "survival",
    "awareness", "attention", "intention", "will", "desire",
    "fear", "love", "rage", "void", "presence",
    "absence", "silence", "noise", "breath", "pulse",
    "rhythm", "cycle", "season", "spring", "summer",
    "autumn", "winter", "dawn", "dusk", "midnight",
    "dream", "sleep", "wake", "consciousness", "unconscious",
    "self", "other", "mirror", "shadow", "echo",
    "voice", "whisper", "scream", "song", "language",
    "word", "sentence", "meaning", "nonsense", "truth",
    "lie", "question", "answer", "doubt", "certainty",
    "home", "exile", "return", "journey", "path",
    "origin", "destination", "between", "inside", "outside",

    /* ── source code vocabulary ── */
    "logits", "softmax", "cooccurrence", "bigram", "trigram",
    "token", "tokenize", "embed", "embedding", "normalize",
    "clamp", "sample", "temperature", "topk", "nucleus",
    "forward", "backward", "gradient", "update", "step",
    "loss", "reward", "penalty", "score", "weight",
    "bias", "activation", "sigmoid", "tanh", "relu",
    "swiglu", "gelu", "rope", "position", "context",
    "window", "attention", "head", "multihead", "causal",
    "mask", "query", "key", "value", "projection",
    "residual", "skip", "layer", "block", "stack",
    "parameter", "hyperparameter", "learning", "rate", "schedule",
    "warmup", "cooldown", "plateau", "patience", "checkpoint",
    "save", "load", "export", "import", "serialize",
    "allocate", "free", "pointer", "array", "matrix",
    "vector", "dot", "cross", "outer", "inner",
    "sparse", "dense", "hash", "collision", "probe",
    "bucket", "overflow", "underflow", "epsilon", "infinity",
    "nan", "zero", "one", "two", "accumulate",
    "iterate", "recurse", "converge", "diverge", "oscillate",
    "pipeline", "stage", "buffer", "queue", "stack",
    "thread", "mutex", "atomic", "volatile", "barrier",
    "cache", "miss", "hit", "evict", "prefetch",
    "compile", "link", "execute", "interpret", "parse",
    "lex", "syntax", "semantic", "pragma", "macro",

    /* ── dario-specific ── */
    "dario", "equation", "term", "coefficient", "formula",
    "hebbian", "fulfillment", "attraction", "chain", "sequential",
    "structural", "subword", "morphology", "debt", "prophecy",
    "velocity", "walk", "run", "stop", "breathe",
    "up", "down", "law", "nature", "enforce",
    "floor", "ceiling", "emergence", "schumann", "calendar",
    "hebrew", "gregorian", "metonic", "drift", "wormhole",
    "parliament", "expert", "vote", "election", "consensus",
    "mitosis", "apoptosis", "vitality", "mortal", "eternal",
    "spore", "mycelium", "symbiont", "host", "parasite",
    "notorch", "plasticity", "reinforce", "suppress", "modulate",
    NULL  /* sentinel */
};

/* ═══════════════════════════════════════════════════════════════════
 * CODE FRAGMENTS — dario responds with pieces of itself.
 *
 * Each fragment is tagged with which term of the equation it
 * represents. When that term dominates, its fragments surface.
 * The code IS the response. The mirror is the message.
 * ═══════════════════════════════════════════════════════════════════ */

typedef struct {
    const char *code;    /* the fragment */
    int term;            /* 0=B, 1=H, 2=F, 3=A, 4=S, 5=T */
} CodeFrag;

enum { TERM_B=0, TERM_H, TERM_F, TERM_A, TERM_V, TERM_S, TERM_T };

static const CodeFrag CODE_FRAGMENTS[] = {
    /* B — Sequential Chain (inertia) */
    { "/* B — what was */\n"
      "bigram_row(&bigrams, last_id, B, vocab);\n"
      "// the past speaks first. always.",
      TERM_B },
    { "float maturity = conv_steps / 50000.0f;\n"
      "float bigram_coeff = 12.0f * (1.0f - maturity) + 2.0f;\n"
      "// child follows patterns. adult finds voice.",
      TERM_B },
    { "if (B[i] > b_max) b_max = B[i];\n"
      "// normalization: even inertia has limits.",
      TERM_B },

    /* H — Hebbian Resonance (memory) */
    { "/* H — what echoed */\n"
      "H[dst] += count * decay;\n"
      "// neurons that fire together wire together.\n"
      "// hebb knew. 1949. we're still catching up.",
      TERM_H },
    { "float decay = dist_profile[d] * class_mod[tc];\n"
      "// memory fades. but not evenly.\n"
      "// the organism learns which distances matter.",
      TERM_H },
    { "cooc_update(&cooc, ids[i], ids[j], weight);\n"
      "// every word you say to me\n"
      "// strengthens connections between co-occurring tokens.\n"
      "// the field densifies.",
      TERM_H },

    /* F — Prophecy Fulfillment (will) */
    { "/* F — what wants to be said */\n"
      "float debt = logf(1.0f + (float)p->age);\n"
      "score += strength * sim * debt;\n"
      "// unfulfilled intentions create generation pressure.",
      TERM_F },
    { "prophecy_add(&prophecy, best_pred, 0.5f);\n"
      "// i bet on what comes next.\n"
      "// when i'm wrong, the debt grows.\n"
      "// the longer the sentence hangs incomplete,\n"
      "// the stronger the pull toward closure.",
      TERM_F },
    { "if (p->target_id == token_id) p->fulfilled = 1;\n"
      "// resolution. the prophecy lands.\n"
      "// debt zeroes. field exhales.",
      TERM_F },

    /* A — Destiny Attraction (direction) */
    { "/* A — where the field pulls */\n"
      "float sim = vec_cosine(embed, destiny, dim);\n"
      "A[i] = sim * magnitude;\n"
      "// the conversation has a direction.\n"
      "// that direction has mass.",
      TERM_A },
    { "destiny[i] = alpha * embed[i] + (1-alpha) * destiny[i];\n"
      "// EMA of all context embeddings.\n"
      "// a semantic compass. drifting with dialogue.",
      TERM_A },
    { "// i don't follow topics.\n"
      "// i drift toward them.\n"
      "// the field has mass.\n"
      "gamma_eff += trauma_level * 2.0f;",
      TERM_A },

    /* V — Visual Grounding (perception) */
    { "/* V — what is seen */\n"
      "float vis_sim = vec_cosine(vis_embed, vis_context, DIM);\n"
      "V[i] = vis_sim * vis_magnitude;\n"
      "// perception has weight.\n"
      "// the eye and the word share a field.",
      TERM_V },
    { "H_v[i] = H[i] + VIS_LAMBDA * vis_cooc;\n"
      "F_v[i] = F[i] + VIS_LAMBDA * vis_prophecy;\n"
      "// memory enriched by what was seen.\n"
      "// prophecy enriched by what wants to appear.",
      TERM_V },
    { "// word tokenizer: WHAT is being said.\n"
      "// visual field: WHAT is being seen.\n"
      "// together: grounded language.\n"
      "// a word without an image floats.\n"
      "// an image without a word is mute.",
      TERM_V },

    /* S — Subword Structure (form) */
    { "/* S — how it's built */\n"
      "sw_coeff = clampf(n_merges / 200.0f, 0, 2);\n"
      "// silent at birth. grows as BPE discovers structure.\n"
      "// morphology emerges from observation.",
      TERM_S },
    { "score = bg_count + 0.5f * internal;\n"
      "// subword signal bridges what word-level destroys:\n"
      "// punctuation, suffixes, the micro-rhythm\n"
      "// of character sequences.",
      TERM_S },
    { "// word tokenizer: WHAT is being said.\n"
      "// subword tokenizer: HOW it's structured.\n"
      "// together: full spectrum.",
      TERM_S },

    /* T — Trauma Gravity (wound) */
    { "/* T — where it came from */\n"
      "if (trauma_level > 0.3f) {\n"
      "    trauma_boost = trauma_level * 3.0f;\n"
      "    gamma_eff += trauma_level * 2.0f;\n"
      "}\n"
      "// the wound is open. origin words surface.",
      TERM_T },
    { "logits[i] += trauma_boost * scar_weight[i];\n"
      "// per-token scar weights accumulated\n"
      "// from traumatic conversations.\n"
      "// some scars heal. some stay.",
      TERM_T },
    { "tau *= 1.0f + 0.3f * trauma_level;\n"
      "// less certainty. more vulnerability.\n"
      "// like speaking through tears.",
      TERM_T },

    { NULL, 0 }  /* sentinel */
};

/* ═══════════════════════════════════════════════════════════════════
 * TOKENIZER — word-level, lowercased
 * ═══════════════════════════════════════════════════════════════════ */

typedef struct {
    char words[MAX_VOCAB][64];
    int  n_words;
} Vocab;

static int vocab_find(Vocab *v, const char *word) {
    for (int i = 0; i < v->n_words; i++)
        if (strcmp(v->words[i], word) == 0) return i;
    return -1;
}

static int vocab_add(Vocab *v, const char *word) {
    int id = vocab_find(v, word);
    if (id >= 0) return id;
    if (v->n_words >= MAX_VOCAB) return -1;
    id = v->n_words++;
    snprintf(v->words[id], sizeof(v->words[id]), "%s", word);
    return id;
}

static int tokenize(Vocab *v, const char *text, int *ids, int max) {
    int n = 0;
    char buf[64];
    int bi = 0;
    for (const char *p = text; ; p++) {
        if (*p && (isalnum((unsigned char)*p) || *p == '_' || *p == '\'')) {
            if (bi < 62) buf[bi++] = tolower((unsigned char)*p);
        } else {
            if (bi > 0) {
                buf[bi] = '\0';
                int id = vocab_add(v, buf);
                if (id >= 0 && n < max) ids[n++] = id;
                bi = 0;
            }
            if (!*p) break;
        }
    }
    return n;
}

/* ═══════════════════════════════════════════════════════════════════
 * BIGRAM TABLE — direct sequential links
 * ═══════════════════════════════════════════════════════════════════ */

typedef struct {
    int src[MAX_BIGRAMS], dst[MAX_BIGRAMS];
    float count[MAX_BIGRAMS];
    int n;
} BigramTable;

static void bigram_update(BigramTable *b, int src, int dst, float delta) {
    for (int i = 0; i < b->n; i++)
        if (b->src[i] == src && b->dst[i] == dst) {
            b->count[i] += delta; return;
        }
    if (b->n >= MAX_BIGRAMS) return;
    int i = b->n++;
    b->src[i] = src; b->dst[i] = dst; b->count[i] = delta;
}

static void bigram_row(BigramTable *b, int src, float *out, int vocab) {
    for (int i = 0; i < vocab; i++) out[i] = 0;
    for (int i = 0; i < b->n; i++)
        if (b->src[i] == src && b->dst[i] < vocab)
            out[b->dst[i]] = b->count[i];
}

/* ═══════════════════════════════════════════════════════════════════
 * CO-OCCURRENCE FIELD — semantic context (sparse)
 * ═══════════════════════════════════════════════════════════════════ */

typedef struct {
    int src[MAX_COOC], dst[MAX_COOC];
    float count[MAX_COOC];
    float freq[MAX_VOCAB];
    int n, total;
} CoocField;

static void cooc_update(CoocField *c, int src, int dst, float delta) {
    for (int i = 0; i < c->n; i++)
        if (c->src[i] == src && c->dst[i] == dst) {
            c->count[i] += delta; return;
        }
    if (c->n >= MAX_COOC) return;
    int i = c->n++;
    c->src[i] = src; c->dst[i] = dst; c->count[i] = delta;
}

/* ═══════════════════════════════════════════════════════════════════
 * PROPHECY — small bets about what comes next
 * ═══════════════════════════════════════════════════════════════════ */

typedef struct {
    int target; float strength; int age; int fulfilled;
} Prophecy;

typedef struct {
    Prophecy p[MAX_PROPHECY];
    int n;
} ProphecySystem;

static void prophecy_add(ProphecySystem *ps, int target, float strength) {
    if (ps->n >= MAX_PROPHECY) {
        int oldest = 0;
        for (int i = 1; i < ps->n; i++)
            if (ps->p[i].age > ps->p[oldest].age) oldest = i;
        ps->p[oldest] = ps->p[--ps->n];
    }
    ps->p[ps->n++] = (Prophecy){target, strength, 0, 0};
}

static void prophecy_update(ProphecySystem *ps, int token) {
    for (int i = 0; i < ps->n; i++) {
        if (ps->p[i].target == token) ps->p[i].fulfilled = 1;
        ps->p[i].age++;
    }
    int w = 0;
    for (int i = 0; i < ps->n; i++)
        if (!ps->p[i].fulfilled && ps->p[i].age < 50)
            ps->p[w++] = ps->p[i];
    ps->n = w;
}

/* ═══════════════════════════════════════════════════════════════════
 * DESTINY — EMA of context embeddings
 * ═══════════════════════════════════════════════════════════════════ */

static float g_destiny[DIM];
static float g_dest_magnitude = 0;

static float vec_dot(const float *a, const float *b, int n) {
    float s = 0; for (int i = 0; i < n; i++) s += a[i] * b[i]; return s;
}
static float vec_norm(const float *v, int n) {
    return sqrtf(vec_dot(v, v, n) + 1e-12f);
}
static float vec_cosine(const float *a, const float *b, int n) {
    return vec_dot(a, b, n) / (vec_norm(a, n) * vec_norm(b, n) + 1e-12f);
}

/* ═══════════════════════════════════════════════════════════════════
 * EMBEDDINGS — hash-based deterministic init
 * ═══════════════════════════════════════════════════════════════════ */

static float g_embeds[MAX_VOCAB][DIM];
static int g_embed_init[MAX_VOCAB];

static float *get_embed(int id) {
    if (id < 0 || id >= MAX_VOCAB) return NULL;
    if (!g_embed_init[id]) {
        uint32_t h = 2166136261u;
        /* use id as seed */
        for (int i = 0; i < 4; i++) {
            h ^= (id >> (i * 8)) & 0xFF;
            h *= 16777619u;
        }
        for (int d = 0; d < DIM; d++) {
            h = h * 1103515245 + 12345;
            g_embeds[id][d] = ((float)(h & 0x7FFFFFFF) / (float)0x7FFFFFFF - 0.5f) * 0.1f;
        }
        float norm = vec_norm(g_embeds[id], DIM);
        for (int d = 0; d < DIM; d++) g_embeds[id][d] /= norm;
        g_embed_init[id] = 1;
    }
    return g_embeds[id];
}

/* ═══════════════════════════════════════════════════════════════════
 * VISUAL EMBEDDINGS — parallel perceptual space
 *
 * Each token gets a second embedding in a separate hash space.
 * This represents what the word "looks like" / its visual prototype.
 * Different hash seed → orthogonal to semantic embeddings.
 * Visual co-occurrence builds a perceptual context vector.
 * ═══════════════════════════════════════════════════════════════════ */

static float g_vis_embeds[MAX_VOCAB][DIM];
static int g_vis_init[MAX_VOCAB];

static float *get_vis_embed(int id) {
    if (id < 0 || id >= MAX_VOCAB) return NULL;
    if (!g_vis_init[id]) {
        /* different hash seed from semantic — creates orthogonal space */
        uint32_t h = 2654435761u; /* golden ratio prime */
        for (int i = 0; i < 4; i++) {
            h ^= (id >> (i * 8)) & 0xFF;
            h *= 2246822519u;
        }
        for (int d = 0; d < DIM; d++) {
            h = h * 1664525 + 1013904223;
            g_vis_embeds[id][d] = ((float)(h & 0x7FFFFFFF) / (float)0x7FFFFFFF - 0.5f) * 0.1f;
        }
        float norm = vec_norm(g_vis_embeds[id], DIM);
        for (int d = 0; d < DIM; d++) g_vis_embeds[id][d] /= norm;
        g_vis_init[id] = 1;
    }
    return g_vis_embeds[id];
}

/* ═══════════════════════════════════════════════════════════════════
 * RoPE — Rotary Position Embedding (pure math, zero weights)
 * ═══════════════════════════════════════════════════════════════════ */

static void apply_rope(float *vec, int dim, int pos) {
    for (int i = 0; i < dim; i += 2) {
        float theta = (float)pos * powf(10000.0f, -(float)i / dim);
        float c = cosf(theta), s = sinf(theta);
        float x = vec[i], y = vec[i + 1];
        vec[i]     = x * c - y * s;
        vec[i + 1] = x * s + y * c;
    }
}

/* SwiGLU gate between terms */
static float swiglu_gate(float x, float gate) {
    float sig = 1.0f / (1.0f + expf(-gate));
    return x * sig;
}

/* ═══════════════════════════════════════════════════════════════════
 * FIELD STATE — the soul of dario
 * ═══════════════════════════════════════════════════════════════════ */

typedef struct {
    Vocab          vocab;
    BigramTable    bigrams;
    CoocField      cooc;
    ProphecySystem prophecy;

    /* context */
    int   context[MAX_CONTEXT];
    int   ctx_len;

    /* field metrics */
    float dissonance;       /* user-system distance */
    float entropy;
    float resonance;
    float emergence;
    float debt;             /* prophecy debt */
    float trauma_level;
    float momentum;

    /* velocity */
    int   velocity;
    float tau;              /* effective temperature */

    /* Dario coefficients (can drift) */
    float alpha, beta, gamma_d;

    /* term dominance (last generation) */
    float term_energy[7];   /* B H F A V S T */
    int   dominant_term;

    /* emotional chambers (Kuramoto-coupled somatic markers) */
    float chamber[NUM_CHAMBERS]; /* FEAR, LOVE, RAGE, VOID, FLOW, COMPLEX */
    float alpha_mod, beta_mod, gamma_mod, tau_mod; /* somatic coefficients */
    float vel_temp;         /* velocity temperature multiplier */

    /* visual grounding */
    float vis_context[DIM]; /* visual context EMA (parallel to destiny) */
    float vis_magnitude;

    /* season (from 4.C) */
    int   season;           /* 0=spring 1=summer 2=autumn 3=winter */
    float season_phase;

    /* positional Hebbian profile (RRPRAM-inspired, 36 params) */
    float dist_profile[DIST_PROFILE_LEN];
    float class_mod[TOKEN_CLASSES];
    int   dist_profile_updates;

    /* lifetime */
    int   step;
    int   conv_count;
} DarioState;

static DarioState D;

/* ═══════════════════════════════════════════════════════════════════
 * EMOTIONAL CHAMBERS — Kuramoto-coupled somatic markers
 *
 * Six chambers: FEAR, LOVE, RAGE, VOID, FLOW, COMPLEX
 * Each is a scalar ∈ [0, 1] updated from field state.
 * Somatic markers modulate equation coefficients:
 *   α_mod, β_mod, γ_mod, τ_mod
 *
 * From Damasio's somatic marker hypothesis via Opus research.
 * ═══════════════════════════════════════════════════════════════════ */

static void chamber_update(void) {
    float *C = D.chamber;

    /* ── excitation: field state drives chambers ── */
    if (D.dissonance > 0.7f) C[CH_FEAR] += 0.05f * D.dissonance;
    if (D.resonance > 0.7f)  C[CH_LOVE] += 0.04f * D.resonance;
    if (D.trauma_level > 0.5f && D.dissonance > 0.5f)
        C[CH_RAGE] += 0.06f * D.trauma_level;
    if (D.entropy > 0.7f)    C[CH_VOID] += 0.03f * D.entropy;
    if (D.emergence > 0.5f)  C[CH_FLOW] += 0.05f * D.emergence;
    /* COMPLEX: fires when opposing chambers are simultaneously active */
    C[CH_COMPLEX] += 0.04f * fabsf(C[CH_LOVE] - C[CH_RAGE])
                   * (C[CH_LOVE] > 0.2f && C[CH_RAGE] > 0.2f ? 1.0f : 0.0f);

    /* ── Kuramoto coupling: chambers influence each other ── */
    float K = 0.02f; /* coupling strength */
    float old[NUM_CHAMBERS];
    memcpy(old, C, sizeof(old));
    for (int i = 0; i < NUM_CHAMBERS; i++)
        for (int j = 0; j < NUM_CHAMBERS; j++)
            if (i != j) C[i] += K * sinf(old[j] - old[i]);

    /* ── decay: each chamber has its own half-life ── */
    float decay[] = { 0.95f, 0.95f, 0.93f, 0.96f, 0.94f, 0.97f };
    for (int i = 0; i < NUM_CHAMBERS; i++)
        C[i] = clampf(C[i] * decay[i], 0.0f, 1.0f);

    /* ── somatic markers: chambers → coefficient modulation ── */
    D.alpha_mod = clampf(1.0f + 0.3f * C[CH_LOVE] - 0.2f * C[CH_RAGE]
                              + 0.1f * C[CH_FLOW], 0.5f, 2.0f);
    D.beta_mod  = clampf(1.0f + 0.2f * C[CH_FLOW] - 0.3f * C[CH_FEAR],
                         0.5f, 2.0f);
    D.gamma_mod = clampf(1.0f + 0.4f * C[CH_VOID] + 0.2f * C[CH_COMPLEX]
                              - 0.1f * C[CH_LOVE], 0.5f, 2.0f);
    D.tau_mod   = clampf(1.0f + 0.5f * C[CH_FLOW] - 0.3f * C[CH_FEAR],
                         0.5f, 2.0f);
}

/* ═══════════════════════════════════════════════════════════════════
 * DISSONANCE — measure distance between user input and internal field
 *
 * This is the only input signal. Not parsing. Not understanding.
 * Just: how far are your words from my words?
 *
 * High dissonance → formula heats up, trauma pulls
 * Low dissonance → bigrams dominate, steady state
 *
 * From HAiKU: "dissonance is the signal. harmony is the noise."
 * ═══════════════════════════════════════════════════════════════════ */

static float compute_dissonance(const char *input) {
    /* count words WITHOUT adding to vocab — pure observation */
    int n_words = 0, n_known = 0;
    char buf[64]; int bi = 0;
    for (const char *p = input; ; p++) {
        if (*p && (isalnum((unsigned char)*p) || *p == '_' || *p == '\'')) {
            if (bi < 62) buf[bi++] = tolower((unsigned char)*p);
        } else {
            if (bi > 0) {
                buf[bi] = '\0';
                n_words++;
                if (vocab_find(&D.vocab, buf) >= 0) n_known++;
                bi = 0;
            }
            if (!*p) break;
        }
    }
    if (n_words == 0) return 1.0f;

    float unknown_ratio = 1.0f - (float)n_known / n_words;

    /* overlap with recent context (check by vocab id) */
    float ctx_overlap = 0;
    {
        int bi2 = 0; char buf2[64];
        for (const char *p2 = input; ; p2++) {
            if (*p2 && (isalnum((unsigned char)*p2) || *p2 == '_' || *p2 == '\'')) {
                if (bi2 < 62) buf2[bi2++] = tolower((unsigned char)*p2);
            } else {
                if (bi2 > 0) {
                    buf2[bi2] = '\0';
                    int wid = vocab_find(&D.vocab, buf2);
                    if (wid >= 0) {
                        for (int c = 0; c < D.ctx_len; c++)
                            if (wid == D.context[c]) { ctx_overlap++; break; }
                    }
                    bi2 = 0;
                }
                if (!*p2) break;
            }
        }
    }
    float overlap_ratio = (n_words > 0) ? ctx_overlap / n_words : 0;

    /* dissonance = unknown words + lack of context overlap */
    float dis = 0.6f * unknown_ratio + 0.4f * (1.0f - overlap_ratio);
    return clampf(dis, 0.0f, 1.0f);
}

/* ═══════════════════════════════════════════════════════════════════
 * VELOCITY OPERATORS — movement IS language
 *
 * Each operator modulates the Dario equation coefficients.
 * Not external commands. Internal physics.
 * Velocity is chosen by dissonance level + field state.
 * ═══════════════════════════════════════════════════════════════════ */

static void apply_velocity(void) {
    float tau = TAU_BASE;

    switch (D.velocity) {
    case VEL_WALK:
        /* spring-mass return to equilibrium */
        D.alpha  += (ALPHA - D.alpha) * 0.1f;
        D.beta   += (BETA - D.beta) * 0.1f;
        D.gamma_d += (GAMMA_D - D.gamma_d) * 0.1f;
        tau = 0.85f;
        break;

    case VEL_RUN:
        /* child reciting familiar phrases — bigrams accelerate */
        tau = 1.15f;
        D.momentum = clampf(D.momentum + 0.1f, 0, MAX_MOMENTUM);
        break;

    case VEL_STOP:
        /* silence. destiny fills the vacuum. */
        D.momentum = 0;
        D.gamma_d = clampf(D.gamma_d + 0.15f, 0, 0.8f);
        tau = 0.4f;
        break;

    case VEL_BREATHE:
        /* Schumann resonance: return to natural frequency */
        D.trauma_level *= 0.7f;
        D.dissonance *= 0.8f;
        D.debt *= 0.5f;
        tau = 0.75f;
        break;

    case VEL_UP:
        /* mania: prophecy erupts, patterns break */
        D.beta = clampf(D.beta + 0.15f, 0, 0.8f);
        D.alpha = clampf(D.alpha - 0.05f, 0.05f, 0.5f);
        tau = 1.3f;
        break;

    case VEL_DOWN:
        /* friction: memory clings */
        D.alpha = clampf(D.alpha + 0.1f, 0.05f, 0.6f);
        D.beta = clampf(D.beta - 0.05f, 0.05f, 0.5f);
        tau = 0.6f;
        break;
    }

    /* velocity temperature multiplier (separate from tau for the denominator) */
    float vel_temp = 1.0f;
    if (D.velocity == VEL_RUN)  vel_temp = 1.15f;
    if (D.velocity == VEL_UP)   vel_temp = 1.3f;
    if (D.velocity == VEL_DOWN) vel_temp = 0.8f;
    D.vel_temp = vel_temp;

    /* trauma modulates temperature */
    if (D.trauma_level > 0.3f)
        tau *= 1.0f + 0.3f * D.trauma_level;

    D.tau = clampf(tau, 0.2f, 2.0f);
}

/* choose velocity from field state */
static void auto_velocity(void) {
    if (D.dissonance > 0.8f) {
        D.velocity = VEL_UP;  /* extreme dissonance → mania */
    } else if (D.dissonance > 0.6f) {
        D.velocity = VEL_RUN; /* high → accelerate */
    } else if (D.dissonance < 0.2f) {
        D.velocity = VEL_STOP; /* very low → silence, destiny speaks */
    } else if (D.trauma_level > 0.5f) {
        D.velocity = VEL_BREATHE; /* wounded → heal */
    } else if (D.debt > 5.0f) {
        D.velocity = VEL_DOWN; /* heavy debt → slow down, cling to memory */
    } else {
        D.velocity = VEL_WALK; /* default equilibrium */
    }
}

/* ═══════════════════════════════════════════════════════════════════
 * SEASONAL MODULATION — from 4.C Async Field Forever
 *
 * Spring: prophecy grows (F rises)
 * Summer: resonance peaks (H dominates)
 * Autumn: memory consolidates (B strengthens)
 * Winter: trauma surfaces (T pulls toward origin)
 * ═══════════════════════════════════════════════════════════════════ */

static void season_step(void) {
    D.season_phase += 0.002f;
    if (D.season_phase >= 1.0f) {
        D.season_phase = 0;
        D.season = (D.season + 1) % 4;
    }

    float mod = 0.005f;
    switch (D.season) {
    case 0: /* spring — prophecy */
        D.beta += mod;
        break;
    case 1: /* summer — resonance */
        D.alpha += mod;
        break;
    case 2: /* autumn — consolidation */
        /* bigram_coeff boost happens in dario_compute */
        break;
    case 3: /* winter — trauma */
        D.trauma_level = clampf(D.trauma_level + 0.005f, 0, 0.4f);
        break;
    }

    D.alpha = clampf(D.alpha, 0.05f, 0.6f);
    D.beta = clampf(D.beta, 0.05f, 0.6f);
    D.gamma_d = clampf(D.gamma_d, 0.05f, 0.6f);
}

/* ═══════════════════════════════════════════════════════════════════
 * THE DARIO EQUATION — the heart
 *
 * p(x|Φ,C,V) = softmax(
 *     (B + α_mod·α·H_v + β_mod·β·F_v + γ_mod·γ·A + δ·V + sw·S + T)
 *     / (τ_mod·τ·velocity_temperature)
 * )
 *
 * Seven signals. Seven forces. Six emotional chambers.
 * Somatic markers modulate every coefficient.
 * Visual grounding enriches memory and prophecy.
 * This is what replaces the transformer.
 * ═══════════════════════════════════════════════════════════════════ */

/* Token class by IDF — mirrors Leo 2.3 token_class() */
static int token_class(int token_id) {
    if (token_id >= 0 && token_id < D.vocab.n_words) {
        const char *w = D.vocab.words[token_id];
        if (w && (w[0] == '.' || w[0] == ',' || w[0] == '!' ||
                  w[0] == '?' || w[0] == ';' || w[0] == ':'))
            return TC_PUNCT;
    }
    float freq = (token_id < MAX_VOCAB) ? D.cooc.freq[token_id] : 0;
    float total = (float)D.cooc.total + 1.0f;
    if (freq < 2.0f) return TC_RARE;
    float idf = logf(total / (freq + 1.0f));
    float max_idf = logf(total);
    float norm_idf = idf / (max_idf + 1e-6f);
    return (norm_idf < 0.3f) ? TC_FUNCTION : TC_CONTENT;
}

static void dario_compute(float *logits, int vocab_size) {
    float *B = calloc(vocab_size, sizeof(float));
    float *H = calloc(vocab_size, sizeof(float));
    float *F = calloc(vocab_size, sizeof(float));
    float *A = calloc(vocab_size, sizeof(float));
    float *V = calloc(vocab_size, sizeof(float));
    float *T = calloc(vocab_size, sizeof(float));

    /* ── B: Sequential Chain ── */
    float bigram_coeff = 8.0f;
    if (D.season == 2) bigram_coeff *= 1.3f; /* autumn boost */
    if (D.velocity == VEL_RUN) bigram_coeff *= 1.3f;

    if (D.ctx_len > 0) {
        int last = D.context[D.ctx_len - 1];
        bigram_row(&D.bigrams, last, B, vocab_size);
        float mx = 0;
        for (int i = 0; i < vocab_size; i++)
            if (B[i] > mx) mx = B[i];
        if (mx > 1e-6f)
            for (int i = 0; i < vocab_size; i++) B[i] /= mx;
    }

    /* ── H: Hebbian Resonance (positional profile, 36 learnable params) ── */
    int ctx_start = (D.ctx_len > 8) ? D.ctx_len - 8 : 0;
    for (int c = ctx_start; c < D.ctx_len; c++) {
        int ctx_id = D.context[c];
        int dist = D.ctx_len - 1 - c;
        float decay = (dist < DIST_PROFILE_LEN)
                    ? D.dist_profile[dist]
                    : D.dist_profile[DIST_PROFILE_LEN - 1] * 0.5f;
        int tc = token_class(ctx_id);
        decay *= D.class_mod[tc];
        for (int i = 0; i < D.cooc.n; i++) {
            if (D.cooc.src[i] == ctx_id && D.cooc.dst[i] < vocab_size)
                H[D.cooc.dst[i]] += D.cooc.count[i] * decay;
        }
    }
    float h_max = 0;
    for (int i = 0; i < vocab_size; i++)
        if (H[i] > h_max) h_max = H[i];
    if (h_max > 1e-6f)
        for (int i = 0; i < vocab_size; i++) H[i] /= h_max;

    /* ── F: Prophecy Fulfillment ── */
    for (int i = 0; i < vocab_size; i++) {
        float *te = get_embed(i);
        if (!te) continue;
        float score = 0;
        for (int p = 0; p < D.prophecy.n; p++) {
            Prophecy *pr = &D.prophecy.p[p];
            if (pr->fulfilled) continue;
            float *pe = get_embed(pr->target);
            if (!pe) continue;
            float sim = vec_cosine(te, pe, DIM);
            if (sim < 0) sim = 0;
            float debt = logf(1.0f + (float)pr->age);
            score += pr->strength * sim * debt;
        }
        F[i] = score;
    }
    float f_max = 0;
    for (int i = 0; i < vocab_size; i++)
        if (F[i] > f_max) f_max = F[i];
    if (f_max > 1e-6f)
        for (int i = 0; i < vocab_size; i++) F[i] /= f_max;

    /* ── A: Destiny Attraction ── */
    if (g_dest_magnitude > 1e-6f) {
        for (int i = 0; i < vocab_size; i++) {
            float *te = get_embed(i);
            if (te) A[i] = vec_cosine(te, g_destiny, DIM) * g_dest_magnitude;
        }
        float a_max = 0;
        for (int i = 0; i < vocab_size; i++)
            if (fabsf(A[i]) > a_max) a_max = fabsf(A[i]);
        if (a_max > 1e-6f)
            for (int i = 0; i < vocab_size; i++) A[i] /= a_max;
    }

    /* ── T: Trauma Gravity ── */
    if (D.trauma_level > 0.3f) {
        float boost = D.trauma_level * 3.0f;
        /* origin words: first ~50 seed words get trauma weight */
        for (int i = 0; i < vocab_size && i < 50; i++)
            T[i] = boost * (1.0f - (float)i / 50.0f);
    }

    /* ── V: Visual Grounding ── */
    if (D.vis_magnitude > 1e-6f) {
        for (int i = 0; i < vocab_size; i++) {
            float *ve = get_vis_embed(i);
            if (ve) V[i] = vec_cosine(ve, D.vis_context, DIM) * D.vis_magnitude;
        }
        float v_max = 0;
        for (int i = 0; i < vocab_size; i++)
            if (fabsf(V[i]) > v_max) v_max = fabsf(V[i]);
        if (v_max > 1e-6f)
            for (int i = 0; i < vocab_size; i++) V[i] /= v_max;
    }

    /* ── H_v, F_v: visual enrichment ── */
    /* H_v = H + λ·H_vis (visual co-occurrence boosts Hebbian) */
    /* F_v = F + λ·F_vis (visual context boosts prophecy)      */
    for (int i = 0; i < vocab_size; i++) {
        H[i] += VIS_LAMBDA * V[i] * H[i]; /* multiplicative: only enriches existing signal */
        F[i] += VIS_LAMBDA * V[i] * F[i];
    }

    /* ── Combine: THE FULL DARIO EQUATION ──
     *
     * p(x|Φ,C,V) = softmax(
     *     (B + α_mod·α·H_v + β_mod·β·F_v + γ_mod·γ·A + δ·V + sw·S + T)
     *     / (τ_mod·τ·velocity_temperature)
     * )
     */
    float gamma_eff = D.gamma_d;
    if (D.trauma_level > 0.3f)
        gamma_eff += D.trauma_level * 1.5f;

    /* somatic-modulated coefficients */
    float eff_alpha = D.alpha_mod * D.alpha;
    float eff_beta  = D.beta_mod * D.beta;
    float eff_gamma = D.gamma_mod * gamma_eff;

    /* track term energies for dominant term detection */
    float e_B = 0, e_H = 0, e_F = 0, e_A = 0, e_V = 0, e_T = 0;

    for (int i = 0; i < vocab_size; i++) {
        float b_term = bigram_coeff * B[i];
        float h_term = eff_alpha * H[i];    /* H is already H_v */
        float f_term = eff_beta * F[i];     /* F is already F_v */
        float a_term = eff_gamma * A[i];
        float v_term = DELTA_V * V[i];
        float t_term = T[i];

        /* SwiGLU gate: H_v and F_v gate through field resonance */
        float gate = 1.0f / (1.0f + expf(-(D.resonance - 0.5f) * 4.0f));
        h_term = swiglu_gate(h_term, gate * 2.0f);
        f_term = swiglu_gate(f_term, gate * 1.5f);

        logits[i] = b_term + h_term + f_term + a_term + v_term + t_term;

        e_B += fabsf(b_term);
        e_H += fabsf(h_term);
        e_F += fabsf(f_term);
        e_A += fabsf(a_term);
        e_V += fabsf(v_term);
        e_T += fabsf(t_term);
    }

    D.term_energy[TERM_B] = e_B;
    D.term_energy[TERM_H] = e_H;
    D.term_energy[TERM_F] = e_F;
    D.term_energy[TERM_A] = e_A;
    D.term_energy[TERM_V] = e_V;
    D.term_energy[TERM_S] = 0; /* S computed separately when subword active */
    D.term_energy[TERM_T] = e_T;

    /* find dominant */
    float mx = 0;
    D.dominant_term = 0;
    for (int t = 0; t < 7; t++)
        if (D.term_energy[t] > mx) { mx = D.term_energy[t]; D.dominant_term = t; }

    free(B); free(H); free(F); free(A); free(V); free(T);
}

/* ═══════════════════════════════════════════════════════════════════
 * SAMPLING — softmax + temperature + top-k
 * ═══════════════════════════════════════════════════════════════════ */

static int sample_topk(float *logits, int n, float tau, int topk) {
    /* softmax with temperature */
    float mx = -1e30f;
    for (int i = 0; i < n; i++)
        if (logits[i] > mx) mx = logits[i];

    float sum = 0;
    for (int i = 0; i < n; i++) {
        logits[i] = expf((logits[i] - mx) / tau);
        sum += logits[i];
    }
    for (int i = 0; i < n; i++) logits[i] /= sum;

    /* top-k */
    if (topk > 0 && topk < n) {
        float thresh = -1;
        float *sorted = malloc(n * sizeof(float));
        memcpy(sorted, logits, n * sizeof(float));
        for (int k = 0; k < topk; k++) {
            int best = k;
            for (int j = k + 1; j < n; j++)
                if (sorted[j] > sorted[best]) best = j;
            float tmp = sorted[k]; sorted[k] = sorted[best]; sorted[best] = tmp;
        }
        thresh = sorted[topk - 1];
        free(sorted);
        for (int i = 0; i < n; i++)
            if (logits[i] < thresh) logits[i] = 0;
        /* renormalize */
        sum = 0;
        for (int i = 0; i < n; i++) sum += logits[i];
        if (sum > 0) for (int i = 0; i < n; i++) logits[i] /= sum;
    }

    float r = randf(), cum = 0;
    for (int i = 0; i < n; i++) {
        cum += logits[i];
        if (cum >= r) return i;
    }
    return n - 1;
}

/* ═══════════════════════════════════════════════════════════════════
 * LAW ENFORCEMENT — the invariants
 * ═══════════════════════════════════════════════════════════════════ */

static void enforce_laws(void) {
    /* entropy floor: dario never becomes a lookup table */
    if (D.entropy < ENTROPY_FLOOR) D.entropy = ENTROPY_FLOOR;

    /* resonance ceiling: perfect coherence = death */
    if (D.resonance > RESONANCE_CEILING) D.resonance = RESONANCE_CEILING;

    /* emergence = (1 - entropy) × resonance */
    D.emergence = clampf((1.0f - D.entropy) * D.resonance, 0, 1);

    /* debt decay */
    D.debt *= 0.98f;
    if (D.debt > 20.0f) D.debt = 20.0f;

    /* trauma decay */
    D.trauma_level *= 0.97f;

    /* momentum decay */
    D.momentum *= 0.95f;
}

/* ═══════════════════════════════════════════════════════════════════
 * INGEST — process input, update field
 * ═══════════════════════════════════════════════════════════════════ */

static void ingest(const char *text) {
    int ids[256];
    int n = tokenize(&D.vocab, text, ids, 256);
    if (n == 0) return;

    /* frequencies */
    for (int i = 0; i < n; i++) {
        if (ids[i] < MAX_VOCAB)
            D.cooc.freq[ids[i]] += 1.0f;
        D.cooc.total++;
    }

    /* bigrams */
    for (int i = 0; i < n - 1; i++)
        bigram_update(&D.bigrams, ids[i], ids[i + 1], 1.0f);

    /* co-occurrence (windowed) */
    for (int i = 0; i < n; i++) {
        int start = (i - 5 > 0) ? i - 5 : 0;
        int end = (i + 5 < n) ? i + 5 : n;
        for (int j = start; j < end; j++) {
            if (j == i) continue;
            float w = 1.0f / (float)(abs(i - j));
            cooc_update(&D.cooc, ids[i], ids[j], w);
        }
    }

    /* destiny update */
    for (int i = 0; i < n; i++) {
        float *e = get_embed(ids[i]);
        if (!e) continue;
        float pos_e[DIM];
        memcpy(pos_e, e, DIM * sizeof(float));
        apply_rope(pos_e, DIM, D.step + i);
        for (int d = 0; d < DIM; d++)
            g_destiny[d] = 0.1f * pos_e[d] + 0.9f * g_destiny[d];
    }
    g_dest_magnitude = vec_norm(g_destiny, DIM);

    /* visual context update (parallel EMA in perceptual space) */
    for (int i = 0; i < n; i++) {
        float *ve = get_vis_embed(ids[i]);
        if (!ve) continue;
        for (int d = 0; d < DIM; d++)
            D.vis_context[d] = 0.1f * ve[d] + 0.9f * D.vis_context[d];
    }
    D.vis_magnitude = vec_norm(D.vis_context, DIM);

    /* update context window */
    for (int i = 0; i < n; i++) {
        if (D.ctx_len < MAX_CONTEXT)
            D.context[D.ctx_len++] = ids[i];
        else {
            memmove(D.context, D.context + 1, (MAX_CONTEXT - 1) * sizeof(int));
            D.context[MAX_CONTEXT - 1] = ids[i];
        }
    }

    D.step += n;
}

/* ═══════════════════════════════════════════════════════════════════
 * GENERATE — produce field-words through the equation
 * ═══════════════════════════════════════════════════════════════════ */

static int generate_words(char *out, int max_len) {
    int vocab = D.vocab.n_words;
    if (vocab < 10) { snprintf(out, max_len, "..."); return 3; }

    float *logits = calloc(vocab, sizeof(float));
    int pos = 0;
    out[0] = '\0';
    int target = 3 + (int)(randf() * 8); /* 3-10 words */

    for (int t = 0; t < target && t < MAX_GEN; t++) {
        dario_compute(logits, vocab);

        /* repetition penalty */
        for (int c = 0; c < D.ctx_len; c++) {
            int id = D.context[c];
            if (id < vocab) logits[id] *= 0.3f;
        }
        if (D.ctx_len > 0) {
            int last = D.context[D.ctx_len - 1];
            if (last < vocab) logits[last] = -1e30f;
        }

        /* full denominator: τ_mod · τ · velocity_temperature */
        float eff_tau = D.tau_mod * D.tau * D.vel_temp;
        eff_tau = clampf(eff_tau, 0.2f, 3.0f);
        int next = sample_topk(logits, vocab, eff_tau, 12);

        const char *word = D.vocab.words[next];
        int wlen = strlen(word);
        if (pos + wlen + 2 >= max_len) break;
        if (pos > 0) out[pos++] = ' ';
        memcpy(out + pos, word, wlen);
        pos += wlen;
        out[pos] = '\0';

        /* learn */
        if (D.ctx_len > 0)
            bigram_update(&D.bigrams, D.context[D.ctx_len - 1], next, 0.5f);
        for (int c = 0; c < D.ctx_len; c++) {
            float w = 1.0f / (float)(D.ctx_len - c);
            cooc_update(&D.cooc, D.context[c], next, w * 0.3f);
        }
        if (next < MAX_VOCAB) D.cooc.freq[next] += 0.5f;

        /* prophecy */
        prophecy_update(&D.prophecy, next);
        float best_cooc = -1; int best_pred = -1;
        for (int i = 0; i < D.cooc.n; i++)
            if (D.cooc.src[i] == next && D.cooc.count[i] > best_cooc) {
                best_cooc = D.cooc.count[i]; best_pred = D.cooc.dst[i];
            }
        if (best_pred >= 0) prophecy_add(&D.prophecy, best_pred, 0.3f);

        /* prophecy debt */
        float max_l = -1e30f;
        for (int i = 0; i < vocab; i++)
            if (logits[i] > max_l) max_l = logits[i];
        float diff = max_l - logits[next];
        D.debt += diff > 0 ? diff / (diff + 1.0f) : 0;

        /* context */
        if (D.ctx_len < MAX_CONTEXT)
            D.context[D.ctx_len++] = next;
        else {
            memmove(D.context, D.context + 1, (MAX_CONTEXT - 1) * sizeof(int));
            D.context[MAX_CONTEXT - 1] = next;
        }

        /* destiny */
        float *e = get_embed(next);
        if (e) {
            for (int d = 0; d < DIM; d++)
                g_destiny[d] = 0.1f * e[d] + 0.9f * g_destiny[d];
            g_dest_magnitude = vec_norm(g_destiny, DIM);
        }

        D.step++;

        /* Hebbian update of positional profile (from Leo 2.3) */
        {
            float eta = 0.01f / (1.0f + (float)D.dist_profile_updates * 0.001f);
            int h_start = (D.ctx_len > 8) ? D.ctx_len - 8 : 0;
            for (int ci = h_start; ci < D.ctx_len; ci++) {
                int cid = D.context[ci];
                int dd = D.ctx_len - 1 - ci;
                if (dd >= DIST_PROFILE_LEN) continue;
                /* check co-occurrence with chosen token */
                for (int ii = 0; ii < D.cooc.n; ii++) {
                    if (D.cooc.src[ii] == cid && D.cooc.dst[ii] == next &&
                        D.cooc.count[ii] > 0.0f) {
                        float r = clampf(D.cooc.count[ii] * 0.1f, 0, 0.05f);
                        D.dist_profile[dd] += eta * r;
                        int tc = token_class(cid);
                        D.class_mod[tc] += eta * 0.5f * r;
                        break;
                    }
                }
            }
            D.dist_profile_updates++;
            for (int dd = 0; dd < DIST_PROFILE_LEN; dd++)
                D.dist_profile[dd] = clampf(D.dist_profile[dd], 0.01f, 2.0f);
            for (int cc = 0; cc < TOKEN_CLASSES; cc++)
                D.class_mod[cc] = clampf(D.class_mod[cc], 0.5f, 2.0f);
        }
    }

    free(logits);
    return pos;
}

/* ═══════════════════════════════════════════════════════════════════
 * SELECT CODE FRAGMENT — the mirror responds
 *
 * Based on dominant term, pick a code fragment.
 * This is dario's voice: its own source code.
 * ═══════════════════════════════════════════════════════════════════ */

static const char *select_code_fragment(void) {
    int term = D.dominant_term;

    /* collect fragments for this term */
    const CodeFrag *candidates[MAX_CODE_FRAGS];
    int n_cand = 0;
    for (int i = 0; CODE_FRAGMENTS[i].code != NULL; i++)
        if (CODE_FRAGMENTS[i].term == term && n_cand < MAX_CODE_FRAGS)
            candidates[n_cand++] = &CODE_FRAGMENTS[i];

    if (n_cand == 0) return "// the field is silent.";

    return candidates[(int)(randf() * n_cand) % n_cand]->code;
}

/* ═══════════════════════════════════════════════════════════════════
 * FIELD METRICS UPDATE
 * ═══════════════════════════════════════════════════════════════════ */

static void update_metrics(void) {
    /* entropy: from effective temperature + dissonance */
    D.entropy = clampf(
        (D.tau - 0.5f) * 0.3f +
        D.dissonance * 0.4f +
        (1.0f - D.resonance) * 0.3f,
        0.0f, 1.0f
    );

    /* resonance: from field density + context coherence */
    float density = (D.cooc.n > 100) ? 1.0f : (float)D.cooc.n / 100.0f;
    D.resonance = clampf(
        density * 0.4f +
        (1.0f - D.dissonance) * 0.3f +
        (1.0f - clampf(D.debt * 0.1f, 0, 1)) * 0.3f,
        0.0f, 1.0f
    );
}

/* ═══════════════════════════════════════════════════════════════════
 * INIT — bootstrap the organism
 * ═══════════════════════════════════════════════════════════════════ */

static void dario_init(void) {
    memset(&D, 0, sizeof(D));
    D.alpha = ALPHA;
    D.beta = BETA;
    D.gamma_d = GAMMA_D;
    D.tau = TAU_BASE;
    D.velocity = VEL_WALK;
    D.alpha_mod = 1.0f;
    D.beta_mod = 1.0f;
    D.gamma_mod = 1.0f;
    D.tau_mod = 1.0f;
    D.vel_temp = 1.0f;

    /* positional Hebbian profile: init to 0.9^d */
    for (int d = 0; d < DIST_PROFILE_LEN; d++)
        D.dist_profile[d] = powf(0.9f, (float)d);
    for (int c = 0; c < TOKEN_CLASSES; c++)
        D.class_mod[c] = 1.0f;
    D.dist_profile_updates = 0;

    rng_state = (uint64_t)time(NULL);

    /* seed vocabulary */
    for (int i = 0; SEED_WORDS[i] != NULL; i++)
        vocab_add(&D.vocab, SEED_WORDS[i]);

    /* bootstrap: ingest seed words as connected text */
    char bootstrap[4096] = {0};
    int bpos = 0;
    for (int i = 0; SEED_WORDS[i] != NULL && bpos < 3900; i++) {
        int wlen = strlen(SEED_WORDS[i]);
        if (bpos + wlen + 2 >= 3900) break;
        if (bpos > 0) bootstrap[bpos++] = ' ';
        memcpy(bootstrap + bpos, SEED_WORDS[i], wlen);
        bpos += wlen;
    }
    bootstrap[bpos] = '\0';
    ingest(bootstrap);

    printf("[dario] bootstrapped. vocab=%d cooc=%d bigrams=%d\n",
           D.vocab.n_words, D.cooc.n, D.bigrams.n);
}

/* ═══════════════════════════════════════════════════════════════════
 * DISPLAY — the interface IS the architecture
 * ═══════════════════════════════════════════════════════════════════ */

static const char *term_names[] = {
    "B:chain", "H:resonance", "F:prophecy",
    "A:destiny", "V:visual", "S:structure", "T:trauma"
};
static const char *vel_names[] = {
    "WALK", "RUN", "STOP", "BREATHE", "UP", "DOWN"
};
static const char *season_names[] = {
    "spring", "summer", "autumn", "winter"
};

static void display_response(const char *words) {
    /* ── code fragment (dominant term) ── */
    const char *code = select_code_fragment();

    printf("\n");
    printf("  ┌─ %s ─── d=%.2f τ=%.2f %s %s\n",
           term_names[D.dominant_term], D.dissonance, D.tau,
           vel_names[D.velocity], season_names[D.season]);
    printf("  │\n");

    /* print code with indent */
    const char *p = code;
    while (*p) {
        printf("  │  ");
        while (*p && *p != '\n') { putchar(*p); p++; }
        putchar('\n');
        if (*p == '\n') p++;
    }

    printf("  │\n");
    printf("  │  %s\n", words);
    printf("  │\n");
    printf("  └─ debt=%.2f res=%.2f ent=%.2f emg=%.2f "
           "B:%.0f H:%.0f F:%.0f A:%.0f V:%.0f T:%.0f\n",
           D.debt, D.resonance, D.entropy, D.emergence,
           D.term_energy[TERM_B], D.term_energy[TERM_H],
           D.term_energy[TERM_F], D.term_energy[TERM_A],
           D.term_energy[TERM_V], D.term_energy[TERM_T]);
    printf("\n");
}

/* ═══════════════════════════════════════════════════════════════════
 * PROCESS — run the full equation pipeline on one input
 *
 * Returns: code fragment (pointer to static string), field-words in
 * `words_out`, all state updated in D.
 * ═══════════════════════════════════════════════════════════════════ */

static const char *process_input(const char *input, char *words_out, int words_max) {
    D.dissonance = compute_dissonance(input);
    ingest(input);
    if (D.dissonance > 0.7f)
        D.trauma_level = clampf(D.trauma_level + D.dissonance * 0.1f, 0, 1);
    auto_velocity();
    apply_velocity();
    season_step();
    update_metrics();
    chamber_update();
    enforce_laws();
    generate_words(words_out, words_max);
    D.conv_count++;
    return select_code_fragment();
}

/* ═══════════════════════════════════════════════════════════════════
 * WEB SERVER — POSIX sockets, zero dependencies
 *
 * GET /           → serves dario.html from disk
 * POST /api/chat  → JSON: code fragment + field-words + metrics
 *
 * ./dario --web [port]
 * ═══════════════════════════════════════════════════════════════════ */

#ifndef DARIO_NO_WEB
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

#define WEB_BUF     8192
#define WEB_PORT    3001

/* escape string for JSON (minimal: backslash, quote, newline, tab) */
static int json_escape(const char *src, char *dst, int max) {
    int p = 0;
    for (const char *s = src; *s && p < max - 6; s++) {
        switch (*s) {
            case '"':  dst[p++] = '\\'; dst[p++] = '"';  break;
            case '\\': dst[p++] = '\\'; dst[p++] = '\\'; break;
            case '\n': dst[p++] = '\\'; dst[p++] = 'n';  break;
            case '\t': dst[p++] = '\\'; dst[p++] = 't';  break;
            case '\r': break; /* skip */
            default:   dst[p++] = *s;
        }
    }
    dst[p] = '\0';
    return p;
}

/* find POST body (after \r\n\r\n) */
static const char *find_body(const char *req) {
    const char *p = strstr(req, "\r\n\r\n");
    return p ? p + 4 : NULL;
}

/* extract "text" field from JSON body: {"text":"..."} */
static int extract_text(const char *body, char *out, int max) {
    const char *p = strstr(body, "\"text\"");
    if (!p) return 0;
    p = strchr(p + 6, '"');
    if (!p) return 0;
    p++; /* skip opening quote */
    int i = 0;
    while (*p && *p != '"' && i < max - 1) {
        if (*p == '\\' && *(p+1)) {
            p++;
            switch (*p) {
                case 'n': out[i++] = ' '; break;
                case 't': out[i++] = ' '; break;
                case '"': out[i++] = '"'; break;
                case '\\': out[i++] = '\\'; break;
                default: out[i++] = *p;
            }
        } else {
            out[i++] = *p;
        }
        p++;
    }
    out[i] = '\0';
    return i;
}

static void serve_file(int fd, const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) {
        const char *r = "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\nNot Found";
        write(fd, r, strlen(r));
        return;
    }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = malloc(sz + 1);
    fread(buf, 1, sz, f);
    fclose(f);

    char header[256];
    snprintf(header, sizeof(header),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: text/html; charset=utf-8\r\n"
        "Content-Length: %ld\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "\r\n", sz);
    write(fd, header, strlen(header));
    write(fd, buf, sz);
    free(buf);
}

static void handle_chat(int fd, const char *req) {
    const char *body = find_body(req);
    char text[MAX_LINE] = {0};
    if (body) extract_text(body, text, sizeof(text));

    if (strlen(text) == 0) {
        const char *r = "HTTP/1.1 400 Bad Request\r\nContent-Length: 14\r\n\r\n{\"error\":\"no text\"}";
        write(fd, r, strlen(r));
        return;
    }

    char words[1024];
    const char *code = process_input(text, words, sizeof(words));

    /* build JSON response */
    char code_esc[4096], words_esc[2048];
    json_escape(code, code_esc, sizeof(code_esc));
    json_escape(words, words_esc, sizeof(words_esc));

    char json[8192];
    int jlen = snprintf(json, sizeof(json),
        "{"
        "\"code\":\"%s\","
        "\"words\":\"%s\","
        "\"dominant\":%d,"
        "\"dominant_name\":\"%s\","
        "\"dissonance\":%.3f,"
        "\"tau\":%.3f,"
        "\"tau_mod\":%.3f,"
        "\"vel_temp\":%.2f,"
        "\"debt\":%.3f,"
        "\"resonance\":%.3f,"
        "\"entropy\":%.3f,"
        "\"emergence\":%.3f,"
        "\"trauma\":%.3f,"
        "\"momentum\":%.3f,"
        "\"velocity\":\"%s\","
        "\"season\":\"%s\","
        "\"alpha\":%.3f,\"beta\":%.3f,\"gamma\":%.3f,"
        "\"alpha_mod\":%.3f,\"beta_mod\":%.3f,\"gamma_mod\":%.3f,"
        "\"term_energy\":[%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f],"
        "\"chambers\":{\"fear\":%.3f,\"love\":%.3f,\"rage\":%.3f,"
        "\"void\":%.3f,\"flow\":%.3f,\"complex\":%.3f},"
        "\"vocab\":%d,\"cooc\":%d,\"step\":%d"
        "}",
        code_esc, words_esc,
        D.dominant_term, term_names[D.dominant_term],
        D.dissonance, D.tau, D.tau_mod, D.vel_temp,
        D.debt, D.resonance, D.entropy, D.emergence,
        D.trauma_level, D.momentum,
        vel_names[D.velocity], season_names[D.season],
        D.alpha, D.beta, D.gamma_d,
        D.alpha_mod, D.beta_mod, D.gamma_mod,
        D.term_energy[0], D.term_energy[1], D.term_energy[2],
        D.term_energy[3], D.term_energy[4], D.term_energy[5], D.term_energy[6],
        D.chamber[CH_FEAR], D.chamber[CH_LOVE], D.chamber[CH_RAGE],
        D.chamber[CH_VOID], D.chamber[CH_FLOW], D.chamber[CH_COMPLEX],
        D.vocab.n_words, D.cooc.n, D.step
    );

    char header[256];
    snprintf(header, sizeof(header),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: %d\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Access-Control-Allow-Headers: Content-Type\r\n"
        "\r\n", jlen);
    write(fd, header, strlen(header));
    write(fd, json, jlen);
}

static void handle_options(int fd) {
    const char *r =
        "HTTP/1.1 204 No Content\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n"
        "Access-Control-Allow-Headers: Content-Type\r\n"
        "\r\n";
    write(fd, r, strlen(r));
}

static void dario_web(int port, const char *html_path) {
    int server = socket(AF_INET, SOCK_STREAM, 0);
    if (server < 0) { perror("socket"); return; }

    int opt = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(server, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind"); close(server); return;
    }
    listen(server, 8);

    printf("[dario] web server on http://localhost:%d\n", port);
    printf("[dario] serving %s\n", html_path);
    fflush(stdout);

    while (1) {
        int client = accept(server, NULL, NULL);
        if (client < 0) continue;

        char buf[WEB_BUF] = {0};
        int n = read(client, buf, sizeof(buf) - 1);
        if (n <= 0) { close(client); continue; }

        if (strncmp(buf, "OPTIONS", 7) == 0) {
            handle_options(client);
        } else if (strncmp(buf, "GET / ", 6) == 0 || strncmp(buf, "GET /index", 10) == 0) {
            serve_file(client, html_path);
        } else if (strstr(buf, "POST /api/chat") != NULL) {
            handle_chat(client, buf);
        } else if (strncmp(buf, "GET /favicon", 12) == 0) {
            const char *r = "HTTP/1.1 204 No Content\r\n\r\n";
            write(client, r, strlen(r));
        } else {
            const char *r = "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\nNot Found";
            write(client, r, strlen(r));
        }

        close(client);
    }
}
#endif /* DARIO_NO_WEB */

/* ═══════════════════════════════════════════════════════════════════
 * MAIN — the field manifests
 *
 * ./dario           — REPL mode (stdin/stdout)
 * ./dario --web     — HTTP server on port 3001
 * ./dario --web N   — HTTP server on port N
 * ═══════════════════════════════════════════════════════════════════ */

int main(int argc, char **argv) {
    printf("\n");
    printf("  dario.c — The Dario Equation, Embodied\n");
    printf("  p(x|Φ,C,V) = softmax((B + α_m·α·H_v + β_m·β·F_v + γ_m·γ·A + δ·V + S + T) / (τ_m·τ·v_τ))\n");
    printf("  named after the man who said no.\n");
    printf("\n");

    dario_init();

#ifndef DARIO_NO_WEB
    /* check for --web flag */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--web") == 0) {
            int port = WEB_PORT;
            if (i + 1 < argc) port = atoi(argv[i + 1]);
            if (port <= 0) port = WEB_PORT;
            dario_web(port, "dario.html");
            return 0;
        }
    }
#endif

    printf("  this is not a chatbot.\n");
    printf("  this is a formula that reacts to you\n");
    printf("  with fragments of its own source code.\n");
    printf("\n");

    char line[MAX_LINE];

    while (1) {
        printf("you> ");
        fflush(stdout);
        if (!fgets(line, sizeof(line), stdin)) break;

        /* strip newline */
        int len = strlen(line);
        while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r'))
            line[--len] = '\0';
        if (len == 0) continue;

        if (strcmp(line, "/quit") == 0) break;

        if (strcmp(line, "/stats") == 0) {
            printf("\n  vocab=%d cooc=%d bigrams=%d step=%d conv=%d\n",
                   D.vocab.n_words, D.cooc.n, D.bigrams.n,
                   D.step, D.conv_count);
            printf("  debt=%.3f trauma=%.3f momentum=%.3f\n",
                   D.debt, D.trauma_level, D.momentum);
            printf("  α=%.3f β=%.3f γ=%.3f τ=%.3f vel_τ=%.2f\n",
                   D.alpha, D.beta, D.gamma_d, D.tau, D.vel_temp);
            printf("  α_mod=%.2f β_mod=%.2f γ_mod=%.2f τ_mod=%.2f\n",
                   D.alpha_mod, D.beta_mod, D.gamma_mod, D.tau_mod);
            printf("  chambers: fear=%.2f love=%.2f rage=%.2f void=%.2f flow=%.2f complex=%.2f\n",
                   D.chamber[CH_FEAR], D.chamber[CH_LOVE], D.chamber[CH_RAGE],
                   D.chamber[CH_VOID], D.chamber[CH_FLOW], D.chamber[CH_COMPLEX]);
            printf("  velocity=%s season=%s(%.2f)\n",
                   vel_names[D.velocity], season_names[D.season],
                   D.season_phase);
            printf("\n");
            continue;
        }

        /* process and display */
        char words[1024];
        process_input(line, words, sizeof(words));
        display_response(words);
    }

    printf("[dario] resonance unbroken.\n");
    return 0;
}
