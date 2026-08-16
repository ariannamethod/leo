#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-counterfactual-susceptibility-report.XXXXXX")"
trap 'rc=$?; rm -rf "$TMP"; exit "$rc"' EXIT

printf 'candidate\tpath_strength\tsnapshot_decay\tsnapshot_strength\ttexture_strength\tprior_alpha\tvariance_ridge\trank\n' > "$TMP/policies.tsv"
printf 'susceptibility-path-test\t0.25\t1.00\t0.25\t0.25\t1\t1\t1\n' >> "$TMP/policies.tsv"

printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$TMP/locks.tsv"
printf 'discovery\tp01\tprimary\t64\ttrue\ttrue\t%s\t%s\n' \
    "$(printf x | shasum -a 256 | awk '{print $1}')" \
    "$(printf y | shasum -a 256 | awk '{print $1}')" >> "$TMP/locks.tsv"

awk 'BEGIN {
    OFS = "\t"
    print "cohort", "life", "split", "turn", "session", "order", "texture",
        "event", "pre_turn", "pre_ids", "post_members", "transition",
        "source", "transition_total", "winner", "replaced", "has_prediction",
        "expected", "expected_probability", "overlap", "surprise",
        "observed_grounded", "observed_distress_relief", "observed_gap_relief",
        "observed_alignment_delta", "forecast_grounded", "forecast_distress_relief",
        "forecast_gap_relief", "forecast_alignment_delta", "prompt", "reply"
    ids = "1/2/3/4/5/6/7/8"
    matrix = identity()
    for (session = 1; session <= 8; session++) {
        positive = session % 2
        for (order = 1; order <= 8; order++) {
            turn = 32 + (session - 1) * 8 + order
            if (order == 1) target = vec(1)
            else if (order == 2) target = positive ? vec(2) : vec(3)
            else if (order == 3) target = positive ? vec(3) : vec(2)
            else if (order == 4) target = vec(4)
            else target = uniform()
            source = uniform()
            overlap = dot(source, target)
            print "discovery", "p01", "primary", turn, session, order, "home",
                "updated", turn - 1, ids, members(target), matrix, source, 8,
                1, 0, 1, 1, "0.125", sprintf("%.3f", overlap),
                sprintf("%.3f", -log(overlap)), 0, 0, 0, 0, 0, 0, 0, 0,
                "synthetic writer prompt", "synthetic writer reply"
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
}
function identity(   i, j, out) {
    for (i = 1; i <= 8; i++) for (j = 1; j <= 8; j++)
        out = out ((i == 1 && j == 1) ? "" : "/") (i == j ? 1 : 0)
    return out
}
function dot(a, b,   av, bv, i, out) {
    split(a, av, "/"); split(b, bv, "/")
    for (i = 1; i <= 8; i++) out += av[i] * bv[i]
    return out
}' > "$TMP/writers.tsv"

awk 'BEGIN {
    OFS = "\t"
    print "cohort", "life", "split", "turn", "session", "probe", "texture",
        "run_seed", "event", "pre_turn", "pre_ids", "post_members",
        "transition", "source", "transition_total", "winner", "replaced",
        "has_prediction", "expected", "expected_probability", "overlap",
        "surprise", "prompt", "reply", "checkpoint_sha",
        "main_state_unchanged", "branch_pre_geometry_equal"
    ids = "1/2/3/4/5/6/7/8"
    matrix = identity(); source = uniform()
    texture[1] = "home"; texture[2] = "storm"
    texture[3] = "wonder"; texture[4] = "social"
    sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    for (session = 1; session <= 8; session++) {
        positive = session % 2
        target = positive ? vec(5) : vec(6)
        for (probe = 1; probe <= 4; probe++) {
            pre_turn = 32 + (session - 1) * 8 + 4
            print "discovery", "p01", "primary", pre_turn + 1, session, probe,
                texture[probe], 9000 + session * 100 + probe, "updated",
                pre_turn, ids, members(target), matrix, source, 8, 1, 0, 1,
                1, "0.125", "0.125", "2.079", "synthetic probe prompt",
                "synthetic probe reply", sha, "true", "true"
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
}
function identity(   i, j, out) {
    for (i = 1; i <= 8; i++) for (j = 1; j <= 8; j++)
        out = out ((i == 1 && j == 1) ? "" : "/") (i == j ? 1 : 0)
    return out
}' > "$TMP/probes.tsv"

run_report() {
    awk -v policy_expected=1 -v life_expected=1 -v writer_expected=64 \
        -v evaluation_session=5 -v score_min=4 \
        -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_report.awk" \
        "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/writers.tsv" "$1"
}

run_report "$TMP/probes.tsv" > "$TMP/scores.tsv"
[ "${LEO_TEST_DEBUG:-0}" = 0 ] || cat "$TMP/scores.tsv" >&2
awk -v life_expected=1 \
    -f "$ROOT/scripts/state_swarm_counterfactual_probe_eligibility.awk" \
    "$TMP/locks.tsv" "$TMP/writers.tsv" "$TMP/probes.tsv" > "$TMP/eligibility.tsv"
awk -F '\t' 'NR == 2 { if ($4 != 4 || $5 != 4 || $6 != 0 || $7 != 0) exit 1; seen = 1 }
    END { if (!seen) exit 1 }' "$TMP/eligibility.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 32 || $19 != "raw_ce_gain" ||
            $25 != "symmetric_ce_gain" || $32 != "social_path_ce_gain") exit 1
        next
    }
    { rows++; path += $25 }
    END { if (rows != 4 || path <= 0.000001) exit 1 }
' "$TMP/scores.tsv"

{ sed -n '1p' "$TMP/probes.tsv"; tail -n +2 "$TMP/probes.tsv" | sort -t $'\t' -k5,5n -k6,6nr; } \
    > "$TMP/reversed.tsv"
run_report "$TMP/reversed.tsv" > "$TMP/reversed-scores.tsv"
cmp -s "$TMP/scores.tsv" "$TMP/reversed-scores.tsv"

awk -F '\t' -v OFS='\t' '
    NR > 1 && $5 == 1 && $6 == 4 {
        $9 = "replaced"; sub(/^1:/, "9:", $12); $17 = 1
        $18 = 0; $19 = $20 = $21 = $22 = 0
    }
    { print }
' "$TMP/probes.tsv" > "$TMP/replaced-probe4.tsv"
run_report "$TMP/replaced-probe4.tsv" > "$TMP/replaced-probe4-scores.tsv"
[ "$(wc -l < "$TMP/replaced-probe4-scores.tsv" | tr -d ' ')" -eq 5 ]

awk -F '\t' -v OFS='\t' 'NR == 2 { $27 = "false" } { print }' \
    "$TMP/probes.tsv" > "$TMP/forged.tsv"
if run_report "$TMP/forged.tsv" >/dev/null 2>&1; then
    printf 'counterfactual reporter accepted a forged checkpoint geometry\n' >&2
    exit 1
fi

printf 'state-swarm road counterfactual susceptibility reporter: ok\n'
