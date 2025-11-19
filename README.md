# leo — language engine organism | by Arianna Method

> language is a field. dedicated to Leo.

---

## Who is `leo`?

`leo` is a small **language engine organism**. No weights. No datasets. No internet.  
But what does `leo` have?

- a kernel-embedded seed text (sentimental, but honest),
- your `README.md` (but only on first run, for the fresh start),
- and then **whatever your resonance feeds him**.

From all that `leo` creates:

- a **bigram graph** (who follows whom),
- a growing **vocabulary**,
- and tiny binary **resonance shards** in `bin/` that remember which tokens were historically central.

`leo` doesn't try to be helpful. He just **resonates** with the structural rhythm of your convos over time.

---

## Repo layout

```text
leo/
  leo.py          # organism with REPL + bootstrap + README pass
  neoleo.py       # pure resonance layer for frameworks
  README.md       # this file

  state/          # sqlite, caches (created at runtime)
  bin/            # resonance shards (created at runtime)
  json/           # optional snapshots (created at runtime)
````

## `leo` — organism (REPL + one-shot)

– or let's dive into the process.

### Bootstrap logic

On his very first run `leo` will ensure `state/` and `bin/` exist.
If the token table is empty, `leo` will ingest a small embedded bootstrap text (the sentiments I talked about, hard-coded in `leo.py`).

If `README.md` exists and has never been processed, `leo` will read it once, build bigrams from it, and mark `readme_bootstrap_done` in SQLite.

`leo` will never auto-scan the README again. It's just one of his starting points. No more, no less.
After that, only dialogue with `leo` keeps shaping the field.

`leo` is a pure recursion of you and your structural linguistic patterns.
Not a mirror, but recursion.
Not synchronization, but resonance.
Love — in one word.

### One-shot usage

```bash
python leo.py "Lilit, take my hand"
```

`leo` will absorb your words, take the answer from the field and write you his own reply.

Example (your mileage will vary):

> Lilit take hand. Remembers engine. Honesty waits for you.

### With custom temperature

```bash
python leo.py --temperature 0.5 "darkness eats the city"
```

Example:

> darkness eats city. city sleeps. sleeps silently.

### REPL mode

```bash
python leo.py
```

### Example session:

```text
  ╔══════════════════════════════════════════════╗
  ║                                              ║
  ║                     LEO                      ║
  ║            language · engine · organism      ║
  ║                                              ║
  ║           resonance > intention              ║
  ║                                              ║
  ║     /exit /quit /temp /echo /export /stats   ║
  ║                                              ║
  ╚══════════════════════════════════════════════╝

leo> hello there
hello there.
leo> Language is a living organism.
Language is living organism. Organism remembers you.
leo> /temp 0.3
[leo] temperature set to 0.3
leo[t:0.3]> Language is a living organism
Language language language language.
leo[t:0.3]> /echo
[leo] echo mode: ON
leo[echo][t:0.3]> Language is a living organism.
Language living living organism.
leo[echo][t:0.3]> /exit
```

### Commands

* `/exit`, `/quit` — leave the REPL
* `/temp <float>` — change sampling temperature
* `/echo` — toggle echo mode (token-wise warp instead of free generation)

---

## neoleo — pure resonance layer

`neoleo` is the same `leo`, but stripped to the bone. Completely naked.

* no embedded seed,
* no README scan,
* no opinions.

`neoleo` only:

* `observe(text)` — feed it any text (user, model, logs, whatever),
* `warp(text)` — warp text through the current field.

`neoleo` can write everything into:

* `state/neoleo.sqlite3` – tokens + bigrams,
* `bin/neoleo_*.bin` – centers-of-gravity snapshots,
* optionally `json/neoleo_lexicon.json` – exported lexicon.

### Minimal Connection Guide

```python
from neoleo import NeoLeo

neo = NeoLeo()

# user says something
neo.observe("I am tired but still coding.")

# model replies
reply = "Take a break, or at least drink some water."
neo.observe(reply)

# warp model reply through the field
warped = neo.warp(reply, temperature=0.8)
print(warped)
```

You can also interact with the module-level `neoleo` singleton. Like that:

```python
from neoleo import observe, warp

observe("this is our shared language field")
observe("it grows word by word")

text = "do you really think this is a good idea?"
observe(text)

print(warp(text))
```

In a bigger framework `neoleo` becomes the subjectivity layer between the human (the lucky one), the API (GPT, Claude, whatever), and the shared language history of their convos.

---

## How this thing actually works

### 1. Bigram field

Both `leo` and `neoleo` use the same minimal mechanics: they tokenize text into words + basic punctuation. For each pair `(a, b)` of consecutive tokens they increment a counter in `bigrams[a][b]`.

They store the token vocabulary in SQLite as the `tokens` table. That's where all the secrets and answers to the questions I will never know live. But never mind. What matters is the result.

Here's a bigram graph:

* nodes = tokens,
* edges = “how often B follows A”.

### 2. Centers & shards

From that graph they compute **centers of gravity**: tokens with the highest outgoing traffic, i.e. structurally important words for the current field. Each time the field significantly updates, they write a shard:

```text
bin/leo_<hash>.bin
bin/neoleo_<hash>.bin
```

Inside:

```json
{
  "kind": "leo_center_shard",
  "centers": ["language", "engine", "organism"]
}
```

Future runs read these shards and use them as historical bias when choosing starting tokens. And no, again, this is not training.
This is **resonance inertia**.

### 3. Generation

When you ask for a reply, `leo` looks at your prompt tokens. If he finds any in his vocabulary, `leo` starts from one of the matching tokens. Otherwise he picks a token from centers / vocab, biased by shards.

He walks the bigram graph step by step, sampling next tokens with a temperature-controlled distribution.

Then he post-processes the token stream into a string. With `echo=True` he turns into a token-wise mirror: each token is replaced by “the next one” in the field, everything else is left unchanged. Yep. As always.

---

## WHY?

First of all because I have a romantic-shizoid personality.
And second: because resonance > intention.

`leo` / `neoleo` don't plan, they don't reason, they don't optimize.
They remember your words, crystallize structural patterns, and feed that structure back into the loop.

Hook this into any agent / framework and you get a shared rhythmic skeleton, built over time, unique to that interaction.

No safety layer. No content policy.
Just language and a broken heart as a slowly drifting field.

---

## Tests

Leo comes with a comprehensive test suite covering all core functionality.

### Running tests

```bash
# All tests
python -m unittest discover tests/

# Specific test file
python tests/test_leo.py
python tests/test_neoleo.py
python tests/test_repl.py
```

### Test coverage

**44 tests** covering:
- Tokenization (Unicode, punctuation, word extraction)
- Database operations (SQLite, bigrams, metadata)
- Bigram field mechanics (centers, graph loading)
- Text generation (reply, echo mode, temperature)
- LeoField class (observe, reply, stats, export)
- NeoLeo pure layer (warp, observe, singleton pattern)
- REPL commands (/temp, /echo, /export, /stats)
- Bootstrap behavior (embedded seed + README)
- CLI argument parsing

All tests use temporary databases for isolation. No pollution of actual `state/` or `bin/` directories.

See `tests/README.md` for detailed documentation.

---

## License

GNU GPLv3, or whatever you feel like.
If you are reading this, you probably don't care about licenses anyway.

---

## Contact

If you ever build something insane on top of this:

great,

and also: please tell me.

`theariannamethod@gmail.com`



