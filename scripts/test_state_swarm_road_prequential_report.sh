#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-prequential-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

cc "$ROOT/tests/state_swarm_road_prequential_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/prequential-fixture" -lpthread

printf 'candidate\tdecay\tstrength\trank\n' > "$TMP/policies.tsv"
printf 'good\t1.00\t1\t1\n' >> "$TMP/policies.tsv"
printf 'strong\t1.00\t3\t2\n' >> "$TMP/policies.tsv"

SHA='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$TMP/locks.tsv"
printf 'discovery\tp01\tprimary\t8\ttrue\ttrue\t%s\t%s\n' "$SHA" "$SHA" >> "$TMP/locks.tsv"
printf 'validation\th01\tholdout\t8\ttrue\ttrue\t%s\t%s\n' "$SHA" "$SHA" >> "$TMP/locks.tsv"

matrix() {
    local out='' separator='' value i j
    for ((i = 0; i < 8; i++)); do
        for ((j = 0; j < 8; j++)); do
            if [ "$i" -eq 0 ]; then
                [ "$j" -eq 0 ] && value=0.9 || { [ "$j" -eq 1 ] && value=0.1 || value=0; }
            elif [ "$i" -eq 1 ]; then
                [ "$j" -eq 0 ] && value=0.1 || { [ "$j" -eq 1 ] && value=0.9 || value=0; }
            else
                value=0.125
            fi
            out+="${separator}${value}"
            separator='/'
        done
    done
    printf '%s' "$out"
}

MATRIX="$(matrix)"
SOURCE='0.5/0.5/0/0/0/0/0/0'
MEMBERS='1:1.000,2:0.000,3:0.000,4:0.000,5:0.000,6:0.000,7:0.000,8:0.000'
IDS='1/2/3/4/5/6/7/8'
printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$TMP/witnesses.tsv"
for cohort_life in 'discovery p01 primary' 'validation h01 holdout'; do
    read -r cohort life split <<< "$cohort_life"
    for ((turn = 33; turn <= 40; turn++)); do
        order=$((turn - 32))
        case $(((turn - 33) % 4)) in
            0) texture=home ;;
            1) texture=storm ;;
            2) texture=wonder ;;
            *) texture=social ;;
        esac
        printf '%s\t%s\t%s\t%s\t1\t%s\t%s\tupdated\t%s\t%s\t%s\t%s\t%s\t8.000000000\t1\t0\t1\t1\t0.500000000\t0.500000000\t0.693147181\tprompt %s\treply %s\n' \
            "$cohort" "$life" "$split" "$turn" "$order" "$texture" "$((turn - 1))" \
            "$IDS" "$MEMBERS" "$MATRIX" "$SOURCE" "$turn" "$turn" \
            >> "$TMP/witnesses.tsv"
    done
done

awk -v policy_expected=2 -v life_expected=2 -v writer_expected=8 \
    -v evaluation_start=35 -v score_min=6 \
    -f "$ROOT/scripts/state_swarm_road_prequential_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/witnesses.tsv" \
    > "$TMP/scores.tsv"
awk -v policy_expected=2 -v life_expected=2 -v min_turns=6 \
    -f "$ROOT/scripts/state_swarm_road_prequential_life.awk" \
    "$TMP/scores.tsv" > "$TMP/reporter-life.tsv"
awk -F '\t' 'NR > 1 && $16 <= 0 { exit 1 } END { if (NR != 25) exit 1 }' \
    "$TMP/scores.tsv"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $19 = "0.700000000" } { print }' \
    "$TMP/witnesses.tsv" > "$TMP/forged.tsv"
if awk -v policy_expected=2 -v life_expected=2 -v writer_expected=8 \
    -v evaluation_start=35 -v score_min=6 \
    -f "$ROOT/scripts/state_swarm_road_prequential_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/forged.tsv" \
    >/dev/null 2>&1; then
    printf 'road prequential reporter accepted forged runtime probability\n' >&2
    exit 1
fi

write_lives() {
    local mode="$1" candidate cohort life split i gain brier destination
    printf 'candidate\tdecay\tstrength\trank\tcohort\tlife\tsplit\tturns\tturn_wins\tmean_raw_ce_gain\tmean_raw_brier_gain\tmean_destination_ce_gain\tmean_destination_brier_gain\thome_raw_ce_gain\tstorm_raw_ce_gain\twonder_raw_ce_gain\tsocial_raw_ce_gain\n'
    for candidate in good bad; do
        for cohort in discovery validation; do
            limit=6
            [ "$cohort" = validation ] && limit=12
            for ((i = 1; i <= limit; i++)); do
                split=primary
                life="p$(printf '%02d' "$i")"
                if [ "$cohort" = validation ] && [ "$i" -gt 6 ]; then
                    split=holdout
                    life="h$(printf '%02d' "$((i - 6))")"
                fi
                gain=0.000000000; brier=0.000000000; destination=0.000000000
                if [ "$mode" = supported ] && [ "$candidate" = good ]; then
                    gain=0.010000000; brier=0.002000000; destination=0.020000000
                fi
                printf '%s\t1\t%s\t%s\t%s\t%s\t%s\t6\t6\t%s\t%s\t%s\t0.002000000\t%s\t%s\t%s\t%s\n' \
                    "$candidate" "$([ "$candidate" = good ] && printf 1 || printf 3)" \
                    "$([ "$candidate" = good ] && printf 1 || printf 2)" \
                    "$cohort" "$life" "$split" "$gain" "$brier" \
                    "$destination" "$gain" "$gain" "$gain" "$gain"
            done
        done
    done
}

run_decision() {
    local mode="$1"
    write_lives "$mode" > "$TMP/$mode-life.tsv"
    awk -v policy_expected=2 \
        -f "$ROOT/scripts/state_swarm_road_prequential_summary.awk" \
        "$TMP/$mode-life.tsv" > "$TMP/$mode-summary.tsv"
    awk -v policy_expected=2 \
        -f "$ROOT/scripts/state_swarm_road_prequential_select.awk" \
        "$TMP/$mode-summary.tsv" > "$TMP/$mode-selection.tsv"
    awk -f "$ROOT/scripts/state_swarm_road_prequential_verdict.awk" \
        "$TMP/$mode-selection.tsv" "$TMP/$mode-summary.tsv" \
        > "$TMP/$mode-verdict.txt"
}

run_decision supported
grep -q $'^good\t1\t1\t1\t6\t6' "$TMP/supported-selection.tsv"
grep -q '^result prequential-row-authority-supported$' "$TMP/supported-verdict.txt"

run_decision none
grep -q $'^none\t0\t0' "$TMP/none-selection.tsv"
grep -q '^result no-prequential-authority-candidate$' "$TMP/none-verdict.txt"

printf 'state-swarm road prequential reporters: ok\n'
