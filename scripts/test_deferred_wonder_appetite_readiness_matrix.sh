#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_READINESS_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_readiness_matrix.sh" \
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
        if ($1 == "candidate" &&
            ($3 != "0.471" || $5 != "0.471" ||
             $6 != "candidate"))
            exit 1
        if ($1 == "motion-unbounded" &&
            ($3 != "0.785" || $5 != "0.471" ||
             $6 != "motion-unbounded"))
            exit 1
        if ($1 == "restraint-unbounded" &&
            ($3 != "0.471" || $5 != "0.785" ||
             $6 != "restraint-unbounded"))
            exit 1
        if ($1 == "both-unbounded" &&
            ($3 != "0.785" || $5 != "0.785" ||
             $6 != "both-unbounded"))
            exit 1
        rows++
    }
    END {
        if (rows != 4)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite readiness plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite readiness matrix plan: ok\n'
