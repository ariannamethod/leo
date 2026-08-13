#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-episode-memory-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf 'candidate\tepisode_decay\tepisode_strength\tsnapshot_decay\tsnapshot_strength\tprior_alpha\tvariance_ridge\trank\n' > "$TMP/policies.tsv"
printf 'episode-good\t0.00\t1\t1.00\t0.25\t1\t1\t1\n' >> "$TMP/policies.tsv"

SHA='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$TMP/locks.tsv"
printf 'discovery\tp01\tprimary\t24\ttrue\ttrue\t%s\t%s\n' "$SHA" "$SHA" >> "$TMP/locks.tsv"

matrix() {
    local out='' separator='' i
    for ((i = 0; i < 64; i++)); do out+="${separator}0.125"; separator='/'; done
    printf '%s' "$out"
}

matrix_without_row() {
    local missing="$1" out='' separator='' row column value
    for ((row = 1; row <= 8; row++)); do
        for ((column = 1; column <= 8; column++)); do
            value=0.125; [ "$row" -eq "$missing" ] && value=0
            out+="${separator}${value}"; separator='/'
        done
    done
    printf '%s' "$out"
}

MATRIX="$(matrix)"
IDS='1/2/3/4/5/6/7/8'
sequence=(1 3 1 2 1 3 2 1 3 3 1 2 3 2 1 3 1 2 3 1 3 2 1 2)
previous=0
printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$TMP/witnesses.tsv"
for ((index = 0; index < 24; index++)); do
    turn=$((33 + index)); session=$((index / 8 + 1)); order=$((index % 8 + 1))
    case $((index % 4)) in 0) texture=home;; 1) texture=storm;; 2) texture=wonder;; *) texture=social;; esac
    source_slot="${sequence[$index]}"
    source='0/0/0/0/0/0/0/0'
    source="$(awk -v slot="$source_slot" 'BEGIN { for (i=1;i<=8;i++) printf "%s%s", (i == 1 ? "" : "/"), (i == slot ? 1 : 0) }')"
    target=$((previous > 0 ? previous + 3 : 4))
    event=updated; replaced=0; post_ids="$IDS"; transition="$MATRIX"; transition_total=8.000000000
    has_prediction=1; expected=1; expected_probability=0.125000000
    overlap=0.125000000; surprise=2.079441542
    if [ "$turn" -eq 40 ]; then event=replaced; replaced=8; post_ids='1/2/3/4/5/6/7/9'; target=8; previous=0; fi
    if [ "$turn" -eq 41 ]; then
        transition="$(matrix_without_row "$source_slot")"; transition_total=7.000000000
        has_prediction=0; expected=0; expected_probability=0
        overlap=0; surprise=0
    fi
    IFS='/' read -r -a member_ids <<< "$post_ids"
    members=''
    for ((slot = 1; slot <= 8; slot++)); do
        activation=0.000; [ "$slot" -eq "$target" ] && activation=1.000
        [ -z "$members" ] || members+=','
        members+="${member_ids[$((slot - 1))]}:${activation}"
    done
    winner="${member_ids[$((target - 1))]}"
    printf 'discovery\tp01\tprimary\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tprompt %s\treply %s\n' \
        "$turn" "$session" "$order" "$texture" "$event" "$((turn - 1))" "$IDS" \
        "$members" "$transition" "$source" "$transition_total" "$winner" "$replaced" \
        "$has_prediction" "$expected" "$expected_probability" "$overlap" "$surprise" "$turn" "$turn" \
        >> "$TMP/witnesses.tsv"
    IDS="$post_ids"
    [ "$event" = replaced ] || previous="$source_slot"
done

awk -v policy_expected=1 -v life_expected=1 -v writer_expected=24 \
    -v evaluation_start=39 -v score_min=16 \
    -f "$ROOT/scripts/state_swarm_road_episode_memory_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/witnesses.tsv" > "$TMP/scores.tsv"
awk -v policy_expected=1 -v life_expected=1 -v min_turns=16 \
    -f "$ROOT/scripts/state_swarm_road_episode_memory_life.awk" \
    "$TMP/scores.tsv" > "$TMP/reporter-life.tsv"
awk -F '\t' '
    NR > 1 { rows++; if ($8 == 40 || $8 == 41) exit 1; if ($18 > 0) gains++ }
    END { if (rows != 16 || gains == 0) exit 1 }
' "$TMP/scores.tsv"

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $19 = "0.200000000" } { print }' \
    "$TMP/witnesses.tsv" > "$TMP/forged.tsv"
if awk -v policy_expected=1 -v life_expected=1 -v writer_expected=24 \
    -v evaluation_start=39 -v score_min=16 \
    -f "$ROOT/scripts/state_swarm_road_episode_memory_report.awk" \
    "$TMP/policies.tsv" "$TMP/locks.tsv" "$TMP/forged.tsv" >/dev/null 2>&1; then
    printf 'road episode-memory reporter accepted forged runtime probability\n' >&2
    exit 1
fi

write_lives() {
    local mode="$1" candidate cohort life split i raw snapshot
    printf 'candidate\tdecay\tstrength\trank\tcohort\tlife\tsplit\tturns\traw_turn_wins\tsnapshot_turn_wins\tmean_raw_ce_gain\tmean_raw_brier_gain\tmean_snapshot_ce_gain\tmean_snapshot_brier_gain\tmean_snapshot_raw_ce_gain\thome_raw_ce_gain\tstorm_raw_ce_gain\twonder_raw_ce_gain\tsocial_raw_ce_gain\n'
    for candidate in episode-good episode-bad; do
        for cohort in discovery validation; do
            limit=12; [ "$cohort" = validation ] && limit=10
            for ((i = 1; i <= limit; i++)); do
                if [ "$i" -le $((limit / 2)) ]; then split=primary; life="p$(printf '%02d' "$i")"
                else split=holdout; life="h$(printf '%02d' "$((i - limit / 2))")"; fi
                raw=0.000000000; snapshot=0.000000000
                if [ "$mode" = supported ] && [ "$candidate" = episode-good ]; then
                    raw=0.010000000; snapshot=0.003000000
                fi
                printf '%s\t0.5\t%s\t%s\t%s\t%s\t%s\t48\t48\t48\t%s\t0.002000000\t%s\t0.001000000\t0.007000000\t%s\t%s\t%s\t%s\n' \
                    "$candidate" "$([ "$candidate" = episode-good ] && printf 1 || printf 0.25)" \
                    "$([ "$candidate" = episode-good ] && printf 1 || printf 2)" "$cohort" \
                    "$life" "$split" "$raw" "$snapshot" "$raw" "$raw" "$raw" "$raw"
            done
        done
    done
}

run_decision() {
    local mode="$1"
    write_lives "$mode" > "$TMP/$mode-life.tsv"
    awk -v policy_expected=2 -v discovery_expected=12 -v validation_expected=10 \
        -f "$ROOT/scripts/state_swarm_road_episode_memory_summary.awk" \
        "$TMP/$mode-life.tsv" > "$TMP/$mode-summary.tsv"
    awk -v policy_expected=2 -f "$ROOT/scripts/state_swarm_road_episode_memory_select.awk" \
        "$TMP/$mode-summary.tsv" > "$TMP/$mode-selection.tsv"
    awk -f "$ROOT/scripts/state_swarm_road_episode_memory_verdict.awk" \
        "$TMP/$mode-selection.tsv" "$TMP/$mode-summary.tsv" > "$TMP/$mode-verdict.txt"
}

run_decision supported
grep -q $'^episode-good\t0.5\t1\t1\t12\t12\t12' "$TMP/supported-selection.tsv"
grep -q '^result episode-memory-supported$' "$TMP/supported-verdict.txt"
run_decision none
grep -q $'^none\t0\t0' "$TMP/none-selection.tsv"
grep -q '^result no-episode-memory-candidate$' "$TMP/none-verdict.txt"

printf 'state-swarm road episode-memory reporters: ok\n'
