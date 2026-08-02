#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-settled-organ-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/plan"
LEO_STATE_SETTLED_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_settled_organ_matrix.sh" "$OUT" \
    > "$TMP/plan.out"
cmp -s "$OUT/warmup/plan.tsv" "$TMP/plan.out"

awk -F '\t' '
    BEGIN {
        label[1] = "home"; label[2] = "storm"
        label[3] = "wonder"; label[4] = "social"
    }
    NR == 1 { next }
    {
        rows++
        lives[$1]++
        slot = $1 SUBSEP $4 SUBSEP $5
        if (seen[slot]++) exit 1
        texture[$1 SUBSEP $4 SUBSEP $6]++
        crossed[$1 SUBSEP $5 SUBSEP $6]++
    }
    END {
        if (rows != 96 || length(lives) != 3) exit 1
        for (cell in lives) {
            if (lives[cell] != 32) exit 1
            for (session = 1; session <= 4; session++)
                for (i = 1; i <= 4; i++)
                    if (texture[cell SUBSEP session SUBSEP label[i]] != 2)
                        exit 1
            for (position = 1; position <= 8; position++)
                for (i = 1; i <= 4; i++)
                    if (crossed[cell SUBSEP position SUBSEP label[i]] != 1)
                        exit 1
        }
    }
' "$TMP/plan.out"

printf 'state-swarm settled warm-up plan: ok\n'
