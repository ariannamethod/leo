#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-covariance-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf 'candidate\tdecay\tstrength\tprior_alpha\tvariance_ridge\trank\n' > "$TMP/policies.tsv"
printf 'cov-good\t1.00\t1\t1\t1\t1\n' >> "$TMP/policies.tsv"

SHA='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$TMP/locks.tsv"
printf 'discovery\tp01\tprimary\t12\ttrue\ttrue\t%s\t%s\n' "$SHA" "$SHA" >> "$TMP/locks.tsv"

matrix() {
    local out='' separator='' i
    for ((i = 0; i < 64; i++)); do
        out+="${separator}0.125"
        separator='/'
    done
    printf '%s' "$out"
}

MATRIX="$(matrix)"
IDS='1/2/3/4/5/6/7/8'
printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$TMP/witnesses.tsv"
for ((turn = 33; turn <= 44; turn++)); do
    session=$(((turn - 33) / 8 + 1))
    order=$(((turn - 33) % 8 + 1))
    case $(((turn - 33) % 4)) in
        0) texture=home ;;
        1) texture=storm ;;
        2) texture=wonder ;;
        *) texture=social ;;
    esac
    event=updated
    replaced=0
    if [ $((turn % 2)) -eq 1 ]; then
        source='1/0/0/0/0/0/0/0'
        members="1:0.000,2:1.000,3:0.000,4:0.000,5:0.000,6:0.000,7:0.000,$([ "$turn" -lt 36 ] && printf '8' || printf '9'):0.000"
        winner=2
    else
        source='0/1/0/0/0/0/0/0'
        members="1:1.000,2:0.000,3:0.000,4:0.000,5:0.000,6:0.000,7:0.000,$([ "$turn" -lt 36 ] && printf '8' || printf '9'):0.000"
        winner=1
    fi
    if [ "$turn" -eq 36 ]; then
        event=replaced
        winner=9
        replaced=8
    fi
    printf 'discovery\tp01\tprimary\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t8.000000000\t%s\t%s\t1\t1\t0.125000000\t0.125000000\t2.079441542\tprompt %s\treply %s\n' \
        "$turn" "$session" "$order" "$texture" "$event" "$((turn - 1))" "$IDS" "$members" \
        "$MATRIX" "$source" "$winner" "$replaced" "$turn" "$turn" >> "$TMP/witnesses.tsv"
    [ "$turn" -eq 36 ] && IDS='1/2/3/4/5/6/7/9'
done

awk -v policy_expected=1 -v life_expected=1 -v writer_expected=12 \
    -v evaluation_start=41 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_covariance_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/witnesses.tsv" \
    > "$TMP/scores.tsv"
awk -v policy_expected=1 -v life_expected=1 -v min_turns=4 \
    -f "$ROOT/scripts/state_swarm_road_covariance_life.awk" \
    "$TMP/scores.tsv" > "$TMP/reporter-life.tsv"
awk -F '\t' 'NR > 1 && ($16 <= 0 || $18 <= 0) { exit 1 }
    END { if (NR != 5) exit 1 }' "$TMP/scores.tsv"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $19 = "0.200000000" } { print }' \
    "$TMP/witnesses.tsv" > "$TMP/forged.tsv"
if awk -v policy_expected=1 -v life_expected=1 -v writer_expected=12 \
    -v evaluation_start=41 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_covariance_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/forged.tsv" \
    >/dev/null 2>&1; then
    printf 'road covariance reporter accepted forged runtime probability\n' >&2
    exit 1
fi

write_lives() {
    local mode="$1" candidate cohort life split i raw prior
    printf 'candidate\tdecay\tstrength\trank\tcohort\tlife\tsplit\tturns\traw_turn_wins\tprior_turn_wins\tmean_raw_ce_gain\tmean_raw_brier_gain\tmean_prior_ce_gain\tmean_prior_brier_gain\thome_raw_ce_gain\tstorm_raw_ce_gain\twonder_raw_ce_gain\tsocial_raw_ce_gain\n'
    for candidate in cov-good cov-bad; do
        for cohort in discovery validation; do
            limit=6
            [ "$cohort" = validation ] && limit=10
            for ((i = 1; i <= limit; i++)); do
                split=primary
                life="p$(printf '%02d' "$i")"
                if [ "$cohort" = validation ] && [ "$i" -gt 5 ]; then
                    split=holdout
                    life="h$(printf '%02d' "$((i - 5))")"
                fi
                raw=0.000000000; prior=0.000000000
                if [ "$mode" = supported ] && [ "$candidate" = cov-good ]; then
                    raw=0.010000000; prior=0.020000000
                fi
                printf '%s\t1\t%s\t%s\t%s\t%s\t%s\t6\t6\t6\t%s\t0.002000000\t%s\t0.002000000\t%s\t%s\t%s\t%s\n' \
                    "$candidate" "$([ "$candidate" = cov-good ] && printf 1 || printf 0.25)" \
                    "$([ "$candidate" = cov-good ] && printf 1 || printf 2)" \
                    "$cohort" "$life" "$split" "$raw" "$prior" \
                    "$raw" "$raw" "$raw" "$raw"
            done
        done
    done
}

run_decision() {
    local mode="$1"
    write_lives "$mode" > "$TMP/$mode-life.tsv"
    awk -v policy_expected=2 -v discovery_expected=6 -v validation_expected=10 \
        -f "$ROOT/scripts/state_swarm_road_covariance_summary.awk" \
        "$TMP/$mode-life.tsv" > "$TMP/$mode-summary.tsv"
    awk -v policy_expected=2 \
        -f "$ROOT/scripts/state_swarm_road_covariance_select.awk" \
        "$TMP/$mode-summary.tsv" > "$TMP/$mode-selection.tsv"
    awk -f "$ROOT/scripts/state_swarm_road_covariance_verdict.awk" \
        "$TMP/$mode-selection.tsv" "$TMP/$mode-summary.tsv" \
        > "$TMP/$mode-verdict.txt"
}

run_decision supported
grep -q $'^cov-good\t1\t1\t1\t6\t6\t6' "$TMP/supported-selection.tsv"
grep -q '^result temporal-covariance-supported$' "$TMP/supported-verdict.txt"

run_decision none
grep -q $'^none\t0\t0' "$TMP/none-selection.tsv"
grep -q '^result no-covariance-candidate$' "$TMP/none-verdict.txt"

printf 'state-swarm road covariance reporters: ok\n'
