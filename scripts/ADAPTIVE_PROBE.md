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

Run the active/waiting turn-attribution matrix:

```sh
make deferred-wonder-attribution
```

A.42 places a narrow address guard immediately before School grounds an
answer. It compares the active Wonder and every waiting pre-Wonder using the
same two-hypothesis glyph coverage as A.41, but does not admit field cosine
into an authoritative decision. The co-occurrence field remains evidence;
it cannot decide which question receives a human lesson.

Adjacency remains the default because Leo's hypotheses are guesses: a human
answer that matches no stored path may be correcting him. Explicitly naming
the active Wonder always permits that correction. A waiting sibling can veto
the active close only when it is named, or when its glyph support is at least
`0.75` and leads both the active question and the next sibling by `0.20`.
The veto does not open, resolve, teach, or speak for the sibling. It only
preserves the current uncertainty.

`--debug-field` emits `[wonder-address: ...]` with the active identity, status,
winner, margin, actual guard and redirect bits, and every candidate's
`glyph/literal/active` tuple. `--no-wonder-attribution` restores the previous
grounding path. The A.41 semantic-shadow matrix passes that ablation
explicitly so its observer-only result remains an isolated historical proof.

The checked matrix grows two independent three-question bodies, opens the
first question, saves it, and forks seven post-sleep turns per body:
semantic and explicit sibling conflicts, active semantic grounding, explicit
active correction, mixed meaning, an unrelated correction, and a sibling
question. Default and ablated runs use the same seed and starting state. All
non-guard cells require complete saved-state equality; guard cells require the
active question to remain unresolved while the ablation reproduces the old
cross-attribution.

Run the explicit address-redirection matrix:

```sh
make deferred-wonder-redirection
```

A.43 gives one narrow meaning to an explicitly named waiting sibling: the human
has changed which unfinished question they are addressing. The current active
question returns to the exact queue slot vacated by that sibling, preserving its
original hypotheses, birth turn, heard count, own-field coordinates, and Wonder
episode. The named sibling then becomes the only School pending question.
Semantic similarity alone can still only guard; it cannot enter this switch.
If both names occur, the active name wins so a human correction remains possible.

State v20 gives the active question a fail-soft provenance tail with the same
record shape as a deferred Wonder. v19 bodies retain their pending question but
receive no invented origin, so explicit switching fails closed to the A.42
guard. A corrupt v20 provenance tail has the same behavior without discarding
the open question or waiting constellation. Address switching can leave several
unresolved Wonder episodes and event-bounded Flow currents, but the current
snapshot identity still selects the single question that has the mouth.

The checked matrix grows the same two independent three-question bodies and
opens slot 1 before every fork. Three explicit slot-2 forms (grounded statement,
bare name, and question) are compared with `--no-wonder-redirection`; a semantic
sibling conflict and a turn naming both active and sibling are negative controls.
The grounded switch additionally sleeps, then returns slot 1 and requires its
original question verbatim. `LEO_REDIRECTION_PLAN_ONLY=1` validates the ten-cell
design without running Leo.

Run the deferred-Wonder return-appetite matrix:

```sh
make deferred-wonder-appetite
```

A.44 observes which waiting question is gathering pressure to return, after the
reply and its Flow snapshot are already history. It remains a shadow organ:
School, generation, routing, and the existing shadow scheduler have no reader
for its receipt. `--no-wonder-appetite` therefore removes only
`[wonder-appetite: ...]`; reply bytes and saved state must remain identical.
A.44 itself has no persistent fields. A.45 introduced state v21 for its
forecast diary; A.48 extends those records in v22 with a birth-time policy
witness
a separate slow calibration diary; the historical A.44 matrix explicitly
ablates that later layer and retains complete state equality.

Each waiting candidate exposes five bounded components:

```text
recurrence = 0.8 * grounded glyph echo + 0.2 * own-field echo
silence    = clamp((turn - last_seen_turn) / 8)
unfinished = 1 when the question has an open spoken episode,
             otherwise blocks / (blocks + 1)
flow_gap   = 1 - cosine(perceived_mean, expressed_mean)
appetite   = 0.55 * recurrence + 0.15 * silence
           + 0.20 * unfinished + 0.10 * flow_gap
```

`flow_gap` belongs to the candidate's exact event-bounded Flow current and is
zero when no such current has meaningful mass. A candidate becomes `salient`
only when recurrence is at least `0.75`, appetite at least `0.62`, and its lead
at least `0.15`. Thus maximal silence, unfinished depth, and Flow residual still
cannot nominate a question whose meaning did not return. Weak and mixed echoes
remain `diffuse`; old unrelated questions remain `quiet`. Literal names are
marked `literal` and excluded from autonomous ranking because A.43 already
treats them as human address.

The checked matrix grows the two independent A.40 bodies and compares default
against `--no-wonder-appetite` in five forks per body: strong semantic return,
weak return, mixed return, maximally aged quiet, and a semantic return to a
spoken question parked by A.43. The parked fork must identify the displaced
question with `spoken=1`, `unfinished=1`, and `flow_gap>=0.90`. Every one of the
ten forks requires reply and complete saved-state equality.

Run the slow return-appetite calibration matrix:

```sh
make deferred-wonder-appetite-calibration
```

A.45 turns only a `salient` A.44 receipt into a falsifiable forecast. Its
deadline is fixed at birth: the next three lived turns. A later semantic echo
cannot slide the window forward, and a second forecast for the same question
cannot overlap the first. Existing forecasts observe the new turn before its
current appetite is allowed to open another forecast, so proposal evidence
never counts as a future hit.

The verdicts preserve causal distinctions:

- `sustained`: the target's recurrence reaches `0.75` again inside the window;
- `faded`: the identity remains intact but no such recurrence follows;
- `external`: the human literally names the target;
- `grounded`: the target is actually learned or its exact Flow episode closes;
- `lost`: the identity disappears before it can be judged;
- `unscorable`: lived chronology skips a turn.

Only `sustained`, `grounded`, and `faded` receive Brier scores. External
invitation, loss, and missing history remain evidence, but are not relabeled as
prediction success or failure. `--no-wonder-appetite-calibration` disables only
this persistent diary. State v21 appends a bounded 32-receipt fail-soft tail;
v20 bodies migrate with no invented forecasts, and damage to v21 discards only
the new diary.

The checked matrix uses both independent A.40 bodies and five lives per body:
unspoken sustained return, one-frame fade, literal external return, sustained
return of a parked spoken question, and a diffuse no-forecast control. Each
future turn is a separate load/respond/save process. ON and OFF must produce
the same 30 reply pairs and the same state prefix through v20. Complete states
must differ only for the eight lives where A.45 has evidence to remember; the
two diffuse controls remain completely byte-identical.

Run the accumulated return-appetite reliability matrix:

```sh
make deferred-wonder-appetite-reliability
```

A.46 derives a reliability diagram from the existing v21 diary. It adds no
state tail and does not update Leo during a reply. Scored forecasts are split
into eight fixed cells:

```text
spoken / unspoken
    x
[0.62, 0.70), [0.70, 0.80), [0.80, 0.90), [0.90, 1.00]
```

Each cell reports sample count, confirmations, mean appetite, observed return
rate, mean Brier score, calibration gap, and a 95% Wilson interval. With fewer
than four scored lives the cell remains `forming`, regardless of apparent
success. At four or more it is `aligned` when the mean prediction lies inside
the Wilson interval, `over` when prediction exceeds the interval, and `under`
when prediction falls below it. These labels describe evidence, not permission:
no School, Flow, shadow, route, sampler, or generator reads the surface.

Only `sustained`, `grounded`, and `faded` enter the diagram. Pending forecasts,
literal human returns, lost identities, and broken chronology remain separately
counted but cannot improve or damage calibration. `--no-wonder-appetite-reliability`
removes only the diagnostic projection; the v21 diary and complete saved state
remain unchanged.

The checked matrix accumulates five real forecasts in each of the two
independent A.40 bodies. Four unspoken lives (`3 sustained + 1 faded`) form an
`aligned` `[0.62,0.70)` cell; one sustained parked-spoken life forms a separate,
still-`forming` `[0.80,0.90)` cell. Every forecast crosses separate
load/respond/save processes. The final ON/OFF forks must have identical replies
and complete states, proving that the surface reconstructs from persisted
evidence without becoming another organ of intervention.

Run the accumulated return-appetite drift matrix:

```sh
make deferred-wonder-appetite-drift
```

A.47 asks whether an apparently calibrated A.46 cell still means the same
thing now as it did earlier. Inside each exact spoken/appetite stratum, it
compares the four oldest and four newest scored receipts in the bounded v21
diary. A cell remains `forming` until it has eight causally scored lives.
Middle receipts are deliberately excluded from the two fixed endpoint windows,
so accumulating history cannot blur the current temporal resolution.

Each measured cell reports early/recent confirmations, mean appetite, observed
return rate, mean Brier score, and four independent shifts: return rate,
appetite, calibration gap, and Brier. `rising` or `falling` requires
non-overlapping 95% Wilson intervals for the two observed return rates;
otherwise the cell is `stable`. These words name the direction of observed
return, not improvement or damage. In particular, base-rate movement cannot
silently become a verdict about self-knowledge.

The checked matrix gives both independent A.40 bodies the same eight unspoken
forecasts in opposite order. Both pooled A.46 cells are `aligned` at `4/8`,
predicted appetite `0.690`, and observed rate `0.500`. One chronology is
`faded x4 -> sustained x4` and becomes `rising`; the other is
`sustained x4 -> faded x4` and becomes `falling`. Final ON/OFF replies and
complete states must remain byte-identical. `--no-wonder-appetite-drift`
removes only this projection; it does not remove or rewrite the v21 diary.

Run the shadow abstention policy matrix:

```sh
make deferred-wonder-appetite-policy
```

A.48 asks a deliberately narrower question than "should Leo speak?": at the
instant A.45 opens a forecast, did the exact spoken/appetite stratum have enough
stable and calibrated history that a hypothetical policy could trust it?
The answer is frozen into the forecast before that forecast can contribute its
own outcome:

```text
fewer than 8 scored lives                         -> forming
8+ lives, A.46 over/under                         -> uncalibrated
8+ lives, A.46 aligned, A.47 rising/falling       -> drifting
8+ lives, A.46 aligned, A.47 stable               -> eligible
```

When the future arrives, `eligible` becomes `supported` or `overreach`;
abstention becomes `missed` or `restraint`. Literal human return, lost
identity, and broken chronology remain `confounded`. These are retrospective
policy receipts, not actions. No School, Flow, route, sampler, or generator
reads them.

State v22 appends the frozen policy, reliability status, drift status, and
support count to each A.45 record. A v21 forecast migrates as `legacy`; Leo does
not reconstruct confidence his older body never witnessed. A corrupt v22 tail
still fails soft by discarding only the forecast diary.

The checked four-case matrix crosses a real save/load/respond/save process for
`eligible -> sustained`, `eligible -> faded`, `drifting -> sustained`, and
`drifting -> faded`. The resulting labels are `supported`, `overreach`,
`missed`, and `restraint`. `--no-wonder-appetite-policy` removes the diagnostic
and prevents new policy snapshots; ON/OFF replies and complete states must
remain byte-identical when no new forecast is born.

The API and frozen-replay lanes do not adapt moves to Leo's answers; they are
baselines. `local-v1` is genuinely adaptive within its nine predeclared phases,
but only through the narrow visible sensors above. Selecting a move from shadow
diagnostics would leak the judge into the stimulus, while sending Leo's private
dialogue to an external API remains outside this protocol.

Run the two-axis policy-regret matrix:

```sh
make deferred-wonder-appetite-regret
```

A.49 derives a policy cost surface from settled A.48 receipts without changing
their frozen decisions. It deliberately refuses a single utility score:

```text
coverage  = eligible / scored
overreach = overreach / eligible
missed    = missed / abstained
```

Both error axes expose separate 95% Wilson intervals. The projection preserves
the exact A.46-A.48 spoken/appetite strata. A cell is
`eligible-observed` after four eligible decisions,
`abstention-observed` after four abstentions, and `paired` only after both arms
independently reach four. Smaller occupied cells remain `forming`.

Pending, confounded, legacy, and ablated receipts are reported but excluded
from the denominators. The surface is reconstructed only for diagnostics:
there is no new persisted field, state remains v22, and no speech or scheduler
path reads it. `--no-wonder-appetite-regret` suppresses only this line.

The checked matrix builds two v22 fixtures with identical `0.500` coverage but
different outcome geometry. The motion-heavy life must report
`overreach=0.375, missed=0.375`; the restraint-heavy life must report
`overreach=0.125, missed=0.625`. Both must contain one paired, one
eligible-observed, and one abstention-observed stratum. ON/OFF forks use the
same seed and require identical replies and byte-identical complete saved
states.

Run the shadow readiness-frontier matrix:

```sh
make deferred-wonder-appetite-readiness
```

A.50 asks whether one exact A.49 stratum has enough evidence to become a
candidate for a later controlled experiment. It does not grant permission to
act. Both policy arms must have at least eight causally scored outcomes, and
the 95% Wilson upper bounds for overreach and missed continuation must each be
strictly below `0.500`.

The boundary means that each error is, with 95% confidence, less common than
its opposite outcome inside its own arm. It is not a chance baseline. It does
not combine the errors, and coverage is reported rather than optimized.
`forming`, `unpaired`, and `observing` keep sample insufficiency distinct from
the three confidence failures: `motion-unbounded`, `restraint-unbounded`, and
`both-unbounded`. Only the fully bounded region is called `candidate`.

The checked matrix holds the stratum, sample count, arm balance, coverage, seed,
prompt, and process path fixed while rotating the two error rates. It requires
the four expected regions at Wilson upper-bound pairs `0.471/0.471`,
`0.785/0.471`, `0.471/0.785`, and `0.785/0.785`. Default and
`--no-wonder-appetite-readiness` forks must produce identical replies and
byte-identical v22 states.

This remains selection-conditioned shadow evidence, not a causal claim about a
speech intervention. A.50 adds no state and has no generation reader.

Run the fixed-future holdout matrix:

```sh
make deferred-wonder-appetite-holdout
```

A.51 opens at most one non-restartable trial for each exact A.50 candidate
stratum. Opening freezes the current turn and latest proposal identity. The
qualifying history cannot grade itself; only later settled A.48 receipts are
eligible.

Each trial consumes exactly 16 future settled policy attempts. Receipts from
other strata and causally confounded receipts still consume budget, so the
experiment cannot wait for a convenient sample. The target stratum needs at
least four eligible and four abstained outcomes. Missing either arm produces
`coverage-starved`. Otherwise the two Wilson upper bounds are judged
independently, producing `confirmed`, `motion-failed`, `restraint-failed`, or
`both-failed`. A `none` or `legacy` policy receipt invalidates the apparatus
rather than being reinterpreted.

State v23 persists the frozen boundary, the 16 proposal identities already
seen, separate arm outcomes, confounds, other-stratum budget, and terminal
status. v22 migrates empty; a damaged v23 tail fails soft without losing the
forecast diary. A terminal trial cannot reopen. `--no-wonder-appetite-holdout`
removes both updates and diagnostics.

The checked matrix includes one real-process arming fork and five terminal
forks. Arming must preserve the reply and every saved byte before the v23 tail.
For each terminal verdict, default and ablated processes must preserve both the
reply and the complete state. The expected Wilson-upper pairs are
`0.471/0.471`, `0.785/0.471`, `0.471/0.785`, and `0.785/0.785`; a fifth case
spends four of its 16 attempts outside the target stratum and ends
`coverage-starved`.

This is still a shadow experiment. `confirmed` does not authorize speech,
scheduling, routing, or a sampler change. It says only that an A.50 candidate
survived one future that it could neither select nor postpone.

Run the immutable admission-receipt fork:

```sh
make deferred-wonder-appetite-admission
```

A.52 preserves the exact A.50 evidence that allowed a new A.51 trial to open.
The receipt binds the trial identity and stratum to the original arm counts:
eligible, abstained, supported, overreach, missed, and restraint. Validation
recomputes both Wilson bounds and rejects a receipt unless each arm had at
least eight observations and both upper bounds were strictly below `0.500`.

State v24 places this immutable receipt in a separate tail after the unchanged
v23 holdout. A v23 trial remains live after migration but is reported as
`legacy`; absent evidence is never reconstructed. A damaged v24 admission tail
fails soft by clearing only provenance, leaving the A.51 trial and all earlier
state intact.

The checked process starts from one exact candidate and forks before arming.
Default and `--no-wonder-appetite-admission` must produce the same reply and
byte-identical state through the complete A.51 holdout tail. Only the new A.52
tail may differ. The admitted fork must preserve the original `7/1 | 1/7`
outcomes and independently recomputed Wilson upper bounds `0.471/0.471`.

The receipt has no generation reader. `attested` means that the holdout has a
verifiable warrant, not that its eventual verdict may change speech.

Run the current-life transport matrix:

```sh
make deferred-wonder-appetite-transport
```

A.53 asks whether one attested, confirmed result still describes the measured
policy geometry of Leo's present. The current window begins strictly after the
last proposal consumed by A.51. Earlier admission evidence and the holdout
cannot grade their own transport.

Each exact spoken/appetite stratum needs eight new eligible and eight new
abstained outcomes. Current overreach and missed-continuation Wilson upper
bounds must independently remain below `0.500`. Policy coverage stays a third
axis: the current 95% interval must overlap both the A.52 admission interval
and the realized A.51 holdout interval.

An interval overlap is a compatibility screen, not an equivalence test. The
success status is therefore `provisional`, not permanent applicability.
`unattested`, `pending`, `refuted`, `incompatible`, `observing`, and `shifted`
preserve the distinct ways a transport claim may be unavailable.

The checked matrix rotates motion risk, restraint risk, admission coverage,
and holdout coverage independently. It also includes thin-current and
policy-language-change cases. Default and
`--no-wonder-appetite-transport` forks must keep identical replies and
byte-identical complete v24 states for all eight rows.

A.53 is derived diagnostics only. It does not persist another judgment and no
speech or scheduler path reads it. Even `provisional` remains evidence, not
permission.
