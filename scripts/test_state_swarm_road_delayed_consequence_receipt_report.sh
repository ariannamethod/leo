#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-delayed-receipt-report.XXXXXX")"
trap 'rc=$?; rm -rf "$TMP"; exit "$rc"' EXIT

cat > "$TMP/policies.tsv" <<'EOF'
candidate	receipt_strength	snapshot_decay	snapshot_strength	texture_strength	prior_alpha	variance_ridge	rank
receipt-test	0.10	1.00	0.25	0.25	1	0.01	1
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
        "expected", "expected_probability", "overlap", "surprise", "prompt", "reply"
    ids = "1/2/3/4/5/6/7/8"
    matrix = "1/0/0/0/0/0/0/0/0/1/0/0/0/0/0/0/0/0/1/0/0/0/0/0/0/0/0/1/0/0/0/0/0/0/0/0/1/0/0/0/0/0/0/0/0/1/0/0/0/0/0/0/0/0/1/0/0/0/0/0/0/0/0/1"
    for (session = 1; session <= 8; session++) {
        positive = session % 2 == 0
        for (order = 1; order <= 8; order++) {
            turn = 32 + (session - 1) * 8 + order
            if (order == 1) {
                source = positive ? vec(1) : vec(2)
                target = positive ? vec(2) : vec(1)
            } else if (order == 5) {
                source = uniform()
                target = positive ? vec(2) : vec(1)
            } else {
                source = uniform()
                target = uniform()
            }
            split(source, s, "/"); split(target, t, "/")
            expected_slot = 1
            overlap = 0
            for (i = 1; i <= 8; i++) {
                if (s[i] > s[expected_slot]) expected_slot = i
                overlap += s[i] * t[i]
            }
            print "discovery", "p01", "primary", turn, session, order, "home", \
                "updated", turn - 1, ids, members(target), matrix, source, 8, \
                expected_slot, 0, 1, expected_slot, sprintf("%.3f", s[expected_slot]), \
                sprintf("%.3f", overlap), sprintf("%.3f", -log(overlap)), \
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
function members(value,   i, item, out) {
    split(value, item, "/")
    for (i = 1; i <= 8; i++) out = out (i == 1 ? "" : ",") i ":" item[i]
    return out
}' > "$TMP/witnesses.tsv"

awk -v policy_expected=1 -v life_expected=1 -v writer_expected=64 \
    -v evaluation_session=5 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_delayed_consequence_receipt_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/witnesses.tsv" > "$TMP/scores.tsv"

[ "${LEO_TEST_DEBUG:-0}" = 0 ] || cat "$TMP/scores.tsv" >&2

awk -F '\t' '
    NR == 1 {
        if (NF != 29 || $11 != "receipt_ce" || $12 != "symmetric_ce" ||
            $26 != "symmetric_ce_gain") exit 1
        next
    }
    { rows++; gain += $26 }
    END { if (rows != 4 || gain <= 0.000001) exit 1 }
' "$TMP/scores.tsv"

awk -F '\t' -v OFS='\t' 'NR == 42 { $21 = "9.999" } { print }' \
    "$TMP/witnesses.tsv" > "$TMP/forged.tsv"
if awk -v policy_expected=1 -v life_expected=1 -v writer_expected=64 \
    -v evaluation_session=5 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_delayed_consequence_receipt_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/forged.tsv" >/dev/null 2>&1; then
    printf 'delayed receipt reporter accepted an incompatible rounded surprise\n' >&2
    exit 1
fi

printf 'state-swarm road delayed consequence receipt reporter: ok\n'
