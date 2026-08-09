#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-authority-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf 'feature\tkind\trank\n' > "$TMP/features.tsv"
printf 'row-coverage\tcoverage\t1\n' >> "$TMP/features.tsv"
printf 'active-row-kl\tactive-kl\t2\n' >> "$TMP/features.tsv"
printf 'forecast-kl\tforecast-kl\t3\n' >> "$TMP/features.tsv"
printf 'survival\tsurvival\t4\n' >> "$TMP/features.tsv"
printf 'coverage-forecast-kl\tproduct\t5\n' >> "$TMP/features.tsv"
printf 'forecast-tv\ttv\t6\n' >> "$TMP/features.tsv"

matrix() {
    local out='' separator='' value i j
    for ((i = 0; i < 8; i++)); do
        for ((j = 0; j < 8; j++)); do
            value=0
            [ "$i" -eq "$j" ] && value=1
            out+="${separator}${value}"
            separator='/'
        done
    done
    printf '%s' "$out"
}

IDENTITY="$(matrix)"
SOURCE='0.7/0.3/0/0/0/0/0/0'
TARGET='1/0/0/0/0/0/0/0'
UNIFORM='0.125/0.125/0.125/0.125/0.125/0.125/0.125/0.125'
HEADER='pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turn\ttexture\ttransition\tanchor_activation\ttarget_activation\tconditional_prediction\tdestination_prior\ttransition_total\tdestination_entropy\tmutual_information\tnormalized_mi\tmean_row_tv\tconditional_ce\tdestination_ce\tuniform_ce\tpersistence_ce\tconditional_brier\tdestination_brier\tuniform_brier\tpersistence_brier\tprompt\treply'

printf '%b\n' "$HEADER" > "$TMP/discovery.tsv"
printf '%b\n' "$HEADER" > "$TMP/validation.tsv"

witness() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\thome\t%s\t%s\t%s\t%s\t%s\t8\t2.079441542\t2.079441542\t1.000000000\t0.875000000\t0.356674944\t2.079441542\t2.079441542\t0.356674944\t0.180000000\t0.875000000\t0.875000000\t0.180000000\tprompt %s\treply %s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$(( $6 + 1 ))" \
        "$IDENTITY" "$SOURCE" "$TARGET" "$SOURCE" "$UNIFORM" "$1" "$2"
}

witness 01 event d01 p01 primary 50 >> "$TMP/discovery.tsv"
witness 01 ecology d02 p02 primary 50 >> "$TMP/discovery.tsv"
witness 02 event d03 p03 primary 60 >> "$TMP/discovery.tsv"
witness 02 ecology d04 p04 primary 60 >> "$TMP/discovery.tsv"
witness 03 organism v01 p05 primary 50 >> "$TMP/validation.tsv"
witness 04 organism v02 p06 primary 50 >> "$TMP/validation.tsv"
witness 05 organism v03 h01 holdout 60 >> "$TMP/validation.tsv"
witness 06 organism v04 h02 holdout 60 >> "$TMP/validation.tsv"

awk -v discovery_expected=4 -v validation_expected=4 \
    -f "$ROOT/scripts/state_swarm_road_authority_report.awk" \
    "$TMP/features.tsv" "$TMP/discovery.tsv" "$TMP/validation.tsv" \
    > "$TMP/reporter-scores.tsv"
grep -q $'^discovery\td01\tevent\tp01\tprimary\trow-coverage\tcoverage\t1\t1.000000000' \
    "$TMP/reporter-scores.tsv"
grep -q $'^discovery\td01\tevent\tp01\tprimary\tactive-row-kl\tactive-kl\t2\t2.079441542' \
    "$TMP/reporter-scores.tsv"
grep -q $'^discovery\td01\tevent\tp01\tprimary\tforecast-tv\ttv\t6\t0.750000000' \
    "$TMP/reporter-scores.tsv"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $19 = "0.500000000" } { print }' \
    "$TMP/discovery.tsv" > "$TMP/false-score.tsv"
if awk -v discovery_expected=4 -v validation_expected=4 \
    -f "$ROOT/scripts/state_swarm_road_authority_report.awk" \
    "$TMP/features.tsv" "$TMP/false-score.tsv" "$TMP/validation.tsv" \
    >/dev/null 2>&1; then
    printf 'road authority reporter accepted a forged witness score\n' >&2
    exit 1
fi

write_scores() {
    local mode="$1" i feature kind rank score gain split
    printf 'cohort\tcase\tarm\tlife\tsplit\tfeature\tkind\trank\tauthority_score\troute_gain\traw_ce\tdestination_ce\tsource_entropy\ttarget_entropy\n'
    for feature in good bad; do
        if [ "$feature" = good ]; then kind=forecast-kl; rank=1; else kind=tv; rank=2; fi
        for ((i = 1; i <= 12; i++)); do
            printf -v score '%d.000000000' "$((13 - i))"
            gain=0.000000000
            [ "$mode" = supported ] && [ "$feature" = good ] && [ "$i" -le 6 ] && gain=0.030000000
            printf 'discovery\td%02d\tevent\tp%02d\tprimary\t%s\t%s\t%s\t%s\t%s\t2.000000000\t2.000000000\t1.000000000\t1.000000000\n' \
                "$i" "$i" "$feature" "$kind" "$rank" "$score" "$gain"
        done
        for ((i = 1; i <= 15; i++)); do
            if [ "$i" -le 3 ] || [ "$i" -ge 7 ] && [ "$i" -le 9 ]; then split=primary; else split=holdout; fi
            if [ "$feature" = good ] && [ "$i" -le 6 ]; then score=10.000000000; else score=1.000000000; fi
            gain=0.000000000
            [ "$mode" = supported ] && [ "$feature" = good ] && [ "$i" -le 6 ] && gain=0.030000000
            printf 'validation\tv%02d\torganism\t%s%02d\t%s\t%s\t%s\t%s\t%s\t%s\t2.000000000\t2.000000000\t1.000000000\t1.000000000\n' \
                "$i" "${split:0:1}" "$i" "$split" "$feature" "$kind" "$rank" "$score" "$gain"
        done
    done
}

write_scores supported > "$TMP/supported.tsv"
awk -v feature_expected=2 -f "$ROOT/scripts/state_swarm_road_authority_select.awk" \
    "$TMP/supported.tsv" > "$TMP/supported-selection.tsv"
awk -v expected=15 -f "$ROOT/scripts/state_swarm_road_authority_verdict.awk" \
    "$TMP/supported-selection.tsv" "$TMP/supported.tsv" \
    > "$TMP/supported-verdict.txt"
grep -q $'^good\tforecast-kl\t1\t6.500000000\t12\t6\t6' \
    "$TMP/supported-selection.tsv"
grep -q '^result row-authority-supported$' "$TMP/supported-verdict.txt"

write_scores none > "$TMP/none.tsv"
awk -v feature_expected=2 -f "$ROOT/scripts/state_swarm_road_authority_select.awk" \
    "$TMP/none.tsv" > "$TMP/none-selection.tsv"
awk -v expected=15 -f "$ROOT/scripts/state_swarm_road_authority_verdict.awk" \
    "$TMP/none-selection.tsv" "$TMP/none.tsv" > "$TMP/none-verdict.txt"
grep -q $'^none\tnone' "$TMP/none-selection.tsv"
grep -q '^result no-row-authority-candidate$' "$TMP/none-verdict.txt"

awk -F '\t' 'BEGIN { OFS=FS } NR == 3 { $2 = "d01" } { print }' \
    "$TMP/supported.tsv" > "$TMP/duplicate.tsv"
if awk -v feature_expected=2 \
    -f "$ROOT/scripts/state_swarm_road_authority_select.awk" \
    "$TMP/duplicate.tsv" >/dev/null 2>&1; then
    printf 'road authority selector accepted duplicate discovery evidence\n' >&2
    exit 1
fi

printf 'state-swarm road authority reporters: ok\n'
