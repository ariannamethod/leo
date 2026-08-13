#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-counterbalanced-consequence-decision.XXXXXX")"
trap 'rc=$?; rm -rf "$TMP"; exit "$rc"' EXIT

write_lives() {
    local mode="$1" candidate cohort i split life raw snapshot texture unordered
    printf 'candidate\tstrength\trank\tcohort\tlife\tsplit\tepisodes\traw_episode_wins\tsnapshot_episode_wins\ttexture_episode_wins\tunordered_episode_wins\tmean_raw_ce_gain\tmean_raw_brier_gain\tmean_snapshot_ce_gain\tmean_snapshot_brier_gain\tmean_texture_ce_gain\tmean_texture_brier_gain\tmean_unordered_ce_gain\tmean_unordered_brier_gain\tmean_snapshot_raw_ce_gain\tmean_texture_snapshot_ce_gain\thome_consequence_ce_gain\tstorm_consequence_ce_gain\twonder_consequence_ce_gain\tsocial_consequence_ce_gain\thome_episodes\tstorm_episodes\twonder_episodes\tsocial_episodes\n'
    for candidate in consequence-good consequence-bad; do
        for cohort in discovery validation; do
            for ((i = 1; i <= 32; i++)); do
                if [ "$i" -le 16 ]; then
                    split=primary; life="p$(printf '%02d' "$i")"
                else
                    split=holdout; life="h$(printf '%02d' "$((i - 16))")"
                fi
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
    awk -v policy_expected=2 -v discovery_expected=32 -v validation_expected=32 \
        -f "$ROOT/scripts/state_swarm_road_episode_consequence_summary.awk" \
        "$TMP/$mode-life.tsv" > "$TMP/$mode-summary.tsv"
    awk -v policy_expected=2 -v expected=32 -v life_win_required=22 \
        -v split_win_required=10 \
        -f "$ROOT/scripts/state_swarm_road_episode_consequence_select.awk" \
        "$TMP/$mode-summary.tsv" > "$TMP/$mode-selection.tsv"
    awk -v expected=32 -v life_win_required=22 -v split_win_required=10 \
        -f "$ROOT/scripts/state_swarm_road_counterbalanced_consequence_verdict.awk" \
        "$TMP/$mode-selection.tsv" "$TMP/$mode-summary.tsv" \
        > "$TMP/$mode-verdict.txt"
}

run_decision supported
grep -q $'^consequence-good\t1\t1\t32\t128\t32\t32\t32\t32' \
    "$TMP/supported-selection.tsv"
grep -q '^required_life_wins 22$' "$TMP/supported-verdict.txt"
grep -q '^required_split_wins 10$' "$TMP/supported-verdict.txt"
grep -q '^result episode-consequence-supported$' "$TMP/supported-verdict.txt"

run_decision none
grep -q $'^none\t0\t0\t32' "$TMP/none-selection.tsv"
grep -q '^result no-episode-consequence-candidate$' "$TMP/none-verdict.txt"

printf 'state-swarm road counterbalanced-consequence decision: ok\n'
