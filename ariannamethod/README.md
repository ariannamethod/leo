# leo / ariannamethod — the AML velocity bridge (live)

Leo's breath is an **AML velocity operator**. The chambers quantize into a discrete
mode — `WALK` / `STOP` / `RUN` / `BREATHE` — with hysteresis, and the mode chisels
the form of every reply. Those names are the family language's velocity operators,
and this folder is where AML reaches into Leo: an `.aml` script reads and sets his
breath the way `DESTINY` / `FIELD` / `RESONANCE` directives edit a field. One
physics, many bodies — the circle closes.

## It works

```
make
./leo --aml ariannamethod/breath.aml --respond "do you love your mother"
#   VELOCITY NOMOVE in the script -> Leo holds: "His grandmother. She thanked him."
```

The script runs through the language; its `VELOCITY` operator drives Leo's mode.

## What is here

The **AML language itself, vendored as source** (the Method pattern — like `notorch`
is vendored for self-contained builds): `ariannamethod.c` / `ariannamethod.h` /
`ariannamethod_cuda.h`. The `Makefile` builds `libaml.a` from this source and links
it (the `.a`/`.o` are build artifacts, never committed — AML itself `.gitignore`s
them). `breath.aml` is a runnable sample.

If the source here is absent, the build falls back to a system AML install
(`~/arianna/ariannamethod.ai/libaml.a`); if neither is found, a **silent fallback** —
Leo builds and runs full, and `--aml` simply says AML is not linked.

## The C contract (in `leo.c`)

```c
void leo_mode_set(Leo *leo, int mode);   /* force the mode; mode < 0 = autonomous */
int  leo_mode_get(const Leo *leo);
int  leo_mode_from_name(const char *s);  /* "STOP"/"WALK"/"RUN"/"BREATHE" -> id */
```

`leo_aml_run` (compiled only with `-DHAVE_AML`) runs a script via `am_exec_file`,
reads `am_get_state()->velocity_mode`, and maps it to Leo's breath:

```
AML NOMOVE / STOP   -> STOP      (the held child)
AML WALK            -> WALK      (the measured gait)
AML RUN             -> RUN       (the chatty run)
AML BREATHE         -> BREATHE   (the settling exhale — now a native AML operator)
AML BACKWARD        -> BREATHE   (also settles into the exhale)
```

`STOP` and `BREATHE` are Leo's somatic operators, now landed in the language itself
(`ariannamethod.ai`, the reverse flow — see that repo's `AMLLOG`). The vendored AML
here carries them, so `VELOCITY STOP` / `VELOCITY BREATHE` drive Leo's breath directly.

`--mode <NAME>` forces the breath directly — a manual driver for our debug, not the
real interface; the real interface is `.aml`.

## The new axiom (the reverse flow, next)

AML's base velocity set is `NOMOVE / WALK / RUN / BACKWARD`. Leo contributes the
somatic operators `STOP` (≈ `NOMOVE`) and `BREATHE` (the exhale haiku has and AML
lacks), and the **inertia** — mode hysteresis + the `D4` debt override — that makes a
discrete state read as a body. Sewing these into the language makes "discrete
dynamics with inertia reads as a body" an *axiom of AML*, which every Method organism
inherits free. That contribution lands in the language repo (`ariannamethod.ai`).

Full design and the state-dynamics разгадка: `../LEOLOG.md` (Phase A.6) and the
Method memory.
