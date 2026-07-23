#!/usr/bin/env bash
# Reproducible multi-turn observatory for Leo's shadow scheduler.
# Usage: scripts/shadow_dialogue_probe.sh [scenario-dir] [output-dir]
# Seeds are controlled with LEO_DIALOGUE_SEEDS="83 137".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENARIO_DIR="${1:-$ROOT/scripts/dialogues}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${2:-${TMPDIR:-/tmp}/leo-shadow-dialogue-$STAMP}"
SEEDS="${LEO_DIALOGUE_SEEDS:-83}"
BIN="$OUT/leo.dialogue"
ROWS="$OUT/receipts.tsv"
SUMMARY="$OUT/summary.txt"

mkdir -p "$OUT/raw" "$OUT/input"
cc "$ROOT/leo.c" -O2 -lm -Wall -Wextra -o "$BIN" -lpthread

printf 'scenario\tseed\tproposal_turn\tprompt\treply\taction\ttarget\tconfidence\treasons\tobserved_turn\tnext_prompt\tnext_reply\tverdict\n' > "$ROWS"

found=0
for source in "$SCENARIO_DIR"/*.txt; do
    [ -f "$source" ] || continue
    found=1
    scenario="$(basename "$source" .txt)"
    input="$OUT/input/$scenario.txt"
    awk 'NF && $0 !~ /^[[:space:]]*#/' "$source" > "$input"
    printf '/quit\n' >> "$input"

    for seed in $SEEDS; do
        raw="$OUT/raw/${scenario}.seed-${seed}.log"
        "$BIN" --corpus "$ROOT/leo.txt" --chat --seed "$seed" < "$input" > "$raw" 2>&1
        awk -v scenario="$scenario" -v seed="$seed" -v prompt_file="$input" \
            -f "$ROOT/scripts/shadow_dialogue_report.awk" "$raw" >> "$ROWS"
    done
done

if [ "$found" -eq 0 ]; then
    printf 'no .txt scenarios found in %s\n' "$SCENARIO_DIR" >&2
    exit 1
fi

awk -f "$ROOT/scripts/shadow_receipt_summary.awk" "$ROWS" > "$SUMMARY"

cat "$SUMMARY"
printf '\nreceipts: %s\nraw transcripts: %s/raw\n' "$ROWS" "$OUT"
