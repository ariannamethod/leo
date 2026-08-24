#!/usr/bin/env bash
# A.127: separate a strict offered pair from ambiguity and counterfeit plural form.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-two-glyph-learned-meaning-$STAMP}"
EXPECTED="${LEO_TWO_GLYPH_LEARNED_MEANING_CASES:-$ROOT/scripts/two_glyph_learned_meaning_cases.tsv}"
VERIFY="${LEO_TWO_GLYPH_LEARNED_MEANING_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_TWO_GLYPH_LEARNED_MEANING_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing A.127 cases: %s\n' "$EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/two_glyph_learned_meaning_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/two-glyph-learned-meaning-fixture" -lpthread
"$OUT/two-glyph-learned-meaning-fixture" --ablation > "$OUT/control.tsv"
"$OUT/two-glyph-learned-meaning-fixture" > "$OUT/candidate.tsv"
awk 'NR == 1 || FNR > 1' \
    "$OUT/control.tsv" "$OUT/candidate.tsv" > "$OUT/anatomy.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/anatomy.tsv"
fi

cat "$OUT/anatomy.tsv"
printf 'result\tstrict-offered-pair-learned\n'
printf 'A.127 two-glyph learned-meaning anatomy: %s\n' "$OUT"
