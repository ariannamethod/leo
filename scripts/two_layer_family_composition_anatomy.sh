#!/usr/bin/env bash
# A.133: direct court for exactly two already-admitted A.120 family edges.
set -Eeuo pipefail

trap 'rc=$?; printf "two-layer family composition anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-two-layer-family-composition-anatomy-$STAMP}"
EXPECTED="${LEO_TWO_LAYER_FAMILY_COMPOSITION_EXPECTED:-$ROOT/scripts/two_layer_family_composition_anatomy.tsv}"
INTERACTION="${LEO_TWO_LAYER_FAMILY_COMPOSITION_INTERACTION:-$ROOT/scripts/two_layer_family_composition_interaction.tsv}"
VERIFY="${LEO_TWO_LAYER_FAMILY_COMPOSITION_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_TWO_LAYER_FAMILY_COMPOSITION_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing direct receipt: %s\n' "$EXPECTED" >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$INTERACTION" ] || { printf 'missing interaction receipt: %s\n' "$INTERACTION" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/two_layer_family_composition_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/two-layer-family-composition-fixture" -lpthread
"$OUT/two-layer-family-composition-fixture" > "$OUT/anatomy.tsv"
"$OUT/two-layer-family-composition-fixture" --interaction > "$OUT/interaction.tsv"

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
printf 'result\ttwo-layer-family-composition-exact\n'
printf 'A.133 two-layer family composition anatomy: %s\n' "$OUT"
