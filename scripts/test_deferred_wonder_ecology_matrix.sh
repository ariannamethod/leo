#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-ecology-matrix-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/plan"
LEO_ECOLOGY_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_ecology_matrix.sh" "$OUT" \
    > "$TMP/plan.out"

cmp -s "$OUT/plan.tsv" "$TMP/plan.out"
awk -F '\t' '
    NR == 1 {
        if (NF != 7 || $1 != "cell" || $2 != "cohort" ||
            $3 != "target" || $4 != "seed" || $5 != "trajectory" ||
            $6 != "expected_primary" || $7 != "life_turns")
            exit 1
        next
    }
    {
        cells++
        cohorts[$2]++
        targets[$3]++
        seeds[$4]++
        trajectories[$5]++
        target_trajectory[$3 SUBSEP $5]++
        outcomes[$6]++
    }
    END {
        if (cells != 30 || length(cohorts) != 2 || length(targets) != 6 ||
            length(seeds) != 6 || length(trajectories) != 5 ||
            length(target_trajectory) != 30)
            exit 1
        if (cohorts["replication"] != 15 ||
            cohorts["confirmatory"] != 15 ||
            outcomes["asked-deferred"] != 18 ||
            outcomes["blocked-deferred"] != 12)
            exit 1
        for (key in targets) if (targets[key] != 5) exit 1
        for (key in seeds) if (seeds[key] != 5) exit 1
        for (key in trajectories) if (trajectories[key] != 6) exit 1
        for (key in target_trajectory)
            if (target_trajectory[key] != 1) exit 1
    }
' "$TMP/plan.out"

printf 'deferred Wonder ecology matrix plan: ok\n'
