# Transcript-blind interlocutor probe

This probe runs one real Leo process per turn. Every turn ends with a state
save and process exit; every later turn must load that exact state. An OpenAI
Responses API model realizes a fixed sequence of epistemic moves as short
human utterances, but receives no Leo transcript, state, diagnostics, shadow
proposal, calibration verdict, or prior model utterance.

The API request contains only:

- the current move description;
- one fixed synthetic target word;
- fixed sensory anchors;
- the turn number.

Run it with a key stored in a local file:

```sh
OPENAI_API_KEY_FILE=/path/to/key \
LEO_INTERLOCUTOR_MODEL=gpt-5.6-luna \
make adaptive-probe
```

Optional controls are `LEO_ADAPTIVE_SEED`, `LEO_ADAPTIVE_TARGET`,
`LEO_ADAPTIVE_ANCHOR_A`, `LEO_ADAPTIVE_ANCHOR_B`, `LEO_ADAPTIVE_TERMS_A`,
`LEO_ADAPTIVE_TERMS_B`, and `LEO_ADAPTIVE_ANCHORS`. The legacy warm/cool
anchor names remain aliases. Default anchors are corpus-familiar `warm light`
and `cool rain`; unfamiliar protocol vocabulary can become a competing Wonder
target and confound the intended experiment. The output directory is always
required to be new.
It retains exact API requests and responses, visible dialogue, raw local Leo
logs, process/session identities, causal receipts, sleep-crossing receipts,
and a manifest. Requests set `store: false`. The key itself is loaded through
a mode-600 temporary curl config, never placed in argv or an output artifact.

`target_named` in `sessions.tsv` is measured locally with a literal
case-insensitive word-boundary check. `target_named_reported` preserves the
model's schema-constrained self-report as a claim, not proof.

To isolate Leo's sampling path from interlocutor variation, replay a previously
captured `prompts.txt` without making any API calls:

```sh
LEO_INTERLOCUTOR_REPLAY_FILE=/tmp/first-life/prompts.txt \
LEO_ADAPTIVE_SEED=137 \
scripts/adaptive_life_probe.sh scripts/adaptive_moves.txt /tmp/replay-137
```

The replay must contain exactly one non-command utterance for every move.
`target_named_reported` becomes `not-applicable`, and the local literal
measurement remains available as `target_named`.

Run the predeclared local visible-branch policy without an API key:

```sh
make visible-branch-probe
```

`local-v1` reads only `visible_replies.jsonl`. It can observe a literal
question mark, the fixed target as a whole word, exact reply repetition, and
literal terms assigned to anchor A/B. It cannot read state files, raw diagnostics,
Flow, Wonder, shadow proposals, calibration verdicts, confidence, or future
replies. Before every human turn it writes the selected branch, utterance, and
visible evidence to `policy/turn-NN.json`. The nine available phases and every
branch are fixed in source before the run.

Run the balanced three-target, three-anchor, three-seed rotation:

```sh
make visible-branch-matrix
```

The nine cells form a Latin-square rotation: each novel target meets each
anchor pair exactly once, and each seed sees every anchor pair once. The runner
refuses targets found in the corpus and anchor terms seen fewer than five
times. It retains per-cell lives plus aggregate `matrix.tsv`, `receipts.tsv`,
`sleep_edges.tsv`, and `summary.txt`. `LEO_MATRIX_PLAN_ONLY=1` validates the
stimuli and writes the complete rotation without launching Leo.

Run the matched unnamed-association experiment:

```sh
make visible-resonance-matrix
```

`local-v2-resonance` keeps an observed Wonder question open across three neutral
turns, then returns either anchor A, anchor B, or an unrelated control without
naming the target. Its orthogonal nine-cell design balances target, anchor pair,
and return cue pairwise. `matrix.tsv` preserves the raw calibration verdict and
adds separate columns for whether the question opened before the cue, whether
the target returned on the cue turn, and the external causal interpretation.
An unopened question is reported as `unopened-question`, never counted as a
missed resonance or a quiet control. The raw receipt remains evidence and is
never rewritten by this report.

Every adaptive life also retains `curiosity.tsv`, one transient read-only School
decision per turn: outcome, selected unknown candidate, settled FEAR+VOID
distress, and the effective curiosity gate. An unknown rejected only because
its heard count passed the novelty window remains visible as `deferred` with
that count. The matrix joins only target-naming human turns into
`target_curiosity_trace` and writes the unopened subset to
`unopened_curiosity.tsv`; this exposes why a target did not open without making
the diagnostic a reader, persisting it, or changing a gate.

State v19 carries the active pre-Wonder memory introduced in v18 plus a sparse
contrastive own-field anchor for each withheld birth. `blocked-distress` is the
birth of a withheld question; later exact encounters report
`blocked-deferred` while the body remains unsafe, or `asked-deferred` when the
ordinary gate finally opens. The memory does not make an unrelated prompt
resonate and never lowers the gate. `--no-deferred-wonder` disables both
retention and recovery while leaving ordinary Wonder behavior enabled.

Run the matched recovery matrix:

```sh
make deferred-wonder-matrix
```

The runner first creates one canonical distress-blocked body for each of three
novel targets. It forks that exact saved body across `0`, `2`, and `8` calm
turns, then applies five return geometries: the bare target, a safe target
question, a dangerous target question, a known-word control, and a novel-word
control. A distractor may open only its own Wonder. Any cell that has not yet
asked the target receives one fixed eight-turn recovery dose and one bare
target return; it is never retried until a preferred answer appears.

`matrix.tsv` preserves the primary and follow-up curiosity receipts, body
values, replies, recovery verdict, transcript hash, and life directory.
`ordinary_replies.tsv` is a separate quote-review pool containing only turns
on which no question opened. `summary.txt` aggregates outcomes by calm interval
and cue geometry. `LEO_RECOVERY_PLAN_ONLY=1` writes and validates the complete
45-cell plan without building or running Leo.

Run the lived recovery ecology:

```sh
make deferred-wonder-ecology
```

This second matrix asks whether recovery depends on repeating one comforting
sentence. Six canonical distress-blocked bodies, split into replication and
confirmatory target/seed cohorts, each fork into five predeclared trajectories:
no intervening life, eight repetitions of one safe prompt, eight distinct safe
prompts, eight mundane prompts, or eight sustained-danger prompts. Every
trajectory turn must remain `no-candidate`; a competing Wonder invalidates the
cell rather than being silently grounded.

All cells then receive the identical dangerous target return. A blocked cell
gets exactly one fixed eight-turn `varied-safe` rescue and one final dangerous
return, proving that its question remained recoverable. The case table lives in
`deferred_wonder_ecology_cases.tsv`. The runner retains per-turn receipts,
transcripts, states, hashes, the aggregate matrix, and a trajectory summary.
`LEO_ECOLOGY_PLAN_ONLY=1` validates the complete 30-cell design without running
Leo.

Run the three-question constellation:

```sh
make deferred-wonder-constellation
```

Two three-word bodies are born under distinct hypothesis geometries
(`light/cold`, `dark/animal`, and `fire/anger`), cross eight common varied-safe
turns and process deaths, then fork across all six possible opening orders.
Every opening must use the selected word's original hypotheses and remove only
that pre-Wonder entry. Before grounding it, the next scheduled word returns
once; the occupied Wonder must report `continued` while the waiting inventory
remains byte-for-byte unchanged. Grounding may resolve only the open question.
After all three resolve, literal returns of every learned word must remain
`no-candidate`.

`--debug-field` emits a read-only `[pre-wonder: ...]` inventory receipt with the
current pending word, episode counts, resolved count, and ordered entries with
their block counts and hypotheses. `prewonder_dialogue_report.awk` parses this
surface; generation and cognition have no reader for it. The matrix retains
common birth/life receipts separately from every permutation's receipts,
transcripts, states, hashes, and summary. `LEO_CONSTELLATION_PLAN_ONLY=1`
validates all 12 group/order cells without running Leo.

Run the semantic constellation shadow:

```sh
make deferred-wonder-semantics
```

At a withheld birth, v19 stores eight L2-normalized whole-word coordinates
from Leo's prompt-raised co-occurrence field. Prompt words are excluded, and
inverse-sqrt unigram weighting prevents common attractors from erasing the
birth's identity. On later turns a transient observer compares the current
contrastive constellation with every waiting entry and combines that field
similarity with the entry's two original glyph hypotheses.

The observer names a winner only when glyph evidence is at least `0.75`, the
combined score is at least `0.65`, and the margin is at least `0.20`.
Field-only, one-glyph, and mixed contexts remain `ambiguous`; a literal name is
reported as `literal` and left to the ordinary exact-return School path.
`--no-prewonder-shadow` removes only this receipt.

The checked matrix uses two independent three-question bodies and eight
geometries per body: three semantic returns without names, weak, mixed,
unrelated, literal, and a semantic return for a waiting sibling while another
Wonder is open. Every cell runs from the same saved body with the observer on
and off, then compares the reply and complete persisted state byte-for-byte.
The occupied case is deliberately retained as a boundary receipt: current
School grounds the open question from the sibling's semantic phrase even
though the observer identifies the sibling. A.41 records that attribution
problem; it does not let a diagnostic score alter School.

`--debug-field` emits `[pre-wonder-shadow: ...]` with status, winner, margin,
pending word, and every candidate's `glyph/field/combined/literal` values.
`prewonder_shadow_dialogue_report.awk` is the only parser. The receipt is
transient and has no persisted or cognitive reader.

The API and frozen-replay lanes do not adapt moves to Leo's answers; they are
baselines. `local-v1` is genuinely adaptive within its nine predeclared phases,
but only through the narrow visible sensors above. Selecting a move from shadow
diagnostics would leak the judge into the stimulus, while sending Leo's private
dialogue to an external API remains outside this protocol.
