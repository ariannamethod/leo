#!/usr/bin/env bash
# A.126 baseline: expose what the single-glyph School does with plural evidence.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-plural-answer-capacity-$STAMP}"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/plural_answer_capacity_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/plural-answer-capacity-fixture" -lpthread
"$OUT/plural-answer-capacity-fixture" --ablation > "$OUT/control.tsv"
"$OUT/plural-answer-capacity-fixture" > "$OUT/candidate.tsv"
awk 'NR == 1 || FNR > 1' \
    "$OUT/control.tsv" "$OUT/candidate.tsv" > "$OUT/anatomy.tsv"

cmp -s "$ROOT/scripts/plural_answer_capacity_cases.tsv" "$OUT/anatomy.tsv"

cat "$OUT/anatomy.tsv"
printf 'result\ttied-glyph-selection-abstains\n'
printf 'A.126 plural-answer capacity anatomy: %s\n' "$OUT"
