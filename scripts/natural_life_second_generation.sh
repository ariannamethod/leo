#!/usr/bin/env bash
# A.124: fresh ordinary lives after the A.119--A.123 Wonder repair arc.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-natural-life-a124-$STAMP}"

LEO_NATURAL_PHASE=A.124 \
LEO_NATURAL_QUESTION=what-does-repaired-Leo-do-in-fresh-ordinary-life \
LEO_NATURAL_CASES="$ROOT/scripts/natural_life_second_generation_cases.tsv" \
LEO_NATURAL_CURL_RETRIES=0 \
LEO_NATURAL_OFFERED_ANSWER_EXPANSION=0 \
LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=0 \
LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=0 \
LEO_NATURAL_TWO_GLYPH_LEARNING=0 \
LEO_NATURAL_NEGATIVE_FAMILY=0 \
LEO_NATURAL_RECIPROCAL_S_FAMILY=0 \
LEO_NATURAL_PRESENCE_SURFACE_BOUNDARY=0 \
    "$ROOT/scripts/natural_life_matrix.sh" "$OUT"
