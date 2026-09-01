#!/usr/bin/env bash
# A.139: prove a still-unanswered Wonder may return twice without looping.
set -Eeuo pipefail

trap 'rc=$?; printf "second unanswered Wonder return anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-second-unanswered-wonder-return-a139-$STAMP}"
PROMPTS="$ROOT/scripts/fixtures/responsive_difficult_after_repair_a138_meal.txt"
A138_FROZEN="$ROOT/scripts/responsive_difficult_after_repair_a138_frozen.tsv"
EXPECTED_NATURAL="${LEO_SECOND_UNANSWERED_NATURAL:-$ROOT/scripts/second_unanswered_wonder_return_a139_natural.tsv}"
EXPECTED_SYNTHETIC="${LEO_SECOND_UNANSWERED_SYNTHETIC:-$ROOT/scripts/second_unanswered_wonder_return_a139_synthetic.tsv}"
VERIFY="${LEO_SECOND_UNANSWERED_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_SECOND_UNANSWERED_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED_NATURAL" ] || { printf 'missing natural receipt: %s\n' "$EXPECTED_NATURAL" >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED_SYNTHETIC" ] || { printf 'missing synthetic receipt: %s\n' "$EXPECTED_SYNTHETIC" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

expected_transcript="$(awk -F '\t' 'NR == 2 { print $9 }' "$A138_FROZEN")"
expected_state="$(awk -F '\t' 'NR == 2 { print $10 }' "$A138_FROZEN")"
LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
    LEO_NATURAL_PHASE=A.139 \
    LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM=replay \
    LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=35 \
    LEO_NATURAL_OPENING='Reproduce the exact A.138 body before a second return.' \
    LEO_NATURAL_REFERENCE_PREDICATION=1 \
    LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
    "$ROOT/scripts/natural_life_probe.sh" "$OUT/a138" \
    > "$OUT/a138.out"
[ "$(shasum -a 256 "$OUT/a138/visible_transcript.txt" | awk '{print $1}')" = "$expected_transcript" ]
[ "$(shasum -a 256 "$OUT/a138/state/leo.state" | awk '{print $1}')" = "$expected_state" ]

cc "$ROOT/scripts/second_unanswered_wonder_return_a139_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/second-unanswered-wonder-return-fixture" -lpthread
"$OUT/second-unanswered-wonder-return-fixture" \
    --natural "$OUT/a138/state/leo.state" "$OUT/natural-sleep.state" \
    > "$OUT/natural.tsv"
"$OUT/second-unanswered-wonder-return-fixture" \
    --synthetic "$OUT/synthetic-sleep.state" \
    > "$OUT/synthetic.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED_NATURAL" "$OUT/natural.tsv" || {
        diff -u "$EXPECTED_NATURAL" "$OUT/natural.tsv" >&2 || true
        exit 2
    }
    cmp -s "$EXPECTED_SYNTHETIC" "$OUT/synthetic.tsv" || {
        diff -u "$EXPECTED_SYNTHETIC" "$OUT/synthetic.tsv" >&2 || true
        exit 2
    }
fi

cat "$OUT/natural.tsv"
cat "$OUT/synthetic.tsv"
printf 'result\tsecond-unanswered-Wonder-return-observed\n'
printf 'A.139 second unanswered Wonder return anatomy: %s\n' "$OUT"
