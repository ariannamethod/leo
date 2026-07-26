#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_matrix.sh" "$OUT/plan" \
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
        kinds[$6]++
        status[$8]++
        rows++
    }
    END {
        if (rows != 10 || length(groups) != 2 ||
            length(cases) != 5 || kinds["semantic"] != 2 ||
            kinds["weak"] != 2 || kinds["mixed"] != 2 ||
            kinds["quiet"] != 2 || kinds["parked"] != 2 ||
            status["salient"] != 4 ||
            status["diffuse"] != 4 || status["quiet"] != 2)
            exit 1
        for (group in groups)
            if (groups[group] != 5)
                exit 1
        for (case in cases)
            if (cases[case] != 2)
                exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite matrix plan: ok\n'
