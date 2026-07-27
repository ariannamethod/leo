#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_HOLDOUT_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_holdout_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 6 || $1 != "case" ||
            $2 != "expected_overreach_rate" ||
            $6 != "expected_status")
            exit 1
        next
    }
    {
        if (NF != 6 || seen[$1]++)
            exit 1
        if ($1 == "confirmed" &&
            ($3 != "0.471" || $5 != "0.471" ||
             $6 != "confirmed"))
            exit 1
        if ($1 == "motion-failed" &&
            ($3 != "0.785" || $5 != "0.471" ||
             $6 != "motion-failed"))
            exit 1
        if ($1 == "restraint-failed" &&
            ($3 != "0.471" || $5 != "0.785" ||
             $6 != "restraint-failed"))
            exit 1
        if ($1 == "both-failed" &&
            ($3 != "0.785" || $5 != "0.785" ||
             $6 != "both-failed"))
            exit 1
        if ($1 == "coverage-starved" &&
            $6 != "coverage-starved")
            exit 1
        rows++
    }
    END {
        if (rows != 5)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite holdout plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite holdout matrix plan: ok\n'
