#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-delayed-outcome-receipt-report.XXXXXX")"
trap 'rc=$?; rm -rf "$TMP"; exit "$rc"' EXIT

cat > "$TMP/policies.tsv" <<'EOF'
candidate	receipt_strength	snapshot_decay	snapshot_strength	texture_strength	prior_alpha	variance_ridge	rank
outcome-receipt-path-test	0.10	1.00	0.25	0.25	1	0.01	1
EOF

printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$TMP/locks.tsv"
printf 'discovery\tp01\tprimary\t64\ttrue\ttrue\t%s\t%s\n' \
    "$(printf x | shasum -a 256 | awk '{print $1}')" \
    "$(printf y | shasum -a 256 | awk '{print $1}')" >> "$TMP/locks.tsv"

awk 'BEGIN {
    OFS = "\t"
    print "cohort", "life", "split", "turn", "session", "order", "texture", \
        "event", "pre_turn", "pre_ids", "post_members", "transition", \
        "source", "transition_total", "winner", "replaced", "has_prediction", \
        "expected", "expected_probability", "overlap", "surprise", \
        "observed_grounded", "observed_distress_relief", \
        "observed_gap_relief", "observed_alignment_delta", \
        "forecast_grounded", "forecast_distress_relief", \
        "forecast_gap_relief", "forecast_alignment_delta", "prompt", "reply"
    old_ids = "1/2/3/4/5/6/7/8"
    new_ids = "1/2/3/4/5/6/7/9"
    for (session = 1; session <= 8; session++) {
        positive = session % 2 == 0
        for (order = 1; order <= 8; order++) {
            turn = 32 + (session - 1) * 8 + order
            event = session == 2 && order == 8 ? "replaced" : "updated"
            ids = session <= 2 ? old_ids : new_ids
            post_ids = event == "replaced" ? new_ids : ids
            matrix = transition_matrix(session == 3 && order == 1 ? 8 : 0)
            has_prediction = session == 3 && order == 1 ? 0 : 1
            if (order == 1) {
                source = has_prediction ? uniform() : onehot(8)
                target = uniform()
                observed_grounded = positive ? 1 : 0
                forecast_grounded = has_prediction ? 0.5 : "na"
            } else if (order == 5) {
                source = uniform()
                target = positive ? vec(2) : vec(1)
                observed_grounded = forecast_grounded = 0
            } else {
                source = uniform()
                target = uniform()
                observed_grounded = forecast_grounded = 0
            }
            split(source, s, "/"); split(target, t, "/")
            expected_slot = 1
            overlap = 0
            for (i = 1; i <= 8; i++) {
                if (s[i] > s[expected_slot]) expected_slot = i
                overlap += s[i] * t[i]
            }
            split(ids, current_id, "/")
            winner = event == "replaced" ? 9 : current_id[expected_slot]
            replaced = event == "replaced" ? 8 : 0
            expected = has_prediction ? current_id[expected_slot] : 0
            expected_probability = has_prediction ? sprintf("%.3f", s[expected_slot]) : 0
            observed_overlap = has_prediction ? sprintf("%.3f", overlap) : 0
            surprise = has_prediction ? sprintf("%.3f", -log(overlap)) : 0
            transition_total = session == 3 && order == 1 ? 7 : 8
            forecast_other = has_prediction ? 0 : "na"
            print "discovery", "p01", "primary", turn, session, order, "home", \
                event, turn - 1, ids, members(target, post_ids), matrix, source, \
                transition_total, winner, replaced, \
                has_prediction, expected, expected_probability, observed_overlap, \
                surprise, observed_grounded, 0, 0, 0, forecast_grounded, \
                forecast_other, forecast_other, forecast_other, \
                "synthetic prompt", "synthetic reply"
        }
    }
}
function uniform(   i, out) {
    out = "0.125"
    for (i = 2; i <= 8; i++) out = out "/0.125"
    return out
}
function vec(slot,   i, out, value) {
    for (i = 1; i <= 8; i++) {
        value = i == slot ? "0.650" : "0.050"
        out = out (i == 1 ? "" : "/") value
    }
    return out
}
function onehot(slot,   i, out, value) {
    for (i = 1; i <= 8; i++) {
        value = i == slot ? "1.000" : "0.000"
        out = out (i == 1 ? "" : "/") value
    }
    return out
}
function transition_matrix(zero_row,   i, j, out, value) {
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            value = i == zero_row ? 0 : (i == j ? 1 : 0)
            out = out (i == 1 && j == 1 ? "" : "/") value
        }
    return out
}
function members(value, ids,   i, item, member_id, out) {
    split(value, item, "/")
    split(ids, member_id, "/")
    for (i = 1; i <= 8; i++)
        out = out (i == 1 ? "" : ",") member_id[i] ":" item[i]
    return out
}' > "$TMP/witnesses.tsv"

awk -v policy_expected=1 -v life_expected=1 -v writer_expected=64 \
    -v evaluation_session=5 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_delayed_outcome_receipt_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/witnesses.tsv" > "$TMP/scores.tsv"

[ "${LEO_TEST_DEBUG:-0}" = 0 ] || cat "$TMP/scores.tsv" >&2

awk -F '\t' '
    NR == 1 {
        if (NF != 34 || $11 != "receipt_ce" || $12 != "path_ce" ||
            $13 != "symmetric_ce" || $30 != "path_ce_gain" ||
            $34 != "path_symmetric_ce_gain") exit 1
        next
    }
    { rows++; receipt += $30; carried += $34 }
    END {
        if (rows != 4 || receipt <= 0.000001 ||
            carried < -0.000001 || carried > 0.000001) exit 1
    }
' "$TMP/scores.tsv"

awk -F '\t' -v OFS='\t' 'NR == 42 { $21 = "9.999" } { print }' \
    "$TMP/witnesses.tsv" > "$TMP/forged.tsv"
if awk -v policy_expected=1 -v life_expected=1 -v writer_expected=64 \
    -v evaluation_session=5 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_delayed_outcome_receipt_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/forged.tsv" >/dev/null 2>&1; then
    printf 'delayed outcome receipt reporter accepted an incompatible rounded surprise\n' >&2
    exit 1
fi

awk -F '\t' -v OFS='\t' 'NR == 42 { $26 = "2.000" } { print }' \
    "$TMP/witnesses.tsv" > "$TMP/forged-outcome.tsv"
if awk -v policy_expected=1 -v life_expected=1 -v writer_expected=64 \
    -v evaluation_session=5 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_delayed_outcome_receipt_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/forged-outcome.tsv" >/dev/null 2>&1; then
    printf 'delayed outcome receipt reporter accepted an impossible forecast outcome\n' >&2
    exit 1
fi

printf 'state-swarm road delayed outcome receipt reporter: ok\n'
