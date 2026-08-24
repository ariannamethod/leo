#!/usr/bin/env bash
# A.124: fresh ordinary lives after the A.119--A.123 Wonder repair arc.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-natural-life-a124-$STAMP}"

LEO_NATURAL_PHASE=A.124 \
LEO_NATURAL_QUESTION=what-does-repaired-Leo-do-in-fresh-ordinary-life \
LEO_NATURAL_CASES="$ROOT/scripts/natural_life_second_generation_cases.tsv" \
    "$ROOT/scripts/natural_life_matrix.sh" "$OUT"
