#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-readout-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf 'candidate\tkind\tparameter\trank\n' > "$TMP/candidates.tsv"
printf 'power-2p00\tpower\t2.00\t1\n' >> "$TMP/candidates.tsv"
printf 'top-1\ttopk\t1\t2\n' >> "$TMP/candidates.tsv"

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
SOURCE='0.7/0.3/0/0/0/0/0/0'
TARGET='1/0/0/0/0/0/0/0'
UNIFORM='0.125/0.125/0.125/0.125/0.125/0.125/0.125/0.125'
HEADER='pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turn\ttexture\ttransition\tanchor_activation\ttarget_activation\tconditional_prediction\tdestination_prior\ttransition_total\tdestination_entropy\tmutual_information\tnormalized_mi\tmean_row_tv\tconditional_ce\tdestination_ce\tuniform_ce\tpersistence_ce\tconditional_brier\tdestination_brier\tuniform_brier\tpersistence_brier\tprompt\treply'

write_witnesses() {
    local kind="$1" discovery="$2" validation="$3"
    local transition conditional total information nmi tv raw_ce raw_brier
    printf '%b\n' "$HEADER" > "$discovery"
    printf '%b\n' "$HEADER" > "$validation"
    if [ "$kind" = identity ]; then
        transition="$IDENTITY"
        conditional="$SOURCE"
        total=8
        information=2.079441542
        nmi=1.000000000
        tv=0.875000000
        raw_ce=0.356674944
        raw_brier=0.180000000
    else
        transition="$RANK_ONE"
        conditional="$UNIFORM"
        total=64
        information=0.000000000
        nmi=0.000000000
        tv=0.000000000
        raw_ce=2.079441542
        raw_brier=0.875000000
    fi
    witness() {
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\thome\t%s\t%s\t%s\t%s\t%s\t%s\t2.079441542\t%s\t%s\t%s\t%s\t2.079441542\t2.079441542\t0.356674944\t%s\t0.875000000\t0.875000000\t0.180000000\tprompt %s\treply %s\n' \
            "$1" "$2" "$3" "$4" "$5" "$6" "$(( $6 + 1 ))" \
            "$transition" "$SOURCE" "$TARGET" "$conditional" "$UNIFORM" \
            "$total" "$information" "$nmi" "$tv" "$raw_ce" "$raw_brier" \
            "$1" "$2"
    }
    witness 01 event d01 p01 primary 50 >> "$discovery"
    witness 01 ecology d02 p02 primary 50 >> "$discovery"
    witness 02 event d03 p03 primary 60 >> "$discovery"
    witness 02 ecology d04 p04 primary 60 >> "$discovery"
    witness 03 organism v01 p05 primary 50 >> "$validation"
    witness 04 organism v02 p06 primary 50 >> "$validation"
    witness 05 organism v03 h01 holdout 60 >> "$validation"
    witness 06 organism v04 h02 holdout 60 >> "$validation"
}

run_pipeline() {
    local discovery="$1" validation="$2" stem="$3"
    awk -v candidate_expected=2 -v discovery_expected=4 \
        -v validation_expected=4 \
        -f "$ROOT/scripts/state_swarm_road_readout_report.awk" \
        "$TMP/candidates.tsv" "$discovery" "$validation" \
        > "$TMP/$stem-scores.tsv"
    awk -v discovery_expected=4 -v validation_expected=4 \
        -f "$ROOT/scripts/state_swarm_road_readout_summary.awk" \
        "$TMP/$stem-scores.tsv" > "$TMP/$stem-summary.tsv"
    awk -v candidate_expected=2 -v expected=4 -v win_required=3 \
        -f "$ROOT/scripts/state_swarm_road_readout_select.awk" \
        "$TMP/$stem-summary.tsv" > "$TMP/$stem-selection.tsv"
    awk -v expected=4 -v win_required=3 \
        -f "$ROOT/scripts/state_swarm_road_readout_verdict.awk" \
        "$TMP/$stem-selection.tsv" "$TMP/$stem-summary.tsv" \
        > "$TMP/$stem-verdict.txt"
}

write_witnesses identity "$TMP/supported-discovery.tsv" \
    "$TMP/supported-validation.tsv"
run_pipeline "$TMP/supported-discovery.tsv" \
    "$TMP/supported-validation.tsv" supported
grep -q $'^top-1\ttopk\t1\t2\t4\t4' "$TMP/supported-selection.tsv"
grep -q '^result readout-dilution-supported$' "$TMP/supported-verdict.txt"

write_witnesses rank-one "$TMP/rank-one-discovery.tsv" \
    "$TMP/rank-one-validation.tsv"
run_pipeline "$TMP/rank-one-discovery.tsv" \
    "$TMP/rank-one-validation.tsv" rank-one
grep -q $'^none\tnone' "$TMP/rank-one-selection.tsv"
grep -q '^result no-primary-readout-candidate$' "$TMP/rank-one-verdict.txt"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $19 = "0.500000000" } { print }' \
    "$TMP/supported-discovery.tsv" > "$TMP/false-score.tsv"
if awk -v candidate_expected=2 -v discovery_expected=4 \
    -v validation_expected=4 \
    -f "$ROOT/scripts/state_swarm_road_readout_report.awk" \
    "$TMP/candidates.tsv" "$TMP/false-score.tsv" \
    "$TMP/supported-validation.tsv" >/dev/null 2>&1; then
    printf 'road readout reporter accepted a forged raw score\n' >&2
    exit 1
fi

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $2 = "event" } { print }' \
    "$TMP/supported-validation.tsv" > "$TMP/false-cohort.tsv"
if awk -v candidate_expected=2 -v discovery_expected=4 \
    -v validation_expected=4 \
    -f "$ROOT/scripts/state_swarm_road_readout_report.awk" \
    "$TMP/candidates.tsv" "$TMP/supported-discovery.tsv" \
    "$TMP/false-cohort.tsv" >/dev/null 2>&1; then
    printf 'road readout reporter accepted a cohort leak\n' >&2
    exit 1
fi

printf 'state-swarm road readout reporters: ok\n'
