#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_SEMANTIC_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_semantic_matrix.sh" "$OUT/plan" \
    > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "cell" || $2 != "group" ||
            $5 != "case" || $6 != "kind" || $9 != "expected_status" ||
            $10 != "expected_winner")
            exit 1
        next
    }
    {
        if (NF != 10 || cells[$1]++)
            exit 1
        groups[$2]++
        cases[$5]++
        status[$9]++
        rows++
    }
    END {
        if (rows != 16 || length(groups) != 2 || length(cases) != 8 ||
            status["confident"] != 8 || status["ambiguous"] != 4 ||
            status["quiet"] != 2 || status["literal"] != 2)
            exit 1
        for (group in groups)
            if (groups[group] != 8)
                exit 1
        for (case in cases)
            if (cases[case] != 2)
                exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder semantic plan\n' >&2
    exit 1
}

printf 'deferred Wonder semantic matrix plan: ok\n'
