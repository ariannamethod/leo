#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

LEO_APPETITE_CALIBRATION_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_appetite_calibration_matrix.sh" \
    "$OUT/plan" > "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 11 || $1 != "cell" || $2 != "group" ||
            $5 != "case" || $6 != "kind" || $7 != "target" ||
            $8 != "expected_verdict" ||
            $9 != "expected_spoken" ||
            $10 != "expected_forecast" ||
            $11 != "expected_full_equal")
            exit 1
        next
    }
    {
        if (NF != 11 || cells[$1]++)
            exit 1
        groups[$2]++
        cases[$5]++
        kinds[$6]++
        verdicts[$8]++
        rows++
    }
    END {
        if (rows != 10 || length(groups) != 2 ||
            length(cases) != 5 || kinds["unspoken"] != 6 ||
            kinds["parked"] != 2 || kinds["control"] != 2 ||
            verdicts["sustained"] != 4 ||
            verdicts["faded"] != 2 ||
            verdicts["external"] != 2 ||
            verdicts["none"] != 2)
            exit 1
        for (group in groups)
            if (groups[group] != 5)
                exit 1
        for (case in cases)
            if (cases[case] != 2)
                exit 1
    }
' "$OUT/plan.tsv" || {
    printf 'invalid deferred Wonder appetite calibration plan\n' >&2
    exit 1
}

printf 'deferred Wonder appetite calibration matrix plan: ok\n'
