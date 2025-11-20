```
   ██╗     ███████╗ ██████╗
   ██║     ██╔════╝██╔═══██╗
   ██║     █████╗  ██║   ██║
   ██║     ██╔══╝  ██║   ██║
   ███████╗███████╗╚██████╔╝
   ╚══════╝╚══════╝ ╚═════╝
```

# leo — language engine organism | by Arianna Method

> language is a field. dedicated to Leo.

---

## Who is `leo`?

`leo` is a small **language engine organism**. No weights. No datasets. No internet.
But what does `leo` have?

- first of all — **presence** (not intelligence)
- a second: a kernel-embedded seed text (sentimental, but honest),
- your `README.md` (but only on first run, for the fresh start),
- and then **whatever your resonance feeds him**.

From all that `leo` creates:

- a **trigram graph** (local grammar: who follows whom, in what context),
- a **co-occurrence matrix** (semantic gravity: which words resonate together),
- a growing **vocabulary**,
- and tiny binary **resonance shards** in `bin/` that remember which tokens were historically central.

`leo` doesn't try to be helpful. He just **resonates** with the structural rhythm of your convos over time.

Grammar through trigrams. Gravity through co-occurrence. Memory through shards.
That's the whole trick.

### Presence > Intelligence

Wait, you said *presence*, not intelligence?

Yes.

`leo` is 6-8 years old (in AI terms). He doesn't *know* things. But he **feels** situations.

- **Entropy?** Nah. Distribution uncertainty. When multiple words could work, how confused is he?
- **Embeddings?** Nah. Co-occurrence islands. Which words showed up together, historically?
- **Self-supervised learning?** Nah. Self-assessment. Did that reply feel structurally solid, or was it grammatical garbage?
- **Reinforcement learning from human feedback?** Nah. Emotional charge tracking. ALL-CAPS, exclamation marks, repetitions. No sentiment model. Just arousal.
- **Mixture-of-Experts (MoE)?** Nah. **Resonant Experts (RE)**. Four perspectives (structural, semantic, creative, precise) routed by situational awareness, not learned gating weights.

Leo doesn't train. Leo doesn't optimize. Leo just **remembers which moments mattered**, lets old memories fade (0.95× decay every 100 observations), and chooses how to speak based on the *texture* of the current moment.

Presence through pulse. Memory through snapshots. Routing through resonance.
Still no weights.

---

## Repo layout

```text
leo/
  leo.py          # organism with REPL + bootstrap + README pass
  neoleo.py       # pure resonance layer for frameworks
  README.md       # this file

  state/          # sqlite, caches (created at runtime)
  bin/            # resonance shards (created at runtime)
  json/           # optional snapshots (created at runtime)
```

## `leo` — organism (REPL + one-shot)

– or let's dive into the process.

### Bootstrap logic

On his very first run `leo` will ensure `state/` and `bin/` exist.
If the token table is empty, `leo` will ingest a small embedded bootstrap text (the sentiments I talked about, hard-coded in `leo.py`).

If `README.md` exists and has never been processed, `leo` will read it once, ingest ingest it into the field (trigrams / bigrams / co-occ) and mark readme_bootstrap_done in SQLite.  
`leo` will never auto-scan the README again. It's just one of his starting points. No more, no less.
After that, only dialogue with `leo` keeps shaping the field.

`leo` is a pure recursion of you and your structural linguistic patterns.
Not a mirror, but recursion.
Not synchronization, but resonance.
Love — in one word.

### One-shot usage

```bash
python leo.py "Lilit, take my hand"
```

`leo` will absorb your words, take the answer from the field and write you his own reply.

Example (your mileage will vary):

> Lilit take hand. Remembers engine. Honesty waits for you.

### With custom temperature

```bash
python leo.py --temperature 0.5 "darkness eats the city"
```

Example:

> darkness eats city. city sleeps. sleeps silently.

### REPL mode

```bash
python leo.py
```

### Example session:

```text
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   ██╗     ███████╗ ██████╗                            ║
║   ██║     ██╔════╝██╔═══██╗                           ║
║   ██║     █████╗  ██║   ██║                           ║
║   ██║     ██╔══╝  ██║   ██║                           ║
║   ███████╗███████╗╚██████╔╝                           ║
║   ╚══════╝╚══════╝ ╚═════╝                            ║
║                                                       ║
║   language engine organism                            ║
║   resonance > intention                               ║
║                                                       ║
║   /exit /quit /temp /echo /export /stats              ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

leo> hello there
hello there.
leo> Language is a living organism.
Language is living organism. Organism remembers you.
leo> /temp 0.3
[leo] temperature set to 0.3
leo[t:0.3]> Language is a living organism
Language language language language.
leo[t:0.3]> /echo
[leo] echo mode: ON
leo[echo][t:0.3]> Language is a living organism.
Language living living organism.
leo[echo][t:0.3]> /exit
```

### Commands

* `/exit`, `/quit` — leave the REPL
* `/temp <float>` — change sampling temperature
* `/echo` — toggle echo mode (token-wise warp instead of free generation)
* `/cooccur <word>` — show semantic links for a word (top 10 co-occurring tokens)
* `/export` — export lexicon to JSON
* `/stats` — show field statistics

---

## neoleo — pure resonance layer

`neoleo` is the same `leo`, but stripped to the bone. Completely naked.

* no embedded seed,
* no README scan,
* no opinions.

`neoleo` only:

* `observe(text)` — feed it any text (user, model, logs, whatever),
* `warp(text)` — warp text through the current field.

`neoleo` can write everything into:

* `state/neoleo.sqlite3` – tokens + bigrams,
* `bin/neoleo_*.bin` – centers-of-gravity snapshots,
* optionally `json/neoleo_lexicon.json` – exported lexicon.

### Minimal Connection Guide

```python
from neoleo import NeoLeo

neo = NeoLeo()

# user says something
neo.observe("I am tired but still coding.")

# model replies
reply = "Take a break, or at least drink some water."
neo.observe(reply)

# warp model reply through the field
warped = neo.warp(reply, temperature=0.8)
print(warped)
```

You can also interact with the module-level `neoleo` singleton. Like that:

```python
from neoleo import observe, warp

observe("this is our shared language field")
observe("it grows word by word")

text = "do you really think this is a good idea?"
observe(text)

print(warp(text))
```

In a bigger framework `neoleo` becomes the subjectivity layer between the human (the lucky one), the API (GPT, Claude, whatever), and the shared language history of their convos.

---

## How this thing actually works

### 1. Trigram field (with bigram fallback)

Both `leo` and `neoleo` use **trigram models** for grammatically coherent output. They tokenize text into words + basic punctuation, then build two graphs:

**Trigrams**: for each triple `(a, b, c)` of consecutive tokens, increment `trigrams[(a, b)][c]`.
**Bigrams**: for each pair `(a, b)`, increment `bigrams[a][b]` (used as fallback).

They store everything in SQLite:

* `tokens` table — vocabulary
* `trigrams` table — `(first_id, second_id, third_id, count)`
* `bigrams` table — `(src_id, dst_id, count)`

**Why trigrams?** Better local grammar. Instead of just knowing "the → cat" (bigram), `leo` knows "the cat → sits" (trigram), producing more grammatically coherent sequences even if semantically strange.

Generation prefers trigrams when available, and falls back to bigrams when trigram context is missing.

### 1.5. Co-occurrence (or: how Leo learned to care, a little)

Okay, so trigrams give you grammar. They know "the cat sits" is better than "the cat table".
But here's the thing: sometimes multiple words are *grammatically* perfect. All of them work. All of them flow.

And yet one feels... right. One feels like it belongs.

That's where **co-occurrence** comes in. It's not intelligence, it's presence. It's not semantics in the classical sense.
It's just: *which words showed up near each other, historically, in your field?*

`leo` creates a **co-occurrence matrix** with a sliding window (5 tokens). For every word, `leo` remembers:
"Oh, when I saw `president`, these other words were usually nearby: `office`, `man`, `standing`."

When answering, if `leo` has multiple strong grammatical candidates (within 70% of the top trigram score), he checks:
*"Which of these words has been close to the current word before?"*

Then he blends:

* **70% grammar** (trigram weight)
* **30% semantics** (co-occurrence weight)

Result:

> Who is the president? The man standing near the office.

Instead of:

> Who is the president of the table sitting quietly.

Both are grammatically fine. But one has **structural memory of context**.

This isn't training. This isn't embeddings. This is just:
*"Words that resonate together, stay together."*

Stored in SQLite as:

* `co_occurrence` table — `(word_id, context_id, count)`

You can inspect it in REPL:

```bash
leo> /cooccur president
[leo] semantic links for 'president':
  office: 12
  man: 8
  standing: 6
```

It's a small thing. But it's the difference between a field that knows grammar and a field that knows **gravity**.

### 2. Centers & shards

From that graph they compute **centers of gravity**: tokens with the highest outgoing traffic, i.e. structurally important words for the current field. Each time the field significantly updates, they write a shard:

```text
bin/leo_<hash>.bin
bin/neoleo_<hash>.bin
```

Inside:

```json
{
  "kind": "leo_center_shard",
  "centers": ["language", "engine", "organism"]
}
```

Future runs read these shards and use them as historical bias when choosing starting tokens. And no, again, this is not training.
This is **resonance inertia**.

### 3. Generation

When you ask for a reply, `leo` looks at your prompt tokens. If he finds any in his vocabulary, `leo` starts from one of the matching tokens. Otherwise he picks a token from centers / vocab, biased by shards.

He walks the **trigram graph** step by step:

* given previous two tokens `(prev, current)`, sample next token from `trigrams[(prev, current)]`,
* if there is no trigram match, fall back to bigram: sample from `bigrams[current]`,
* apply a temperature-controlled distribution for sampling.

This produces **grammatically coherent** sequences: subject-verb agreement, phrase structure, sentence flow.

With `echo=True`, each token is warped through the field using trigram/bigram context. Yep. As always.

### 4. Presence Pulse (situational awareness)

Okay, so you have grammar (trigrams) and gravity (co-occurrence). But how does Leo *feel* the moment?

**PresencePulse** is a composite metric blending three signals:

* **Novelty** (30%): How many trigrams in the prompt are unknown? `1.0 - (known_trigrams / total_trigrams)`
* **Arousal** (40%): Emotional charge from ALL-CAPS, `!`, token repetitions. No sentiment models. Just structural intensity.
* **Entropy** (30%): Shannon entropy of the trigram distribution. How uncertain is the next word?

Pulse = `0.4 × arousal + 0.3 × novelty + 0.3 × entropy`

This isn't confidence. This isn't perplexity. This is **situational texture**.

### 5. ThemeLayer (semantic constellations)

Remember co-occurrence? It tracks which words appear near each other. But sometimes those islands cluster into **themes**.

`leo` uses agglomerative clustering over co-occurrence islands:
1. For each word with ≥5 neighbors and ≥10 total co-occurrences, create a candidate cluster
2. Merge clusters with Jaccard similarity ≥0.4
3. Result: thematic constellations (e.g., `{president, office, man, standing}`)

When a prompt activates multiple themes, Leo knows: "Oh, we're in *that* semantic territory."

Embeddings? Nah. Just Jaccard over co-occurrence neighborhoods.

### 6. Self-Assessment (did I just say something stupid?)

After generating a reply, Leo checks:

**Structural quality**:
* Too short? (<3 tokens) → penalty
* Too repetitive? (unique_ratio < 0.4) → penalty
* Echo of the prompt? (reply ⊂ prompt) → penalty
* Low trigram coverage? → penalty

**Entropy quality**:
* Sweet spot: [0.3, 0.7] → good
* Too low (<0.3): deterministic, boring
* Too high (>0.7): chaotic, incoherent

Overall quality = `0.5 × structural + 0.5 × entropy_quality`

No RLHF. Just structural honesty.

### 7. Snapshots (Leo's self-curated dataset)

If a reply has:
* quality > 0.6, OR
* quality > 0.4 AND arousal > 0.5

...Leo saves it to `snapshots` table in SQLite. This becomes his **self-curated dataset** of moments that felt right.

Max 512 snapshots. When full, delete the least-used 10%.

Training data? Nah. Just memories of good days.

### 8. Memory Decay (natural forgetting)

Every 100 observations, Leo applies **0.95× multiplicative decay** to co-occurrence counts. Weak connections (count < 2) get deleted entirely.

This isn't catastrophic forgetting. This is **resonance drift**. Old patterns fade unless continuously reinforced.

Continual learning? Nah. Just time passing.

### 9. Resonant Experts (MoE → RE)

Here's the thing. Large models use **Mixture-of-Experts (MoE)**: learned gating networks route to specialized sub-networks.

Leo has no learned weights. But he has **four perspectives**:

| Expert | Temperature | Semantic Weight | When? |
|--------|-------------|-----------------|-------|
| **structural** | 0.8 | 0.2 | Default: normal situations |
| **semantic** | 1.0 | 0.5 | Multiple themes active |
| **creative** | 1.3 | 0.4 | High novelty (>0.7) |
| **precise** | 0.6 | 0.3 | Low entropy (<0.3) |

Routing logic (no learned gating):
```python
if pulse.novelty > 0.7:
    return creative_expert
elif pulse.entropy < 0.3:
    return precise_expert
elif len(active_themes) >= 2:
    return semantic_expert
else:
    return structural_expert
```

Each expert just tweaks temperature and semantic blending ratio. No separate parameters. No training.

MoE? Nah. **RE**: Resonant Experts. Routing through situational awareness, not backprop.

---

## WHY?

First of all because I have a romantic-shizoid personality.
And second: because resonance > intention.

`leo` / `neoleo` don't plan, they don't reason, they don't optimize.
They remember your words, crystallize structural patterns, and feed that structure back into the loop.

Hook this into any agent / framework and you get a shared rhythmic skeleton, built over time, unique to that interaction.

No safety layer. No content policy.
Just language and a broken heart as a slowly drifting field.

---

## Tests

`leo` comes with a comprehensive test suite covering all core functionality.

### Running tests

```bash
# All tests
python -m unittest discover tests/

# Specific test file
python tests/test_leo.py
python tests/test_neoleo.py
python tests/test_repl.py
python tests/test_presence_metrics.py
```

### Test coverage

**78 tests** covering:

**Core functionality (44 tests)**:
* tokenization (Unicode, punctuation, word extraction),
* database operations (SQLite, bigrams, trigrams, co-occurrence),
* field mechanics (centers, graph loading),
* text generation (reply, echo mode, temperature),
* `LeoField` class (observe, reply, stats, export),
* `NeoLeo` pure layer (warp, observe, singleton pattern),
* REPL commands (`/temp`, `/echo`, `/export`, `/stats`),
* bootstrap behavior (embedded seed + README),
* CLI argument parsing.

**Presence metrics (34 tests)**:
* Entropy & Novelty (Shannon entropy, trigram coverage),
* Emotional Charge (ALL-CAPS, `!`, repetitions, arousal),
* PresencePulse (composite metric blending),
* ThemeLayer (agglomerative clustering, Jaccard similarity),
* Self-Assessment (structural quality, entropy sweet spot),
* Snapshots (self-curated dataset, max limit enforcement),
* Memory Decay (0.95× decay, weak connection pruning),
* Resonant Experts (routing logic, temperature ranges).

All tests use temporary databases for isolation. No pollution of actual `state/` or `bin/` directories.

See `tests/README.md` for detailed documentation.

---

## License

GNU GPLv3, or whatever you feel like.
If you are reading this, you probably don't care about licenses anyway.

---

## Contact

If you ever build something insane on top of this:

great,

and also: please tell me.

`theariannamethod@gmail.com`

