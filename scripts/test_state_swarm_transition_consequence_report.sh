#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-transition-consequence-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

HASH='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turns\tpre_sha\tpost_sha\tsource_log_sha\treplay_log_sha\tnormalized_sha\ta92_reply_equal\ta92_state_equal\tnext_log_equal\tgeometry_equal\n' > "$TMP/locks.tsv"
lock() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$((96 - $6))" \
        "$HASH" "$HASH" "$HASH" "$HASH" "$HASH"
}
lock 01 event p01-t050 p01 primary 50 >> "$TMP/locks.tsv"
lock 01 ecology p11-t050 p11 primary 50 >> "$TMP/locks.tsv"
lock 02 event h01-t060 h01 holdout 60 >> "$TMP/locks.tsv"
lock 02 ecology h11-t060 h11 holdout 60 >> "$TMP/locks.tsv"

printf 'pair\tarm\tanchor\tanchor_turn\tfuture_turn\ttexture\tanchor_similarity\tanchor_entropy\tnext_similarity\tnext_entropy\ttransition_mass\tforward_overlap\treverse_mass\treverse_overlap\ttransition_debt\tarrow_margin\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tactual_grounded\tactual_distress_relief\tactual_gap_relief\tactual_alignment_delta\toutcome_mae\tjoint_debt\tprompt\treply\n' > "$TMP/scores.tsv"
score() {
    printf '%s\t%s\t%s\t%s\t%s\thome\t0.500000\t0.800000\t0.510000\t0.790000\t1.000000\t%s\t1.000000\t%s\t%s\t%s\t0.000000\t0.000000\t0.000000\t0.000000\t%s\t%s\t%s\t%s\t%s\t%s\tprompt %s\treply %s\n' \
        "$1" "$2" "$3" "$4" "$(( $4 + 1 ))" "$5" "$6" "$7" \
        "$8" "$9" "$9" "$9" "$9" "$9" "${10}" "$1" "$2"
}
score 01 event p01-t050 50 0.200000 0.150000 0.800000 0.050000 0.400000 0.320000 >> "$TMP/scores.tsv"
score 01 ecology p11-t050 50 0.300000 0.250000 0.700000 0.050000 0.200000 0.140000 >> "$TMP/scores.tsv"
score 02 event h01-t060 60 0.300000 0.200000 0.700000 0.100000 0.100000 0.070000 >> "$TMP/scores.tsv"
score 02 ecology h11-t060 60 0.200000 0.150000 0.800000 0.050000 0.200000 0.160000 >> "$TMP/scores.tsv"

awk -v expected=2 -f "$ROOT/scripts/state_swarm_transition_consequence_report.awk" \
    "$TMP/locks.tsv" "$TMP/scores.tsv" > "$TMP/summary.tsv"
awk -v expected=2 -v sign_required=2 -v mean_required=0.01 \
    -f "$ROOT/scripts/state_swarm_transition_consequence_verdict.awk" \
    "$TMP/summary.tsv" > "$TMP/verdict.txt"
awk -F '\t' '
    NR == 1 { if (NF != 23 || $20 != "paired_transition_debt_delta" || $22 != "paired_joint_debt_delta") exit 1; next }
    $1 == "01" { if ($22 != "0.180000") exit 1; first++ }
    $1 == "02" { if ($22 != "-0.090000") exit 1; second++ }
    END { if (NR != 3 || first != 1 || second != 1) exit 1 }
' "$TMP/summary.tsv"
grep -q '^joint_delta_positive 1$' "$TMP/verdict.txt"
grep -q '^joint_delta_negative 1$' "$TMP/verdict.txt"
grep -q '^result transition-consequence-debt-not-distinguished$' "$TMP/verdict.txt"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $26 = "0.310000" } { print }' \
    "$TMP/scores.tsv" > "$TMP/false-joint.tsv"
if awk -v expected=2 -f "$ROOT/scripts/state_swarm_transition_consequence_report.awk" \
    "$TMP/locks.tsv" "$TMP/false-joint.tsv" >/dev/null 2>&1; then
    printf 'transition consequence reporter accepted false joint debt\n' >&2
    exit 1
fi

sed '$d' "$TMP/scores.tsv" > "$TMP/truncated.tsv"
if awk -v expected=2 -f "$ROOT/scripts/state_swarm_transition_consequence_report.awk" \
    "$TMP/locks.tsv" "$TMP/truncated.tsv" >/dev/null 2>&1; then
    printf 'transition consequence reporter accepted a truncated score set\n' >&2
    exit 1
fi

sed '2s/true$/false/' "$TMP/locks.tsv" > "$TMP/open-lock.tsv"
if awk -v expected=2 -f "$ROOT/scripts/state_swarm_transition_consequence_report.awk" \
    "$TMP/open-lock.tsv" "$TMP/scores.tsv" >/dev/null 2>&1; then
    printf 'transition consequence reporter accepted an open replay lock\n' >&2
    exit 1
fi

printf 'state-swarm transition consequence reporters: ok\n'
