#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_REGRET_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_regret_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 7 || $1 != "case" ||
            $6 != "expected_overreach_axis" ||
            $7 != "expected_missed_axis")
            exit 1
        next
    }
    {
        if (NF != 7 || seen[$1]++)
            exit 1
        if ($1 == "motion-heavy" &&
            ($3 != 3 || $4 != 3 || $6 != "0.375" ||
             $7 != "0.375"))
            exit 1
        if ($1 == "restraint-heavy" &&
            ($3 != 1 || $4 != 5 || $6 != "0.125" ||
             $7 != "0.625"))
            exit 1
        rows++
    }
    END {
        if (rows != 2)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite regret plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite regret matrix plan: ok\n'
