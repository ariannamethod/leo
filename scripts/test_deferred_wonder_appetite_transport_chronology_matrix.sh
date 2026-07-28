#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_TRANSPORT_CHRONOLOGY_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_transport_chronology_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 15 || $1 != "case" ||
            $2 != "expected_post_settled" ||
            $15 != "expected_status")
            exit 1
        next
    }
    {
        if (NF != 15 || seen[$1]++)
            exit 1
        if ($1 == "chronology-provisional" &&
            ($9 != "0.471" || $10 != "0.471" ||
             $11 != "0.471" || $12 != "0.471" ||
             $13 != 1 || $14 != 1 ||
             $15 != "provisional"))
            exit 1
        if ($1 == "chronology-early-shift" &&
            ($9 != "0.694" || $11 != "0.324" ||
             $13 != 1 || $15 != "early-shifted"))
            exit 1
        if ($1 == "chronology-recent-shift" &&
            ($9 != "0.324" || $11 != "0.694" ||
             $13 != 1 || $15 != "recent-shifted"))
            exit 1
        if ($1 == "chronology-both-shift" &&
            ($9 != "0.694" || $12 != "0.694" ||
             $13 != 1 || $15 != "both-shifted"))
            exit 1
        if ($1 == "chronology-ecology-shift" &&
            ($5 != 12 || $6 != 4 || $7 != 4 || $8 != 12 ||
             $13 != 1 || $14 != 0 ||
             $15 != "ecology-shifted"))
            exit 1
        if ($1 == "chronology-aggregate-shift" &&
            ($13 != 0 || $15 != "aggregate-shifted"))
            exit 1
        if ($1 == "chronology-observing" &&
            ($2 != 31 || $15 != "observing"))
            exit 1
        if ($1 == "chronology-coverage-starved" &&
            ($5 != 16 || $6 != 0 ||
             $15 != "coverage-starved"))
            exit 1
        if ($1 == "chronology-incompatible" &&
            $15 != "incompatible")
            exit 1
        rows++
    }
    END {
        if (rows != 9)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite transport chronology plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite transport chronology matrix plan: ok\n'
