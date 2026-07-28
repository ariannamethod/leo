#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_CHECKPOINT_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_checkpoint_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 4 || $1 != "case" ||
            $4 != "expected_sequence")
            exit 1
        next
    }
    {
        if (NF != 4 || seen[$1]++)
            exit 1
        expected["checkpoint-one"] = "1/provisional/one"
        expected["checkpoint-stable"] = "2/provisional/stable-provisional"
        expected["checkpoint-emerging"] = "2/early-shifted/emerging-shift"
        expected["checkpoint-persistent"] = "2/recent-shifted/persistent-shift"
        expected["checkpoint-recovered"] = "2/provisional/recovered"
        expected["checkpoint-insufficient"] = "2/coverage-starved/insufficient"
        expected["checkpoint-incompatible"] = "1/incompatible/incompatible"
        expected["checkpoint-pending"] = "0/pending/empty"
        if (($2 "/" $3 "/" $4) != expected[$1])
            exit 1
        rows++
    }
    END {
        if (rows != 8)
            exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite checkpoint plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite checkpoint matrix plan: ok\n'
