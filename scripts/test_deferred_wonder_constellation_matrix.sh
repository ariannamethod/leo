#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-constellation-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/plan"
LEO_CONSTELLATION_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_constellation_matrix.sh" "$OUT" \
    > "$TMP/plan.out"

cmp -s "$OUT/plan.tsv" "$TMP/plan.out"
awk -F '\t' '
    NR == 1 {
        if (NF != 6 || $1 != "cell" || $2 != "group" ||
            $3 != "cohort" || $4 != "seed" || $5 != "order" ||
            $6 != "target_order")
            exit 1
        next
    }
    {
        cells++
        groups[$2]++
        cohorts[$3]++
        seeds[$4]++
        orders[$5]++
        group_order[$2 SUBSEP $5]++
        delete targets
        split($6, targets, ",")
        if (length(targets) != 3 || targets[1] == targets[2] ||
            targets[1] == targets[3] || targets[2] == targets[3])
            exit 1
    }
    END {
        if (cells != 12 || length(groups) != 2 || length(cohorts) != 2 ||
            length(seeds) != 2 || length(orders) != 6 ||
            length(group_order) != 12)
            exit 1
        for (key in groups) if (groups[key] != 6) exit 1
        for (key in cohorts) if (cohorts[key] != 6) exit 1
        for (key in seeds) if (seeds[key] != 6) exit 1
        for (key in orders) if (orders[key] != 2) exit 1
        for (key in group_order)
            if (group_order[key] != 1) exit 1
    }
' "$TMP/plan.out"

printf 'deferred Wonder constellation matrix plan: ok\n'
