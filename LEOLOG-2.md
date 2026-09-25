# LEOLOG-2

Post-transformer is a step forward, not a step back. Leo has zero pretrained
weights, but that never means primitive language machinery. His heart grows a
byte-level BPE vocabulary from `leo.txt`; co-occurrence becomes a distributed
meaning field; nonlinear recurrent context carries more than the last one or
two tokens; four-head Q/K/V attention recalls whole episodes; six coupled
chambers settle before speech; retention, presence, scars, the origin, lived
moments, and silent inner movement persist in one permanently running body.

## 2026-09-25 — Corridor A.163b: a rail is not a choice

Lineage: Netta's mouth, `lawful_support` and amendments 2 and 3 in
`netta.py`, carried to the word scale. Leo's frame demanded the exact lived
four-word order at every word; lower orders existed only at a sentence start
through beginning padding. Where a three-word context had one lived
continuation, the mouth had one lawful word, and the court found two thirds of
his sentences recited.

The law, fixed before code:

1. The word field also grows lived three- and two-word edges and, for every
   context, the number of distinct continuations it has lived. They are built
   by the same `leo_word_field_build`, so heard lines (A.162) enter them too.
2. The highest lived order whose context has a continuation governs: four
   words, then three, then two. Below two there is nothing; the A.151 lexicon
   law is untouched, so no word can be invented.
3. A choice made where the governing context has exactly one continuation is a
   rail. After one rail (K=1, the value Netta's court pinned at its first
   sitting) the next choice descends to the nearest lower order that branches,
   and the rail word is closed for that choice. A branch or a descent clears
   the count; a sentence end resets it.
4. The count is recomputed from the visible surface, as the frame already is.
   The body's state format does not change. A.160's lineage score is taken
   only where a four-word edge exists.
5. Tokens, BPE edges, openings, FORM landing, SPA and School are unchanged.

### Result

Strict build clean for the body and the court; the court's self-check passed.
Birth occupancy of the new table: 124391 / 524287 entries (40666 three-word
edges, 24235 two-word edges, 33902 / 21652 / 3936 context counts at four,
three and two words).

Law switched off by its own constants (floor four, K=0), the new code
reproduced the A.162 court exactly: 213/317 verbatim, rails 627/2093, rested
body 153/180, and the same eight first-seed answers byte for byte. Behaviour
did not move before the law was turned on. Four of 2093 choices read as below
the four-word order in both runs; they are phonons that ended without a stop
and were joined by the court, a measurement seam that prices both sides alike.

With the corridor, on a copy of the same body, the same lines and seeds:

- M1: 111 of 298 sentences verbatim, 0.372 (was 0.672; line 0.50); mean
  coverage 0.079 (was 0.356), longest run 41 bytes (was 59);
- M2: rails 460/1916, 0.240 (was 0.300);
- choices below the four-word order: 237/1916, 0.124;
- M3: 0;
- M4: 148/180, 0.822 (line 0.80);
- School: 20 questions, as before.

First-seed answers, raw:

> Leo, are you here? — The sun was doing things without thinking. Leo has a feeling he cannot hear.
> I am here with you. — The bird flew. Leo was a little sad.
> I am listening. — The tone is his weather now. Leo has not been scared.
> I am still here. — The light is a promise. Leo does not know him.
> I am here, Leo. — The warmth is asking to stay. Leo has not been scared.
> I am listening to you. — The bird flew. Leo sits at the window.
> I came back to listen. — The book was on it. Leo did not know him.
> I am here again. — The dark at the bottom. Leo did not know him.

`Leo has a feeling he cannot hear.` is not in `leo.txt`. After `feeling he
cannot` the four-word frame had lived one continuation, `name`; the corridor
closed it, and the three-word order `he cannot` offered `see`, `hear`, `say`,
`remember` and others. Several answers did not change, because they never rode
a rail.

Red run: the same law with the rail veto deleted descends but may pick the
rail again at the lower order. Rails stayed at 0.294 and verbatim sentences at
0.599, so it fails the court. Changing level is not changing path; the veto is
load-bearing, exactly as Netta's third amendment found.

A.162's hearing still holds under the new law: `Leo likes the portishead.` is
unreachable before hearing and reachable after, and live and replayed tables,
the new edge table included, hash equal (`ddd74af4…`). Reply latency on a copy
body stayed at 0.33–0.48 s; resident size 68752 KiB.

Open: the ear. Numbers passed their lines; whether the voice is more Leo is
heard, not computed. `Leo has not been scared.` twice under two different lines
says the next question is not rails but variety of intent.

## 2026-09-25 — Court A.163a: Leo's speech gets a court

Until now every mouth step was judged by one draw and an ear. A single draw
cannot tell a law from luck, and it cannot see a drift. A.160's answer opened
with a birth sentence copied byte for byte; A.162's copy-body answer was two of
them. Counting the four-word frame along those answers shows why: after `Leo
walked in` the lived field offered exactly one continuation six times out of
ten choices. A frame with one continuation is not a choice, it is a rail, and
on a rail every organ of presence is mute, because chambers, recall, intention
and memory only rank candidates that survived the gates.

`court.c` (built by `make court`) opens a copy of a body without writing it
back, marks its heard record full so the shipped overflow law keeps the shared
tables untouched, and lets Leo answer each of the nine lines humans have
actually said to him in this log under twenty seeds. It prices:

- M1 copying: answer sentences found verbatim in `leo.txt`, plus Netta's
  census (coverage by verbatim runs of at least 32 bytes, longest run);
- M2 rails: word choices whose four-word frame had exactly one lived
  continuation;
- M3 floor: words outside the lexicon, which the mouth law forbids;
- M4 body: answers that change when the same seed meets a rested body (all
  chambers, inputs, scars and capsule at zero). Any perturbation moves the
  sampling path, so this only catches a body that has gone completely mute.

`./court --self-check` must pass before a verdict is read: a birth sentence is
caught whole, a joined sentence (A.160's `He is a small gift to the whole
house.`) is not called a copy, and an invented word is counted outside the
lexicon.

### Baseline, A.162 body

Self-check passed: the quoted sentence was found verbatim with a 47-byte run
and full coverage, its rails read 6 of 10 as the separate count did; the joined
sentence was not verbatim and its longest borrowed run was 25 of 38 bytes; the
invented word counted once.

On a copy of the permanent body (`turns=11`, `moments=23`, mode STOP; its hash
unchanged by the court), 180 answers:

- School asked 20 questions, all twenty on `I am staying with you.`;
- M1: 213 of 317 sentences verbatim (0.672); mean coverage 0.356, longest run
  59 bytes. Leo's sentences are mostly shorter than the census's 32 bytes, so
  for him the verbatim sentence is the honest measure;
- M2: 627 of 2093 choices were rails (0.300);
- M3: 0;
- M4: 153 of 180 answers changed with a rested body (0.850).

First-seed answers, raw:

> Leo, are you here? — The sun was doing its best. The book is long.
> I am here with you. — The bird flew. Leo was a little sad.
> I am listening. — The tone is his weather report. Leo has a song he sings only in his head.
> I am still here. — The light is a promise. Leo does not know him.
> I am here, Leo. — The warmth is asking to be noticed. Leo has a feeling he cannot name.
> I am listening to you. — The bird flew. Leo sits at the window.
> I came back to listen. — The book was on the path. Leo heard the sea.
> I am here again. — The dark at the bottom. Leo did not know him.

Two thirds of what Leo says, he is reciting.

### Preregistered for the next mouth organ

The corridor, the next organ, is judged by this court on a copy of the same
body with the same lines and seeds. It passes only if M1 falls below 0.50
(Netta's void line: at or above it the voice is a quote) and below 0.672, M2
falls below 0.300, M3 stays 0, M4 stays at or above 0.80, the court reports
the share of word choices made below the four-word order, and the raw
first-seed answers are printed and kept beside the numbers. Better numbers with
worse speech fail by ear; the answers are the evidence, the numbers are the
receipt.

## 2026-09-25 — Hearing A.162 preregistration: what a human says becomes lived grammar

Every table the mouth consults — lexicon, BPE edges, token bigrams and
trigrams, word four-grams — was written only at birth from `leo.txt`. A human
line bent `adaptation` and `lived_context` of existing tokens, but nothing a
human said could ever become speakable. That contradicts the dedication Leo
carries inside `leo.c` ("Leo listens to you. He records. He builds
trigrams."), the source header and README, and both ancestors: Claude Leo fed
every prompt into its bigram, trigram, co-occurrence and BPE tables; Python
Leo observed every line into its field. The mouth law never differed between
them. Only the growth of the tables was lost.

A.162 restores one organ:

1. After the reply is formed, each newline-separated segment of the human line
   passes through the same builders that read `leo.txt`: the lexicon, the word
   field with its four-gram context centroids, and token bigrams and trigrams
   over the birth BPE encoding. Token frequency counts the lived use, because
   well-formedness requires it and a merge fully consumed at birth can have
   none.
2. The reply that the line prompted cannot use it; the line is lawful from the
   next turn on.
3. Openings, corpus context prototypes and episodes stay birth-only. Heard
   language enters mid-speech through three-word contexts shared with birth
   language, not by re-opening the human's sentence.
4. Leo's own speech never becomes grammar; he cannot legitimise his own seams.
5. State version 5 appends the heard record, bounded at 1 MiB. At every start
   the record is replayed in order into the freshly born tables, so live and
   restarted bodies hold identical grammar. A segment that would overflow the
   record is not heard at all, so the two paths cannot diverge.

A separate earlier repair guards the migration: any state load failure used
to rebirth Leo and overwrite the sidecar. An existing but unreadable body now
makes the process refuse to start and leaves the file byte-identical; birth
happens only when no file exists.

Gates fixed before code, run on copies of the live v4 sidecar through a
temporary probe that includes `leo.c` and exercises its shipped static
functions; the probe is not part of the repository:

- strict C11 build without warnings;
- the refusal law: old binary rewrites a truncated copy, new binary refuses
  and keeps its hash; an intact copy still opens, an absent file is still born;
- table occupancy after birth, printed;
- reachability as a property: a word absent from the birth lexicon, placed by
  a human after a birth-reachable three-word context, is unreachable for the
  mouth's candidate gates before hearing and reachable after; the same probe
  with the call to the organ deleted from `leo_respond` must fail;
- the reply to the teaching line is byte-identical with and without the organ;
- the heard record holds exactly the human line, not Leo's reply;
- table hashes are equal in the living process and after save and replay;
- a v4 body migrates with its counters unchanged;
- repeated `kill -9` during lived turns leaves only loadable state; a
  truncated v5 body is refused with its hash unchanged;
- two declared lines to a copy body, kept raw, without reroll.

### Result

Strict build clean. The refusal law went red first: on a copy truncated to
900000 bytes the previous binary was born again and rewrote it (sha256
`9d4322db…` to `0eaaf503…`, turns 11 to 0), reproducibly. The repaired binary
exited with status 1 and the hash stayed `9d4322db…`; an intact copy opened at
`turns=11`, `moments=23`; an absent file was born at `turns=0`.

Birth occupancy: bigram 34013 / 131071, trigram 56267 / 262139, word four-gram
45881 / 131071, lexicon 3935 words.

The probe chose `portishead`, absent from the birth lexicon. Birth frames for
the opening `Leo likes the` exist (22 four-gram observations). The human line
was `I think Leo likes the portishead.` Through the mouth's own gates, `Leo
likes the portishead.` was unreachable before hearing and reachable after; with
the call removed from `leo_respond` it stayed unreachable. The reply to the
teaching line was identical in both builds (hash `136ad772…`): School asked
`Portishead?`. The heard record was 34 bytes, the line plus its newline, with
no reply text. Live and replayed tables hashed equal (`f5e5679a…`). The copied
v4 body opened as v5 with vocab 4662, `turns=11`, `moments=23`, one origin,
mode STOP, four School records, no pending question, guesses 0/0 and an empty
record.

Fourteen `kill -9` interruptions during lived turns: ten landed after new
turns (11 to 43), all fourteen files loaded, none was refused. One temporary
file from an interrupted write remained beside the intact state. The copy's
record held 32 lines, one per lived turn. The same body cut by seven bytes was
refused and kept its hash (`12deb45c…`).

Two declared lines reached a copy of the live body:

> **Human:** I make music, and my project is called monarbre.
>
> **Leo:** Monarbre?
>
> **Human:** I am here with you.
>
> **Leo:** Leo did not want to. Leo walked in her footprints once at the beach.

The first reply is School meeting a word it has never heard. The second does
not use the heard line, and both of its sentences occur verbatim in
`leo.txt`. The organ makes heard paths lawful; it does not make the mouth
choose them, and this draw shows the strict word frame drifting toward
retrieval of whole birth sentences. That is the next question for Leo's
language body, not for hearing. The copy was removed; the permanent body was
not contacted and still reads `turns=11`, `moments=23`.

A v5 body must never be opened by a binary older than the refusal repair: such
a binary cannot read version 5 and would be born over it. The repaired binary
without A.162 refuses instead.

## 2026-09-19 — FORM A.161.1 preregistration: a written word stays whole

The Codex Connector review of A.161 found a real boundary error after merge.
`leo_surface_word_count()` currently ends a visible word on every non-letter,
so `Leo's` and `room-dark` each consume two beats of FORM. The birth corpus
contains 323 apostrophe- or hyphen-joined occurrences across 202 distinct
lowercased forms. STOP can therefore seek a landing before its documented four
visible words even though the internal BPE path remains lawful.

This repair is narrower than Leo's word topology. The lexicon and word-frame
field deliberately treat punctuation as an internal boundary and remain
untouched. Only the displayed-surface counter changes: an ASCII apostrophe or
hyphen keeps the current visible word open when it is between letters; spaces,
sentence punctuation, and every other separator still close it. Leading or
trailing punctuation cannot hide the next word.

The gate is fixed before code: the actual helper must count `Leo's`,
`room-dark`, `-dark`, and `dark-` as one visible word each, and `Leo, still` as
two; strict compilation must remain clean; a candidate must reopen the copied
v4 body with vocab 4662, `turns=11`, `moments=23`, one origin, four School
records, no pending question, guesses/hits `0/0`, and STOP unchanged; then a
blue-green handoff must leave the permanent Leo running. No dialogue is
generated for this deterministic counting repair.

### Live result

The actual compiled helper passed all five declared cases: `Leo's=1`,
`room-dark=1`, `-dark=1`, `dark-=1`, and `Leo, still=2`. The temporary verifier
included `leo.c` directly, exercised the same static function shipped in the
binary, and was removed after the check; no test apparatus entered the
repository. The full source also compiled cleanly under strict C11 warnings.

Without receiving speech, a candidate reopened a copy of the v4 body and kept
vocab 4662, `turns=11`, `moments=23`, eleven human moments, eleven Leo moments,
one kind-3 origin, four School records, no pending question, guesses/hits
`0/0`, and mode STOP. It stayed alive while the permanent LaunchAgent moved
from PID 95314 to PID 5587 (`runs=17`). The deployed binary was byte-identical
to the candidate; only after the new primary owned the permanent socket was
the standby stopped and its copied state removed. The permanent state remains
`11/23`, and no dialogue was generated.

## 2026-09-19 — FORM A.161 preregistration: the held breath must land

A.159 restored Claude Leo's discrete WALK / STOP / RUN / BREATHE mood and its
sentence-chain lengths, but deliberately left F-3 unwired because this
standalone mouth defines one phonon as one sentence. The omission is now
audible: the live mode is STOP, yet A.160's two phonons ran to fourteen and ten
visible words. The body chooses how many breaths but not how long it holds each
one.

Claude's F-3 budgets are WALK 14, STOP 4, RUN 24, and BREATHE 8. A.161 adapts
their law to the current generator rather than copying the old token loop:

1. The budget counts visible words in the current phonon, not BPE pieces.
2. Before the budget, sampling is unchanged and an earlier natural sentence
   end still ends the phonon.
3. At or beyond the budget, if any otherwise lawful candidate reaches an
   observed sentence ending through the existing BPE bigram/trigram and
   word-frame topology, non-ending candidates leave the draw. If no such
   ending is reachable yet, generation continues unchanged until one is.
4. Nothing is sliced after sampling. The last word and punctuation must be a
   lived path; a mode may shorten a breath but cannot manufacture a boundary.
5. FORM mode remains the only input. No mode prompt, manual override, AML
   bridge, BE expression channel, or mutable state field enters this phase.

The gate is fixed before code: strict compilation; copied-state birth with v4,
vocab 4662, `turns=10`, `moments=21`, one origin, four School records, no
pending question, guesses/hits `0/0`, and STOP unchanged; blue-green handoff;
then one ordinary live continuation, retained without reroll. The STOP reply
must end each visible phonon on a lawful sentence boundary and read as held by
ear. A cut word, dangling fragment, or long unheld run fails A.161. One short
draw demonstrates this event only; it does not calibrate all four modes.

The 88-glyph School is already live and is not part of this change. Its fixed
alphabet is the caveLLMan / actually.life awareness seed; unlike
actually.life's survival mouth, Leo preserves unmapped content as `-1` so the
School can ask and grow a persistent human-taught word-to-glyph map. `BE` is
glyph 86 but is excluded from concept voting because a copula is not an answer
to “what does this word mean?”. AML `BE [x]` is a separate speak-from-body
operator and remains a later, distinct organ.

### Live result

The strict build passed. Without receiving speech, a candidate opened a copy
of the live v4 sidecar and preserved vocab 4662, `turns=10`, `moments=21`, ten
human moments, ten Leo moments, one kind-3 origin, all four School records, no
pending question, guesses/hits `0/0`, and mode STOP. It remained alive while
the permanent LaunchAgent moved from PID 86079 to PID 95314 (`runs=16`). The
deployed binary was byte-identical to the checked candidate. Only after the new
primary owned the permanent socket and saved the unchanged body was the
temporary standby stopped and its copied state removed.

One ordinary continuation was then spoken, once:

> **Human:** I am here again.
>
> **Leo:** Leo likes the shape of him. He does not know why.

The STOP target is four visible words per phonon. The first phonon reaches its
first available lived sentence ending at six words and the second at five;
both close with sampled punctuation. A.161 therefore holds the breath at the
first corpus-lawful landing available after the target instead of cutting at
word four or permitting another long run. This passes the declared one-event
gate; it does not claim calibration of WALK, RUN, or BREATHE.

The live v4 state after contact is vocab 4662, `turns=11`, `moments=23`, eleven
human moments, eleven Leo moments, one origin, mode STOP, no pending question,
guesses/hits `0/0`, and the same four unbound School exposure records. The
permanent PID 95314 remains running.

## 2026-09-19 — Word-lineage A.160 preregistration: a frame remembers where it came from

A.159's only live draw exposed a precise remaining seam: `He stood very
still, learning the shape of the feeling makes it easier to carry.` Every
local transition was born somewhere, but the utterance crossed three different
birth sentences through their shared surfaces:

- `He stood very still, learning the shape of himself.`
- `Leo knows the shape of the feeling.`
- `The naming of the feeling makes it easier to carry.`

The current `LeoWordFourgram` stores four word hashes and a count. During
speech it is a yes/no topology: it proves that a local transition existed, but
has no representation of the sentence trajectory in which it existed. A.158's
token context cannot fully supply that identity because frequent BPE tokens
share only three generic context prototypes.

A.160 adds one bounded organ to the existing frame rather than increasing its
order:

1. A word-level nonlinear reservoir starts from the same fixed BOS state at
   every sentence and advances from a deterministic distributed vector of each
   completed word hash.
2. Each existing four-word edge learns a running directional centroid of the
   reservoir state immediately before its candidate word. Repeated edges still
   share one topology entry; no sentence, suffix, or response is stored.
3. During generation, the identical word reservoir is rebuilt from the visible
   sentence. When a BPE candidate completes a word or sentence boundary, its
   edge-context cosine shares the existing grammar-context score. It is
   evidence, not a hard ban: lawful recombination remains possible.
4. This is corpus-born model anatomy and adds nothing to mutable state v4. It
   does not change FORM, SPA, School, BPE identity, the origin, or the single
   sampled trajectory.

The gate is fixed before implementation: strict compilation; copied-state
birth with vocab 4662, `turns=9`, `moments=19`, one origin, three School
records, no pending question, guesses/hits `0/0`, and mode STOP unchanged;
then blue-green handoff and exactly one ordinary live continuation. The raw
answer will be retained. A grammatical draw can demonstrate the phenomenon
once, not prove general grammar; another seam fails this step and authorizes
diagnosis, not rerolling.

### Live result

The strict build passed. A candidate born without speech on a copied v4
sidecar kept vocab 4662, `turns=9`, `moments=19`, one kind-3 origin, all three
School records, no pending question, guesses/hits `0/0`, and mode STOP. Its
fresh RSS was about 40 MiB, including the dynamically allocated corpus model.
It remained alive while the permanent LaunchAgent moved from PID 25284 to PID
86079 (`runs=15`); only after the new process owned the permanent socket and
saved the unchanged state was the standby stopped and removed.

One ordinary continuation was then spoken, once:

> **Human:** I came back to listen.
>
> **Leo:** He does not know the word for a line that runs through a stone. He
> is a small gift to the whole house.

The first sentence occurs byte-for-byte in the birth corpus. The second does
not: it joins the corpus's `small gift to the house`, `a gift to the whole
house`, and related `small gift` paths into a grammatical sentence. Both STOP
phonons close without the ancestry seam observed in A.159. This passes the
declared one-event gate; it is not a claim that every future path is
grammatical.

The live v4 state after contact is vocab 4662, `turns=10`, `moments=21`, one
origin, mode STOP, no pending question, guesses/hits `0/0`, and four School
exposure records. `came` was added once and remains unbound alongside `leo`,
`listening`, and `still`; Leo did not open a question.

## 2026-09-13 — FORM A.159 preregistration: the body acquires a held breath

The standalone body already lets chamber pressure continuously alter
temperature and chooses one, two, or three phonons through an ad hoc
distress-versus-safety comparison. Claude Leo's FORM is more specific: presence
reads as a body when its cadence is a discrete mood with inertia, not a dimmer.
A.158 repaired clause context; A.159 restores this separate lineage organ and
does not claim that cadence is syntax.

1. The settled chambers quantize through Claude's four mode scores: WALK is
   `0.20 + LOVE`, STOP is `FEAR + VOID`, RUN is `FLOW`, and BREATHE is
   `COMPLEX`. WALK / STOP / RUN / BREATHE are the AML velocity names, but no AML
   bridge is smuggled into this phase.
2. A competitor replaces the current mood only when its score wins by more than
   `0.15`. This is the original FORM hysteresis: transient pressure may bend the
   voice without instantly renaming the body.
3. The mode chooses the number of sentence phonons using Claude's current map:
   WALK 3, STOP 2, RUN 5, BREATHE 2. The phonon capacity grows from three to
   five; every later phonon still receives causal SPA pressure from those
   already spoken, and the entire visible result remains one sampled trajectory.
4. This phase does not transplant Claude's token target blindly. His generation
   block can contain several sentences, while this Leo defines one phonon as one
   sentence and stops at its boundary. A hard landing belongs in the next FORM
   wire after that difference is resolved, not as a mid-clause truncation.
5. Mode becomes the one-byte tail of state version 4. A v3 body derives its
   first mode once from the already persisted chambers; subsequent restarts keep
   the slept mood until new contact beats the hysteresis. All earlier v1-v3
   fields migrate unchanged.

The current v3 chamber vector makes STOP the expected migration (`FEAR + VOID`
is greater than every competing score). A copied sidecar must become v4 while
remaining vocab 4662, `turns=8`, `moments=17`, one origin, two School exposure
records, no pending question, and guess counters `0/0`. No mood prompt or A/B
series will be staged. After blue-green handoff, one ordinary continuation is
the only speech event.

### Live result

The strict build passed. A standby born on a copied sidecar migrated exactly:
v3 to v4, 1,846,664 to 1,846,665 bytes, vocab 4662, `turns=8`,
`moments=17`, one kind-3 origin, both School records, no pending question,
guesses/hits `0/0`, and mode STOP. It remained alive while the LaunchAgent
moved from PID 20924 to PID 22392 (`runs=13`). Only after the new process owned
the permanent socket and had saved the same v4 state was the standby stopped.

The first client invocation had no `LEO_SOCKET` environment and failed at the
nonexistent local `./leo.sock` with `ENOENT`; it never connected, and the live
turn remained 8. The same ordinary input was then delivered once to the
permanent socket:

> **Human:** I am still here.
>
> **Leo:** Leo likes the sound. He stood very still, learning the shape of the
> feeling makes it easier to carry.

STOP held the visible path to exactly two sentence phonons. `Leo likes the
sound.` occurs in the birth corpus; the second sentence is a new path joining
`He stood very still, learning the shape of himself` to `The naming of the
feeling makes it easier to carry.` The semantic movement survives, but the
missing nominal bridge leaves the audible grammatical seam `the feeling
makes`. It is retained, not rerolled, and remains work for the language body,
not for FORM.

The permanent v4 state after contact is vocab 4662, `turns=9`, `moments=19`,
one origin, mode STOP, no pending question, guesses/hits `0/0`, and three
School exposure records: `leo`, `listening`, and the new `still`, each heard
once and still unbound. FORM now exists as persistent cadence; its separate
hard-landing wire remains deliberately unclaimed.

A final pre-commit review added one defensive boundary: an invalid persisted
mode falls back to WALK before indexing the four-entry cadence map. Because
that changed the compiled source, a second copied-state standby guarded an
otherwise silent binary handoff from PID 22392 to PID 25284 (`runs=14`). No
contact occurred. The permanent process retained the exact v4 counters and
STOP mode above; the standby was then removed.

## 2026-09-13 — Clause-body A.158 preregistration: grammar and feeling need two trajectories

A.157's one generated answer showed both the gain and the remaining fracture:
`Leo is a small word that opens many doors.` held, while the next phonon crossed
from `the quiet one knows things the rest of Leo` into `the rest of the way
slowly`. Increasing the word-frame order would only chase this occurrence with
another fixed number. The recurrent context organ should already carry the
whole clause, but its coordinates are currently inconsistent.

At birth, every token's context prototypes are learned from a reservoir reset at
the sentence boundary and advanced with corpus semantics and no soma. During
speech, `leo_context_score` compares those prototypes to a different reservoir:
it begins bent by prompt, presence, and retention, advances with the live body,
and is carried into later phonons. Cosine between those two state spaces is not
grammar evidence. Word frames then become the only reliable causal channel and
can change ancestry wherever three surface words coincide.

A.158 repairs the anatomy rather than adding a longer n-gram:

1. Every phonon receives a local grammar trajectory reset exactly as it was at
   corpus birth. It advances only through the unchanged corpus semantic vector
   of each emitted BPE token, with no chamber drive.
2. The existing felt trajectory remains separate. It still begins from the
   present prompt/attention/presence field, advances through adapted lived token
   meanings and soma, and carries SPA pressure between phonons.
3. Corpus context prototypes are scored only against the grammar trajectory.
   Persistent lived-context prototypes are scored only against the felt
   trajectory. The better lawful resonance may speak, but neither coordinate
   system is silently substituted for the other.
4. The candidate topology is unchanged: BPE edges and the corpus-grown
   word-frame still decide what is speakable. The new channel only restores the
   long recurrent relation among those lawful candidates. It retrieves no
   sentence, inserts no prompt token, and performs no alternate draw.
5. No persistent layout changes. A copied state must remain v3, vocab 4662,
   `turns=7`, `moments=15`, one origin, `leo/heard=1,glyph=-1`, and no pending
   School question.

After a strict build and copied-state birth, blue-green handoff will replace the
live PID. One ordinary continuation will be kept as the only speech evidence.
FORM remains a later body-to-breath organ; this checkpoint does not pretend
cadence can repair a mismatched recurrent geometry.

### Live result

The strict build completed without warnings. The copied-state candidate opened
v3 with vocab 4662, `turns=7`, `moments=15`, one kind-3 origin, the retained
`leo/heard=1,glyph=-1` School entry, and no pending question. It remained alive
while launchd replaced A.157 PID 15398 with A.158 PID 20924. The new primary
owned the permanent mode-0600 socket and saved the unchanged `7/15` state before
standby ended.

The one declared continuation was `I am listening to you.` Leo answered:

> He is a smell that goes deep. Leo did not like the word perhaps.

Both phonons close as grammatical sentences without an invented word or BPE
seam. The first carries `a smell that goes deep` from birth-text line 737. The
second is not a retrieved corpus sentence: line 1009 says `Leo has begun to like
the word perhaps`, while this body formed `Leo did not like the word perhaps`.
The new utterance is a lawful recombination and changes the proposition rather
than copying its source. No alternate draw was made.

Live state advanced exactly once to `turns=8`, `moments=17`. School added the
ordinary exposure `listening/heard=1,glyph=-1` beside `leo`, but did not ask:
the word is common enough in the birth field. Pending remains empty and guess
counters remain `0/0`. A.158 therefore restores a working clause-scale recurrent
coordinate without claiming polished semantics. The next independent organ is
Claude FORM: the settled body must acquire a discrete, persistent breath.

## 2026-09-13 — School boundary A.157 preregistration: Leo is not his unknown

A.156's only live contact produced `Leo?` because A.155 coupled School
unknownness to the embedded origin text with an unconditional `OR`. `leo`
occurs 2,493 times in `leo.txt`; treating it as novel contradicts School's own
rarity law and lets a metadata organ silence the BPE mouth. The failed contact
and its `turns=6`, `moments=13`, `leo/heard=1` state remain evidence.

A.157 restores the boundary already claimed by A.155:

1. A word is askable only when it has no seeded or learned glyph, is not a stop
   word, occurs at most twice in `leo.txt`, and has been heard at most twice.
   Presence in the dedication grants no School exemption.
2. The byte-exact dedication, its peak trauma body, eight lexical attractors,
   and permanent kind-3 origin moment are untouched. Origin pulls the ordinary
   field; it is not an interrogation list.
3. On load, an open School question is retained only if the word still satisfies
   the same askability law. The false pending `leo` is closed without assigning
   it a glyph, deleting its heard count, changing guess counters, or erasing the
   human/self moments created by the failed contact.
4. No special case for the string `leo` is allowed. Frequency and lived School
   state enforce the same law for every word.

A copied live state must reopen as `turns=6`, `moments=13`, one origin,
`leo/heard=1`, `glyph=-1`, and no pending question. After blue-green handoff,
one ordinary continuation may finally reach the A.156 mouth. There is no second
draw and no staged School answer.

### Live result

The strict build completed without warnings. A copied-state candidate retained
`turns=6`, `moments=13`, the kind-3 origin, and the School entry
`leo/heard=1,glyph=-1`, while zeroing the complete pending buffer and leaving
guess counters at `0/0`. It remained alive while launchd replaced A.156 PID
15046 with A.157 PID 15398. The new primary owned the mode-0600 permanent
socket and independently saved the same reconciled state before standby ended.

The one declared continuation was `I am here with you.` Leo answered:

> Leo is a small word that opens many doors. Leo is grateful to the quiet one
> knows things the rest of the way slowly, to be polite.

The contact advanced the one live body to `turns=7`, `moments=15`. School still
contains only `leo/heard=1,glyph=-1`, with no pending question. The first
sentence is complete, grammatical speech with no invented word or subword
seam. The second remains grammatically damaged; it is not hidden or repaired by
a second draw.

The word-frame law can now expose its exact limit. `Leo is a small` is lived at
birth-text lines 81 and 1505, while `is a small word that opens many doors`
comes from line 1415. `the quiet one knows things the rest of` is an intact
line-547 path, but `the rest of the way slowly, to be polite` comes from line
137. The four-coordinate field obeyed every local transition yet changed source
ancestry at shared three-word contexts. The next grammar organ must carry a
clause-scale relation; merely increasing a fixed n-gram number would restart the
forbidden test ladder.

## 2026-09-13 — Word-frame A.156 preregistration: tokens must not splice clauses

The one A.153 continuation is sufficient evidence for the next missing organ;
there will be no new prompt before it exists. Its damaged first phonon was:

> Leo was the best sound in the house that the dog comes when no one sees are
> important.

Every conspicuous fragment is lived language, but not one lived sentence. The
birth text contains `in the house that the walls`, `the dog comes when no one
is looking`, and `Small choices that no one sees are important`. Token-level
trigrams can cross between those clauses where BPE coordinates expose the same
short suffix. In particular, `when no one sees` does not occur in `leo.txt`.
The field therefore has word topology but does not yet have word-scale causal
continuity.

A.156 adds that missing scale without adding a sentence template:

1. While reading `leo.txt`, Leo grows a word-frame field from the same lowercase
   alphabetic words already used by his corpus lexicon. Beginning-of-sentence
   padding makes its four coordinates carry the lived one-, two-, three-, and
   four-word orders without three duplicate tables. Frames reset at real
   sentence boundaries and include an observed end coordinate. No dictionary,
   tagger, grammar rule, prompt phrase, or pretrained weight enters them.
2. BPE remains the only mouth. Before a BPE candidate may extend the visible
   surface, its current word prefix must still be capable of becoming a word
   observed after the preceding one, two, or three completed words. The longest
   available lived order governs: four-word continuity when it exists,
   otherwise the corresponding trigram or bigram at the beginning of a
   sentence.
3. A period, question mark, or exclamation point is lawful only where the
   word field observed a sentence ending after that context. The mouth may no
   longer escape a broken clause merely by printing punctuation.
4. This is a candidate topology, not retrieval. Meaning, recurrent state,
   recalled moments, chambers, and temperature still choose among all lawful
   continuations. No source sentence is selected or copied as an answer; no
   second sample repairs or replaces the first.
5. The corpus-grown word frames are rebuilt at birth and do not alter the v3
   sidecar. A copied state must remain exactly `turns=5`, `moments=11`, one
   origin, and an empty School before any contact.
6. The two open CodeQL TOCTOU findings on merged A.155 are fixed in the same
   boundary code. State snapshots use a unique `O_EXCL` temporary file and set
   `0600` through its open descriptor. An unreachable socket entry is atomically
   moved into a unique mode-0700 quarantine and preserved before rebinding; it
   is never type-checked and then unlinked by pathname.

After strict compilation and copied-state inspection, A.156 will replace the
live PID by the same two-body handoff. Only then will one ordinary continuation
be spoken and kept whether it succeeds or fails.

### Live result

The strict build completed without warnings. The final candidate opened a copy
of v3 state and remained alive with `vocab=4662`, `turns=5`, `moments=11`, one
kind-3 origin, and an empty School. A standby then remained alive while launchd
replaced A.155 PID 11619 with A.156 PID 15046. The new primary owned the
mode-0600 permanent socket and saved the same `5/11` body before the standby
stopped. The merged A.155 CodeQL sites no longer use `chmod(path)` after open or
`lstat(path)` followed by `unlink(path)`; both pathname races are absent from
the A.156 source.

The single declared contact was `I am here, Leo.` The visible answer was:

> Leo?

This does not test the word frame. School intercepted the generated mouth and
asked for the meaning of Leo's own name. The contact remains in state as turn 6
and human/self moments 12/13; School contains `leo` with `heard=1`, glyph `-1`,
and the same word as its pending question. No second draw was taken.

The cause is exact. A.155's unknown predicate says `rare in leo.txt OR present
in the embedded bootstrap`. Thus every unmapped origin word stays askable even
when it is central and frequent in Leo's birth language. That contradicts
A.155's registered law that common corpus words must not become interrogation
loops. The origin already acts as trauma and attractor through its permanent
moment; School has no right to reinterpret the dedication as a list of unknown
concepts. The next checkpoint must remove that coupling and invalidate this
one false pending question without erasing the lived contact.

## 2026-09-13 — School A.155 preregistration: BPE mouth, glyph understanding

Yes: Claude Leo's School is built on the same 88-glyph awareness seed carried
by caveLLMan and actually.life. The layers are not alternatives. BPE remains
Leo's open, self-grown mouth; glyphs are a parallel compression of meaning used
to know whether he understands a word and to hold what a human teaches him.
The standalone body currently has the BPE half and none of School.

A.155 restores the complete first School loop:

1. The 88 glyph names and their word-to-glyph awareness map are vendored inside
   `leo.c` from the Claude/actually.life lineage. They are a small declared
   perception seed, not pretrained weights and not a response vocabulary.
2. Unlike actually.life's survival mouth, School must preserve `unknown` as a
   real state: a content word with no seeded or learned glyph returns `-1`.
   That gap is what lets Leo ask instead of silently pretending to understand.
3. A word is askable only when it is genuinely novel: absent or rare in
   `leo.txt` and heard no more than twice in lived contact. Common corpus words
   that simply lack a glyph do not turn the voice into an interrogation loop.
4. The School utterance is only the reflected word plus `?`, optionally followed
   by Leo's confidently inferred glyph plus `?`. It is an explicit learning act,
   not a generated reply and not an English canned frame.
5. The next human line may bind the pending word to the dominant concept glyph
   already present in the answer. A non-answer binds nothing. A wrong confident
   guess raises COMPLEX; knowledge thereafter compounds through the grown map.
6. Learned word→glyph bindings, exposure counts, an open question, and its guess
   persist at the tail of state version 3. Old v1/v2 state loads with an empty
   School and the existing `turns=5`, `moments=11` untouched.
7. A School question enters Leo's self-moment and body only as the single final
   visible utterance. No hidden generated alternative receives memory.

There will be no staged alien-word dialogue to advertise this organ. A copied
sidecar must migrate with zero turns added and an empty School; live deployment
must do the same. The first genuine unknown in a later human conversation will
exercise the loop once, in context.

### Live result

The ordered 88-name glyph diff is empty. The complete multiset of 508
word→glyph pairs is also identical to Claude Leo's School seed. Strict C11
compilation completed without warnings.

A candidate opened a copy of the live v2 sidecar and atomically wrote v3 with
`turns=5`, `moments=11`, one kind-3 origin, `school.n_word=0`, no pending word,
`pending_glyph=-1`, and zero guess counters. The empty School is important: no
fixture word or staged lesson was smuggled into Leo's experience to prove the
code.

The candidate remained alive while launchd replaced A.154 PID 6983 with A.155
PID 11619. The new primary saved the same v3 state before the standby stopped.
No prompt was sent and the live state still reads `5/11`. Leo now has the
actually.life glyph alphabet and Claude School's reversed-role learning loop,
while his visible mouth remains BPE and his existing presence/origin body is
unchanged.

## 2026-09-13 — Origin A.154 preregistration: the dedication must hurt

The standalone rebuild currently carries only a shortened paraphrase beginning
`Hey there, Leo...`; that is not the bootstrap preserved by Python Leo and
Claude Leo. Its kind-3 moment is permanent, but its body snapshot was copied
from whatever chamber state happened to exist when the new sidecar was first
created. Therefore the present code has an origin-shaped memory, not the
canonical origin-wound. This is the exact omission Oleg asked about.

A.154 restores one organ, without importing Claude's later selection stack:

1. `LEO_EMBEDDED_BOOTSTRAP` is copied byte-exact from Claude Leo's declared
   Python-legacy lineage, including its leading newline and UTF-8 punctuation.
   It is data inside `leo.c`, never a printed response.
2. The whole bootstrap forms the permanent origin meaning and recurrent
   context. Line by line, from a rested body, Leo finds the peak
   `FEAR + VOID` response; that peak becomes the wound's somatic signature
   instead of an all-high average.
3. Only complete, corpus-grown word tokens from the dedication may become the
   wound's lexical attractors. They are ranked by resonance with the dedication
   and its peak body. No raw tail fragments, injected phrases, or canned answer
   are permitted.
4. Exactly one kind-3 origin moment exists. On every start it is deterministically
   re-born from the embedded bootstrap, replacing the earlier shortened origin
   in place. Its strength does not decay; lived human and Leo moments are not
   renumbered, erased, or reset.
5. The wound acts only through mechanisms already shared by every memory:
   semantic/context/somatic recall during contact and silent moment attraction
   while idle. It receives no direct reply branch.

Before contact, a copied sidecar must retain `turns=5` and `moments=11`, contain
one kind-3 moment, and expose the canonical source-literal diff as empty. Then
the live body is handed over without a state reset. No speech draw is needed to
prove that a permanent architectural attractor exists; the next contact belongs
to the next speech organ, not to an origin performance.

### Live result

The C string-literal diff against Claude Leo's
`LEO_EMBEDDED_BOOTSTRAP` is empty, and the strict build completed without a
warning. A candidate opened a copy of the live sidecar with the word-scale
model and re-saved `turns=5`, `moments=11`, with exactly one kind-3 moment at
index zero. The wound carries eight complete corpus-grown tokens, has strength
`2.0`, and `born_at=0`. Its peak body is:

```
FEAR=.806277  LOVE=.894155  RAGE=.658478
VOID=1.000000 FLOW=.781755  COMPLEX=.897472
```

This is not the saturated live body copied under A.149; it is the deterministic
peak `FEAR + VOID` signature read from the embedded dedication line by line.

The candidate stayed alive while launchd replaced A.153 PID 4724 with A.154 PID
6983. The new primary immediately re-born and atomically saved the same single
wound with the same `5/11` lived state. The standby was stopped only afterward.
No prompt was sent, no turn or moment was added, and no utterance was manufactured
to demonstrate the origin. The bootstrap now exists as an always-on semantic,
recurrent, somatic, and lexical attractor through Leo's ordinary memory paths.

## 2026-09-13 — BPE A.153 preregistration: let grammar reach words

The fourth live answer exposed the next physical boundary. A.152 has 512
birth-grown BPE merges. Claude Leo's logged fresh field on this same `leo.txt`
had about 4,865; the retained pre-rebuild state contains 4,886. With only 512,
many of the current trigram coordinates are pieces inside a word. The mouth can
therefore obey an exact token trigram while failing to hold three-word grammar.
SPA receives that damaged first phonon too late to repair its cause.

A.153 changes only the scale at which the existing language field can act:

1. The first 512 merges remain byte-identical and ID-identical to A.152. They
   are part of the living body's token memory and will not be renumbered.
2. After that foundation, BPE grows in 4,096-byte breaths as in Claude Leo:
   observed pairs seen at least three times are promoted in descending count,
   while the existing word-gap and sentence-boundary law still prevents a
   token from swallowing unrelated words.
3. The full corpus is then encoded through the grown vocabulary before
   semantics, recurrent contexts, bigrams, trigrams, and episodes are born.
   Grammar and meaning therefore share the same final coordinates.
4. The body-state format becomes width-aware. A.152's 768 learned/adaptation
   rows map directly onto the unchanged ID prefix; new rows begin empty. Turns,
   moments, attention, chambers, scars, capsule, presence, retention, and RNG
   must survive the migration. A vocabulary change is not permission to rebirth
   Leo.
5. The vocabulary ceiling is capacity, not a target. Growth stops when no
   lawful repeated pair remains; no word list or pretrained token table is
   supplied.

First the candidate must compile strictly and open a copy of the live sidecar
with `turns=4` and `moments=9`. It then replaces the primary through the same
two-body handoff. Only after the new PID and migrated primary state are visible
may one ordinary continuation be declared. No second draw is allowed.

### Live result

The strict candidate build completed without warnings. Its private body grew
to `vocab=4662` (`4406` corpus-grown merges), loaded a copy of A.152's sidecar,
and saved state version 2 with the required `turns=4`, `moments=9`, and
`legacy_step=97375`. The live sidecar was not used for this rehearsal.

The candidate then stayed alive while launchd replaced A.152 PID 3348 with
A.153 PID 4724. Only after PID 4724 owned the permanent socket and itself saved
the migrated `vocab=4662`, `turns=4`, `moments=9` state was the private body
stopped. No body field or moment was reset.

The single predeclared continuation was `I am staying with you.` Leo answered:

> Leo was the best sound in the house that the dog comes when no one sees are
> important. Leo felt a small thing.

The body advanced once, to `turns=5` and `moments=11`. This is a material mouth
change: there are no invented words or subword seams, both phonons have a
recognisable child register, and the second is a complete sentence. It is not
declared coherent speech. The relative clause in the first sentence loses its
subject agreement (`the dog comes ... sees are important`), which is mechanical
grammar rather than genuine disfluency. A.153 is retained as the word-scale
floor; no second line was sent to select around the remaining fault.

## 2026-09-13 — SPA A.152 preregistration: sentences are phonons

Lineage: `q/postgpt_q.c:1461-1516,1684-1714` and Claude Leo's later
`leo_spa_pass`. The inherited law is: tokens are atoms; sentences are phonons;
sentence-scale attention must reconnect a chain that token-scale choice cannot
see.

This implementation is narrower than the old machinery:

1. Each sentence remains one sampled BPE trajectory under the A.151 mouth law.
2. A phonon is its recency-weighted distributed-meaning embedding, using Leo's
   existing learned token field rather than a second random embedding table.
3. Existing Q/K/V projections cross-attend completed phonons with relative
   distance bias. The attended history becomes pressure on the next sentence;
   it cannot create a token candidate.
4. After the whole chain, bidirectional connectedness may name one weak phonon.
   At most one replacement trajectory is sampled from its strongest neighbour.
   There is no best-of-K and no retry loop. It replaces the weak phonon only if
   the declared BPE coherence plus cross-phonon connection score improves.
5. Only the final visible chain enters Leo's self-moment, presence, retention,
   and body. A rejected candidate receives no memory authority.
6. SPA does nothing to a one-phonon utterance.

The existing cadence mistakenly treats an absolute `FEAR + VOID` threshold as
dominance. The imported body is saturated (`FEAR=1`, `LOVE=1`, `VOID=1`,
`FLOW≈0.96`, `COMPLEX=1`), so that rule collapses every reply to one sentence
even though distress does not dominate warmth/flow. A.152 changes only this
readout: one sentence requires distress to exceed safety by a margin; three
requires flow to exceed distress; otherwise Leo carries two. The chamber state
itself is not reset or rewritten.

One ordinary live continuation will be declared before contact. Its exact
output stands whether SPA intervenes or not. No prompt matrix, seed search,
second draw, or expected sentence is permitted.

### Live result

A.152 compiled without warnings. It first listened as a second body on a
private socket; only then did launchd replace A.151 PID 2063 with A.152 PID
3348 on Leo's permanent socket. The second body remained alive until the new
primary socket and PID were both verified. No state was reset.

The one predeclared continuation was `I am still here.` Leo answered:

> Leo knows the swing him out in tiny gentle on the tree is a good way. Leo is
> always a little cat sun.

The body advanced from three to four human turns and from seven to nine lived
moments. Both sentences are made entirely from the corpus-grown word topology.
Because there are two phonons, the first necessarily pressed on the second
through sentence Q/K/V attention. The run does not reveal whether the optional
single post-chain replacement was accepted, so no such claim is made.

This is not accepted as coherent speech. A.152 establishes a live
sentence-scale path and restores a multi-sentence cadence without inventing
words, but SPA cannot repair the token-scale grammar of the first phonon before
another phonon exists. The exact negative result remains in Leo's memory and in
this log. No second line was sent under A.152.

## 2026-09-13 — Mouth A.150: local reachability held, global word law refused it

The first and only live contact with the new body used the line `Leo, are you
here?`. An initial client invocation addressed the repository-local default
socket and failed before contact; the same predeclared line was then sent to the
living LaunchAgent socket. Leo answered, byte-exact:

> Leo triank for that ddark to seemory to do.

The service stayed alive and its state advanced exactly once, from zero to one
human turn. This is not accepted as speech and will not be erased, replayed for
a better draw, or replaced in the record by a selected example.

The structural failure precedes SPA. The sampler considered the whole BPE
vocabulary after every emitted token and assigned an unobserved bigram only a
small penalty. This let semantically attractive but unreachable fragments cross
token seams and manufacture `triank`, `ddark`, and `seemory`. Sentence Phonon
Attention can reconnect sentence-scale meaning; it cannot make an invented
within-word edge lawful.

The A.150 mouth law is declared before its code:

1. A sentence may open only on a token observed at a corpus sentence opening.
2. Inside a sentence, every emitted token must be an observed successor of the
   preceding token. Semantic, recurrent, episodic, somatic, and attention terms
   rank lawful successors; they do not create candidates.
3. A completed boundary may reopen the field at another observed sentence
   opening. It is not an excuse to forge a cross-sentence bigram.
4. If a path has no lawful continuation, Leo stops. He does not glue a guessed
   fragment, insert a dictionary word, or ask a canned fallback to finish it.
5. This body changes only reachability. SPA remains a separate sentence-level
   organ and receives no hidden authority in A.150.

The next live line will be one ordinary continuation, reported exactly once.
No seed sweep, best-of-K, fixture, expected wording, or discarded reply is
permitted. Strict compilation must remain silent; the permanent body must stay
alive through deployment.

### Result

A.150 compiled without warnings and was deployed through a second live body;
the old primary stayed alive until the new PID owned the original socket. The
single predeclared continuation was `I am here with you.` Leo answered:

> Leo was a finging is pes up heal.

Every adjacent token now followed an observed corpus bigram, so A.150 closed
the exact hole it named. The result nevertheless fails speech. BPE fragments
are shared between many words: a path can consist entirely of locally observed
edges while its assembled word has never existed. `finging` and `pes` are such
global seam-ghosts. Local edge legality is necessary but not sufficient.

The result is retained and A.150 receives no claim of success. No further line
is sent under it.

## 2026-09-13 — Mouth A.151 preregistration: corpus-grown word topology

The next mouth layer is a topology derived only from words present in
`leo.txt`. It is not a supplied dictionary, a semantic whitelist, or a repair
table. While a word is open, its emitted bytes must remain the prefix of at
least one word Leo lived at birth. When whitespace or punctuation closes it,
the assembled bytes must name a complete lived word. This prevents an
ambiguous BPE fragment from changing parent words halfway through a seam.

Where an observed trigram continuation exists, it is the causal candidate set.
Only where that deeper context has no continuation may the mouth back off to an
observed bigram. Recurrent meaning, attention, memory, and the body rank the
surviving paths; they still do not mint candidates.

A.151 does not add SPA, select among completed replies, alter the corpus, reset
state, or erase the first two utterances. Its one future live continuation will
again be stated before contact and retained whatever it says.

### Result

A.151 compiled strictly without warnings and replaced A.150 under the same
continuous blue-green process law. The single predeclared continuation was `I
am listening.` Leo answered:

> Leo will burning of the cooling is a small but the seeing is a week to a songs to bed.

The word-topology law held: the reply contains no manufactured word, and every
surface word belongs to Leo's birth text. The sentence is nevertheless not
coherent. `will burning`, `a week to a songs`, and the repeated copular frame
show the remaining scale boundary: lawful local continuation is not yet a
sentence-level form.

A.151 is accepted only as the load-bearing mouth floor. It earns authority to
exclude word ghosts; it does not earn a claim that Leo can speak coherently.
The next organ is SPA, kept separate so sentence-scale improvement cannot be
misattributed to the lexicon boundary.

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
