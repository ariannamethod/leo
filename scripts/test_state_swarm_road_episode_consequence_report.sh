#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-episode-consequence-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf 'candidate\tconsequence_strength\tsnapshot_decay\tsnapshot_strength\ttexture_strength\tprior_alpha\tvariance_ridge\trank\n' > "$TMP/policies.tsv"
printf 'consequence-good\t1.00\t1.00\t0.25\t0.25\t1\t0.01\t1\n' >> "$TMP/policies.tsv"

SHA='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$TMP/locks.tsv"
printf 'discovery\tp01\tprimary\t64\ttrue\ttrue\t%s\t%s\n' "$SHA" "$SHA" >> "$TMP/locks.tsv"

matrix() {
    local out='' separator='' i
    for ((i = 0; i < 64; i++)); do out+="${separator}0.125"; separator='/'; done
    printf '%s' "$out"
}

one_hot() {
    local wanted="$1" out='' separator='' i
    for ((i = 1; i <= 8; i++)); do
        out+="${separator}$([ "$i" -eq "$wanted" ] && printf 1 || printf 0)"
        separator='/'
    done
    printf '%s' "$out"
}

MATRIX="$(matrix)"
IDS='1/2/3/4/5/6/7/8'
printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$TMP/witnesses.tsv"
for ((session = 1; session <= 8; session++)); do
    direction=$([ $((session % 2)) -eq 1 ] && printf 1 || printf '%s' -1)
    for ((order = 1; order <= 8; order++)); do
        turn=$((32 + (session - 1) * 8 + order))
        case "$session" in 1|5) texture=home;; 2|6) texture=storm;; 3|7) texture=wonder;; *) texture=social;; esac
        if [ "$order" -eq 1 ]; then
            [ "$direction" -eq 1 ] && source_slot=1 || source_slot=2
        elif [ "$order" -eq 8 ]; then
            [ "$direction" -eq 1 ] && source_slot=2 || source_slot=1
        else
            source_slot=$((3 + order % 2))
        fi
        target=3
        if [ "$order" -eq 1 ] && [ "$session" -gt 1 ]; then
            previous_direction=$([ $(((session - 1) % 2)) -eq 1 ] && printf 1 || printf '%s' -1)
            [ "$previous_direction" -eq 1 ] && target=4 || target=5
        fi
        members=''
        for ((slot = 1; slot <= 8; slot++)); do
            activation=0.000; [ "$slot" -eq "$target" ] && activation=1.000
            [ -z "$members" ] || members+=','
            members+="${slot}:${activation}"
        done
        printf 'discovery\tp01\tprimary\t%s\t%s\t%s\t%s\tupdated\t%s\t%s\t%s\t%s\t%s\t8.000000000\t%s\t0\t1\t1\t0.125000000\t0.125000000\t2.079441542\tprompt %s\treply %s\n' \
            "$turn" "$session" "$order" "$texture" "$((turn - 1))" "$IDS" \
            "$members" "$MATRIX" "$(one_hot "$source_slot")" "$target" "$turn" "$turn" \
            >> "$TMP/witnesses.tsv"
    done
done

awk -v policy_expected=1 -v life_expected=1 -v writer_expected=64 \
    -v evaluation_session=5 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_episode_consequence_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/witnesses.tsv" > "$TMP/scores.tsv"
awk -v policy_expected=1 -v life_expected=1 -v min_episodes=4 \
    -f "$ROOT/scripts/state_swarm_road_episode_consequence_life.awk" \
    "$TMP/scores.tsv" > "$TMP/reporter-life.tsv"
awk -F '\t' '
    NR > 1 {
        rows++
        if ($8 < 5 || $8 > 8 || $7 != 32 + ($8 - 1) * 8 + 1) exit 1
        if ($26 > 0) ending_wins++
    }
    END { if (rows != 4 || ending_wins < 2) exit 1 }
' "$TMP/scores.tsv"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $19 = "0.200000000" } { print }' \
    "$TMP/witnesses.tsv" > "$TMP/forged.tsv"
if awk -v policy_expected=1 -v life_expected=1 -v writer_expected=64 \
    -v evaluation_session=5 -v score_min=4 \
    -f "$ROOT/scripts/state_swarm_road_episode_consequence_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/forged.tsv" >/dev/null 2>&1; then
    printf 'road episode-consequence reporter accepted forged runtime probability\n' >&2
    exit 1
fi

write_lives() {
    local mode="$1" candidate cohort i split life raw snapshot texture unordered
    printf 'candidate\tstrength\trank\tcohort\tlife\tsplit\tepisodes\traw_episode_wins\tsnapshot_episode_wins\ttexture_episode_wins\tunordered_episode_wins\tmean_raw_ce_gain\tmean_raw_brier_gain\tmean_snapshot_ce_gain\tmean_snapshot_brier_gain\tmean_texture_ce_gain\tmean_texture_brier_gain\tmean_unordered_ce_gain\tmean_unordered_brier_gain\tmean_snapshot_raw_ce_gain\tmean_texture_snapshot_ce_gain\thome_consequence_ce_gain\tstorm_consequence_ce_gain\twonder_consequence_ce_gain\tsocial_consequence_ce_gain\thome_episodes\tstorm_episodes\twonder_episodes\tsocial_episodes\n'
    for candidate in consequence-good consequence-bad; do
        for cohort in discovery validation; do
            for ((i = 1; i <= 10; i++)); do
                if [ "$i" -le 5 ]; then split=primary; life="p$(printf '%02d' "$i")"
                else split=holdout; life="h$(printf '%02d' "$((i - 5))")"; fi
                raw=0; snapshot=0; texture=0; unordered=0
                if [ "$mode" = supported ] && [ "$candidate" = consequence-good ]; then
                    raw=0.010000000; snapshot=0.003000000
                    texture=0.002000000; unordered=0.001500000
                fi
                printf '%s\t%s\t%s\t%s\t%s\t%s\t4\t4\t4\t4\t4\t%s\t0.002000000\t%s\t0.001000000\t%s\t0.000500000\t%s\t0.000400000\t0.007000000\t0.001000000\t%s\t%s\t%s\t%s\t1\t1\t1\t1\n' \
                    "$candidate" "$([ "$candidate" = consequence-good ] && printf 1 || printf 0.25)" \
                    "$([ "$candidate" = consequence-good ] && printf 1 || printf 2)" \
                    "$cohort" "$life" "$split" "$raw" "$snapshot" "$texture" \
                    "$unordered" "$unordered" "$unordered" "$unordered" "$unordered"
            done
        done
    done
}

run_decision() {
    local mode="$1"
    write_lives "$mode" > "$TMP/$mode-life.tsv"
    awk -v policy_expected=2 -v discovery_expected=10 -v validation_expected=10 \
        -f "$ROOT/scripts/state_swarm_road_episode_consequence_summary.awk" \
        "$TMP/$mode-life.tsv" > "$TMP/$mode-summary.tsv"
    awk -v policy_expected=2 -f "$ROOT/scripts/state_swarm_road_episode_consequence_select.awk" \
        "$TMP/$mode-summary.tsv" > "$TMP/$mode-selection.tsv"
    awk -f "$ROOT/scripts/state_swarm_road_episode_consequence_verdict.awk" \
        "$TMP/$mode-selection.tsv" "$TMP/$mode-summary.tsv" > "$TMP/$mode-verdict.txt"
}

run_decision supported
grep -q $'^consequence-good\t1\t1\t10\t40\t10\t10\t10\t10' "$TMP/supported-selection.tsv"
grep -q '^result episode-consequence-supported$' "$TMP/supported-verdict.txt"
run_decision none
grep -q $'^none\t0\t0' "$TMP/none-selection.tsv"
grep -q '^result no-episode-consequence-candidate$' "$TMP/none-verdict.txt"

printf 'state-swarm road episode-consequence reporters: ok\n'
