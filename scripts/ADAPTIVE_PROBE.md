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

Optional controls are `LEO_ADAPTIVE_SEED`, `LEO_ADAPTIVE_TARGET`, and
`LEO_ADAPTIVE_WARM_ANCHOR`, `LEO_ADAPTIVE_COOL_ANCHOR`, and
`LEO_ADAPTIVE_ANCHORS`. The default anchors are corpus-familiar `warm light`
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
literal warm/cool anchor terms. It cannot read state files, raw diagnostics,
Flow, Wonder, shadow proposals, calibration verdicts, confidence, or future
replies. Before every human turn it writes the selected branch, utterance, and
visible evidence to `policy/turn-NN.json`. The nine available phases and every
branch are fixed in source before the run.

The API and frozen-replay lanes do not adapt moves to Leo's answers; they are
baselines. `local-v1` is genuinely adaptive within its nine predeclared phases,
but only through the narrow visible sensors above. Selecting a move from shadow
diagnostics would leak the judge into the stimulus, while sending Leo's private
dialogue to an external API remains outside this protocol.
