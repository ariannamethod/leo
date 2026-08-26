#!/usr/bin/env bash
# A.131: direct court for pairwise heard evidence on one admitted A.120 edge.
set -Eeuo pipefail

trap 'rc=$?; printf "family-heard-threshold anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-family-heard-threshold-anatomy-$STAMP}"
EXPECTED="${LEO_FAMILY_HEARD_THRESHOLD_CASES:-$ROOT/scripts/family_heard_threshold_cases.tsv}"
INTERACTION="${LEO_FAMILY_HEARD_THRESHOLD_INTERACTION:-$ROOT/scripts/family_heard_threshold_interaction.tsv}"
CORPUS_EXPECTED="${LEO_FAMILY_HEARD_THRESHOLD_CORPUS:-$ROOT/scripts/family_heard_threshold_corpus.tsv}"
VERIFY="${LEO_FAMILY_HEARD_THRESHOLD_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_FAMILY_HEARD_THRESHOLD_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing direct cases: %s\n' "$EXPECTED" >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$INTERACTION" ] || { printf 'missing interaction cases: %s\n' "$INTERACTION" >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$CORPUS_EXPECTED" ] || { printf 'missing corpus receipt: %s\n' "$CORPUS_EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/family_heard_threshold_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/family-heard-threshold-fixture" -lpthread
"$OUT/family-heard-threshold-fixture" > "$OUT/anatomy.tsv"
"$OUT/family-heard-threshold-fixture" --interaction > "$OUT/interaction.tsv"
"$OUT/family-heard-threshold-fixture" --corpus "$ROOT/leo.txt" > "$OUT/corpus.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/anatomy.tsv" || {
        diff -u "$EXPECTED" "$OUT/anatomy.tsv" >&2 || true
        exit 2
    }
    cmp -s "$INTERACTION" "$OUT/interaction.tsv" || {
        diff -u "$INTERACTION" "$OUT/interaction.tsv" >&2 || true
        exit 2
    }
    cmp -s "$CORPUS_EXPECTED" "$OUT/corpus.tsv" || {
        diff -u "$CORPUS_EXPECTED" "$OUT/corpus.tsv" >&2 || true
        exit 2
    }
fi

cat "$OUT/anatomy.tsv"
cat "$OUT/interaction.tsv"
cat "$OUT/corpus.tsv"
printf 'result\tfamily-heard-threshold-exact\n'
printf 'A.131 family heard threshold anatomy: %s\n' "$OUT"
