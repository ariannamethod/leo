#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-alphabet-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/plan"
LEO_STATE_ALPHABET_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_alphabet_matrix.sh" "$OUT" > "$TMP/plan.out"
cmp -s "$OUT/plan.tsv" "$TMP/plan.out"

awk -F '\t' '
    BEGIN {
        label[1] = "home"
        label[2] = "storm"
        label[3] = "wonder"
        label[4] = "social"
    }
    NR == 1 { next }
    {
        rows++
        lives[$1]++
        sessions[$1 SUBSEP $5]++
        slot = $1 SUBSEP $4 SUBSEP $5 SUBSEP $6
        if (seen[slot]++) exit 1
        if ($4 == "writer") {
            writers[$1]++
            texture[$1 SUBSEP $5 SUBSEP $7]++
            half = $5 <= 4 ? 1 : 2
            crossed[$1 SUBSEP half SUBSEP $6 SUBSEP $7]++
            if ($9 != 1) exit 1
        } else if ($4 == "probe") {
            probes[$1]++
            if ($9 != 0) exit 1
        } else exit 1
    }
    END {
        if (rows != 288 || length(lives) != 3 || length(sessions) != 24)
            exit 1
        for (cell in lives) {
            if (lives[cell] != 96 || writers[cell] != 64 || probes[cell] != 32)
                exit 1
            for (session = 1; session <= 8; session++)
                for (i = 1; i <= 4; i++) {
                    if (texture[cell SUBSEP session SUBSEP label[i]] != 2)
                        exit 1
                }
            for (half = 1; half <= 2; half++)
                for (position = 1; position <= 8; position++)
                    for (i = 1; i <= 4; i++) {
                        if (crossed[cell SUBSEP half SUBSEP position SUBSEP label[i]] != 1)
                            exit 1
                    }
        }
    }
' "$TMP/plan.out"

RECEIPTS="$TMP/receipts.tsv"
awk -F '\t' '
    BEGIN {
        OFS = "\t"
        print "cell", "cohort", "base_seed", "phase", "session", "order", "texture", "run_seed", "turn", "states", "active", "winner", "event", "similarity", "entropy", "members", "member_sum", "adjacent", "replaced", "has_prediction", "expected", "expected_probability", "overlap", "surprise", "observed_grounded", "observed_distress_relief", "observed_gap_relief", "observed_alignment_delta", "forecast_grounded", "forecast_distress_relief", "forecast_gap_relief", "forecast_alignment_delta", "prompt", "reply", "voice_equal", "state_equal"
        state["home"] = 1
        state["storm"] = 2
        state["wonder"] = 3
        state["social"] = 4
    }
    NR == 1 || $4 != "writer" { next }
    {
        cell = $1
        t = ++turn[cell]
        winner = state[$7]
        members = "1:" (winner == 1 ? "1.000" : "0.000") ",2:" (winner == 2 ? "1.000" : "0.000") ",3:" (winner == 3 ? "1.000" : "0.000") ",4:" (winner == 4 ? "1.000" : "0.000")
        event = t <= 4 ? "born" : "updated"
        adjacent = t > 1 ? 1 : 0
        prediction = t > 1 ? 1 : 0
        print $1, $2, $3, "writer", $5, $6, $7, $8, t, 4, 1,
              winner, event, "1.000", "0.000", members, "1.000",
              adjacent, 0, prediction, prediction ? winner : 0,
              prediction ? "1.000" : 0, prediction ? "1.000" : 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, $10, "reply", "na", "na"
    }
' "$TMP/plan.out" > "$RECEIPTS"

awk -f "$ROOT/scripts/state_swarm_alphabet_report.awk" "$RECEIPTS" \
    > "$TMP/alphabet.tsv"
awk -F '\t' '
    {
        rows++
        if (NF != 22 || $4 != 32 || $5 != 32 || $6 != "1.000000" ||
            $7 != "1.000000" || $8 != "1.000000" || $9 != 0 ||
            $10 != "0.000000" || $11 != "0.000000" || $13 != 0 ||
            $14 != "0.000000" || $15 != "0.000000" || $17 != 4 ||
            $18 != 4 || $19 != 0 || $20 != 0 || $21 != 0 ||
            $22 != "texture-alphabet")
            exit 1
    }
    END { if (rows != 3) exit 1 }
' "$TMP/alphabet.tsv"

printf 'state-swarm alphabet crossover plan: ok\n'
