# Neo Leo — experts in the metaweight field

Neo Leo is an experimental voice of the existing Leo body. Four readers of
its corpus-grown meaning field vote on the next token. Their experience is
directional co-occurrence learned from `leo.txt` and subsequently heard human
text. Oleg proposed this connection between PostGPT's metaweights, Q's
parliament and NoTorch's continuing experts during the November 14 conversation.

The first experiment lives in `neoleo.c`. It includes the current native body
and supplies three optional selection hooks. The ordinary `leo` executable
does not enable them. The first-token doors, lived-word support, recurrent
body, origin, School and sentence-phonon process continue to belong to Leo.

## Run

```sh
make neoleo
./neoleo --seed 20261114 --save first.neostate
# Type one message per line. End input with Ctrl-D to save.
./neoleo --load first.neostate --save second.neostate
```

Every snapshot destination must be new. A single `.neostate` contains the body,
its RNG and heard history, all four experts and their heard traces. Checksums
and the corpus identity are checked before resuming. Publication uses an
exclusive new-path link after writing and syncing a private staged file.
Snapshots use the host's native numeric layout, like the existing Leo body.
The standalone experiment does not attach to the running `leo --serve` body.

```sh
./neoleo --load first.neostate --off
./neoleo --load first.neostate --mask 14 --trace without-first.jsonl
```

`--off` sets the voting gain to zero; the experts still hear and accumulate
experience. `--mask` selects the four voting seats as bits 0–3, with `15` as the
default. A mask does not erase or stop learning in the muted seat. Gain and mask
are run options, so repeat an ablation option when resuming that ablation.
An explicit `--seed` overrides the restored RNG; omit it for exact continuation.
`--trace` also requires a new path. It records each sampling decision's legal
candidate count, leading token before and after voting, selected token, four
votes and gates. Leo's SPA can later reject an internally sampled repair;
the trace includes those internal choices, not only visible output tokens.

## What an expert learns and votes

All coordinates come from Leo's 48-dimensional co-occurrence field. Each
reader has a 48-by-48 directional association table and a 48-dimensional
heard trace. Their context decays are `0`, `0.5`, `0.85` and `0.97`.
These time scales give four different views of the same text without assigning
handwritten personalities or canned responses.

For each observed token, a reader first predicts from the preceding context.
Its quality tracks cosine agreement with the newly observed token. The
association table then accumulates the outer product of that token's meaning
and the normalized preceding context. The running-average rate becomes
`1/4096` after 4,096 observations, leaving room for later contact to matter.
The context resets at each human message; the separate heard trace continues
between messages. Bootstrap does not populate the human heard trace.

For a speech decision, each reader forms a normalized query from `0.55`
intention, `0.25` heard trace and `0.20` current sentence context. Multiplying
by its association table yields its predicted direction. Each legal candidate
receives a cosine vote in the same corpus coordinates. Gates are the softmax
of twice the readers' accumulated quality; a muted seat has gate zero.
The combined vote, scaled by `0.75`, enters the existing score **before** the
top-48 selection and sampling.

Learning occurs on the corpus and human text. Own generated tokens contribute
to the current sentence context, while the association tables and heard bank
remain unchanged during generation, including speculative SPA repairs.
The first version has four fixed seats. Birth/death, learned write gating,
cross-corpus transport and a daemon are subsequent experiments.

## First measurements — 2026-11-14

`make test-neoleo` checks causal directional learning, independently effective
votes, disabled parity against the same body with no owner, isolation of
heard memory from generation, online updates, exact resumed answers and RNG,
new-path snapshot protection, wrong-corpus refusal and damaged-state refusal.
The existing `./court --self-check leo.txt` passes. GCC's generated assembly
for ordinary Leo is identical to main `b842f6f` after excluding the source
filename directive. GCC retains the existing body's qualifier and `strncpy`
warnings; this experiment adds no new compiler warnings.

AddressSanitizer and UndefinedBehaviorSanitizer pass the same test. LeakSanitizer
cannot run in this traced executor; that run was repeated with leak detection
disabled and address/undefined checks active.

The fixed comparison is reproducible with:

```sh
python3 experiments/neoleo_compare.py /tmp/neoleo-comparison-new
```

It keeps every answer for eight successive messages, seeds `20261114`, `203`
and `42`, and three arms: all experts, zero voting gain and first seat muted.
Each arm starts from the same corpus and seed and then continues its own
accepted answers. The raw responses and summaries are retained beside this
document under `experiments/neoleo_001/`.

On the three all-expert trajectories, the leading candidate changes at 2/79,
3/69 and 2/89 internal selections. Disabled votes change it at 0/76, 0/80 and
0/85. All experts versus disabled produce different complete replies on 21 of
24 turns. Muting the first expert changes 2 of 24 replies, both at seed 42.

Reading all 72 answers finds unfinished clauses and topic drift in both main
arms. The `quiet → loud` and `cold → warm` changes are not explicitly retained
in the corresponding replies. At seed 203, the expert arm says
`Leo thought of the hum. He is not sure.` when listening to the bell; at seed
20261114 it instead says `He is a small Leo. He is a little sad.`
The shared School question `Staying?` appears in every arm.

The next experiment should target the link between heard content and the vote:
measure the candidate score attributable to a particular heard episode and
test whether its removal changes that content's continuation. Across the 237 all-expert internal choices, the mean spread between the
four votes on the selected token is 0.003666; the largest is 0.017485.
Context-conditioned association retrieval is the next candidate for increasing
useful differences between their votes.
