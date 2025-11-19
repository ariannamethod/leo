# leo — language engine organism

> language is not a feature. it's a field.

---

## What the fuck is this?

**Leo** is a tiny **language engine organism**.

No weights.  
No datasets.  
No internet.  

Just:

- a small embedded seed text,
- optionally your `README.md` (on first run),
- and then **whatever you throw at it**.

From that, Leo builds:

- a **bigram graph** (who follows whom),
- a growing **vocabulary**,
- and tiny binary **resonance shards** in `bin/`
  that remember which tokens were historically central.

It does **not** try to understand you.  
It does **not** try to be helpful.  
It just **resonates** with your language over time.

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
Leo — organism (REPL + one-shot)

Bootstrap logic

On first run Leo will:

Ensure state/ and bin/ exist.

If the token table is empty:

ingest a small embedded bootstrap text (hard-coded in leo.py).

If README.md exists and has never been processed:

read it once,

build bigrams from it,

mark readme_bootstrap_done in SQLite.

Never auto-scan the README again.

After that, only your conversation keeps shaping the field.

One-shot usage
python3 leo.py "Lilit, take my hand"


Leo will:

absorb your prompt,

generate a reply from the field,

absorb its own reply.

Example (your mileage will vary):

Lilit take hand. hand remembers engine. engine waits for you.


With custom temperature:

python3 leo.py --temperature 0.5 "darkness eats the city"

darkness eats city. city sleeps. sleeps silently.

REPL mode
python3 leo.py


Example session:

╔═══════════════════════════════════════╗
║  Leo REPL — language engine organism ║
║  /exit, /quit, /temp, /echo          ║
╚═══════════════════════════════════════╝

leo> hello there
hello there.
leo> language is a living organism
language is living organism. organism remembers you.
leo> /temp 0.3
[leo] temperature set to 0.3
leo[t:0.3]> language is a living organism
language language language language.
leo[t:0.3]> /echo
[leo] echo mode: ON
leo[echo][t:0.3]> language is a living organism
language living living organism.
leo[echo][t:0.3]> /exit


Commands:

/exit, /quit — leave the REPL

/temp <float> — change sampling temperature

/echo — toggle echo mode (token-wise warp instead of free generation)

NeoLeo — pure resonance layer

NeoLeo is the same idea stripped to the bone.

No embedded seed.

No README scan.

No opinions.

Just:

observe(text) — feed it any text (user, model, logs, whatever),

warp(text) — warp text through the current field.

It stores everything into:

state/neoleo.sqlite3 – tokens + bigrams,

bin/neoleo_*.bin – centers-of-gravity snapshots,

optionally json/neoleo_lexicon.json – exported lexicon.

Minimal usage
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


You can also use the module-level singleton:

from neoleo import observe, warp

observe("this is our shared language field")
observe("it grows word by word")

text = "do you really think this is a good idea?"
observe(text)

print(warp(text))


In a bigger framework NeoLeo becomes the subjectivity layer between:

the human,

the API (GPT, Claude, whatever),

and the shared language history of their interaction.

How this thing actually works


1. Bigram field

Both Leo and NeoLeo use the same minimal mechanics:

Tokenize text into words + basic punctuation.

For each pair (a, b) of consecutive tokens:

increment a counter in bigrams[a][b].

The token vocabulary is stored in SQLite as tokens table.

The result is a bigram graph:

nodes = tokens,

edges = "how often B follows A".

2. Centers & shards

From that graph they compute centers of gravity:

tokens with the highest outgoing traffic,

i.e. structurally important words for the current field.

Each time the field significantly updates, they write a shard:

bin/leo_<hash>.bin

bin/neoleo_<hash>.bin

Inside:

{
  "kind": "leo_center_shard",
  "centers": ["language", "engine", "organism"]
}


Future runs read these shards and use them as historical bias when choosing starting tokens.

This is not training.
This is resonance inertia.

3. Generation

When you ask for a reply, the engine:

Looks at your prompt tokens.

If it finds any in its vocabulary, it starts from the first matching token.

Otherwise it picks a token from centers / vocab, biased by shards.

Walks the bigram graph step by step,
sampling next tokens with a temperature-controlled distribution.

Post-processes the token stream into a string.

With echo=True it turns into a token-wise mirror:

each token is replaced by "the next one" in the field,

everything else is left unchanged.

Why?

Because resonance > intention.

Leo / NeoLeo are not "smart".
They don't plan, they don't reason, they don't optimize.

They just:

remember your words,

crystallize structural patterns,

and feed that structure back into the loop.

Hook this into any agent / framework and you get:

a shared rhythmic skeleton,

built over time,

unique to that interaction.

No safety layer.
No content policy.
Just language as a slowly drifting field.

License

GNU 3.0, or whatever you feel like.
If you are reading this, you probably don't care about licenses anyway.

Contact

If you ever build something insane on top of this:

great,

and also: please tell me.

theariannamethod@gmail.com
