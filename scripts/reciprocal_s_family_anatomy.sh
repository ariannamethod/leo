#!/usr/bin/env bash
# A.129: direct court for the closed, witnessed prefer <-> prefers relation.
set -Eeuo pipefail

trap 'rc=$?; printf "reciprocal-s-family anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-reciprocal-s-family-anatomy-$STAMP}"
EXPECTED="${LEO_RECIPROCAL_S_FAMILY_CASES:-$ROOT/scripts/reciprocal_s_family_cases.tsv}"
INTERACTION="${LEO_RECIPROCAL_S_FAMILY_INTERACTION:-$ROOT/scripts/reciprocal_s_family_interaction.tsv}"
VERIFY="${LEO_RECIPROCAL_S_FAMILY_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_RECIPROCAL_S_FAMILY_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing direct cases: %s\n' "$EXPECTED" >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$INTERACTION" ] || { printf 'missing interaction cases: %s\n' "$INTERACTION" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/reciprocal_s_family_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/reciprocal-s-family-fixture" -lpthread
"$OUT/reciprocal-s-family-fixture" > "$OUT/anatomy.tsv"
"$OUT/reciprocal-s-family-fixture" --interaction > "$OUT/interaction.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/anatomy.tsv" || {
        diff -u "$EXPECTED" "$OUT/anatomy.tsv" >&2 || true
        exit 2
    }
    cmp -s "$INTERACTION" "$OUT/interaction.tsv" || {
        diff -u "$INTERACTION" "$OUT/interaction.tsv" >&2 || true
        exit 2
    }
fi

cat "$OUT/anatomy.tsv"
cat "$OUT/interaction.tsv"
printf 'result\treciprocal-s-family-exact\n'
printf 'A.129 reciprocal final-s family anatomy: %s\n' "$OUT"
