#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_ADMISSION_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_admission_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 7 || $1 != "case" ||
            $2 != "expected_scored" ||
            $7 != "expected_status")
            exit 1
        next
    }
    {
        if (NF != 7 || seen[$1]++)
            exit 1
        if ($1 != "attested" || $2 != 16 ||
            $3 != 8 || $4 != 8 ||
            $5 != "0.471" || $6 != "0.471" ||
            $7 != "attested")
            exit 1
        rows++
    }
    END {
        if (rows != 1)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite admission plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite admission matrix plan: ok\n'
