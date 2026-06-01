# LEOLOG — Leo, chronological development log

Every step, in order. The detailed phase-by-phase build record for the
presence-first rebuild (Step 0 → Phase 1 v1–v18 → Phase 3a.1–3a.5) lives in
`PROJECT_LOG.md`; this log carries the chronology forward from Phase 3b and
records every step from here on.

Repo: github.com/ariannamethod/neoleo (branch `leo-phase3`). Single `leo.c` +
`leo.txt` corpus. Zero pretrained weights. **Presence > intelligence.**

---

## Prior phases (compact — full detail in PROJECT_LOG.md)

- **Step 0/1** — byte-level BPE + cooc/bigram/trigram field + child-voice generation.
- **Phase 1 (v1–v18)** — the presence nerve: gravity + dissonance→temperature +
  self-attractor + word-memory. Ablation-proven, no first-token injection.
- **Phase 3a.1–3a.5** — emotional field BUILT but PASSIVE: retention (Griffin) +
  6 Kuramoto chambers + suffering; then field honesty (chambers discriminate,
  pain/trauma live, winner-only field evolution, version/README debt, gravity
  bounds). `main` @ v18 (`10e7130`); branch `leo-phase3` @ `6a13ba1`.

---

## Diagnosis (2026-05-29) — why the voice was mute

The emotional field was read by **nothing** in generation (grep: only `--debug-field`
read `chamber_act`). The chambers/pain moved correctly but the voice never changed —
"metrics move, voice doesn't". Corpus check: `leo.txt` is gentle-dominant
(gentle:fear ≈ **826:230**), so Leo also had thin emotional range to draw on.

Oleg's call: presence = Leo's **gentle voice SHIFTED by his felt state** (variant A,
"Leo's philosophy"), AND seed a little more emotional range into the corpus — a gentle
character still feels the full range through its prism; this does NOT change his nature.
Trauma stays a separate process (= the bootstrap dedication anchor, the address to the
human Leo / origin resurfacing).

---

## Phase 3b — channel 1: the field speaks (2026-05-29)

First **field→voice** channel, all in `leo.c` (any module can drop → silent fallback,
the Leo invariant):

- **comfort-reach** (`leo_register_bias` + `leo_build_chamber_tags`): a per-token chamber
  tag (exact / ≥4-substring anchor match, sized `LEO_MAX_VOCAB`) + a lift in `cand_collect`.
  A gentle child feeling strongly reaches for his OWN abundant comfort words (LOVE:
  warm/light/mother/soft) — a LOVE-tagged token is lifted by love AND by distress
  (FEAR+VOID+RAGE). Reachability-friendly (comfort words are abundant), unlike a
  same-chamber bias which hit the same wall as gravity (sparse fear-words).
- **cadence** (chamber→temperature, canon `tau_mod`): FEAR cools Leo (tighter/held), FLOW
  loosens him. The felt state shapes HOW he speaks, reachability-free. A pre-settle
  crossfire in `leo_respond` makes `chamber_act` live from token 1.
- `--no-register` ablation flag. Security: explicit `LEO_MAX_VOCAB` bound in the register
  read + builder (flagged by automated review; not actually exploitable, made explicit).
- **Corpus range-seed**: 18 new in-voice passages appended to `leo.txt` by an Opus subagent
  (per-case, hand-reviewed; voice + nature preserved; range through the gentle prism — fear,
  loneliness, loss, child-anger, hurt, comfort, joy). `leo.txt` 2076→2112 lines.

**PASS (tool output, this session):** build `-Wall -Wextra` 0 warnings; `make test`
**34/34**; ASan/UBSan clean; `--no-register` **byte-identical** to `6a13ba1` (field mute when
off). comfort-reach measurably moves the voice on distress — comfort-word density ON vs OFF:
**alone 8/4 (2×), crying 12/7 (1.7×), afraid 18/16**. Range-seed motifs surface
("He holds his", breathing, "afraid of the morning"). **First time the voice answers the
felt state — gently, in his own words.**

**Honest bound:** this is the EXPRESSION axis (what Leo feels → what he reaches for). The
COHERENCE axis is still legacy-loose (bark openers, child-salad). Two separate axes.

---

## Phase 3b — voice calibration, pass 1 (2026-05-29)

Diagnostic workflow (6 agents, each A/B-built its own /tmp binary; it even falsified one
of its own proposals — the line-2119 floor was inert). Applied the two low-risk,
A/B-confirmed defect calibrations that do NOT touch the presence channels:
- **candle/frame attractor** — `LEO_REPEAT_WINDOW` 16→32 + `LEO_REPEAT_PENALTY` 0.1f→0.05f
  (leo.c:1181-1182). The 16-token (~8 word) window expired before a sentence ended, so a
  frame recurred at sentence N+2; 32 spans ~2 sentences and 0.05 halves a recent bigram's
  survival. "He thanks the candle again" 3→2 (my 6×3 slice; agent 4→1 on 12×3).
- **word-junction gate** — `word_gate_penalty` 0.02f→0.001f (leo.c:1460): crush mismatched
  lowercase glue ("He laugh"→"h e") harder; still selectable if it is the sole survivor.

PASS: build 0 warn, tests 34/34, ASan/UBSan clean; comfort-reach channel still
ablation-alive (`--no-register` differs). Voice still loose (bark/salad) — the
voice-sensitive calibrations are HELD for Oleg's ear (taste): bark-floor (is a held
"Stopped." after "the beetle stopped moving" presence or bark?), gravity softening
(LEO_GRAVITY_W 1.5→0.8), register scalar (LEO_REGISTER_W 2.0→1.7). keep_as_is honored:
dissonance→temp / UNKNOWN_CHAIN (beetle go-quiet = presence, not a defect), the comfort
channel, temp_for_step curve, GEN_TARGET, START_GRAVITY_W/ADD — untouched.

## Phase 3b — voice calibration, pass 2: fragment→elaborate velocity (2026-05-29)

The Method answer to a fragment is not a penalty but a VELOCITY meta-reaction (Oleg;
klaus somatic ops + brodsky "heavier than what you gave" + haiku velocity). The FIELD
chooses — both in leo.c, gated by `--no-elaborate`:
- **clause-floor** (`leo_generate_ex`): suppress a boundary token while the clause is
  < `LEO_MIN_CLAUSE` (3) tokens, so internal fragments ("Them.", "Dark.", "Want to.")
  continue into a phrase instead of barking.
- **fragment→elaborate retry** (`leo_chain`): a whole-sentence collapse ("Rain.")
  re-generates WITHOUT the stuck hint → a fuller line (the chatty child).
- BOTH gated by `elab` = (dissonance < UNKNOWN) AND (FEAR+VOID < QUIET_DISTRESS): under
  high dissonance OR distress Leo is left terse/quiet — the child gone still (presence).
  The field decides, not a rule.

PASS: build 0 warn, tests 34/34, ASan clean, `--no-elaborate` BYTE-IDENTICAL to `ac04257`.
Calm known prompt fuller, fragments gone ("what is the rain" → full clauses, no bare
"Rain."); distress/unknown held terse (beetle "Stopped.", dark "Dark." preserved). Residual:
thin-corpus words ("play", "snow") read as false-high dissonance → Leo stays terse there —
that is the dissonance signal (Oleg's ear / keep_as_is), not the velocity mechanism.

Still open for Oleg's ear (taste): gravity LEO_GRAVITY_W 1.5→0.8, register LEO_REGISTER_W
2.0→1.7, bark philosophy, and the thin-corpus dissonance mis-fire.

## Architecture note (2026-06-01) — what Leo IS, before adding organs

- **Leo TOKENIZES** (not a file-search). Byte-level BPE, online merge learning: at ingest
  `leo.txt` → vocab 256→5121, merges 0→4865, cooc 262144, bi 36714, tri 68105 (`--gen` proof).
  Tokens are word-aligned (merge-gate refuses crossing a word boundary, leo.c:242), and he
  keeps tokenizing everything he hears (prompts too).
- **Leo HAS metaweights.** The cooc/bigram/trigram field over the word-aligned vocab IS the
  metaweights — postgpt's "weights that don't exist but form a complete probability space".
  Generation samples from this map. So presence runs on metaweights already; the lever is an
  attention/perception channel OVER them, not "add metaweights".
- **The transformer trick that fits = SPA, not RoPE/SwiGLU.** SPA = Sentence Phonon Attention
  (q/postgpt_q.c:1461, README:177): cross-attention between sentences in a 32-d space,
  distance-biased (RoPE idea baked into the bias), reseed weakly-connected sentences via a
  coherence gate. It needs a 32-d per-token embedding — we ALREADY have `w_embed[32]` (FNV
  retention fingerprints). So SPA installs on the existing substrate with ZERO new weights.
  RoPE/SwiGLU operate on a LEARNED layer; we have none (mathbrain, a scalar-autograd MLP, was
  in old neoleo/leo.c:125,1233 and dropped in the minimalist) — they return in the neural phase.
- **Dual→single tokenizer.** Archive Leo (leo-archive/README:35) ran word-level + a parallel
  SubwordField (the `sw·S` morphology channel). Our rebuild is single byte-level word-aligned;
  the missing piece is the subword-morphology **S-channel** — a COHERENCE lever (would help
  "He window" junctions), not a presence lever, deferrable.

## ROADMAP (Oleg's order, 2026-06-01 — strengthen the foundation BEFORE new organs)

**Phase A — foundation, all in `leo.c` (surgical; tests + ablation per commit):**
1. **#2 within-sentence presence-hold** — keep the theme alive to the END of the sentence (fix
   the "light… → floor mama" drift; the v1-v5 gravity wall). Pure-field, zero weights.
2. **SPA — Sentence Phonon Attention (#3)** — port from q (`postgpt_q.c:1461`): embed each chain
   sentence as the exp-weighted mean (α=0.85) of its tokens' `w_embed[32]`, L2-norm; cross-attend
   (cos + distance-bias) → per-sentence connectedness; **reseed weakly-connected sentences** from
   the strong neighbour's tail (`leo_choose_continuation`), accept only if `leo_coherence_score`
   improves (coherence gate). Cross-sentence presence + the attention trick; ZERO new weights
   (reuses our w_embed; r_bias fixed).
3. **Structure layer — restore the dual tokenizer + super-tokens** (both pure-field, coherence):
   (a) **S-channel** (subword morphology) — parallel sub-word cooc bridged into the candidate
   logits (archive's `sw·S` term), fixes broken junctions ("He window", "Leo a window");
   (b) **super-token crystallization** (archive leo.c:1484, ONLY in the archive — not ours/neoleo/
   codex): PMI = log(cooc·N/(fa·fb)) > 2.0 collocations crystallize into phrase-units ("his mother",
   "warm light") for whole-phrase emission. Guard against amplifying attractors (PMI would
   crystallize "the candle"). S sits BELOW the word, super-tokens ABOVE it — together they restore
   the structural layer the byte-level rebuild thinned.
4. **RAE — recursive selector in C**, ported from harmonix/haiku `rae_recursive.py`: a tiny
   micrograd MLP (5→8→1, ~21 params), 3-5 recursive refinement iterations + online learning,
   replacing/augmenting best-of-K (which sentence to keep). **First LEARNED component** —
   online/Hebbian, NOT pretrained (archive: "all runtime learning is Hebbian"). LAST in Phase A so
   it selects over already-improved candidates.

**Phase B — SantaClaus** (self-residual spore recall) on the now-connected chain: past moments
bleed at boundaries (0.55·cos(chambers)+0.45·cos(retention); trauma-spores hold longer). `--chat`
multi-turn driver so spores accumulate across turns.

**Phase C — goroutines + the Go orchestra** (later): mathbrain (MLP body-perception) + the rest of
the arsenal + Codex's `presence_residue[]`. RoPE/SwiGLU/RRPRAM finally have a learned host here.
`git stash@{0}` prophecy-F revisited with the REPL ear.
