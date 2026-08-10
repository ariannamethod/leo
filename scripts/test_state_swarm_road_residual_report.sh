#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-residual-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf 'candidate\tdecay\tstrength\tprior_alpha\trow_shrinkage\trank\n' > "$TMP/policies.tsv"
printf 'excess-good\t1.00\t1\t1\t1\t1\n' >> "$TMP/policies.tsv"

SHA='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$TMP/locks.tsv"
printf 'discovery\tp01\tprimary\t8\ttrue\ttrue\t%s\t%s\n' "$SHA" "$SHA" >> "$TMP/locks.tsv"

matrix() {
    local out='' separator='' i
    for ((i = 0; i < 64; i++)); do
        out+="${separator}0.125"
        separator='/'
    done
    printf '%s' "$out"
}

MATRIX="$(matrix)"
SOURCE='1/0/0/0/0/0/0/0'
MEMBERS='1:1.000,2:0.000,3:0.000,4:0.000,5:0.000,6:0.000,7:0.000,8:0.000'
IDS='1/2/3/4/5/6/7/8'
printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$TMP/witnesses.tsv"
for ((turn = 33; turn <= 40; turn++)); do
    order=$((turn - 32))
    case $(((turn - 33) % 4)) in
        0) texture=home ;;
        1) texture=storm ;;
        2) texture=wonder ;;
        *) texture=social ;;
    esac
    printf 'discovery\tp01\tprimary\t%s\t1\t%s\t%s\tupdated\t%s\t%s\t%s\t%s\t%s\t8.000000000\t1\t0\t1\t1\t0.125000000\t0.125000000\t2.079441542\tprompt %s\treply %s\n' \
        "$turn" "$order" "$texture" "$((turn - 1))" "$IDS" "$MEMBERS" \
        "$MATRIX" "$SOURCE" "$turn" "$turn" >> "$TMP/witnesses.tsv"
done

awk -v policy_expected=1 -v life_expected=1 -v writer_expected=8 \
    -v evaluation_start=35 -v score_min=6 \
    -f "$ROOT/scripts/state_swarm_road_residual_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/witnesses.tsv" \
    > "$TMP/scores.tsv"
awk -v policy_expected=1 -v life_expected=1 -v min_turns=6 \
    -f "$ROOT/scripts/state_swarm_road_residual_life.awk" \
    "$TMP/scores.tsv" > "$TMP/reporter-life.tsv"
awk -F '\t' 'NR > 1 && ($18 <= 0 || $20 <= 0) { exit 1 }
    END { if (NR != 7) exit 1 }' "$TMP/scores.tsv"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $19 = "0.200000000" } { print }' \
    "$TMP/witnesses.tsv" > "$TMP/forged.tsv"
if awk -v policy_expected=1 -v life_expected=1 -v writer_expected=8 \
    -v evaluation_start=35 -v score_min=6 \
    -f "$ROOT/scripts/state_swarm_road_residual_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/forged.tsv" \
    >/dev/null 2>&1; then
    printf 'road residual reporter accepted forged runtime probability\n' >&2
    exit 1
fi

write_lives() {
    local mode="$1" candidate cohort life split i raw control
    printf 'candidate\tdecay\tstrength\trank\tcohort\tlife\tsplit\tturns\traw_turn_wins\tcontrol_turn_wins\tmean_raw_ce_gain\tmean_raw_brier_gain\tmean_control_ce_gain\tmean_control_brier_gain\tmean_destination_ce_gain\tmean_destination_brier_gain\thome_raw_ce_gain\tstorm_raw_ce_gain\twonder_raw_ce_gain\tsocial_raw_ce_gain\n'
    for candidate in excess-good excess-bad; do
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
                raw=0.000000000; control=0.000000000
                if [ "$mode" = supported ] && [ "$candidate" = excess-good ]; then
                    raw=0.010000000; control=0.004000000
                fi
                printf '%s\t1\t%s\t%s\t%s\t%s\t%s\t6\t6\t6\t%s\t0.002000000\t%s\t0.001000000\t0.020000000\t0.002000000\t%s\t%s\t%s\t%s\n' \
                    "$candidate" "$([ "$candidate" = excess-good ] && printf 1 || printf 3)" \
                    "$([ "$candidate" = excess-good ] && printf 1 || printf 2)" \
                    "$cohort" "$life" "$split" "$raw" "$control" \
                    "$raw" "$raw" "$raw" "$raw"
            done
        done
    done
}

run_decision() {
    local mode="$1"
    write_lives "$mode" > "$TMP/$mode-life.tsv"
    awk -v policy_expected=2 \
        -f "$ROOT/scripts/state_swarm_road_residual_summary.awk" \
        "$TMP/$mode-life.tsv" > "$TMP/$mode-summary.tsv"
    awk -v policy_expected=2 \
        -f "$ROOT/scripts/state_swarm_road_residual_select.awk" \
        "$TMP/$mode-summary.tsv" > "$TMP/$mode-selection.tsv"
    awk -f "$ROOT/scripts/state_swarm_road_residual_verdict.awk" \
        "$TMP/$mode-selection.tsv" "$TMP/$mode-summary.tsv" \
        > "$TMP/$mode-verdict.txt"
}

run_decision supported
grep -q $'^excess-good\t1\t1\t1\t6\t6\t6' "$TMP/supported-selection.tsv"
grep -q '^result residual-transition-learning-supported$' "$TMP/supported-verdict.txt"

run_decision none
grep -q $'^none\t0\t0' "$TMP/none-selection.tsv"
grep -q '^result no-residual-transition-candidate$' "$TMP/none-verdict.txt"

printf 'state-swarm road residual reporters: ok\n'
