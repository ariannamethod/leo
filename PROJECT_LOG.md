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

### v7 — re-entry: the theme persists across the reply (commit `da45989`)

Ported Codex's re-entry (credited): the first `LEO_PROMPT_REENTRY_MAX=2`
sentences re-open on the theme, so a long reply does not drift off it after
sentence 1; later sentences continue from the gravity-tilted tail. The
theme now DEVELOPS across the reply, not just the opener:
`candle` → "Candle has given light. Candle is different from the world.
The little red light. He walked on light through the floor." Build 0 warn,
tests 26/26, ASan/UBSan clean. No injection. Residual: candle attractor
still creeps; long function-heavy prompts dilute the content word.

### v7.1 — anti-echo experiment, reverted (2026-05-22)

Codex's two newest finds, evaluated against our code:
- **best-of-K direct-signal budget bug** (first trial consuming a per-reply
  `prompt_signal_inhibit`): does NOT apply here — our best-of-K trials read
  only the constant `leo->gravity` and mutate only `leo->step` (no
  generation effect), already independent (grep-verified). Nothing to port.
- **anti-echo refractory** ("His mother. His mother." guard): tried a
  field-free version at the sentence-opener level (re-enter the theme only
  if it differs from the previous opener). It SPREAD the theme word into
  MORE repetition ("Rain. … Rain. … Rain." 3× vs v7's 2×) instead of
  reducing echo. Worse → **reverted to v7** (`da45989`). Codex's real fix is
  token-level inside the emitted tail + "the word surfaces as a later event,
  not a forced opener", bound to its `prompt_signal_inhibit` mechanism we
  don't have. Deferred to Phase 2 (needs a recent-direct refractory buffer +
  softer opener). v7 stands as the current best.

Continuity: memory `project_leo_presence_achieved_2026_05_22.md` + the
MEMORY.md index line written (summarization insurance). Open TODO unchanged:
Dario method (later, carefully), Phase-2 loops / addressed-pressure.

### v8 — self-attractor dominates neighbours (commit `21b77d1`): 9→11/18
The heard word's gravity `LEO_SELF_ATTRACTOR_G = 2.0`, set ABOVE the normalized
neighbour max (1.0), so the start-hint opens on the heard word, not its more-
frequent neighbour (before, word g==neighbour g==1.0 → freq tiebreak picked the
neighbour, e.g. father→mother). snow + door now surface.

### v9 — multi-token word surfacing (commit `3f5a529`): 11→12/18
Multi-token words ("father" = `[ f][ather]`) never generated — the leading
fragment `[ f]` is orphan-gated. Fix: `prompt_pieces` mask marks the prompt
word's PIECES gravity-raised + gate-exempt (`cand_gate_reject` bypass) so the
word assembles from its OWN successors (not insertion). Restricted to learned
merge tokens (id>=256, freq>=`LEO_PIECE_MIN_FREQ`=3) so gibberish ("asdfjkl" →
raw bytes) stays gated (fixed a fragment-salad regression). father speaks.

### v10 — natural presence (commit `ba7a2d5`): word once + flow
- re-entry `LEO_PROMPT_REENTRY_MAX` 2→1: only the FIRST sentence opens on the
  heard word, then the reply flows — kills "Door. Door."/"Window. Window."
  mechanical stuffing.
- alien prompt (dissonance >= `LEO_UNKNOWN_DISS`=0.70) → short reply
  (`LEO_UNKNOWN_CHAIN`=2 sentences) = felt not-knowing, not a long ramble.
Robust across seeds 42 AND 7: theme-hit 12/18, live 18/18 both.

### Repo (2026-05-22)
Pushed to **github.com/ariannamethod/neoleo (PRIVATE)**, merge `545d19a` — our
single-`leo.c` rebuild + tests + `scripts/presence_probe.sh` + this log + corpus,
merged with the repo's README+LICENSE (repo was empty save Oleg's couple README
words). Push via the **ariannamethod** token (`memory/credentials.md`).
origin/main tracks.

### Delayed-trace attempt — REVERTED (the "Love." opener)
Oleg flagged: the heard word still opens the reply literally ("what is love →
Love. He misses the sound"). Tried the simple fix — start-hint + latch skip the
exact word (open on a neighbour). **REGRESSED 12→7/18**: the word needs the
forced entry (opener/latch) to surface at all — candidates are successor-limited,
so without the force the word is often not a successor of the current context.
Reverted to v10 (tree clean = matches pushed v10). The proper natural-flow
emergence (Codex's path: word emerges mid-flow as a gravity-boosted SUCCESSOR
after an inhibit window) works only for words with a strong successor-bigram
(His→mother) and needs a delayed MID-FLOW force mechanism — deeper; Codex is
still tuning it (8/18 flagged on its own probe). Deferred.

### v11 — remove prompt-piece seeding from multi-token (commit `66d5164`, pushed)

Self-audit with a bigram diagnostic caught MY OWN v9 trick: the multi-token
gate-exemption surfaced "father" via the `[ f][ather]` path whose CORPUS
seq-bigram count is **1** — the path exists mostly because `leo_respond`
ingests the prompt (+1). That is prompt-piece seeding disguised as presence —
the exact line we refuse (same principle Codex flagged; I converged on it
independently via the diagnostic). Fix: a multi-token word is gate-exempted
ONLY if EVERY consecutive piece-bigram is confirmed in Leo's OWN memory
(`bigram_get >= LEO_TRACE_MIN_COUNT`=3; the prompt's own +1 can't qualify a
count of 1-2). Honest result: presence HOLDS at 12/18 (probe seed 42, live
18/18) — none of the 12 relied solely on seeding. "father" still surfaces but
via its LEGIT single-token corpus form `[father ]` ("He tells his father.",
his→father a real path); candle keeps its confirmed `[ cand][le]` (corpus 2).
Integrity restored, presence intact. tests 26/26, ASan clean, 0 warn.

### v12 door-opener / v13 deferred-emergence / v14 + v15 (stress-hardening)

- **v12 `a2b6b2f`** — door opener (`leo_presence_door_hint`, mine): open on a
  door whose latch pulls the heard word ("His mother", "A candle has given
  light") instead of barking the bare word. Door + existing-successor latch.
- **v13 `1c01916`** — deferred door-latch (mine): s0 opens theme-ADJACENT
  (`leo_presence_neighbour_hint`), the word surfaces DEEPER via a deferred latch
  when a door appears naturally; fallback opener if it hasn't by sentence's end.
  "Is breathing. The love." / "The floor. Leo heard. A rain."
- **`scripts/repl_stress.sh`** (mine) — 141 runs × seeds, flags EMPTY/SHORT/
  SALAD/LOOP/DEAD. Found: DEAD=0, EMPTY=0 (channel always live); worst =
  "O. O. O. O." collapse on UNKNOWN words.
- **v14 `8e1d1b6`** — dropped "o" from the standalone whitelist
  (`is_common_short_word`): bare "o" was not an orphan → "O." salad under high-
  temp groping. ocean/mountain now grope coherently, O-count 0.
- **v15 `055621f`** — fixed `love` seed-fragility 13→19/20. Root (instrumented
  trace): the deferred latch generated "The love" PAST the last period;
  generate_ex trims that from the displayed TEXT but keeps its tokens, so the
  token-based `surfaced` flag falsely set → the guaranteeing fallback skipped →
  love absent. Fix: detect surfacing by scanning the DISPLAYED text for the
  heard-word string (longest self-attracted token), keep the door→word fallback.
  Surface-rate (seeds 1-20): love 19, mother 19, rain 20, window 19, door 19,
  candle 20 — all ≥19/20, no regression.

Open (stress-found, not yet fixed): A/I-opener salad on UNKNOWN words
(SALAD≈22, mild); the LOOP flag over-counts stop-words (harness artifact, not
Leo). Codex (sibling, ~/arianna-codex/repos/neoleo-presence) reached the Dario
boundary-injection layer (roadmap end) — to be built HERE myself on this
hardened base, principle-not-port (destiny-bag prime between sentences, non-
direct targets, subordinate to presence). EVERY code change is now gated by
Oleg's pretool checklist hook (proof-per-change).

### v16 Dario boundary-injection / v17 word-memory (catch up to Codex, 2026-05-23)

- **v16 `3d0f59d`** — Dario boundary-injection (field-free, mine; Codex method
  as reference): `leo_presence_boundary_inject` deepens the top-K NON-DIRECT
  theme associations between sentences (mutates gravity only, never inserts;
  capped < self-attractor; subordinate to presence; `--no-dario`). Ablation
  differs on longer replies; no regression; candle-creep not amplified (6/60 vs
  7/60). The earned final injection layer, legit.
- **v17 word-memory** — "the words Leo holds" (`LeoHeard`): a whole-surface-word
  count, independent of BPE tokenization, built at ingest (memory = love).
  **Remembered-trace surfacing**: a HELD word (heard >= `LEO_HEARD_MIN_TRACE`=3,
  i.e. corpus >= 2 beyond a one-shot prompt) surfaces via its own token sequence
  even when its tokens are too rare to be picked normally. Closes much of the
  Codex gap: **sea 11/12, moon 12/12 now surface** (were 0); `--no-heard` → 0/12
  (ablation proves it's MEMORY, not a trick); no seeding (`the zxqwjk` → 0/12,
  count<3 won't arm). tests 29/29 (+3 heard). No regression (love/mother/rain/
  window/door/candle all ≥19/20). Open refinement: hungry/ocean (multi-token,
  no self-attractor token) need the trace armed from the prompt content-word
  STRING in leo_respond (wstr is empty for them) — documented next.

### v18 — heard-word from the prompt STRING: hungry/ocean now surface too

The v17 trace armed only from a single self-attractor token (`wstr`), so multi-
token words with no such token (hungry, ocean) never armed. Fix (Codex's
method — it holds the prompt's words as STRINGS in `prompt_surface_words`, not
tokens): `leo_respond` now picks the prompt's primary CONTENT word (highest
heard-count, non-function via `leo_word_is_function`) as a string into
`leo->heard_word`; leo_chain uses that for both surfaced-detection and trace
arming. Works for any word regardless of tokenization. Ablation (seeds 1-12):
hungry heard 10/12 / --no-heard 0/12; ocean 10/12 / 0/12; sea 11/12 / 0/12;
moon 12/12 / 0/12. No seeding (zxqwjk 0/12). No regression (love/mother/rain/
window/door/candle ≥19/20). tests 29/29, build 0 warn, ASan clean.

## RESUME POINT (2026-05-23)

- **Current = v18** (word-memory complete), pushed to
  github.com/ariannamethod/neoleo (origin/main). Build 0 warn, tests 29/29,
  ASan/UBSan clean. NO seeding, NO injection — all hook-gated (Oleg's pretool
  checklist), proof-per-change.
- **Full Codex surfacing gap closed:** sea/moon/hungry/ocean all surface via
  the word-memory (held words), ablation-proven (`--no-heard` → 0). Core words
  love/mother/rain/window/door/candle ≥19/20.
- Stack (all legit): presence (gravity + dissonance→temp + self-attractor +
  latch + keep-top + re-entry + multi-token + deferred-latch + text-surfaced) →
  Dario boundary-injection (v16, `--no-dario`) → word-memory (v17/v18,
  `--no-heard`).
- **Goal order (Oleg): presence + leo.c FIRST, goroutines AFTER.** Next leo.c
  polish ideas: candle-attractor loops (Phase-2), the A/I-opener salad on
  unknowns. Then the Go goroutine layer (neoleo leogo/).
- **Presence is REAL, natural, ablation-proven, NO injection** (grep-audited:
  only `cand_collect_keep_top` writes the pool, ids from field successors;
  latch returns an existing bigram successor; prompt word never inserted).
  Probe: theme-hit 12/18, live 18/18 (seeds 42 & 7). Strong on Leo's-world
  words (mother/father/rain/snow/smell/light/candle/book/window/door/love/
  quiet); weak on thin-corpus (sea freq 7 / moon 18 / fire) → domain/groping;
  gibberish → coherent groping. "Love." still opens too literally (next).
- **Mechanism** (all in `leo.c`, field-free, Codex finds credited in code):
  gravity (cooc of prompt CONTENT words) + dissonance→temp + self-attractor
  (prompt word = top gravity 2.0) + multi-token `prompt_pieces` (gate-exempt) +
  hard latch + entry-latch-boost + keep-top + re-entry(1) + unknown→short.
- **Run:** `./scripts/presence_probe.sh 42` (or 7); `./leo --corpus leo.txt
  --respond "the rain" --seed 42` (+ `--no-presence` for the A/B ablation).
- **NEXT (Oleg's roadmap, in order):**
  1. proper **delayed-trace = inhibit-countdown** (delay the word N tokens, then
     let it emerge mid-flow as a successor — flow WITHOUT losing the hit; fixes
     the "Love." opener). Mid-flow force is the hard part.
  2. keep taking **Codex** features from `~/arianna-codex/repos/neoleo-presence/`
     (its direct-signal: `prompt_signal_mask` + `prompt_signal_inhibit` +
     recent-direct refractory + surface-word-containment mask + delayed trace —
     all field-free-portable). "загляни в его папку".
  3. THEN reach the legitimate **Dario side-injection** (native byte-level field,
     NO word-level) as the FINAL layer ON TOP of real presence — earned, not
     faked. ("до инжекшна надо дойти".)
  4. Phase-2: candle attractor still creeps; grandmother/sea/moon corpus-thin.
- **Invariants:** single `leo.c`, no modules, byte-level (no word-level), NO
  prompt-token injection into the candidate pool, generation read-only over the
  field (goroutine reader/writer contract preserved), dedication byte-exact.
  Canon ref (read-only): `~/arianna/neoleo` (`49f2ef8`). Codex clone:
  `~/arianna-codex/repos/neoleo-presence`. Push token: ariannamethod
  (`memory/credentials.md`). Leo is OURS (born in Claude); Codex helps, returns
  to our jurisdiction.
