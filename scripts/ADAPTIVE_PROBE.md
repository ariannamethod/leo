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

The API and frozen-replay lanes do not adapt moves to Leo's answers; they are
baselines. `local-v1` is genuinely adaptive within its nine predeclared phases,
but only through the narrow visible sensors above. Selecting a move from shadow
diagnostics would leak the judge into the stimulus, while sending Leo's private
dialogue to an external API remains outside this protocol.
