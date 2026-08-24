#!/usr/bin/env bash
# A.125: separate a single offered answer plus expansion from ambiguous forms.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-natural-answer-form-anatomy-$STAMP}"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/natural_answer_form_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/natural-answer-form-fixture" -lpthread
"$OUT/natural-answer-form-fixture" > "$OUT/anatomy.tsv"
"$OUT/natural-answer-form-fixture" --interaction > "$OUT/interaction.tsv"
cmp -s "$ROOT/scripts/natural_answer_form_cases.tsv" "$OUT/anatomy.tsv"
cmp -s "$ROOT/scripts/natural_answer_form_interaction.tsv" "$OUT/interaction.tsv"

cat "$OUT/anatomy.tsv"
cat "$OUT/interaction.tsv"
printf 'result\tnatural-answer-form-factorial-separated\n'
printf 'A.125 natural-answer-form anatomy: %s\n' "$OUT"
