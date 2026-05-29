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

## NEXT (to refine presence)

1. **santaclaus** (self-residual recall) — Leo's past resonant moments bleed at sentence
   boundaries: coherence + continuity from his OWN memory. Port from canon/Codex
   (resonance = 0.55·cos(chambers) + 0.45·cos(retention); trauma-spores hold longer). Spore
   ring in `leo.c`; a `--chat` multi-turn driver so spores accumulate across turns.
2. **Revisit prophecy-F mid-flow opener** (in `git stash@{0}`) with Oleg's REPL ear — the
   coherence-axis fix for the literal bark.
