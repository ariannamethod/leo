#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_TRANSPORT_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_transport_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "case" ||
            $2 != "expected_exact" ||
            $10 != "expected_status")
            exit 1
        next
    }
    {
        if (NF != 10 || seen[$1]++)
            exit 1
        if ($1 == "transport-provisional" &&
            ($5 != "0.471" || $6 != "0.471" ||
             $7 != 1 || $8 != 1 || $9 != 1 ||
             $10 != "provisional"))
            exit 1
        if ($1 == "transport-motion-shift" &&
            ($5 != "0.785" || $7 != 0 || $8 != 1 ||
             $9 != 1 || $10 != "shifted"))
            exit 1
        if ($1 == "transport-restraint-shift" &&
            ($6 != "0.785" || $7 != 1 || $8 != 0 ||
             $9 != 1 || $10 != "shifted"))
            exit 1
        if ($1 == "transport-both-shift" &&
            ($7 != 0 || $8 != 0 || $9 != 1 ||
             $10 != "shifted"))
            exit 1
        if ($1 == "transport-coverage-shift" &&
            ($2 != 32 || $3 != 24 || $7 != 1 || $8 != 1 ||
             $9 != 0 || $10 != "shifted"))
            exit 1
        if ($1 == "transport-holdout-coverage-shift" &&
            ($2 != 32 || $3 != 24 || $7 != 1 || $8 != 1 ||
             $9 != 0 || $10 != "shifted"))
            exit 1
        if ($1 == "transport-observing" &&
            $10 != "observing")
            exit 1
        if ($1 == "transport-incompatible" &&
            $10 != "incompatible")
            exit 1
        rows++
    }
    END {
        if (rows != 8)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite transport plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite transport matrix plan: ok\n'
