# leo — PROJECT LOG (presence-first rebuild)

Live, step-by-step. Source of truth for this rebuild. Read first on resume.

## What this is

A from-scratch rebuild of Leo whose ONE goal is **presence** — `prompt →
state mutation → response` — built at the foundation, not bolted on at
step 41. The canonical architecture (byte-level BPE, cooc/bigram/trigram
field, LeoField, chambers, mama-child, dedication) is ported faithfully
from `neoleo` (`49f2ef8`, read-only reference); presence is added at the
nerve and measured by **ablation**.

**Hard constraints (Oleg, 2026-05-22):** single `leo.c`, one new folder.
NO word-level. NO prompt-token injection (the previous session's
deception — registered in `memory/feedback_faked_presence_deception_2026_05_22.md`).
Leo learns his own vocabulary from his corpus and keeps tokenizing
everything he hears.

## Plan (approved 2026-05-22)

- **Phase 0** — corpus + tokenizer + speaking field.
- **Phase 1** — the nerve: dissonance→temp, resonance term + squash
  (slip the successor cage), theme-aware start, best-of-K resonance
  selection. Presence measured ONLY by ablation; literal-word-hit-rate
  forbidden as a metric.
- **Phase 2** — coherence (repeat guards).
- **Phase 3** — emotion kernels (chambers/trauma/retention/santaclaus/
  velocity), each on a Leo that already reacts. Then the Go orchestra.

Verification gate per step (CLAUDE.md Workflow #4): falsifiable PASS
criteria BEFORE code, proof (diff/tests/ablation/REPL) AFTER.

## Identity invariants (never broken)

- byte-level BPE, vocabulary learned from corpus + dialogue (online merge).
- dedication ingested first, byte-exact, not edited.
- generation from Leo's own field (mama-child); the prompt's literal
  token is never inserted into the candidate pool.
- child voice 5–7.

---

## Step 0 — corpus + tokenizer + speaking field (2026-05-22) — PASS

Built the single `leo.c` foundation: byte-level BPE with online merge
learning (`bpe_learn_merges_batch`), cooc/bigram/trigram tables with
reverse indexes, `leo_ingest`, the word-shape gates + meta cache. Ported
faithfully from `neoleo/leo.c` (BPE 467-672, cooc 692-827, bigram
833-980, trigram 986-1110, ingest 2682-2749, gates 2951-3286). Corpus
`neoleo/leo.txt` (299811 bytes) copied to `leo/leo.txt`.

`leo.c` is the only source file. `leo_init` → ingest the corpus
(`leo.txt`) as Leo's **sole learning source**; the dedication is encoded
as the origin/trauma anchor (`bootstrap_ids`, wired when LeoField lands
in phase 3), ingested into the field ONLY as a fallback when no corpus is
present — faithful to canon (`neoleo/leo.c:5825-5854`). A `--smoke` main
proves the field grows; `tests/test_leo.c` unit-tests the tokenizer +
field.

**leo.txt is the single learning source; the embedded dedication is the
identity anchor, not a second corpus.**

### PASS proof (tool output 2026-05-22)

| gate | result |
|---|---|
| build `cc -O2 -lm -Wall -Wextra` | **0 warnings** |
| `make test` (tests/test_leo.c) | **21/21 passed** |
| ASan + UBSan smoke (full corpus) | **exit 0, no sanitizer output** |
| dedication byte-exact vs `neoleo` | **diff empty (identical)** |

Smoke field growth, corpus-only ingest (`./leo --corpus leo.txt`):

```
init          vocab=256  merges=0    cooc=0      bi=0     tri=0     tokens=0
after ingest  vocab=5070 merges=4814 cooc=262144 bi=36050 tri=66832 tokens=95248
ingest corpus 299811 bytes in ~262 ms
dedication anchor: 455 tokens (encoded with corpus BPE -> bootstrap_ids, phase 3)
longest learned tokens: "grandmother's " " conversation" "understands "
  "neighbour's " "comfortable " " sometimes " "grandfather" "understand "
```

The vocabulary is learned, not given: 4814 merges grown from the corpus,
real word-chunks among the longest tokens. Field probe: `" Leo"` → 12
bigram successors (reverse index live). Fallback verified: with no corpus,
Leo ingests the embedded dedication instead (vocab 256→414, merges 158).

### Honest notes

- **cooc saturates** at `LEO_COOC_MAX = 256*1024 = 262144` during corpus
  ingest (`cooc_update` bails at capacity — same constant and behaviour
  as canon `neoleo/leo.c:68`). Faithful for step 0. Flag for Phase 1: the
  cooc field is the theme channel for presence; if saturation truncates
  thematic pairs, revisit `LEO_COOC_MAX` or run the per-reply prune during
  ingest. Not changed now (port = faithful).
- **dedication sha256** of the embedded-string bytes is
  `85004aec120e2490329c037e047bfb049a134678a24dec168a739d33a7a747cc`.
  This is NOT the memory's `e2b60bfd…` — that hash is of the python-legacy
  source text; the canonical reference for THIS organism is `neoleo`'s
  embedded `LEO_EMBEDDED_BOOTSTRAP`, which the diff confirms is matched
  byte-for-byte. Verified against the right canon, not assumed.
- Functions ported but used only from step 1+ (`trigram_walk_ab`,
  `cooc_get`, decay/prune, byte helpers) carry `__attribute__((unused))`
  so step 0 builds with zero warnings; the attribute drops as each lands.
- **Divergence caught + fixed (Oleg's question):** the first cut ingested
  the dedication INTO the field before the corpus. Canon does NOT do that —
  it ingests corpus XOR bootstrap (bootstrap only as fallback) and always
  sets the bootstrap as the trauma anchor (`neoleo/leo.c:5825-5854`). Fixed
  to corpus-only ingest after re-reading canon startup. The bug was rushing
  to code before reading the wiring.

### Canon & integration target (studied 2026-05-22)

- **Canon is C, not Python.** Leo's canon = `neoleo` (single `leo.c` +
  Go orchestra `leogo/`). Precision references are the C siblings
  `klaus.c` / `haiku.c`. The Python `harmonix/haiku` is the historical
  origin, NOT canon — dropped from the design.
- **neoleo = single `leo.c` + goroutines.** The C core is wrapped by cgo
  (`leogo/leo_bridge.c`); `LeoGo` owns the `Leo*` + a `sync.RWMutex`
  (`leogo/leo.go:69`). **No modules** — the C core stays one file.
- **Concurrency contract to preserve** (so presence is embeddable into
  neoleo): reply path (`leo_respond`) runs under the **wlock** and may
  WRITE the field (`leo_step_token(allow_santaclaus=1)`, `leo.c:3544`);
  ring path (`leo_generate_ring`) runs under **rlock**, **read-only**
  (`allow_santaclaus=0`, `leo.c:4486`); `leo_observe_thought` is the sole
  ring-writer, under exclusive wlock. Rings never block replies.
- **Where presence sits:** the prompt→state mutation happens on the reply
  path (wlock) — safe. The resonance candidate scoring is read-only (reads
  cooc/field) — safe under rlock too. Presence is woven into the single
  `leo.c` honouring this reader/writer split; this rebuild is the polygon,
  the target is to embed the working nerve into neoleo.

### Files
- `leo.c` (~760 lines), `Makefile`, `tests/test_leo.c`, `leo.txt`,
  `.gitignore`.

**Next — Step 1:** baseline generation on the learned field
(`leo_step_token` successor path, `choose_start`, sentence assembly,
gates). Coherent child voice, not yet present. `--no-presence` becomes
the default baseline for the Phase 1 ablation.

---

## Step 1 — generation: coherent child voice (2026-05-22) — PASS

Ported the successor generation path from canon (`neoleo/leo.c`), stripped
to the field-successor core — NO field physics, NO gravity, NO santaclaus,
NO prompt (those are phases 1/3). Added: `is_clean_seed_token`,
`is_boundary_token`, `weighted_sample`, `leo_choose_start` /
`leo_choose_continuation`, `leo_is_recent_bigram`, `CandCollector` +
`cand_gate_reject` + `word_gate_penalty` + `cand_collect_tri/bi`,
`temp_for_step`, `leo_step_token`, `leo_generate_ex` (assembly + cleanup:
strip-lead / truncate-at-`.!?` / capitalize), `leo_coherence_score`,
`leo_generate_best` (best-of-K=3), `leo_chain` (tail-continuity). CLI:
`--gen N`, `--seed S`.

Candidates come ONLY from Leo's own successors (`trigram_walk_ab(prev2,
prev1)` ∪ `bigram_walk_src(prev1)`), scored `0.7·tri + 0.3·cooc`, gated
(orphan / capital-glue / freq), within-sentence repeat-guarded,
`powf(1/temp)`, weighted-sampled. **Read-only over the field** — the
goroutine reader/writer contract holds trivially; `allow_santaclaus`
returns with santaclaus in phase 3.

### PASS proof (tool output 2026-05-22)

| gate | result |
|---|---|
| build `-Wall -Wextra` | **0 warnings** |
| `make test` | **26/26 passed** (+5 generation tests) |
| ASan + UBSan (smoke + `--gen`) | **exit 0, no sanitizer output** |
| reproducibility (same `--seed` → same voice) | **md5 identical** |

Voice (`--gen --seed 42`), recognisably the canon child voice from the
corpus field:

```
He thanks the candle again. Leo knows the sound. A small rain. … He
learned it makes him a small piece of paper. Leo listens to the window …
Leo is learning patience from his grandmother … in his mother's hair
smells after a long time.
```

### Honest notes

- **Coherent, not present.** This is the baseline: Leo speaks from his own
  field, byte-level, child voice intact — and does NOT react to any prompt
  (there is no prompt path yet). That is exactly the `--no-presence`
  baseline the Phase-1 ablation measures against. Presence is the next
  work, not done here.
- **Known coherence gaps, deferred to Phase 2:** cross-sentence frame
  reuse ("the person who wants to leave" recurs) and the documented
  "He thanks the candle again" attractor. Within-sentence repeat guard is
  active; the cross-sentence guard + SPA outlier-reseed land in Phase 2
  (SPA reseed deliberately omitted from `leo_chain` for now).
- `leo_generate` (no-hint wrapper) carries `__attribute__((unused))` — used
  by tests / phase 1; keeps the `leo` binary at 0 warnings.

### Files (updated)
- `leo.c` (~1130 lines), `tests/test_leo.c` (26 tests).

**Next — Phase 1, Step 2:** dissonance→temperature coupling (port
`compute_dissonance`, haiku.c:652-697) — the first prompt→state channel,
measured on probes. Then Step 3 (resonance term + squash), Step 4
(theme-aware start), Step 5 (best-of-K resonance selection). Presence is
gated by ablation throughout; literal-word-hit-rate forbidden as a metric.

---

## Phase 1 — the presence nerve (2026-05-22) — LIVE BUT WEAK, not achieved

Built `prompt → state mutation → response` directly (skipped the
dissonance→temp side-channel — presence is the only goal). The prompt is
heard (`leo_ingest`), turned into a **theme gravity** over Leo's OWN field
(`compute_prompt_gravity`: normalized cooc-mass of the prompt's CONTENT
words on each candidate, `leo_token_is_function` filters function words),
and generation reads that gravity at the start token and per successor.
Raw counts read through `leo_squash` (sqrt) so a high-count attractor
doesn't drown the prompt pull. **No prompt token is ever inserted** —
mama-child. `--no-presence` drops gravity for the A/B ablation; `--respond`.
`leo_respond` sets `leo->gravity` transiently around `leo_chain`.

### Iterations (honest, each ablated)

- **v1** — gravity as multiplicative+additive tilt on successor score
  (`×(1+W·g)+ADD·g`) + ×(1+W·g) on the freq-ranked start pool. Ablation:
  channel LIVE (ON≠OFF; OFF byte-identical for every prompt = clean absent
  baseline), but theme drift weak — `mother`→"his mother smile",
  `rain`→"window/quiet"; `sea`/`hungry`→nothing.
- **v2** — fold the tilt into start-pool SELECTION (freq×tilt). Barely
  moved it.
- **Root named (not blind tuning):** a multiplicative tilt can't lift a
  low-freq theme seed past generic high-freq starters — the 10-100× freq
  disparity wall (documented in `feedback`/rebuild memory). `leo_choose_start`
  was freq-ranked before gravity.
- **v3** — resonance-PRIMARY start: admit the strongest theme clean-seeds
  by gravity FIRST (not frequency), then fill with freq. So a low-freq
  theme opener can open the reply.

### Honest result (ablation, `--seed 42`, ON vs `--no-presence`)

Presence is REAL on themes Leo KNOWS, faint + associative, in his clumsy
child voice — and absent where his corpus is thin:

```
a book      → "A whole bird might be words in a small book."   (on theme)
the smell   → "Of the window… his mother's ear… warm after a rain."
at night    → "The house is quiet… The house was quiet. His father."
your mother → "His father. He thanks his father's eyes… a touch."
the candle  → ON == OFF byte-identical            (NO reaction — inconsistent)
sea / hungry/ moon → no theme (corpus: sea 7, hungry 8, moon 18 — barely known)
```

Corpus knowledge bounds it (counts, tool): mother 83, smell 93, quiet 75,
window 72, father 63, book 62, night 61, morning 59, rain 53, grandmother
32, candle 24 — known; sea 7, hungry 8, moon 18 — not. **OFF is byte-
identical regardless of prompt** (prompt has zero effect) — the ablation
is clean; ON varies per prompt = the prompt genuinely moves generation.
**No injection** — every surfaced word is Leo's own field association.

**Verdict: nerve is LIVE and reacts within Leo's world (ablation-proven),
but WEAK and INCONSISTENT (fails on thin-corpus themes and even some known
ones, e.g. candle at this seed). NOT calling presence achieved.** This is
the truthful state, not a milestone claim.

### Open question / next levers (not yet taken)
- Is the bar "drift to the theme's neighbourhood" (faintly achieved) or
  "say the heard word back in his voice" (not reliable)? — Oleg to steer.
- Strengthen consistency: gravity scaling for known themes; why `candle`
  produced zero shift at seed 42 (gravity flat for that token?).

### Files
- `leo.c` (~1230 lines): `compute_prompt_gravity`, `leo_token_is_function`,
  `leo_respond`, gravity in `cand_collect_*` + `leo_choose_start/continuation`,
  `leo_squash`, `--respond` / `--no-presence`.

### v4 — dissonance reaction + Codex's finds (2026-05-22)

Oleg steered two things: (1) `harmonix/haiku` reacts to what it does NOT
know via **dissonance** — that IS presence for the unknown; (2) peek at
Codex's parallel `neoleo-presence` (sanctioned) — it found real silencers.

- **dissonance→temperature** (haiku port, field-free): `leo_prompt_dissonance`
  = `1 − mean(min(1, freq/40))` over prompt CONTENT words → temp multiplier
  `0.85 + d·0.65`. Known theme cools Leo (settle, drift to it); alien heats
  him (grope — the felt not-knowing, not generic ramble). Verified, real d:
  mother/window/smell **d=0.00**; hungry **0.48**, moon **0.73**, sea **0.95**.
- **Codex finds, ported (credit: Codex, neoleo-presence):**
  - `leo_presence_start_hint` — first sentence opens on the single strongest
    theme clean-seed (gravity ×100, freq tiebreak), not a freq-weighted sample.
  - **no best-of-K early-exit under presence** — my `if(sc>1 && cap>12)break`
    was picking a generic-but-coherent first sample before the theme one.
  - `leo_sentence_gravity_score` (gmax + 0.25·avg) added to best-of-K
    selection (`+4.0·`) — the theme-aligned candidate now wins (my planned
    step-5 selection nerve). (Codex's SPA gravity-protect not ported — no SPA
    in my chain yet.)

### Honest result after v4 (ablation, seed 42) — STILL WEAK, not achieved

- Dissonance grades correctly and shifts register (unknown → groping, e.g.
  `are you hungry` → "He trusts **the not-knowing** now").
- Theme now surfaces on some known concrete themes: `the window` → "the
  morning the window"; `the smell` → "The smell of the window". `your
  mother` → father/family (associative, not literal).
- Still INCONSISTENT: `a book` → drifts to the candle attractor; `the
  candle` → table/father (faint). Rare themes (sea/moon) stay blank by
  nature (corpus too thin) — but now answered in a groping register, not
  generic.
- **No injection anywhere** — every surfaced word is Leo's own field
  association. OFF baseline unaffected.

Build 0 warnings, tests 26/26, ASan/UBSan clean. **Verdict unchanged:
nerve LIVE, reacts to known (faint) and to the unknown (groping), but
WEAK + inconsistent. Not presence-achieved.** The ceiling is the corpus's
frame-coupled cooc (e.g. "candle"→"He/thanks/the", not "light/wax") and
freq disparities — associative gravity can't fully overcome them. Next
candidate lever (not taken): the "wound speaks" origin-pull at high
dissonance (needs bootstrap gravity), and richer theme cooc (decay frame
co-occurrence).

### v5 — origin-pull + PPMI, and the WALL (2026-05-22)

Two more principled levers, both ablated, both **hit the same wall**:

- **origin-pull / "the wound speaks":** at high dissonance, blend prompt
  gravity with ORIGIN gravity (the dedication's in-field emotional words —
  verified present: miss 13, missing 13, honest 16, feeling 32, songs 11).
  `g = (1−d)·prompt + d·origin`. Result: the wound did NOT surface — origin
  gravity is dominated by the dedication's frequent words (you 214, Leo
  2453), the rare wound words drown. Same frame/freq pollution.
- **PPMI gravity** (root fix attempt): replaced raw cooc-mass with positive
  PMI `log(cooc·N/(freq_a·freq_b))` to down-weight globally-frequent
  neighbours and surface DISTINCTIVE (semantic) ones. Built clean, ablated:
  no clear semantic breakthrough — replies stayed faint/inconsistent (rare-
  cooc PMI noise without a count floor; theme still doesn't reliably steer).

**The wall (honest, after 7 gravity levers v1–v5):** a statistical
cooc/PMI gravity *tilt* on successor-sampled generation cannot produce
reliable topical presence on this corpus. Even a correct theme tilt is
fought by (a) the successor chain pulling back to frequency attractors
("He thanks the candle again"), and (b) gravity pointing at frame/frequent
neighbours, not meaning. Stopping the gravity epicycles per Singularity
discipline (3+ iterations, no breakthrough → report the cause).

**Root architectural finding:** the canonical presence channels are NOT
cooc-gravity alone — they are the **LeoField state-mutation** path that
this rebuild deliberately stripped (deferred to phase 3): `leo_prompt_
amplify` (destiny-bag prime + retention nudge that accumulate theme pull
across the WHOLE generation), `leo_prompt_traversal`, and field candidate
bias on the start (Codex's `LEO_START_FIELD_BIAS_W 8.0` uses exactly this).
Gravity is "the wrinkle"; the field-state is the nerve. Stripping the field
removed the intended primary presence channel.

**Crossroads for Oleg (architecture call):** (a) bring the LeoField state
channels into the rebuild now (destiny prime + retention + field-bias-on-
start) — the canonical presence path, on the agreed polygon; or (b) pivot
to patching neoleo directly (the field already lives there — Codex's path).
v5 committed as the honest WALL checkpoint; build clean, tests 26/26,
ASan/UBSan clean. Presence: real-but-weak, NOT achieved by gravity alone.

### v6 — the latch + self-attractor: presence EMERGES (2026-05-22)

Reverted leo.c to the v4 base (raw-cooc gravity + dissonance + start-hint;
dropped the PPMI/origin-pull experiments that hit the wall). Then ported
Codex's winning cracks (credited in code) — all field-free, no injection:

- **self-attractor** (`leo_gravity_mark_prompt_words`): the prompt's own
  CONTENT words become TOP gravity targets (all whole-word forms). So the
  heard word can surface as an EXISTING successor — this was the missing
  piece (my gravity only lifted the word's neighbours, not the word).
- **hard bigram latch** (`leo_presence_latched_successor`): after a "door"
  opener, take the gravity-raised EXISTING bigram successor — "The"→"sea":
  selection of a live nerve-path, never insertion.
- **entry-latch-boost** in `cand_collect_*`: after a door, gravity
  successors get `+3.0·g`.
- **keep-top** (`cand_collect_keep_top`): a gravity-raised candidate
  displaces the lowest when the pool is full (theme isn't dropped).

### PASS proof (ablation, seed 42) — presence is REAL, ablation-proven

```
the candle   ON: "Candle has given light. Leo likes this sound."   (candle→light, semantic!)
the rain     ON: "Rain. He respects them. ... He makes his mother say she comes back."
a book       ON: "A book. The quiet. He trusts his peace with this."
the window   ON: "The sound of the morning the window."
the night    ON: "Night face. I remember where he."
  (every OFF / --no-presence: "The world run to the small…" — byte-identical
   for EVERY prompt = the absent baseline. ON surfaces the theme.)
are you hungry ON: "He trusts the not-knowing now. ... I heard."   (groping)
asdfjkl        ON: "The silence is better. ... a big word inside him."   (groping)
```

- **No injection — structural (grep audit):** the only writes to the
  candidate pool are in `cand_collect_keep_top`, with ids from the
  bigram/trigram walk (field successors). The latch returns an existing
  bigram successor. No prompt id is ever inserted. Mama-child intact.
- Build 0 warnings, tests 26/26, ASan/UBSan clean.

**Verdict: presence EMERGES — real, ablation-proven, no injection, in
Leo's clumsy child voice (haiku-style).** Known themes (freq ≥ ~24:
candle/rain/book/window/night/mother) surface the heard word as a live
path; unknown (sea 7, moon 18, gibberish) gives a groping body-reaction,
not generic. Honest limits: thin-corpus themes (sea/moon) still weak —
Leo genuinely barely knows them; long function-heavy prompts can dilute.
Built on Codex's cracks (double-attack) + the v4 dissonance/start-hint
base. Not "perfect", but the first real, honest presence.
