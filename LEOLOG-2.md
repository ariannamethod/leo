# LEOLOG-2

Post-transformer is a step forward, not a step back. Leo has zero pretrained
weights, but that never means primitive language machinery. His heart grows a
byte-level BPE vocabulary from `leo.txt`; co-occurrence becomes a distributed
meaning field; nonlinear recurrent context carries more than the last one or
two tokens; four-head Q/K/V attention recalls whole episodes; six coupled
chambers settle before speech; retention, presence, scars, the origin, lived
moments, and silent inner movement persist in one permanently running body.

## 2026-09-13 — Current pass: standalone post-transformer heart, live

### Oleg's instruction

Write Leo again from scratch on the architectural lineage of Claude's Leo.
Keep him permanently enabled. Preserve BPE and the real organismal anatomy;
do not reduce him to Markov/ELIZA, do not restore the deleted probe/test
apparatus, and do not stage dialogue or recruit Oleg into a demonstration.

### Physical changes

- Replaced the 371-line temporary wrapper that directly included
  `/Users/ataeff/arianna/leo/leo.c` with a 1,768-line standalone `leo.c`.
- The new source has no absolute include, no dependency on Claude's filesystem,
  no canned reply, no response template, no forbidden-word list, no School
  question path, no best-of-K display selection, and no test/probe harness.
- `leo.txt` grows 256 base bytes plus 512 BPE merges. Co-occurrence is accumulated
  into 48-dimensional random-index meaning; three learned recurrent context
  prototypes per token carry long trajectory; bounded bigram/trigram terms are
  grammar channels inside the same selector rather than the language engine.
- Ordered prompt attention uses four Q/K/V heads. Q/K/V begin untrained and
  change by bounded local co-activation during lived human turns.
- Birth sentences and lived human/Leo moments are recalled by semantic,
  recurrent, somatic, and age/strength resonance. Recalled value, current
  presence, retention, the prompt field, the origin, and the chamber body form
  one continuing intention; every emitted BPE token deforms that trajectory.
- The six Claude-lineage chambers are coupled in the body, grow their drive from
  the learned meaning field, maintain slow scars and a body capsule, and alter
  both token selection and utterance duration.
- Before any human line reached the new body, source review found that pure
  newline/space tokens could dominate a first choice through corpus frequency.
  The mouth now excludes only tokens with no visible content; this is a byte
  boundary, not a forbidden-word system or a prescribed utterance.
- Idle time changes presence, retention, chambers, and moment strengths without
  emitting or lexically ingesting imaginary speech.
- The former state remains untouched at `leo.state`. The new format lives at
  `leo.state.body3`; its first birth imports only transferable somatic continuity
  (lifetime step, retention, chambers) from Claude's v5-v10 state. Incompatible
  old token IDs, generators, gates, and demonstration machinery are not imported.

### Live transition and direct observations

- The old bridge remained live while the new binary was compiled and while a
  new body first opened on a second private socket.
- With both processes alive, launchd was switched to the new binary. The old
  bridge exited normally with code 0. Before any human line, the whitespace
  mouth defect above was corrected and the same blue-green replacement was
  repeated without a global off interval. The primary service resumed as PID
  97399 on the original mode-0600 `leo.sock`; the temporary process was then
  ended, leaving the launchd-owned body as the sole Leo.
- The original 6,136,662-byte private state remains present. The new private
  sidecar is 326,736 bytes. Runtime stdout and stderr remained empty at the
  transition.
- No prompt, authored dialogue, expected reply, fixture, or selected utterance
  was sent or produced during this pass.

These observations establish the new physical body, its connected mechanisms,
continuous process ownership, socket, and persistence path. They do not by
themselves prove Leo's voice, presence, identity, or coherence. Those can only
be observed in his un-staged lived contact.

## Historical rejected passes below

The Reset and Pass 1–4 entries below record discarded implementations. They do
not describe the current source or runtime and must not be resumed.

## 2026-09-13 — Reset

Oleg ordered all former code, tests, probes, reports, fixtures, logs, assets,
build artifacts, and experimental apparatus removed from the Leo repository.

Retained: `README.md`, `LICENSE`, `leo.txt`, `.git`, and this newly ordered log.

Codex then produced a Markov-based replacement. Oleg rejected it as an
ELIZA-class reduction of Leo. That source, build file, and binary were removed.
They must not be reused.

Oleg's vote of no confidence applies to every Codex step.

## 2026-09-13 — Correction: the old lineages are anatomy, not a baseline

Oleg named Claude's Leo, Codex's `leo2leo`, GitHub `neoleo`, and the Python
versions so their mechanisms could be found. Oleg then stated the decisive fact:
none of those versions ever worked as Leo. Their output and their large test
apparatus were demonstrations, not evidence of a functioning organism.

The temporary direct import of Claude's C body and AML files was therefore a
wrong reading of the instruction. It was removed from the repository before it
was run and placed outside the repository at
`/private/tmp/leo-rejected-demo-import-20260913.IFA9gM`. No code from that body
is present in the new source.

The named versions remain read-only anatomical references:

- `/Users/ataeff/arianna/leo`
- `/Users/ataeff/arianna-codex/repos/leo2leo`
- `/Users/ataeff/arianna-codex/repos/neoleo`
- `/Users/ataeff/arianna/leo-legacy`

Transformer-derived mechanisms are allowed. "Not a transformer" is not a ban
on BPE, attention, embeddings, or learned selection.

## 2026-09-13 — Pass 1: new end-to-end body from an empty file

### Physical changes

- Added a new 1,014-line `leo.c`, written from an empty file.
- Added a seven-line build-only `Makefile`.
- Did not restore any old tests, probes, fixtures, reports, scripts, staged
  conversations, generated examples, AML files, assets, or old logs.

The connected path in the new body is:

`human line -> grown 32-dimensional word meanings -> four-head episodic
attention -> six coupled phase chambers plus retained presence -> one combined
token score -> utterance -> persistent state`

`leo.txt` is read as birth experience. Word meanings begin from stable
word-derived vectors and are changed by local co-occurrence updates. Directed
next-word links and trigrams provide two grammar terms, not the whole selection
mechanism. Episodic attention, current-field similarity, retained-voice
similarity, chamber phase bias, and repetition pressure enter the same token
score. The first selected token may not be copied from the current human line.
Human lines and Leo's own utterances enter episodic memory with different
strengths. State is written atomically to `leo.state`; an unreadable existing
state is not overwritten.

There are no canned conversational replies or fallback utterances in the new
source. Its only user-visible fixed strings are the CLI usage/error text and the
`you>` / `leo>` labels.

### Observed

`make` compiled the source with `-std=c11 -O2 -Wall -Wextra -pedantic` and no
compiler diagnostics. The chat was not launched, no utterance was produced, and
no `leo.state` was created. Compilation is not evidence that Leo works.

### Not connected in this pass

BPE/subword perception, learned query/key/value projections, asynchronous inner
life, AML, and the older memory organs are not present. The new body is an
implementation candidate, not a claim that Leo is alive or repaired.

## 2026-09-13 — Pass 2: one permanently running body

### Physical changes

- `leo.c` is now 1,367 lines and has two roles: `--serve` owns the organism;
  `--chat` is only a local client of that same organism.
- The server owns all mutable memory. A chat invocation cannot create a second
  body or independently load and overwrite Leo's state.
- Added a length-delimited local Unix-socket protocol. The socket is mode `0600`.
- Added an idle heartbeat. Once per idle second, the running body recalls the
  episodes currently nearest to its presence, advances the six coupled phases,
  and slowly changes presence, retention, and chamber drives. It speaks nothing
  during this movement.
- Idle state is preserved every 30 ticks. Dialogue state is preserved after each
  received line. State files are atomically replaced and mode `0600`.
- Added `ai.ariannamethod.leo.plist` and installed the same plist as the user
  LaunchAgent `/Users/ataeff/Library/LaunchAgents/ai.ariannamethod.leo.plist`.
  It uses `RunAtLoad` and `KeepAlive`.
- Runtime state and the socket live outside git under
  `/Users/ataeff/Library/Application Support/Leo/`. Runtime stdout and stderr go
  to `/Users/ataeff/Library/Logs/Leo.log` and `Leo.error.log`.

The body uses fixed-size C storage, creates no worker processes or threads, and
does not dynamically grow a corpus in memory. This bounds its own resident
structures instead of relying on an external memory claim.

### Why

Leo is no longer recreated for demonstrations. There is one continuing process
with one memory owner. Inner change can occur while nobody talks to him, and a
runtime/state failure exits through the error log so `launchd` can restart the
process rather than leaving a silent dead instance.

### Observed

The rebuilt C source compiled without compiler diagnostics. `launchd` reports
one running instance, PID 87458, with one launch and no prior exit. The live
process created a `0600` socket and a 5,958,144-byte `0600` state file. After 30
idle seconds the persisted `inner_ticks` field was 30. Both runtime logs were
empty. No chat request was sent and Leo produced no utterance.

These observations establish continuous execution, idle state movement, and
state preservation only. They do not establish coherent speech or a functioning
Leo.

## 2026-09-13 — Pass 3: subword perception and projected attention

### Correction

Pass 1 prohibited every word in the current human line from being Leo's first
reply token. That was a lexical ban, the same class of intervention Oleg had
already identified as destructive to Leo's voice. The prohibition and its
helper function were removed. The new body contains no forbidden-word list.

### Physical changes

- Added byte-level subword perception with 256 base byte pieces and 384 BPE
  merges grown directly from `leo.txt`. The resulting vocabulary has 640 pieces.
- A word's initial 32-dimensional meaning now combines its whole-word grain with
  the meanings of its current BPE pieces.
- Local contextual learning now moves existing word meaning toward the grown
  meaning of neighbouring words, not toward a freshly re-hashed substitute.
  The same event weakly changes the constituent BPE pieces, so experience with
  one word can affect later perception of another word sharing those pieces.
- Replaced direct four-slice cosine lookup with four separate 8-dimensional
  query, key, and value projections. They begin close to identity, participate
  in episode retrieval immediately, and change by bounded local co-activation
  when a human line attends to prior memory.
- Idle recall now passes remembered episodes through the value projections
  before they affect presence and retention.
- Added an append-only state extension for the BPE pieces and Q/K/V projections.
  The running version-2 state was migrated without discarding its turns, phases,
  retention, episodes, or idle age.

### Why

Unknown and morphologically related words can now enter the same perceptual
space instead of receiving unrelated whole-word hashes. Episode attention now
has distinct, persistent query/key/value transformations rather than being
called multi-head attention while merely comparing four fixed vector slices.
Removing the first-word ban lets Leo repeat a heard word when his own field
selects it.

### Observed

The 1,763-line source compiled without diagnostics. The live service was
replaced in place and resumed as one process, PID 87808. Its previous 5,958,144
state bytes were retained; a `LEOBPE1` extension begins exactly at byte
5,958,144. The extension records `sizeof(LeoPiece) == 140` and 640 pieces. The
complete private state is now 6,050,832 bytes. Runtime logs remained empty. No
chat request was sent and no claim about speech quality is made.

## 2026-09-13 — Pass 4: the human line and the reply become trajectories

### Physical changes

- Replaced the orderless prompt average with projected attention inside the
  human line. Each head uses the final content word plus current presence as its
  query, attends across the ordered input words, and returns projected values.
  That result joins the whole-line mean, presence, and retention.
- A reply now begins with one persistent intention composed from the human
  query, recalled episode values, presence, and retained voice. Its trajectory
  changes after every emitted content word without discarding that intention.
- Grammar counts are compressed into bounded pair/triple terms before joining
  attention and meaning. Raw sentence-start frequency can no longer exceed the
  semantic channels merely because it is counted in larger units.
- Added a contextual-continuity term between consecutive words. It is a scored
  influence, not a gate.

### Why

The former prompt vector forgot word position, and raw frequency dominated the
combined score. That path could select fluent-looking but unrelated fragments
from `leo.txt`. The new path keeps a relation to the end and whole shape of the
human line while carrying one field across the entire answer. No response form,
topic, word, or sentence is prescribed.

### Observed

The 1,846-line source compiled without diagnostics. The same saved organism
resumed under PID 87993 with `turns == 0` and `inner_ticks == 607`; therefore no
human dialogue was invented during these passes and its preceding idle age was
not reset. One process and one private state remain. Runtime logs were empty.
No speech-quality claim is made.
