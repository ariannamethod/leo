#!/usr/bin/env bash
# A.130: direct court for an exact whole-word presence receipt in displayed speech.
set -Eeuo pipefail

trap 'rc=$?; printf "presence-surface-boundary anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-presence-surface-boundary-anatomy-$STAMP}"
EXPECTED="${LEO_PRESENCE_SURFACE_BOUNDARY_CASES:-$ROOT/scripts/presence_surface_boundary_cases.tsv}"
INTERACTION="${LEO_PRESENCE_SURFACE_BOUNDARY_INTERACTION:-$ROOT/scripts/presence_surface_boundary_interaction.tsv}"
VERIFY="${LEO_PRESENCE_SURFACE_BOUNDARY_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_PRESENCE_SURFACE_BOUNDARY_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing direct cases: %s\n' "$EXPECTED" >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$INTERACTION" ] || { printf 'missing interaction cases: %s\n' "$INTERACTION" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/presence_surface_boundary_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/presence-surface-boundary-fixture" -lpthread
"$OUT/presence-surface-boundary-fixture" > "$OUT/anatomy.tsv"
"$OUT/presence-surface-boundary-fixture" --interaction > "$OUT/interaction.tsv"

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
printf 'result\tpresence-surface-boundary-exact\n'
printf 'A.130 presence surface boundary anatomy: %s\n' "$OUT"
