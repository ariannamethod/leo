#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-prospective-plan.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_STATE_PROSPECTIVE_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_prospective_incidence_matrix.sh" "$TMP/run" \
    > "$TMP/plan.stdout"

cmp -s "$TMP/run/screen-plan.tsv" "$TMP/plan.stdout"
[ ! -e "$TMP/run/writer-plan.tsv" ]
awk -F '\t' '
    NR == 1 {
        if (NF != 9 || $1 != "life" || $2 != "split" ||
            $4 != "phase" || $8 != "run_seed" || $9 != "prompt") exit 1
        next
    }
    {
        rows++; lives[$1]++; cohort_life[$2 SUBSEP $1] = 1
        if ($1 !~ /^[ph][0-9][0-9]$/ ||
            $2 !~ /^(primary|holdout)$/ || $3 !~ /^[0-9]+$/ ||
            $4 != "warm" || $5 < 1 || $6 < 1 ||
            $7 !~ /^(home|storm|wonder|social)$/ ||
            $8 !~ /^[0-9]+$/ || $9 == "" || seed[$1 SUBSEP $8]++) exit 1
    }
    END {
        if (rows != 1280 || length(lives) != 40) exit 1
        for (life in lives)
            if (lives[life] != 32) exit 1
        primary = holdout = 0
        for (key in cohort_life) {
            split(key, part, SUBSEP)
            if (part[1] == "primary") primary++
            else if (part[1] == "holdout") holdout++
        }
        if (primary != 30 || holdout != 10) exit 1
    }
' "$TMP/run/screen-plan.tsv"

awk -F '\t' 'BEGIN { OFS = FS }
    NR == 2 { $3++ }
    { print }
' "$ROOT/scripts/state_swarm_prospective_incidence_candidates.tsv" \
    > "$TMP/tampered-candidates.tsv"
if LEO_STATE_PROSPECTIVE_CANDIDATES="$TMP/tampered-candidates.tsv" \
    LEO_STATE_PROSPECTIVE_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_prospective_incidence_matrix.sh" \
    "$TMP/tampered-run" >/dev/null 2>&1; then
    printf 'prospective plan accepted a changed seed grid\n' >&2
    exit 1
fi

if LEO_STATE_PROSPECTIVE_JOBS=0 LEO_STATE_PROSPECTIVE_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_prospective_incidence_matrix.sh" \
    "$TMP/bad-jobs" >/dev/null 2>&1; then
    printf 'prospective plan accepted zero jobs\n' >&2
    exit 1
fi

printf 'state-swarm prospective incidence matrix plan: ok\n'
