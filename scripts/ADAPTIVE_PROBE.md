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

Run the two-epoch current-life chronology:

```sh
make deferred-wonder-appetite-transport-chronology
```

A.54 asks whether A.53's pooled present is hiding a regime change. It uses the
complete current 32-settled-attempt post-holdout window already bounded by the
A.48 diary. The older 16 attempts form the `early` epoch and the newer 16 form
the `recent` epoch. Their proposal boundaries must be ordered and
non-overlapping. If earlier post-holdout evidence has rotated away, A.54 makes
no claim to have recovered it; this is chronology inside the observable
present, not a reconstruction of the first historical era.

Every settled attempt spends one epoch slot, including another stratum or a
causally confounded outcome. Pending receipts do not become outcomes and leave
the window `observing`. A `none` or `legacy` policy, or non-monotonic proposal
identity, makes it `incompatible`.
Each complete epoch independently needs at least four exact eligible and four
exact abstained outcomes. An absent arm produces `coverage-starved` rather than
borrowing observations from the neighboring era.

For each epoch, motion and restraint retain separate 95% Wilson upper-bound
vetoes below `0.500`. Its policy-coverage interval must also overlap both the
A.52 admission interval and the realized A.51 holdout interval. Finally, the
early and recent coverage intervals must overlap each other. As in A.53,
interval overlap is only a compatibility screen, not evidence of equivalent
distributions.

The pooled A.53 cell must remain `provisional` before A.54 can be
`provisional`. Chronology can only add vetoes:

```text
aggregate-shifted  pooled A.53 transport already failed
early-shifted      only the older observed epoch fails
recent-shifted     only the newer observed epoch fails
both-shifted       both epochs fail, possibly on different risk axes
ecology-shifted    both epochs pass history screens but their coverages diverge
provisional        pooled and both local screens expose no measured shift
```

The nine-case matrix includes three temporal arrangements with identical
pooled arm totals, an opposite-axis cancellation, a `12/4 -> 4/12` policy
ecology inversion whose pooled coverage remains `16/16`, a pooled failure,
thin chronology, epoch-local coverage starvation, and policy incompatibility.
Default and `--no-wonder-appetite-transport-chronology` forks must preserve
strict proposal order, identical replies, and byte-identical complete v24
states in every row.

A.54 adds no state and no speech, scheduler, routing, sampling, or generation
reader. It is a readerless chronology of evidence, not permission to intervene.

Run the persisted transport-life sequence:

```sh
make deferred-wonder-appetite-checkpoint
```

A.55 stops asking the rotating A.48 diary to impersonate long time. Once an
A.51 trial is confirmed and its A.52 admission receipt is attested, a
checkpoint opens after that trial's terminal proposal. It owns exactly the
next 32 settled policy attempts as two adjacent 16-attempt epochs unless a
changed policy language invalidates comparison earlier. Every attempt stores
its proposal identity and raw outcome category. Another stratum or a confound
spends time without filling either arm; pending forecasts spend no slot.
`none` or `legacy` closes the lane early as `incompatible`.

When a checkpoint terminates, its `through_proposed_turn` becomes the next
checkpoint's exclusive boundary. The next life therefore cannot reuse an
outcome from the previous one. The v25 state keeps at most the two most recent
terminal lives per trial plus one active life. Rates, intervals, and the
terminal status are not trusted as opaque claims: load validation recomputes
the verdict from raw counts and rejects duplicate proposal identities,
non-monotonic proposals, overlap, and mismatched stored status.

The last two terminal lives produce a readerless sequence:

```text
one                 one complete life, no regime claim
stable-provisional  both lives are provisional
emerging-shift      provisional -> shifted
persistent-shift    shifted -> shifted, even on different risk axes
recovered           shifted -> provisional
insufficient        either life is coverage-starved
incompatible        policy language changed; no translation is attempted
```

An unfinished 31-attempt life remains `pending` across save/load and produces
no sequence claim. A v24 body starts its first checkpoint after every
calibration receipt it already carries; migration cannot retrospectively turn
old diary entries into a new experiment. A truncated or corrupt v25 tail
fails soft by discarding only checkpoints and anchoring future observation
after the surviving diary. The body, trial, and admission proof remain intact.

The eight-case process matrix covers one life, stable provisionality, emerging
and persistent shifts, recovery, insufficient coverage, policy
incompatibility, and a 31/32 active life. Default and
`--no-wonder-appetite-checkpoint` forks keep strict checkpoint boundaries,
identical replies, and byte-identical complete states in all eight rows. A
separate writer isolation pair holds all pre-v25 bytes equal while the
checkpoint tail differs, then confirms that those two distinct readerless
states still produce the same reply.

A.55 persists evidence, not authority. School, Flow, shadow, routing,
sampling, scheduling, and generation do not read the checkpoint or its
sequence.

## A.80: state-swarm ecology and prospective road calibration

Run the complete readerless ecology:

```sh
make state-swarm-ecology
```

The matrix creates three independent lives (`river`, `window`, and `lantern`).
Each life receives three eight-turn writer sessions. Surface language changes
between sessions while the sealed laboratory texture order remains:

```text
home, storm, home, wonder, social, home, storm, home
```

The labels are not passed to Leo. Every writer turn runs in a fresh process,
loads the previous state when one exists, and saves the next state. Each
session is followed by four fixed counterfactual probes. A probe forks one
saved body between default and `--no-state-swarm`; both processes must emit the
same visible reply, and neither may change the state file.

The run contains 108 observations:

```text
3 lives * (24 persisted writer turns + 12 counterfactual probes)
```

The runtime receipt records the full activation membership, its rounded mass,
adjacency, observed delayed consequences, and a next-state/outcome forecast
made from the transition ledger before the current update. The strict parser
rejects partial predictions, duplicate state IDs, malformed channels, and
activation mass outside `[0.995, 1.005]`.

Outputs are written to a new timestamped directory under `${TMPDIR:-/tmp}`:

```text
plan.tsv       sealed chronology, prompts, process boundaries, and seeds
receipts.tsv   one parsed state-swarm receipt per observation
epochs.tsv     per-life, per-session acquisition and forecast measurements
summary.tsv    whole-life ecology, anchor, and forecast measurements
verdict.txt    aggregate invariants and predeclared classifications
lives/         saved bodies and raw default/ablation logs
```

Classification is fixed before observing a run:

```text
stable       >=3/4 holdout anchors return, zero holdout replacements,
             and dominant share <0.75
thrashing    >2 holdout replacements or >2 novel holdout anchors
collapsed    <=1 winner or dominant share >=0.85 after acquisition
provisional  everything between those boundaries
```

An ecological classification never fails the command. Only receipt shape,
chronology, visible-voice equality, or state-file equality can do that. The
matrix also reports forecast accuracy, probability assigned to the observed
winner, log-surprise against a uniform-state baseline, and four-channel
forecast MAE. Those measurements grade the road model separately from the
state geometry.

The recorded 2026-07-31 run is
`/tmp/leo-state-swarm-ecology-a80-r4-20260731`. It produced two stable lives
and one provisional life, with no thrashing or collapse. All 36 probes were
reply-identical and state-identical. No life replaced a state; each retained
seven or eight distinct winners with a 0.188-0.250 dominant share. Acquisition
mostly settled by session three.

Forecasting did not pass the same bar. Whole-life top-1 accuracy was at most
0.133 and excess log-surprise over uniform remained positive by 2.398-3.190.
Two lives became marginally better than uniform during session three, while
one remained worse. Consequence MAE improved to roughly 0.18. The warranted
conclusion is therefore narrow: Leo can revisit configurations, but this
experiment does not establish a reliable model of their sequence.

A.80 changes no persisted state version and adds no generation reader. It is
not evidence for routing, sampling, scheduling, or speech intervention.

## A.81: six-session prospective road calibration

Run the longer readerless horizon:

```sh
make state-swarm-road-calibration
```

A.81 preserves the complete A.80 first half and adds three unseen sessions.
The cases file must contain 48 unique writer prompts in the same hidden
eight-position texture order plus four fixed probes. Its validator rejects the
plan unless sessions one through three and every probe are byte-identical to
the sealed A.80 case file.

The resulting 216 observations contain three lives, 144 persisted writer
turns, and 72 counterfactual probes. A writer always exits after saving. Each
probe forks the same body between default and `--no-state-swarm`; visible reply
and complete state bytes must remain equal.

`epochs.tsv` scores the pre-update raw transition forecast per session against:

```text
uniform       equal probability for every current state
persistence   the prior turn's complete soft activation
marginal      the normalized activation occupancy before this turn
same-position normalized activation at this position in earlier sessions
kernel        similarity-weighted targets of earlier activation transitions
```

The same-position control uses hidden laboratory order and cannot become a Leo
reader. The activation-kernel is also offline: it is a candidate measurement,
not an implementation. All scores use the same overlap log-loss floor as the
runtime witness.

`holdout.tsv` compares sessions one through three with sessions four through
six. Classifications are fixed before observing the full run:

```text
learned-road       >=23 holdout forecasts; raw beats uniform by >=0.10 nat
                   and rolling marginal by >=0.05 nat
transition-defect  raw loses to uniform by >=0.10 nat while same-position
                   beats raw by >=0.50 nat
exposure-limited   raw improves by >=0.50 nat but has not cleared the learned
                   road boundary
provisional        none of those claims is warranted

kernel supported   >=20 scores and >=0.10 nat better than raw
kernel harmful     >=20 scores and >=0.10 nat worse than raw
kernel neutral     measured between those bounds
```

The recorded run at `/tmp/leo-state-swarm-road-a81-r1-20260731` produced two
exposure-limited lives and one provisional life. Holdout raw/uniform surprise
was `1.927/2.079`, `2.438/2.074`, and `2.004/2.079`. All three finish with eight
states, no replacements, and 72/72 voice- and state-identical probes.

Activation-kernel backoff is neutral in all lives: its difference from raw is
less than `0.001` nat. Raw also remains within `0.003-0.014` of rolling
marginal. More exposure clearly reduces early surprise, but A.81 does not show
that the transition ledger learned specific order beyond occupancy. Therefore
no backoff, state format, update law, or generation reader is added.

## A.82: factor the state alphabet before predicting its sequence

Run the balanced crossover:

```sh
make state-swarm-alphabet
```

The case file defines eight sessions of eight writer turns plus four fixed
probes. `home`, `storm`, `wonder`, and `social` are laboratory labels only and
never enter Leo. Each session contains every texture twice. Within both the
four-session acquisition half and four-session holdout half, every texture
appears exactly once at every temporal position. Holdout changes adjacency and
uses entirely new prompts.

The matrix runs three independent lives with a real save/load process boundary
after every writer. Four default/`--no-state-swarm` probes follow every
session. The complete experiment therefore contains:

```text
3 lives * (64 persisted writers + 32 counterfactual probes) = 288 processes
```

Acquisition averages full soft activation distributions into texture and
position prototypes. A joint prototype preserves each of the 32 crossed
cells. Held-out similarity is the Bhattacharyya coefficient, which remains
bounded and does not reward a prototype merely for being more diffuse.

Predeclared boundaries are:

```text
texture alphabet   accuracy >=0.50, mean true-vs-best-other margin >=0.02
position alphabet  accuracy >=0.25, mean margin >=0.01
joint interaction  accuracy >=0.125, mean margin >=0.005
geometry veto      >1 holdout birth or any holdout replacement
```

Passing texture and position is `factorized`; only one passing yields
`texture-alphabet` or `order-alphabet`. Joint passing without either main
effect is `entangled`. No passing factor is `unformed`. Geometry veto is
`unstable-geometry`. These are descriptions of a readerless measurement, not
authority for state updates or generation.

The recorded run is
`/tmp/leo-state-swarm-alphabet-a82-r2-20260801`. Texture accuracy is
`0.4375`, `0.5000`, and `0.4688` against chance `0.25`, but all three margins
are negative (`-0.0115`, `-0.0037`, `-0.0177`). Position is at or below its
`0.125` chance rate with negative margins. Joint accuracy is zero. All lives
finish with eight states and holdout contains no birth or replacement. The
verdict is three `unformed` lives.

The synthetic contract test supplies a perfect four-state texture code. It
must score `32/32` for texture and zero for both position and joint because
their prototypes tie under exact balance. This prevents a successful factor
from leaking into another label.

A.82 does not conclude that holistic tiny weights are useless. It concludes
that they are episodic coordinates rather than a stable texture/order
alphabet. No C code, state version, backoff, or speech reader changes. The next
candidate experiment is per-organ similarity factorization, still diagnostic
and still pre-update.

## A.83: decompose state similarity before dividing the organism

Run the exact A.82 crossover with pre-update organ receipts:

```sh
make state-swarm-organs
```

The runner first executes `state_swarm_alphabet_matrix.sh` unchanged, including
all save/load boundaries and 96 default/`--no-state-swarm` probes. It then
extracts seven existing similarity components for every prior state:

```text
perception  expression  own-field  body  rhythm  form  darkmatter
```

`body` preserves the equal chamber/retention contribution and `rhythm`
preserves the 2:1 rhythm-distance/rhythm-class contribution. Their seven
weighted values reconstruct the old holistic score. The component receipt is
runtime-only and separately allocated; the persisted v27 swarm is unchanged.

Birth and replacement slots are emitted as `na` and excluded because their
prototype is the current observation itself. Every other component is captured
before the state update. Each organ independently converts similarity to soft
activation with temperature `0.12`, then builds texture and position prototypes
from sessions one through four and scores sessions five through eight with the
same Bhattacharyya classifier and thresholds as A.82.

Coverage is factor-specific:

```text
texture   at least 4 valid acquisition turns per texture
position  at least 2 valid acquisition turns per temporal position
holdout   all 32 observations valid, with no birth/replacement exclusion
```

The recorded run is
`/tmp/leo-state-swarm-organs-a83-20260802-r4`. Texture has three adequate lives;
position has two because River's sparsest acquisition position has one valid
turn after birth exclusion. All seven organs are `unformed`. Perception alone
has positive texture margins in every life (`+0.0132`, `+0.0160`, `+0.0029`),
but none reaches both `0.50` accuracy and `+0.02` margin. Body repeats `14/32`
texture hits in every life with negative margins. Every adequate position
margin is negative.

The embedded synthetic scorer creates a pure texture code in perception and a
pure position code in expression. Each must score `32/32` only on its own
factor; the other five uniform organs remain `unformed`. The live holistic
scores exactly reproduce A.82, and all 96 counterfactual pairs remain reply-
and state-identical.

A.83 therefore forbids factorized weights for now. Its next warranted test is
a settled-organ crossover: use an unscored warm-up to finish births, then begin
a fully balanced acquisition half with no tautological holes. That experiment
can decide whether perception's small positive margin deserves its own shadow
prototype or remains only an episodic trace.

## A.84: test whether local settlement survives a new life surface

Run the unscored warm-up followed by the sealed A.82/A.83 crossover:

```sh
make state-swarm-settled-organs
```

The warm-up is a four-session Latin crossing of four laboratory textures and
eight positions. It contributes 32 unique prompts per life and is excluded
from every classifier prototype. The runner admits the scored experiment only
after each life has eight states and its entire fourth warm-up session contains
updates rather than births or replacements.

The resulting v27 bodies begin A.82 at persisted turn 33. A.82's acquisition,
holdout, process boundaries, seeds, and counterfactual probes are otherwise
unchanged. The report distinguishes two claims:

```text
local settlement    warm-up session four has no structural change
settlement transfer no birth or replacement anywhere in scored acquisition
                    or holdout, in all three lives
```

Only complete transfer may admit an organ verdict. An empirical failure still
exits successfully and records every replacement and partial factor row;
malformed plans, broken chronology, counterfactual voice/state differences,
or incomplete receipts remain command failures.

The recorded run at
`/tmp/leo-state-swarm-settled-organs-a84-20260802-r2` passes local settlement
in `3/3` lives but complete transfer in only `1/3`. Window replaces one state
during scored acquisition and Lantern replaces two during holdout. All organs
are therefore `not-admitted`. The result is reproducible byte-for-byte against
an independent first run for warm-up receipts, holistic receipts, and factor
rows.

This is evidence about plasticity, not an update defect. A full swarm replaces
its weakest coordinate only when every existing holistic similarity is below
`0.40`; further arbitrary warm-up cannot guarantee that an unseen moment will
clear that gate. A.84 consequently changes no novelty/replacement threshold,
state format, generation path, or reader.

## A.85: follow an experience after its coordinate is displaced

Run the sealed causal return matrix:

```sh
make state-swarm-displacement-return
```

A.85 reuses the three deterministic replacement events exposed by A.84. Each
target is replayed from a freshly settled warm body to the turn immediately
before replacement. The runner then forks that body: the default branch lets
the state swarm observe the trigger, while a one-turn `--no-state-swarm`
control preserves the old coordinate. Prompt, seed, reply, and all normalized
non-swarm diagnostics must match; the two saved state files must differ.

Four predeclared observations return independently to both forks:

```text
exact birth       original observation that first formed the displaced ID
birth paraphrase  new surface form of that observation
exact anchor      later observation with the displaced ID's highest prior mass
anchor paraphrase new surface form of that later anchor
```

The return commands deliberately omit `--save`. Leo still performs the normal
in-process post-speech state observation, whose receipt is the measurement,
but the input state bytes remain unchanged for every independent probe.

A fate is qualified only when the no-displacement control updates the old ID,
assigns it at least `0.20` activation mass, and separates it from the next
state by at least `0.02`. The displaced receipt is then classified as:

```text
trigger-capture  winner is the ID born from the displacement trigger
survivor-return  winner is another surviving ID
rebirth          the return itself produces a replacement
unanchored       the control does not strongly identify the old ID
```

A case needs at least two qualified probes. One qualified fate yields that
case label; multiple qualified fates yield `mixed-return`; fewer than two
remain `unanchored`. These are topology descriptions, not proof of semantic
transfer between weights.

The recorded run at
`/tmp/leo-state-swarm-displacement-a85-20260802-r6` reproduced all three A.84
replacements and qualified five of 12 return probes. Window51 and Lantern77
remain case-level `unanchored` with one witness each. Lantern68 qualifies
three probes and visits all three fates, producing `mixed-return`. A second
run from the sealed warm checkpoint is byte-identical across the plan, trigger
receipts, raw returns, classified probes, and case summary.

The runner verifies provenance rather than trusting the labels in the return
file: every exact-birth prompt must match the displaced ID's real warm-up
`born` receipt, and every exact-anchor prompt must attain that ID's maximum
activation over all replay turns before displacement.

A.85 changes no organism code or speech path. Its next use is to predeclare an
offline per-organ fate analysis and test it on new displacement events before
considering any reader, freeze, or replacement-policy change.

## A.86: require new displacements before explaining their anatomy

Run the sealed eight-life population:

```sh
make state-swarm-displacement-anatomy
```

Each life receives 32 unscored settlement observations followed by all 64
A.82 writer observations. The eight seed rows are fixed in
`state_swarm_displacement_anatomy_lives.tsv`; do not add lives after seeing the
event count. Every post-settlement replacement is admitted automatically.

For an admitted event the runner forks the exact pre-trigger body, repeats the
trigger with `--no-state-swarm`, and requires equal reply and normalized
non-swarm diagnostics with different saved bodies. It then derives at most two
returns from the event's own earlier receipts:

```text
exact-birth   the observation and seed that created the displaced ID
exact-anchor  the strongest earlier updated observation won by that ID
```

Each return enters control and displaced bodies without saving. The control
qualifies only when the old ID wins with mass `>=0.20` and margin `>=0.02`.
The displaced receipt is recomputed seven times offline while omitting one
organ and renormalizing the remaining holistic weights. Values within `0.002`
of the `0.40` gate are `boundary`; at least `6/7` matching fates is robust.

Population adequacy requires at least eight qualified returns, four events,
and four lives. The recorded run at
`/tmp/leo-state-swarm-displacement-anatomy-a86-20260802-r4` has eight settled
lives but zero replacements in 512 scored writer observations. Its result is
therefore `insufficient`. Writer minimum similarities range from `0.409` to
`0.457`; the population approaches but never crosses the gate. Independent
`r5` receipts, final states, and scientific tables are byte-identical.

The fork/provenance/scorer path is separately exercised on the two old A.85
seed trajectories. It recovers all three known replacements and processes six
automatic returns without changing the A.86 population result. Treat those
rows as a technical receipt only: they reuse discovery lives and fail the
predeclared event/life adequacy floor.

The runtime-only receipt exposes nearest and removed pre-update seven-organ
vectors so a future qualified event can be scored without reconstructing lost
state. It changes no persisted body or update. The shared dialogue parser also
now accepts the legitimate diffuse case `active=0`: the winner exists even
when no soft activation reaches the active-membership threshold.

Do not extend A.86 until it produces a preferred answer. If replacement
incidence itself needs explanation, open a separately sealed population study
of event rate and near-gate distance first.

## A.87: map displacement incidence before reopening anatomy

Run the 32-life sealed population:

```sh
make state-swarm-displacement-incidence
```

The population is fixed in
`state_swarm_displacement_incidence_lives.tsv`: 24 primary and eight holdout
lives on an arithmetic seed grid that was declared without screening for
replacement. Every life receives the unchanged 32-turn A.84 settlement
crossover followed by the unchanged 64 A.82 writer observations. Each turn is
a separate process with a real save/load boundary.

The runner changes no state body, update law, `0.40` replacement threshold,
sampler, routing path, or speech reader. It retains one complete receipt per
turn, all visible replies and local logs, final states, a life table, every
replacement event, and fixed-order strata by split, texture, session, and
position. Similarities are partitioned before the run into `<0.400`,
`0.400..0.405`, `0.405..0.410`, `0.410..0.420`, `0.420..0.450`, and `>=0.450`.
The debug similarity is printed to three decimals, so the below-gate band is
classified by the actual `replaced` event; an unrounded value just below the
gate may legitimately render as `0.400`.

Anatomy may reopen only if all 32 lives meet A.84 settlement and at least four
new replacements occur in four lives with representation in both primary and
holdout. Fewer events are an underpowered incidence result, not permission to
raise the gate, append seeds, or reuse A.85 discovery lives as confirmation.
`LEO_STATE_INCIDENCE_PLAN_ONLY=1` validates and prints all 3,072 observations
without launching Leo. Independent lives may run concurrently through
`LEO_STATE_INCIDENCE_JOBS`; receipts are concatenated in the sealed TSV order.
If the process is interrupted after all per-life receipts are complete,
`LEO_STATE_INCIDENCE_AGGREGATE_ONLY=1` rebuilds only the derived tables in the
same output directory and refuses any life that does not contain 96 receipts.

The recorded run is
`/private/tmp/leo-state-swarm-displacement-incidence-a87-r1-20260805`.
Thirty of 32 lives met the fixed settlement condition; `p20` and `p21` each
made one replacement during warm-up session four and are excluded from every
incidence denominator. The 30 eligible lives contribute 1,920 writer
observations and eight replacements across seven lives. Primary contributes
five events in five lives; holdout independently contributes three events in
two lives. Eligible life incidence is `7/30 = 0.233333` (Wilson 95%
`0.117922..0.409287`); turn incidence is `8/1920 = 0.004167` (Wilson 95%
`0.002113..0.008201`).

Events are not evenly distributed across the sealed trajectory: social has
four, home three, wonder one, and storm zero. Sessions three, five, and eight
contain four, three, and one respectively. This establishes that A.86's zero
events in eight lives was an underpowered trajectory sample, not proof that
displacement vanished.

The predeclared `32/32` settlement gate still fails, so the formal result is
`settlement-incomplete` and A.87 does not admit organ anatomy. Do not append
lives or discard only the two failures. A new population may instead declare
settlement as a prospective enrollment condition before any writer turn,
retain a fixed age of 32 warm observations, and require a minimum eligible
population before capturing new events. Re-aggregation after the BSD-Bash
empty-array harness fix is byte-identical for `life-summary.tsv`, `events.tsv`,
`strata.tsv`, and `verdict.txt`.
