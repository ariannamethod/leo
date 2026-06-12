# leo / ariannamethod — the AML velocity bridge

Leo's breath is an **AML velocity operator**. The chambers quantize into a discrete
mode — `WALK` / `STOP` / `RUN` / `BREATHE` — with hysteresis, and the mode chisels
the form of every reply (its word budget). Those names are not a coincidence: they
are the family language's velocity operators. This folder is where AML reaches into
Leo, so an `.aml` script can read and set his breath the way `DESTINY` / `FIELD` /
`RESONANCE` directives edit a field. One physics, many bodies.

## The C contract (already in `leo.c`)

The breath is settable from outside. The AML runtime drives it through:

```c
void leo_mode_set(Leo *leo, int mode);   /* force the mode (a VELOCITY operator); mode < 0 = autonomous */
int  leo_mode_get(const Leo *leo);       /* read the current mode */
int  leo_mode_from_name(const char *s);  /* "STOP"/"WALK"/"RUN"/"BREATHE" -> mode id, or -1 */
```

`leo->mode_override` holds the forced mode (`-1` = the chambers choose autonomously).
`leo_mode_update` honours the override, then falls back to the hysteretic quantization.
A manual driver already exists for testing and for the listening marathon:

```
./leo --mode STOP --respond "do you love your mother"     # the held child, even on warmth
./leo --mode RUN  --chat                                  # the chatty run, all session
```

So the same prompt, forced into different moods, lands in different forms — exactly
what an `.aml` `VELOCITY` operator will do.

## What goes here (Oleg curates)

The AML **compiler / runtime** parts that Leo needs to parse and execute an `.aml`
breath script. The shape of the integration:

1. The compiler parses an `.aml` script and, on a `VELOCITY <mode>` directive,
   calls `leo_mode_set(leo, leo_mode_from_name(<mode>))`.
2. A `--aml <script>` host hook in `leo.c` loads the script and runs it (so the
   breath can be programmed, not only forced by `--mode`).
3. The vocabulary is unified (the reverse flow Mythos named): AML's base velocity
   set is `NOMOVE / WALK / RUN / BACKWARD`; Leo contributes the somatic operators
   `STOP` (≈ `NOMOVE`) and `BREATHE` (the exhale haiku has and AML lacks). Sewing
   the two gives the Method its full somatics, and the inertia (mode hysteresis +
   the `D4` debt override) becomes an axiom of the language, not a per-organism hack.

Leo's side is ready. The compiler lands here, curated.

## See also

`breath.aml` — a sample script (the target syntax; illustrative until the compiler
runs it). The full design and the state-dynamics разгадка are in `../LEOLOG.md`
(Phase A.6) and the Method memory.
