#!/usr/bin/env bash
# Observe shadow proposals across real process death, save, and reload.
# Usage: scripts/shadow_life_probe.sh [life-dir] [output-dir]
# Seeds are controlled with LEO_DIALOGUE_SEEDS="83 137".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFE_DIR="${1:-$ROOT/scripts/dialogue_lives}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${2:-${TMPDIR:-/tmp}/leo-shadow-life-$STAMP}"
SEEDS="${LEO_DIALOGUE_SEEDS:-83}"
BIN="$OUT/leo.life"
ROWS="$OUT/receipts.tsv"
SESSIONS="$OUT/sessions.tsv"
EDGES="$OUT/sleep_edges.tsv"
SUMMARY="$OUT/summary.txt"

mkdir -p "$OUT/raw" "$OUT/input" "$OUT/state"
cc "$ROOT/leo.c" -O2 -lm -Wall -Wextra -o "$BIN" -lpthread
printf 'scenario\tseed\tproposal_turn\tprompt\treply\taction\ttarget\tconfidence\treasons\tobserved_turn\tnext_prompt\tnext_reply\tverdict\n' > "$ROWS"
printf 'scenario\tseed\tturn\tsession\tsession_seed\tprompt\n' > "$SESSIONS"

found=0
for life in "$LIFE_DIR"/*; do
    [ -d "$life" ] || continue
    found=1
    scenario="$(basename "$life")"
    for seed in $SEEDS; do
        state="$OUT/state/${scenario}.seed-${seed}.state"
        prompts="$OUT/input/${scenario}.seed-${seed}.all.txt"
        combined="$OUT/raw/${scenario}.seed-${seed}.all.log"
        : > "$prompts"
        : > "$combined"
        turn=0
        session=0

        for source in "$life"/*.txt; do
            [ -f "$source" ] || continue
            session=$((session + 1))
            session_seed=$((seed + session - 1))
            chapter="$(basename "$source" .txt)"
            input="$OUT/input/${scenario}.seed-${seed}.session-${session}.txt"
            raw="$OUT/raw/${scenario}.seed-${seed}.session-${session}.log"
            awk 'NF && $0 !~ /^[[:space:]]*#/' "$source" > "$input"
            while IFS= read -r prompt; do
                turn=$((turn + 1))
                printf '%s\n' "$prompt" >> "$prompts"
                printf '%s\t%s\t%d\t%d\t%d\t%s\n' \
                    "$scenario" "$seed" "$turn" "$session" "$session_seed" \
                    "$prompt" >> "$SESSIONS"
            done < "$input"
            printf '/quit\n' >> "$input"

            if [ "$session" -eq 1 ]; then
                "$BIN" --corpus "$ROOT/leo.txt" --chat --seed "$session_seed" \
                    --save "$state" < "$input" > "$raw" 2>&1
            else
                "$BIN" --load "$state" --chat --seed "$session_seed" \
                    --save "$state" < "$input" > "$raw" 2>&1
                if ! grep -Fq "[leo] loaded state from $state" "$raw"; then
                    printf 'session %s/%s (%s) did not load its prior state\n' \
                        "$scenario" "$chapter" "$seed" >&2
                    exit 1
                fi
            fi
            [ -s "$state" ] || { printf 'state was not saved: %s\n' "$state" >&2; exit 1; }
            printf '===== session %d: %s =====\n' "$session" "$chapter" >> "$combined"
            cat "$raw" >> "$combined"
        done

        [ "$session" -gt 1 ] || {
            printf 'life %s needs at least two session files\n' "$life" >&2
            exit 1
        }
        printf '/quit\n' >> "$prompts"
        awk -v scenario="$scenario" -v seed="$seed" -v prompt_file="$prompts" \
            -f "$ROOT/scripts/shadow_dialogue_report.awk" "$combined" >> "$ROWS"
    done
done

if [ "$found" -eq 0 ]; then
    printf 'no life directories found in %s\n' "$LIFE_DIR" >&2
    exit 1
fi

awk -f "$ROOT/scripts/shadow_receipt_summary.awk" "$ROWS" > "$SUMMARY"
awk -f "$ROOT/scripts/shadow_sleep_edges.awk" "$SESSIONS" "$ROWS" > "$EDGES"

cat "$SUMMARY"
printf '\nsleep-crossing receipts: %d\n' "$(( $(wc -l < "$EDGES") - 1 ))"
printf 'receipts: %s\nsleep edges: %s\nraw sessions: %s/raw\nstates: %s/state\n' \
    "$ROWS" "$EDGES" "$OUT" "$OUT"
