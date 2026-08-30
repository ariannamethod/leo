#!/usr/bin/env bash
# A.135: prove that rejection of the only guess returns as a bare Wonder.
set -Eeuo pipefail

trap 'rc=$?; printf "single-hypothesis rejection return anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-single-hypothesis-rejection-return-$STAMP}"
EXPECTED="${LEO_SINGLE_HYPOTHESIS_REJECTION_EXPECTED:-$ROOT/scripts/single_hypothesis_rejection_return_expected.tsv}"
NATURAL_EXPECTED="${LEO_SINGLE_HYPOTHESIS_REJECTION_NATURAL:-$ROOT/scripts/single_hypothesis_rejection_return_natural.tsv}"
A134_FROZEN="$ROOT/scripts/responsive_a133_continuation_a134_frozen.tsv"
PROMPTS="$ROOT/scripts/fixtures/responsive_a133_continuation_a134_meal.txt"
VERIFY="${LEO_SINGLE_HYPOTHESIS_REJECTION_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_SINGLE_HYPOTHESIS_REJECTION_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing synthetic receipt: %s\n' "$EXPECTED" >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$NATURAL_EXPECTED" ] || { printf 'missing natural receipt: %s\n' "$NATURAL_EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/single_hypothesis_rejection_return_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/single-hypothesis-rejection-return-fixture" -lpthread
"$OUT/single-hypothesis-rejection-return-fixture" \
    --synthetic "$OUT/sleep.state" > "$OUT/synthetic.tsv"

IFS=$'\t' read -r _life _seed _fixture _prefix _api _prompts_sha \
    transcript_sha state_sha _rest < <(
        awk -F '\t' 'NR == 2 { print }' "$A134_FROZEN")
LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
    LEO_NATURAL_PHASE=A.135 \
    LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM=replay \
    LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=24 \
    LEO_NATURAL_OPENING='Reproduce the exact A.134 meal body.' \
    LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
    "$ROOT/scripts/natural_life_probe.sh" "$OUT/a134" \
    > "$OUT/a134.out"
[ "$(shasum -a 256 "$OUT/a134/visible_transcript.txt" | awk '{print $1}')" = "$transcript_sha" ]
[ "$(shasum -a 256 "$OUT/a134/state/leo.state" | awk '{print $1}')" = "$state_sha" ]
"$OUT/single-hypothesis-rejection-return-fixture" \
    --natural "$OUT/a134/state/leo.state" > "$OUT/natural.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/synthetic.tsv" || {
        diff -u "$EXPECTED" "$OUT/synthetic.tsv" >&2 || true
        exit 2
    }
    cmp -s "$NATURAL_EXPECTED" "$OUT/natural.tsv" || {
        diff -u "$NATURAL_EXPECTED" "$OUT/natural.tsv" >&2 || true
        exit 2
    }
fi

cat "$OUT/synthetic.tsv"
cat "$OUT/natural.tsv"
printf 'result\tsingle-hypothesis-rejection-return-exact\n'
printf 'A.135 single-hypothesis rejection return anatomy: %s\n' "$OUT"
