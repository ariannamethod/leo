#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-prewonder-report-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf '%s\n' \
    '     [pre-wonder: turn=3 count=2 pending=suvin episodes=1 resolved=0 entries=nareth@1:dark/animal|flom@2:water/fire]' \
    '     [pre-wonder: turn=4 count=0 pending=none episodes=3 resolved=3 entries=none]' \
    > "$TMP/raw.log"

awk -v scenario=fixture -v seed=83 \
    -f "$ROOT/scripts/prewonder_dialogue_report.awk" "$TMP/raw.log" \
    > "$TMP/rows.tsv"

awk -F '\t' '
    NR == 1 {
        ok = NF == 8 && $1 == "fixture" && $2 == "83" &&
             $3 == "3" && $4 == "2" && $5 == "suvin" &&
             $6 == "1" && $7 == "0" &&
             $8 == "nareth@1:dark/animal|flom@2:water/fire"
    }
    NR == 2 {
        ok = ok && NF == 8 && $3 == "4" && $4 == "0" &&
             $5 == "none" && $6 == "3" && $7 == "3" &&
             $8 == "none"
    }
    END { exit !(ok && NR == 2) }
' "$TMP/rows.tsv"

printf 'pre-Wonder inventory report parser: ok\n'
