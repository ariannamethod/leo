#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-information-report.XXXXXX")"
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

matrix() {
    local kind="$1" out='' separator='' value
    local i j
    for ((i = 0; i < 8; i++)); do
        for ((j = 0; j < 8; j++)); do
            value=1
            if [ "$kind" = identity ] && [ "$i" -ne "$j" ]; then
                value=0
            fi
            out+="${separator}${value}"
            separator='/'
        done
    done
    printf '%s' "$out"
}

IDENTITY="$(matrix identity)"
RANK_ONE="$(matrix rank-one)"
ONE_HOT='1/0/0/0/0/0/0/0'
UNIFORM='0.125/0.125/0.125/0.125/0.125/0.125/0.125/0.125'
HEADER='pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turn\ttexture\ttransition\tanchor_activation\ttarget_activation\tconditional_prediction\tdestination_prior\ttransition_total\tdestination_entropy\tmutual_information\tnormalized_mi\tmean_row_tv\tconditional_ce\tdestination_ce\tuniform_ce\tpersistence_ce\tconditional_brier\tdestination_brier\tuniform_brier\tpersistence_brier\tprompt\treply'
printf '%b\n' "$HEADER" > "$TMP/supported.tsv"
printf '%b\n' "$HEADER" > "$TMP/equivalent.tsv"

score_supported() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\thome\t%s\t%s\t%s\t%s\t%s\t8\t2.079441542\t2.079441542\t1.000000000\t0.875000000\t0.000000000\t2.079441542\t2.079441542\t0.000000000\t0.000000000\t0.875000000\t0.875000000\t0.000000000\tprompt %s\treply %s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$(( $6 + 1 ))" \
        "$IDENTITY" "$ONE_HOT" "$ONE_HOT" "$ONE_HOT" "$UNIFORM" \
        "$1" "$2"
}

score_equivalent() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\thome\t%s\t%s\t%s\t%s\t%s\t64\t2.079441542\t0.000000000\t0.000000000\t0.000000000\t2.079441542\t2.079441542\t2.079441542\t0.000000000\t0.875000000\t0.875000000\t0.875000000\t0.000000000\tprompt %s\treply %s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$(( $6 + 1 ))" \
        "$RANK_ONE" "$ONE_HOT" "$ONE_HOT" "$UNIFORM" "$UNIFORM" \
        "$1" "$2"
}

score_supported 01 event p01-t050 p01 primary 50 >> "$TMP/supported.tsv"
score_supported 01 ecology p11-t050 p11 primary 50 >> "$TMP/supported.tsv"
score_supported 02 event h01-t060 h01 holdout 60 >> "$TMP/supported.tsv"
score_supported 02 ecology h11-t060 h11 holdout 60 >> "$TMP/supported.tsv"

score_equivalent 01 event p01-t050 p01 primary 50 >> "$TMP/equivalent.tsv"
score_equivalent 01 ecology p11-t050 p11 primary 50 >> "$TMP/equivalent.tsv"
score_equivalent 02 event h01-t060 h01 holdout 60 >> "$TMP/equivalent.tsv"
score_equivalent 02 ecology h11-t060 h11 holdout 60 >> "$TMP/equivalent.tsv"

report() {
    local scores="$1" stem="$2"
    awk -v expected=4 \
        -f "$ROOT/scripts/state_swarm_road_information_report.awk" \
        "$TMP/locks.tsv" "$scores" > "$TMP/$stem-summary.tsv"
    awk -v expected=4 -v win_required=3 \
        -f "$ROOT/scripts/state_swarm_road_information_verdict.awk" \
        "$TMP/$stem-summary.tsv" > "$TMP/$stem-verdict.txt"
}

report "$TMP/supported.tsv" supported
grep -q '^result conditional-road-supported$' "$TMP/supported-verdict.txt"
grep -q '^conditional_ce_wins 4$' "$TMP/supported-verdict.txt"

report "$TMP/equivalent.tsv" equivalent
grep -q '^result destination-prior-equivalent$' "$TMP/equivalent-verdict.txt"
grep -q '^mean_normalized_mi 0.000000000$' "$TMP/equivalent-verdict.txt"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $19 = "0.100000000" } { print }' \
    "$TMP/supported.tsv" > "$TMP/false-score.tsv"
if awk -v expected=4 \
    -f "$ROOT/scripts/state_swarm_road_information_report.awk" \
    "$TMP/locks.tsv" "$TMP/false-score.tsv" >/dev/null 2>&1; then
    printf 'road information reporter accepted a false proper score\n' >&2
    exit 1
fi

sed '2s/true$/false/' "$TMP/locks.tsv" > "$TMP/open-lock.tsv"
if awk -v expected=4 \
    -f "$ROOT/scripts/state_swarm_road_information_report.awk" \
    "$TMP/open-lock.tsv" "$TMP/supported.tsv" >/dev/null 2>&1; then
    printf 'road information reporter accepted an open replay lock\n' >&2
    exit 1
fi

printf 'state-swarm road information reporters: ok\n'
