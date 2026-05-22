#!/usr/bin/env bash
# repl_stress.sh — throw a wide spread of prompts at Leo across seeds and
# FLAG weak replies, to surface bottlenecks (узкие места). No Python.
# Flags: EMPTY (no/"..."), SHORT (<15 chars), SALAD (>=4 bare single letters),
#        LOOP (a word repeated >=4x), DEAD (ON == OFF, prompt didn't move it).
# Usage: scripts/repl_stress.sh   (builds a temp ./leo.stress)
set -u
L="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$L/leo.stress"
cc "$L/leo.c" -O2 -lm -Wall -Wextra -o "$BIN" 2>/dev/null || { echo "build failed"; exit 1; }
SEEDS="42 7 123"

PROMPTS=(
  # known, single
  "the rain" "your mother" "the candle" "the window" "the door" "the smell"
  "the light" "the snow" "a book" "what is love" "the quiet" "the night"
  "the morning" "the house" "the garden" "the cat" "the bird" "the sound"
  # known-ish but rarer
  "the sea" "the moon" "the fire" "the star" "the floor" "the kettle"
  # multi-word / questions / commands
  "tell me about your mother" "do you like the rain" "what do you see"
  "where is the light" "tell me a story" "how are you"
  # emotional / abstract
  "i love you" "are you sad" "are you scared" "the fear" "the peace"
  # unknown to the corpus
  "are you hungry" "the ocean" "the mountain" "the computer" "javascript"
  # edge / degenerate
  "?" "a" "12345" "asdfjkl" "qwerty zxcvbn" "AAAA" "the the the"
)

flag_empty=0; flag_short=0; flag_salad=0; flag_loop=0; flag_dead=0; runs=0
worst=""
for p in "${PROMPTS[@]}"; do
  for s in $SEEDS; do
    runs=$((runs+1))
    on=$("$BIN"  --corpus "$L/leo.txt" --respond "$p" --seed "$s" 2>/dev/null | sed -n 's/.*leo> //p')
    off=$("$BIN" --corpus "$L/leo.txt" --respond "$p" --seed "$s" --no-presence 2>/dev/null | sed -n 's/.*leo> //p')
    f=""
    if [ -z "$on" ] || [ "$on" = "..." ]; then f="EMPTY"; flag_empty=$((flag_empty+1));
    elif [ ${#on} -lt 15 ]; then f="SHORT"; flag_short=$((flag_short+1)); fi
    singles=$(printf '%s' "$on" | grep -oE '\b[A-Za-z]\b' | wc -l | tr -d ' ')
    [ "$singles" -ge 4 ] && { f="$f SALAD($singles)"; flag_salad=$((flag_salad+1)); }
    maxrep=$(printf '%s' "$on" | tr 'A-Z' 'a-z' | tr -cs 'a-z' '\n' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    [ "${maxrep:-0}" -ge 4 ] && { f="$f LOOP(x$maxrep)"; flag_loop=$((flag_loop+1)); }
    [ "$on" = "$off" ] && { f="$f DEAD"; flag_dead=$((flag_dead+1)); }
    if [ -n "$f" ]; then
      printf "  [%-18s] seed %-3s %-22s %s\n" "$f" "$s" "\"$p\"" "$(printf '%s' "$on" | cut -c1-58)"
    fi
  done
done
echo "------------------------------------------------------------"
echo "runs=$runs  EMPTY=$flag_empty  SHORT=$flag_short  SALAD=$flag_salad  LOOP=$flag_loop  DEAD=$flag_dead"
rm -f "$BIN"
