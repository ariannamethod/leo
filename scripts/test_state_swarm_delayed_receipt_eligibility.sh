#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-delayed-receipt-eligibility.XXXXXX")"
trap 'rc=$?; rm -rf "$TMP"; exit "$rc"' EXIT

cat > "$TMP/enrollment.tsv" <<'EOF'
life	split	base_seed	candidate_order	enrollment_rank
p01	primary	1	1	1
h01	holdout	2	17	17
EOF

awk 'BEGIN {
    OFS = "\t"
    print "life", "split", "base_seed", "phase", "session", "order", \
        "texture", "run_seed", "turn", "states", "active", "winner", \
        "event", "similarity", "entropy", "members", "member_sum", \
        "adjacent", "replaced", "has_prediction", "expected", \
        "expected_probability", "overlap", "surprise", "observed_grounded", \
        "observed_distress_relief", "observed_gap_relief", \
        "observed_alignment_delta", "forecast_grounded", \
        "forecast_distress_relief", "forecast_gap_relief", \
        "forecast_alignment_delta", "prompt", "reply"
    for (which = 1; which <= 2; which++) {
        life = which == 1 ? "p01" : "h01"
        split_name = which == 1 ? "primary" : "holdout"
        for (session = 1; session <= 8; session++)
            for (order = 1; order <= 8; order++) {
                turn = 32 + (session - 1) * 8 + order
                event = which == 2 && session == 6 && order == 3 ? "replaced" : "updated"
                replaced = event == "replaced" ? 1 : 0
                print life, split_name, which, "writer", session, order, "home", turn, \
                    turn, 8, 1, 1, event, 1, 0, "1:1", 1, 1, \
                    replaced, 1, 1, 1, 1, 0, 0, 0, 0, 0, \
                    0, 0, 0, 0, "prompt", "reply"
            }
    }
}' > "$TMP/writer.tsv"

awk -v life_expected=2 -f "$ROOT/scripts/state_swarm_delayed_receipt_eligibility.awk" \
    "$TMP/enrollment.tsv" "$TMP/writer.tsv" > "$TMP/eligibility.tsv"

grep -q $'^discovery\tp01\tprimary\t1\t7\t4\t0$' "$TMP/eligibility.tsv"
grep -q $'^validation\th01\tholdout\t17\t5\t2\t1$' "$TMP/eligibility.tsv"

printf 'state-swarm delayed receipt eligibility: ok\n'
