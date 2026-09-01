#!/usr/bin/env bash
# A.140: close a synthetic Wonder only after its second literal return.
set -Eeuo pipefail

trap 'rc=$?; printf "delayed answer after second return anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-delayed-answer-after-second-return-a140-$STAMP}"
EXPECTED="${LEO_DELAYED_SECOND_RETURN_EXPECTED:-$ROOT/scripts/delayed_answer_after_second_return_a140_expected.tsv}"
VERIFY="${LEO_DELAYED_SECOND_RETURN_VERIFY:-1}"

[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_DELAYED_SECOND_RETURN_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing expected receipt: %s\n' "$EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

cc "$ROOT/scripts/delayed_answer_after_second_return_a140_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/delayed-answer-after-second-return-fixture" -lpthread
"$OUT/delayed-answer-after-second-return-fixture" \
    "$OUT/before-answer.state" \
    "$OUT/after-answer.state" \
    "$OUT/resolved-sleep.state" > "$OUT/anatomy.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/anatomy.tsv" || {
        diff -u "$EXPECTED" "$OUT/anatomy.tsv" >&2 || true
        exit 2
    }
fi

cat "$OUT/anatomy.tsv"
printf 'result\tdelayed-answer-after-second-return-observed\n'
printf 'A.140 delayed answer after second return anatomy: %s\n' "$OUT"
