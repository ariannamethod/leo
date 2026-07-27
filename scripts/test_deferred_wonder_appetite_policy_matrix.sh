#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_POLICY_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_policy_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 5 || $1 != "case" || $2 != "history" ||
            $4 != "expected_policy" || $5 != "expected_result")
            exit 1
        next
    }
    {
        if (NF != 5 || seen[$1]++)
            exit 1
        if ($2 == "stable" && $4 != "eligible")
            exit 1
        if ($2 == "rising" && $4 != "drifting")
            exit 1
        if ($3 == "sustained" &&
            ($2 == "stable" ? $5 != "supported" : $5 != "missed"))
            exit 1
        if ($3 == "faded" &&
            ($2 == "stable" ? $5 != "overreach" : $5 != "restraint"))
            exit 1
        rows++
    }
    END {
        if (rows != 4)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite policy plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite policy matrix plan: ok\n'
