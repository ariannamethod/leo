#!/usr/bin/env bash
# presence_probe.sh — systematic presence measurement (no Python).
# Runs leo --respond on prompts across categories, ON vs --no-presence,
# same --seed. Reports: does the heard CONTENT word surface ON? does ON
# differ from OFF (channel live)?
#
# Usage: scripts/presence_probe.sh [seed]   (builds a temp ./leo.probe)
set -u
L="$(cd "$(dirname "$0")/.." && pwd)"
SEED="${1:-42}"
BIN="$L/leo.probe"
cc "$L/leo.c" -O2 -lm -Wall -Wextra -o "$BIN" 2>/dev/null || { echo "build failed"; exit 1; }

# prompt | content-word | category
PROBES=(
  "your mother|mother|parental"
  "tell me about your father|father|parental"
  "the grandmother|grandmother|parental"
  "the rain|rain|element"
  "the sea|sea|element"
  "the moon|moon|element"
  "the snow|snow|element"
  "the fire|fire|element"
  "the smell|smell|sensation"
  "the light|light|sensation"
  "the candle|candle|object"
  "a book|book|object"
  "the window|window|object"
  "the door|door|object"
  "what is love|love|abstract"
  "the quiet|quiet|abstract"
  "are you hungry|hungry|unknown"
  "asdfjkl|asdfjkl|noise"
)

hit=0; tot=0; live=0
printf "%-26s %-8s %-4s %-4s  %s\n" "prompt" "word" "ON?" "live" "reply (ON)"
for row in "${PROBES[@]}"; do
  p="${row%%|*}"; rest="${row#*|}"; w="${rest%%|*}"
  on=$("$BIN"  --corpus "$L/leo.txt" --respond "$p" --seed "$SEED" 2>/dev/null | sed -n 's/.*leo> //p')
  off=$("$BIN" --corpus "$L/leo.txt" --respond "$p" --seed "$SEED" --no-presence 2>/dev/null | sed -n 's/.*leo> //p')
  tot=$((tot+1))
  H=no; if echo "$on" | grep -qiw "$w"; then H=yes; hit=$((hit+1)); fi
  Lv=no; [ "$on" != "$off" ] && { Lv=yes; live=$((live+1)); }
  printf "%-26s %-8s %-4s %-4s  %s\n" "$p" "$w" "$H" "$Lv" "$(echo "$on" | cut -c1-66)"
done
echo "----"
echo "theme-word hit (ON): $hit/$tot   |   ON differs from OFF (live): $live/$tot"
rm -f "$BIN"
