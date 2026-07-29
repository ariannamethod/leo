#!/usr/bin/env bash
# A.58: ask whether policy-arm starvation was temporal or structural.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-cadence-$STAMP}"
TARGETS=(suvin nareth flom lume tavin merel porel cavin)
ANCHORS_A=(
    "bright sun"
    "rock mountain"
    "morning sun"
    "tree forest"
    "bread cake"
    "warm fire"
    "ground soil"
    "night shadow"
)
ANCHORS_B=(
    "cold winter"
    "dog bird"
    "rain ocean"
    "fire flame"
    "sea rain"
    "bread soup"
    "sky wind"
    "walk travel"
)
TRIALS_PER_SOURCE=6
TURNS_PER_SOURCE=$((4 + 4 * TRIALS_PER_SOURCE))
TURNS=$(( ${#TARGETS[@]} * TURNS_PER_SOURCE ))
SCENARIOS=(late mixed)

if [ "${LEO_APPETITE_CADENCE_PLAN_ONLY:-0}" = 1 ]; then
    printf 'case\tsources\ttrials_per_source\tturns\tcue_pattern\tplan_visibility\n'
    printf 'late\t%d\t%d\t%d\tall-after-window\tsealed-before-replies\n' \
        "${#TARGETS[@]}" "$TRIALS_PER_SOURCE" "$TURNS"
    printf 'mixed\t%d\t%d\t%d\ttwo-within-one-after-pattern\tsealed-before-replies\n' \
        "${#TARGETS[@]}" "$TRIALS_PER_SOURCE" "$TURNS"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_holdout_fixture.c" -lm \
    -o "$OUT/holdout-fixture"
"$OUT/holdout-fixture" "$OUT/base.state" confirmed

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

checkpoint_from_log() {
    awk -v scenario="$2" -v seed=9301 \
        -f "$ROOT/scripts/wonder_appetite_checkpoint_dialogue_report.awk" \
        "$1"
}

cell_values() {
    local cells="$1"
    printf '%s\n' "$cells" |
        awk '
            {
                n = split($0, items, /\|/)
                for (i = 1; i <= n; i++) {
                    split(items[i], pair, /:/)
                    if (pair[1] != "u62-70") continue
                    split(pair[2], values, /\//)
                    for (j = 1; j <= 51; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

new_policy_counts() {
    local entries="$1"
    printf '%s\n' "$entries" |
        awk '
            {
                n = split($0, items, /\|/)
                for (i = 1; i <= n; i++) {
                    split(items[i], pair, /:/)
                    if (pair[1] ~ /^hold/) continue
                    split(pair[2], values, /\//)
                    if (values[7] == "eligible")
                        eligible++
                    else if (values[7] == "forming" ||
                             values[7] == "uncalibrated" ||
                             values[7] == "drifting")
                        abstained++
                    if (values[8] == "supported") supported++
                    if (values[8] == "overreach") overreach++
                    if (values[8] == "missed") missed++
                    if (values[8] == "restraint") restraint++
                }
                printf "%d\t%d\t%d\t%d\t%d\t%d\n",
                       eligible + 0, abstained + 0,
                       supported + 0, overreach + 0,
                       missed + 0, restraint + 0
            }
        '
}

for scenario in "${SCENARIOS[@]}"; do
    mkdir -p "$OUT/$scenario/on" "$OUT/$scenario/off"
    cp "$OUT/base.state" "$OUT/$scenario/on/state"
    cp "$OUT/base.state" "$OUT/$scenario/off/state"

    plan="$OUT/$scenario/sealed-plan.tsv"
    printf 'turn\tsource\tphase\ttrial\tintended_outcome\tprompt\n' > "$plan"
    turn=0
    for source_index in "${!TARGETS[@]}"; do
        target="${TARGETS[$source_index]}"
        anchor_a="${ANCHORS_A[$source_index]}"
        anchor_b="${ANCHORS_B[$source_index]}"
        for phase in $(seq 1 "$TURNS_PER_SOURCE"); do
            turn=$((turn + 1))
            trial=0
            intended=none
            prompt="I do not know."
            if [ "$phase" -eq 1 ]; then
                prompt="Does $target feel like $anchor_a or $anchor_b?"
            elif [ "$phase" -ge 5 ]; then
                trial=$(( (phase - 5) / 4 + 1 ))
                trial_phase=$(( (phase - 5) % 4 ))
                intended=faded
                if [ "$scenario" = mixed ] &&
                   [ $(( (trial - 1) % 3 )) -lt 2 ]; then
                    intended=sustained
                fi
                if [ "$trial_phase" -eq 0 ] ||
                   { [ "$trial_phase" -eq 3 ] &&
                     [ "$intended" = sustained ]; }; then
                    prompt="$anchor_a. $anchor_b."
                fi
            fi
            printf '%d\t%s\t%d\t%d\t%s\t%s\n' \
                "$turn" "$target" "$phase" "$trial" \
                "$intended" "$prompt" >> "$plan"
        done
    done
    [ "$turn" -eq "$TURNS" ] || {
        printf '%s plan has %d turns, expected %d\n' \
            "$scenario" "$turn" "$TURNS" >&2
        exit 1
    }
    shasum -a 256 "$plan" > "$OUT/$scenario/sealed-plan.sha256"

    reply_equal=0
    while IFS=$'\t' read -r plan_turn target phase trial intended prompt; do
        [ "$plan_turn" = turn ] && continue
        seed=$((9300 + plan_turn))
        "$ROOT/leo" --load "$OUT/$scenario/on/state" --seed "$seed" \
            --respond "$prompt" --debug-field \
            --save "$OUT/$scenario/on/state" \
            > "$OUT/$scenario/on/turn-$plan_turn.log" 2>&1
        "$ROOT/leo" --load "$OUT/$scenario/off/state" --seed "$seed" \
            --respond "$prompt" --debug-field \
            --no-wonder-appetite-checkpoint \
            --save "$OUT/$scenario/off/state" \
            > "$OUT/$scenario/off/turn-$plan_turn.log" 2>&1
        [ "$(reply_from_log "$OUT/$scenario/on/turn-$plan_turn.log")" = \
          "$(reply_from_log "$OUT/$scenario/off/turn-$plan_turn.log")" ] || {
            printf '%s checkpoint writer changed reply at turn %d\n' \
                "$scenario" "$plan_turn" >&2
            exit 1
        }
        reply_equal=$((reply_equal + 1))
    done < "$plan"
    printf '%d\n' "$reply_equal" > "$OUT/$scenario/reply-equal"

    calibration="$OUT/$scenario/calibration.tsv"
    printf 'scenario\tseed\tturn\tpending\tscored\tconfirmed\texternal\tlost\tunscorable\tbrier\tentries\n' \
        > "$calibration"
    policy="$OUT/$scenario/policy.tsv"
    printf 'scenario\tseed\teligible\tforming\tuncalibrated\tdrifting\tlegacy\tnone\tsupported\toverreach\tmissed\trestraint\tconfounded\tpending\tentries\n' \
        > "$policy"
    checkpoints="$OUT/$scenario/checkpoints.tsv"
    printf 'scenario\tseed\tbudget\tepochs\thistory\tactive\tterminal\tblocked\tcells\tone\tstable\temerging\tpersistent\trecovered\tinsufficient\tincompatible\tsequences\n' \
        > "$checkpoints"
    for report_turn in $(seq 1 "$TURNS"); do
        awk -v scenario="$scenario" -v seed=9301 \
            -f "$ROOT/scripts/wonder_appetite_calibration_dialogue_report.awk" \
            "$OUT/$scenario/on/turn-$report_turn.log" >> "$calibration"
        awk -v scenario="$scenario" -v seed=9301 \
            -f "$ROOT/scripts/wonder_appetite_policy_dialogue_report.awk" \
            "$OUT/$scenario/on/turn-$report_turn.log" >> "$policy"
        checkpoint_from_log \
            "$OUT/$scenario/on/turn-$report_turn.log" \
            "$scenario" >> "$checkpoints"
    done

    checkpoint_tail="$("$OUT/holdout-fixture" --checkpoint-tail-size)"
    state_size="$(wc -c < "$OUT/$scenario/on/state" | tr -d ' ')"
    prefix_size=$((state_size - checkpoint_tail))
    prefix_equal=0
    [ "$prefix_size" -gt 0 ] &&
        cmp -s -n "$prefix_size" \
            "$OUT/$scenario/on/state" "$OUT/$scenario/off/state" &&
        prefix_equal=1
    printf '%d\n' "$prefix_equal" > "$OUT/$scenario/prefix-equal"
done

OBSERVED="$OUT/observed.tsv"
printf 'case\tturns\treply_equal\tbody_prefix_equal\tfinal_scored\tfinal_confirmed\tfinal_brier\tnew_eligible\tnew_abstained\tnew_supported\tnew_overreach\tnew_missed\tnew_restraint\tcheckpoint_terminal\tcheckpoint_status\tcheckpoint_early_eligible\tcheckpoint_early_abstained\tcheckpoint_recent_eligible\tcheckpoint_recent_abstained\tcheckpoint_cells\n' \
    > "$OBSERVED"
for scenario in "${SCENARIOS[@]}"; do
    IFS=$'\t' read -r _ _ _ _ final_scored final_confirmed _ _ _ \
        final_brier _ < <(tail -n 1 "$OUT/$scenario/calibration.tsv")
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ policy_entries \
        < <(tail -n 1 "$OUT/$scenario/policy.tsv")
    IFS=$'\t' read -r new_eligible new_abstained new_supported \
        new_overreach new_missed new_restraint \
        < <(new_policy_counts "$policy_entries")
    report="$(tail -n 1 "$OUT/$scenario/checkpoints.tsv")"
    IFS=$'\t' read -r _ _ _ _ _ _ terminal _ cells _rest <<< "$report"
    checkpoint_status=none
    early_eligible=0
    early_abstained=0
    recent_eligible=0
    recent_abstained=0
    cell="$(cell_values "$cells")"
    if [ -n "$cell" ]; then
        IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ n \
            _ _ first_status _ _ _ _ _ _ \
            _ early_eligible early_abstained _ _ \
            _ recent_eligible recent_abstained _ _ _tail <<< "$cell"
        if [ "${n:-0}" -gt 0 ]; then
            checkpoint_status="$first_status"
        fi
    fi
    reply_equal="$(cat "$OUT/$scenario/reply-equal")"
    prefix_equal="$(cat "$OUT/$scenario/prefix-equal")"
    printf '%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$scenario" "$TURNS" "$reply_equal" "$prefix_equal" \
        "$final_scored" "$final_confirmed" "$final_brier" \
        "$new_eligible" "$new_abstained" "$new_supported" \
        "$new_overreach" "$new_missed" "$new_restraint" \
        "$terminal" "$checkpoint_status" \
        "$early_eligible" "$early_abstained" \
        "$recent_eligible" "$recent_abstained" "$cells" \
        >> "$OBSERVED"
done

late="$(awk -F '\t' '$1 == "late" { print }' "$OBSERVED")"
mixed="$(awk -F '\t' '$1 == "mixed" { print }' "$OBSERVED")"
IFS=$'\t' read -r _ _ late_replies late_prefix late_scored \
    late_confirmed _ late_eligible late_abstained late_supported \
    late_overreach late_missed late_restraint \
    late_terminal late_status late_early_eligible \
    late_early_abstained late_recent_eligible \
    late_recent_abstained _ <<< "$late"
IFS=$'\t' read -r _ _ mixed_replies mixed_prefix mixed_scored \
    mixed_confirmed _ mixed_eligible mixed_abstained \
    mixed_supported mixed_overreach mixed_missed _ \
    mixed_terminal mixed_status _rest <<< "$mixed"

[ "$late_replies" -eq "$TURNS" ] &&
[ "$mixed_replies" -eq "$TURNS" ] &&
[ "$late_prefix" = 1 ] && [ "$mixed_prefix" = 1 ] &&
[ "$late_scored" = 32 ] && [ "$late_confirmed" = 0 ] &&
[ "$late_eligible" = 0 ] && [ "$late_abstained" = 32 ] &&
[ "$late_supported" = 0 ] && [ "$late_overreach" = 0 ] &&
[ "$late_missed" = 0 ] && [ "$late_restraint" = 32 ] &&
[ "$late_terminal" = 1 ] &&
[ "$late_status" = coverage-starved ] &&
[ "$late_early_eligible" = 0 ] &&
[ "$late_early_abstained" = 16 ] &&
[ "$late_recent_eligible" = 0 ] &&
[ "$late_recent_abstained" = 16 ] &&
[ "$mixed_scored" = 32 ] &&
[ "$mixed_confirmed" -gt 0 ] &&
[ "$mixed_eligible" -gt 0 ] &&
[ "$mixed_abstained" -gt 0 ] &&
[ "$mixed_supported" -gt 0 ] &&
[ "$mixed_overreach" -gt 0 ] &&
[ "$mixed_missed" -gt 0 ] &&
[ "$mixed_terminal" = 0 ] &&
[ "$mixed_status" = none ] || {
    printf 'cadence boundary contract failed\n' >&2
    cat "$OBSERVED" >&2
    exit 1
}

cat "$OBSERVED"
printf '\nsealed lives: %s\n' "$OUT"
