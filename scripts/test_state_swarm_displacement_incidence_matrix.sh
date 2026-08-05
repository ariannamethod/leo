#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-incidence-plan.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_STATE_INCIDENCE_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_displacement_incidence_matrix.sh" "$TMP/run" \
    > "$TMP/plan.stdout"

cmp -s "$TMP/run/plan.tsv" "$TMP/plan.stdout"
awk -F '\t' '
    NR == 1 {
        if (NF != 9 || $1 != "life" || $2 != "split" ||
            $4 != "phase" || $8 != "run_seed" || $9 != "prompt") exit 1
        next
    }
    {
        rows++; lives[$1]++; phase[$1 SUBSEP $4]++
        cohort_life[$2 SUBSEP $1] = 1
        if ($1 !~ /^[ph][0-9][0-9]$/ ||
            $2 !~ /^(primary|holdout)$/ || $3 !~ /^[0-9]+$/ ||
            $4 !~ /^(warm|writer)$/ || $5 < 1 || $6 < 1 ||
            $7 !~ /^(home|storm|wonder|social)$/ ||
            $8 !~ /^[0-9]+$/ || $9 == "" || seed[$1 SUBSEP $8]++) exit 1
    }
    END {
        if (rows != 3072 || length(lives) != 32) exit 1
        for (life in lives)
            if (lives[life] != 96 || phase[life SUBSEP "warm"] != 32 ||
                phase[life SUBSEP "writer"] != 64) exit 1
        primary = holdout = 0
        for (key in cohort_life) {
            split(key, part, SUBSEP)
            if (part[1] == "primary") primary++
            else if (part[1] == "holdout") holdout++
        }
        if (primary != 24 || holdout != 8) exit 1
    }
' "$TMP/run/plan.tsv"

printf 'state-swarm displacement incidence matrix plan: ok\n'
