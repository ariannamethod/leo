#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_ATTRIBUTION_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_attribution_matrix.sh" "$OUT/plan" \
    > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 9 || $1 != "cell" || $2 != "group" ||
            $5 != "case" || $6 != "kind" ||
            $8 != "expected_status" || $9 != "expected_winner")
            exit 1
        next
    }
    {
        if (NF != 9 || cells[$1]++)
            exit 1
        groups[$2]++
        cases[$5]++
        status[$8]++
        rows++
    }
    END {
        if (rows != 14 || length(groups) != 2 || length(cases) != 7 ||
            status["sibling-conflict"] != 4 ||
            status["sibling-explicit"] != 2 ||
            status["active-semantic"] != 2 ||
            status["active-explicit"] != 2 ||
            status["ambiguous"] != 2 ||
            status["adjacent"] != 2)
            exit 1
        for (group in groups)
            if (groups[group] != 7)
                exit 1
        for (case in cases)
            if (cases[case] != 2)
                exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder attribution plan\n' >&2
    exit 1
}

printf 'deferred Wonder attribution matrix plan: ok\n'
