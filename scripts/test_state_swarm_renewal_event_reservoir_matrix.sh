#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-renewal-reservoir-plan.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

awk -F '\t' '
    NR == 1 {
        if (NF != 3 || $1 != "life" || $2 != "split" || $3 != "base_seed") exit 1
        next
    }
    {
        rows++
        expected_life = rows <= 40 ? sprintf("p%02d", rows) : sprintf("h%02d", rows - 40)
        expected_split = rows <= 40 ? "primary" : "holdout"
        expected_seed = 192643 + (rows - 1) * 1033
        if ($1 != expected_life || $2 != expected_split || $3 != expected_seed || seed[$3]++) exit 1
    }
    END { if (rows != 80) exit 1 }
' "$ROOT/scripts/state_swarm_renewal_event_reservoir_candidates.tsv"

old_last="$(tail -n 1 "$ROOT/scripts/state_swarm_balanced_event_reservoir_candidates.tsv" | awk -F '\t' '{ print $3 }')"
new_first="$(sed -n '2p' "$ROOT/scripts/state_swarm_renewal_event_reservoir_candidates.tsv" | awk -F '\t' '{ print $3 }')"
[ "$new_first" -eq $((old_last + 1033)) ]

LEO_STATE_PROSPECTIVE_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_renewal_event_reservoir_matrix.sh" "$TMP/run" \
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
        rows++; lives[$1]++; split_life[$2 SUBSEP $1] = 1
        if ($1 !~ /^[ph][0-9][0-9]$/ ||
            $2 !~ /^(primary|holdout)$/ || $3 !~ /^[0-9]+$/ ||
            $4 != "warm" || $5 < 1 || $6 < 1 ||
            $7 !~ /^(home|storm|wonder|social)$/ ||
            $8 !~ /^[0-9]+$/ || $9 == "" || seed[$1 SUBSEP $8]++) exit 1
    }
    END {
        if (rows != 2560 || length(lives) != 80) exit 1
        for (life in lives) if (lives[life] != 32) exit 1
        primary = holdout = 0
        for (key in split_life) {
            split(key, part, SUBSEP)
            if (part[1] == "primary") primary++
            else if (part[1] == "holdout") holdout++
        }
        if (primary != 40 || holdout != 40) exit 1
    }
' "$TMP/run/screen-plan.tsv"

printf 'state-swarm renewal event reservoir matrix plan: ok\n'
