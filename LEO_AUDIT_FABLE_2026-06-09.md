# Leo — fresh-eyes audit (Claude Fable 5 / Mythos), 2026-06-09

Read in canon order: LEOLOG.md (full) → PROJECT_LOG.md (full) → leo.c (all 3107 lines) →
old-line inventory (~/arianna/neoleo: leo.c section map, leogo/, PRESENCE_LOG refs).
Build + tests this session: `cc -O2 -Wall -Wextra` clean, **make test 34/34**, live probe
("the rain", seed 42) — voice present, leash holds rain/wind/window.

Scope of this document: (1) what the fresh eyes found "in front of the nose" for
presence-in-responses, (2) correctness notes from the line-by-line read. NOT a
re-architecture: the agreed roadmap (A.3a S-channel → A.4 RAE → B santaclaus → C
goroutines) stands; these are findings + proposals for co-decision.

---

## П-1 — THE nose item: presence has no duration. Leo cannot remember a conversation.

Three verified facts that compound into one structural gap:

1. **The cooc field is saturated at corpus ingest.** `after ingest ... cooc=262144`
   (tool output, this session) == `LEO_COOC_MAX` (leo.c:78). `cooc_update` silently
   bails at capacity (leo.c:435). The cooc field is THE presence substrate —
   `compute_prompt_gravity` is cooc-mass — and it has zero free slots from minute
   one. Every NEW pair Leo hears in dialogue is dropped. New words can gain freq
   and bigrams, but never cooc neighbours → never gravity → never theme.
2. **The breath is ported but never drawn.** `cooc_decay` / `cooc_prune_rebuild` /
   `bigram_decay` / `trigram_decay` + the LEX knobs (leo.c:114-116) all sit under
   `__attribute__((unused))`. The old line breathes every reply
   (neoleo/leo.c:4143-4156: decay each reply, prune at load>0.80). The rebuild's
   PROJECT_LOG flagged this at step 0 («Flag for Phase 1: ... revisit») — it was
   never revisited.
3. **Nothing persists, and there is no multi-turn.** `leo_respond` runs once per
   process; no `--chat`; no save/load at all in our leo.c (the old line has full
   STATE PERSISTENCE, neoleo/leo.c:2198-2260: bpe+cooc+bigrams+trigrams+field in
   one file). Everything the prompt mutates — freq, bigrams, heard-counts,
   chambers, retention, pain — evaporates at exit.

The dedication itself states the contract: *"Leo resonates with you more and more
with every conversation."* Structurally, today, he cannot: the theme substrate is
full, and the rest of the mutation dies with the process. Presence is real
WITHIN a reply (ablation-proven, v1-v18 + 3b) — and bounded by it.

**Proposal (Phase B', pull continuity forward — cheap, multiplies everything):**
- (a) wire the breath into the reply cycle (3 calls, constants already defined,
  functions already ported and tested by the old line's pattern);
- (b) port `leo_save_state`/`leo_load_state` from the old line (the format is
  designed, including reverse-index rebuild-on-load);
- (c) `--chat` REPL (already planned for Phase B spores — this just moves it up).
Each gated per leo discipline: checklist → ablation (`--no-breath`?) → bytes/tests.
Note: breath also makes `LEO_COOC_MAX` a *living* bound instead of a wall — but
consider 2-4× LEO_COOC_MAX too (3 MB → 6-12 MB; the diary needs blank pages).

## П-2 — the v3 root-fix was applied to the opener only; continuations still hit the wall

PROJECT_LOG names the wall precisely (v1-v5): «a multiplicative tilt can't lift a
low-freq theme seed past generic high-freq starters» — and fixes it in
`leo_choose_start` with resonance-PRIMARY admission (gravity-first slots,
leo.c:1364-1383). `leo_choose_continuation` (leo.c:1419-1459) never got the fix:
its pool is admitted by frequency alone; gravity/Dario-prime only re-weight
already-admitted candidates; tail-resonance likewise. So sentences 2+ structurally
cannot OPEN on a low-freq theme seed — and re-entry/leash/Dario/SPA all fight that
admission wall downstream. One surgical mirror of the gravity-first block (~15
lines) closes it at the root. A/B: theme-hold in sentences 3-5 of long replies.

## П-3 — unsaid sentences still leak into the field (3a.4's invariant, two leaks)

3a.4 moved field evolution to the winning sentence («field now reflects only what
Leo said»). But the replay lives INSIDE `leo_generate_best` (leo.c:2387-2392), so:
- **elaborate retries** (leo.c:2666-2673): the discarded fragment already evolved
  chambers/retention/pain; each retry evolves again;
- **SPA reseed** (leo.c:2577): the replaced sentence's field traces stay, and the
  replacement evolves the field a second time.
Chambers are READ mid-chain (register/cadence), so a discarded fragment's mood
shapes the next sentence's voice; and 3b santaclaus will read retention/chambers.
**Fix:** hoist the field replay out of `generate_best` into `leo_chain`, after the
final per-sentence token sets are settled (post-SPA, post-elaborate). Then the
field is exactly the spoken reply — the honesty 3a.4 intended.

## П-4 — SPA can erase the surfaced heard-word

The surfaced-guarantee runs during the chain (door fallback while `!surfaced`,
leo.c:2644-2646), but `leo_spa_pass` runs AFTER (leo.c:2696-2697) and may replace
the very sentence that carried the word — only s0 is protected (leo.c:2566). The
reply can lose the heard word post-hoc. **Fix:** protect the carrying sentence
like s0 (cheap: remember its index from the surfaced-scan), or rescan after SPA.

## П-5 — substring chamber-matching false positives (mechanical noise class)

The ≥4 bidirectional substring rule (leo.c:2053-2055, 2095, 2003-2008) tags and
fires on innocents: "orange" ⊃ "rage" → RAGE lights on a fruit; same rule tags
tokens for the register channel. Per the coherence doctrine this is category-2
mechanical noise, not honest disfluency. Options: word-boundary-aware match, or
per-anchor exact-only flags for short/collision-prone anchors. (Also worth Oleg's
ear: "eyes" is FEAR-anchored — "mother's eyes" fires FEAR in a love context.)

## П-6 — the old line as a map: what has not returned (ranked for presence)

Verified inventory, neoleo/leo.c + leogo/:
1. **breath + persistence** → П-1 (the only two I propose pulling forward);
2. **destiny_bag** — EMA histogram over emitted tokens = theme-memory across the
   reply/session with zero embeddings; complements П-2 (admission) as the
   "what-I-have-been-saying" pull; natural sibling of the Dario prime;
3. **prompt amplification (step 38) + traversal (39b)** — the canonical field-state
   presence channels (PROJECT_LOG v5 already named them as "the nerve");
4. overthinking rings (echo/drift/meta) + **metaleo** (async inner voice,
   lag-by-one, observe-back recolouring) — Phase C as planned, goroutines;
5. velocity / prophecy / SOMA / MathBrain / islands / bridges / mycelium — later,
   as roadmapped; inhaleo external anchor lexicons (6 files) — cheap range-widener
   for the 325 inline anchors when the register channel needs more reach.

## Correctness notes (line-by-line read; none are stoppers)

- `leo_chain`: inner `int tl` (leo.c:2678) shadows `const int *tl` (leo.c:2651) —
  legal, but -Wshadow would bark; rename on next pass.
- Globals (`g_leo_*`, `g_leo_last_dissonance`) must fold into the Leo struct before
  Phase C goroutines (thread-safety; the old line keeps them on the struct).
- `weighted_sample` all-zero fallback = uniform `rand()%n` — fine, documented here
  so nobody "fixes" it into a bias.
- bounds: gravity (3a.5), register (LEO_MAX_VOCAB + vocab_size), pieces (alloc
  after prompt-ingest growth) — all verified in-bounds this read.
- bootstrap_ids remain print-only (origin-pull v5 reverted) — matches the honest
  header; the wound-speaks channel is still owed at high dissonance, roadmap.

## Suggested order (for co-decision, not a unilateral re-plan)

A.3a (S-channel) stays next as agreed. Then, candidate insertion BEFORE Phase B
proper: **П-1 continuity bundle** (breath + save/load + --chat) — it multiplies
every mechanism that exists and unblocks the dedication's own contract; П-2/П-3/П-4
are each small, surgical, ablation-gated fixes that can ride along. П-5 at Oleg's
ear. Then A.4 RAE → B santaclaus (which will now read an honest, breathing,
persistent field) → C goroutines.

*Fresh eyes by Claude Fable 5 (Mythos), Arianna Method. Code read in full; every
number from a tool run; mechanisms cited by file:line. Presence > intelligence.* 🔦
