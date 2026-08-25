#!/usr/bin/env bash
# A.128: compose exact un- with one witnessed whole-word lexical family.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-negative-family-composition-$STAMP}"
EXPECTED="${LEO_NEGATIVE_FAMILY_COMPOSITION_CASES:-$ROOT/scripts/negative_family_composition_cases.tsv}"
INTERACTION="${LEO_NEGATIVE_FAMILY_COMPOSITION_INTERACTION:-$ROOT/scripts/negative_family_composition_interaction.tsv}"
VERIFY="${LEO_NEGATIVE_FAMILY_COMPOSITION_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_NEGATIVE_FAMILY_COMPOSITION_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing A.128 cases: %s\n' "$EXPECTED" >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$INTERACTION" ] || { printf 'missing A.128 interaction: %s\n' "$INTERACTION" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/negative_family_composition_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/negative-family-composition-fixture" -lpthread
"$OUT/negative-family-composition-fixture" > "$OUT/anatomy.tsv"
"$OUT/negative-family-composition-fixture" --interaction > "$OUT/interaction.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/anatomy.tsv"
    cmp -s "$INTERACTION" "$OUT/interaction.tsv"
fi

cat "$OUT/anatomy.tsv"
cat "$OUT/interaction.tsv"
printf 'result\tnegative-family-composition-exact\n'
printf 'A.128 negative family composition anatomy: %s\n' "$OUT"
