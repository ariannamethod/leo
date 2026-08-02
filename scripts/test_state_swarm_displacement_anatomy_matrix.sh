#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-anatomy-plan.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_STATE_ANATOMY_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_displacement_anatomy_matrix.sh" "$TMP/run" \
    > "$TMP/plan.stdout"

cmp -s "$TMP/run/plan.tsv" "$TMP/plan.stdout"
awk -F '\t' '
    NR == 1 {
        if (NF != 9 || $1 != "life" || $4 != "phase" ||
            $8 != "run_seed" || $9 != "prompt") exit 1
        next
    }
    {
        rows++; lives[$1]++; phases[$1 SUBSEP $4]++
        if ($2 != "holdout" || $3 !~ /^[0-9]+$/ ||
            $4 !~ /^(warm|writer)$/ || $5 < 1 || $6 < 1 ||
            $7 !~ /^(home|storm|wonder|social)$/ || $8 !~ /^[0-9]+$/ ||
            $9 == "" || seed[$1 SUBSEP $8]++) exit 1
    }
    END {
        if (rows != 768 || length(lives) != 8) exit 1
        for (life in lives)
            if (lives[life] != 96 || phases[life SUBSEP "warm"] != 32 ||
                phases[life SUBSEP "writer"] != 64) exit 1
    }
' "$TMP/run/plan.tsv"

printf 'state-swarm displacement anatomy matrix plan: ok\n'
