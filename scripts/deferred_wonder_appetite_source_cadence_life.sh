#!/usr/bin/env bash
# A.59: join source plurality to timely recurrence before adding a handoff.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-source-cadence-$STAMP}"
TARGETS=(suvin nareth flom lume tavin merel porel cavin)
DEFERRED_TARGETS=(suvin flom lume tavin merel porel cavin)
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
ACQUISITION_TURNS_PER_SOURCE=26
ACQUISITION_TURNS=$((
    ${#TARGETS[@]} * ACQUISITION_TURNS_PER_SOURCE
))
ROUNDS=14
TURNS_PER_TRIAL=4
CONTINUATION_TURNS=$((
    ${#DEFERRED_TARGETS[@]} * ROUNDS * TURNS_PER_TRIAL
))

if [ "${LEO_APPETITE_SOURCE_CADENCE_PLAN_ONLY:-0}" = 1 ]; then
    printf 'case\tacquisition_sources\tdeferred_sources\trounds\tacquisition_turns\tcontinuation_turns\tcue_pattern\tplan_visibility\n'
    printf 'source-cadence\t%d\t%d\t%d\t%d\t%d\tround-robin-alternating-sustained-faded\tsealed-before-replies\n' \
        "${#TARGETS[@]}" "${#DEFERRED_TARGETS[@]}" "$ROUNDS" \
        "$ACQUISITION_TURNS" "$CONTINUATION_TURNS"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/acquire" "$OUT/on" "$OUT/off"

PLAN="$OUT/sealed-plan.tsv"
printf 'turn\tstage\tsource\tphase\tround\tintended_outcome\tprompt\n' \
    > "$PLAN"
turn=0
for source_index in "${!TARGETS[@]}"; do
    target="${TARGETS[$source_index]}"
    anchor_a="${ANCHORS_A[$source_index]}"
    anchor_b="${ANCHORS_B[$source_index]}"
    for phase in $(seq 1 "$ACQUISITION_TURNS_PER_SOURCE"); do
        turn=$((turn + 1))
        if [ "$phase" -eq 1 ]; then
            prompt="Does $target feel like $anchor_a or $anchor_b?"
        elif [ "$phase" -ge 5 ] &&
             [ $(( (phase - 5) % 4 )) -eq 0 ]; then
            prompt="$anchor_a. $anchor_b."
        else
            prompt="I do not know."
        fi
        printf '%d\tacquire\t%s\t%d\t0\tacquire\t%s\n' \
            "$turn" "$target" "$phase" "$prompt" >> "$PLAN"
    done
done

for round in $(seq 1 "$ROUNDS"); do
    for target in "${DEFERRED_TARGETS[@]}"; do
        source_index=-1
        for i in "${!TARGETS[@]}"; do
            if [ "${TARGETS[$i]}" = "$target" ]; then
                source_index="$i"
                break
            fi
        done
        [ "$source_index" -ge 0 ] || exit 1
        anchor_a="${ANCHORS_A[$source_index]}"
        anchor_b="${ANCHORS_B[$source_index]}"
        intended=faded
        if [ $(( (round + source_index) % 2 )) -eq 0 ]; then
            intended=sustained
        fi
        for phase in $(seq 1 "$TURNS_PER_TRIAL"); do
            turn=$((turn + 1))
            prompt="I do not know."
            if [ "$phase" -eq 1 ] ||
               { [ "$phase" -eq "$TURNS_PER_TRIAL" ] &&
                 [ "$intended" = sustained ]; }; then
                prompt="$anchor_a. $anchor_b."
            fi
            printf '%d\tcontinue\t%s\t%d\t%d\t%s\t%s\n' \
                "$turn" "$target" "$phase" "$round" \
                "$intended" "$prompt" >> "$PLAN"
        done
    done
done

TOTAL_TURNS=$((ACQUISITION_TURNS + CONTINUATION_TURNS))
[ "$turn" -eq "$TOTAL_TURNS" ] || {
    printf 'sealed plan has %d turns, expected %d\n' \
        "$turn" "$TOTAL_TURNS" >&2
    exit 1
}
shasum -a 256 "$PLAN" > "$OUT/sealed-plan.sha256"

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_holdout_fixture.c" -lm \
    -o "$OUT/holdout-fixture"
"$OUT/holdout-fixture" "$OUT/base.state" confirmed
cp "$OUT/base.state" "$OUT/acquire/state"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

while IFS=$'\t' read -r plan_turn stage source phase round intended prompt; do
    [ "$plan_turn" = turn ] && continue
    [ "$stage" = acquire ] || continue
    seed=$((9400 + plan_turn))
    "$ROOT/leo" --load "$OUT/acquire/state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --save "$OUT/acquire/state" \
        > "$OUT/acquire/turn-$plan_turn.log" 2>&1
done < "$PLAN"

cp "$OUT/acquire/state" "$OUT/on/state"
cp "$OUT/acquire/state" "$OUT/off/state"
reply_equal=0
while IFS=$'\t' read -r plan_turn stage source phase round intended prompt; do
    [ "$plan_turn" = turn ] && continue
    [ "$stage" = continue ] || continue
    seed=$((9400 + plan_turn))
    local_turn=$((plan_turn - ACQUISITION_TURNS))
    "$ROOT/leo" --load "$OUT/on/state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --save "$OUT/on/state" \
        > "$OUT/on/turn-$local_turn.log" 2>&1
    "$ROOT/leo" --load "$OUT/off/state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-checkpoint \
        --save "$OUT/off/state" \
        > "$OUT/off/turn-$local_turn.log" 2>&1
    [ "$(reply_from_log "$OUT/on/turn-$local_turn.log")" = \
      "$(reply_from_log "$OUT/off/turn-$local_turn.log")" ] || {
        printf 'checkpoint writer changed Leo reply at continuation turn %d\n' \
            "$local_turn" >&2
        exit 1
    }
    reply_equal=$((reply_equal + 1))
done < "$PLAN"

CURIOSITY="$OUT/acquisition-curiosity.tsv"
printf 'scenario\tseed\tturn\toutcome\tcandidate\tdeferred\tdeferred_heard\tdistress\tgate\n' \
    > "$CURIOSITY"
for report_turn in $(seq 1 "$ACQUISITION_TURNS"); do
    awk -v scenario=source-cadence -v seed=9401 \
        -f "$ROOT/scripts/curiosity_dialogue_report.awk" \
        "$OUT/acquire/turn-$report_turn.log" >> "$CURIOSITY"
done
queued="$(
    awk -F '\t' 'NR > 1 && $4 == "queued-occupied" { n++ }
                  END { print n + 0 }' "$CURIOSITY"
)"

CALIBRATION="$OUT/continuation-calibration.tsv"
printf 'scenario\tseed\tturn\tpending\tscored\tconfirmed\texternal\tlost\tunscorable\tbrier\tentries\n' \
    > "$CALIBRATION"
POLICY="$OUT/continuation-policy.tsv"
printf 'scenario\tseed\teligible\tforming\tuncalibrated\tdrifting\tlegacy\tnone\tsupported\toverreach\tmissed\trestraint\tconfounded\tpending\tentries\n' \
    > "$POLICY"
CHECKPOINTS="$OUT/continuation-checkpoints.tsv"
printf 'scenario\tseed\tbudget\tepochs\thistory\tactive\tterminal\tblocked\tcells\tone\tstable\temerging\tpersistent\trecovered\tinsufficient\tincompatible\tsequences\n' \
    > "$CHECKPOINTS"
for report_turn in $(seq 1 "$CONTINUATION_TURNS"); do
    awk -v scenario=source-cadence -v seed=9401 \
        -f "$ROOT/scripts/wonder_appetite_calibration_dialogue_report.awk" \
        "$OUT/on/turn-$report_turn.log" >> "$CALIBRATION"
    awk -v scenario=source-cadence -v seed=9401 \
        -f "$ROOT/scripts/wonder_appetite_policy_dialogue_report.awk" \
        "$OUT/on/turn-$report_turn.log" >> "$POLICY"
    awk -v scenario=source-cadence -v seed=9401 \
        -f "$ROOT/scripts/wonder_appetite_checkpoint_dialogue_report.awk" \
        "$OUT/on/turn-$report_turn.log" >> "$CHECKPOINTS"
done

policy_stats() {
    local entries="$1"
    printf '%s\n' "$entries" |
        awk '
            {
                n = split($0, items, /\|/)
                for (i = 1; i <= n; i++) {
                    split(items[i], pair, /:/)
                    split(pair[2], values, /\//)
                    word = pair[1]
                    if (!(word in seen)) {
                        seen[word] = 1
                        sources++
                    }
                    count[word]++
                    if (count[word] > max_source)
                        max_source = count[word]
                    if (values[7] == "eligible") eligible++
                    else if (values[7] == "forming" ||
                             values[7] == "uncalibrated" ||
                             values[7] == "drifting")
                        abstained++
                    if (values[8] == "supported") supported++
                    if (values[8] == "overreach") overreach++
                    if (values[8] == "missed") missed++
                    if (values[8] == "restraint") restraint++
                }
                printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                       sources + 0, max_source + 0,
                       eligible + 0, abstained + 0,
                       supported + 0, overreach + 0,
                       missed + 0, restraint + 0
            }
        '
}

checkpoint_cell_values() {
    local checkpoint_cells="$1"
    printf '%s\n' "$checkpoint_cells" |
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

IFS=$'\t' read -r _ _ _ final_pending final_scored final_confirmed \
    _ _ _ final_brier final_calibration_entries \
    < <(tail -n 1 "$CALIBRATION")
IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ final_policy_entries \
    < <(tail -n 1 "$POLICY")
IFS=$'\t' read -r sources max_source eligible abstained \
    supported overreach missed restraint \
    < <(policy_stats "$final_policy_entries")
last_checkpoint="$(tail -n 1 "$CHECKPOINTS")"
IFS=$'\t' read -r _ _ budget epochs history active terminal blocked \
    cells one stable emerging persistent recovered insufficient \
    incompatible sequences <<< "$last_checkpoint"
IFS=$'\t' read -r _ _ _ _ active_attempts active_status \
    active_sources active_max_source active_early_sources \
    active_early_max active_recent_sources active_recent_max \
    terminal_records \
    first_after first_through first_status first_sources first_max_source \
    first_early_sources first_early_max first_recent_sources first_recent_max \
    first_early_attempts first_early_eligible first_early_abstained \
    first_early_overreach first_early_missed \
    first_recent_attempts first_recent_eligible first_recent_abstained \
    first_recent_overreach first_recent_missed \
    second_after second_through second_status second_sources \
    second_max_source second_early_sources second_early_max \
    second_recent_sources second_recent_max \
    second_early_attempts second_early_eligible second_early_abstained \
    second_early_overreach second_early_missed \
    second_recent_attempts second_recent_eligible second_recent_abstained \
    second_recent_overreach second_recent_missed \
    < <(checkpoint_cell_values "$cells")

checkpoint_tail="$("$OUT/holdout-fixture" --checkpoint-tail-size)"
state_size="$(wc -c < "$OUT/on/state" | tr -d ' ')"
prefix_size=$((state_size - checkpoint_tail))
prefix_equal=0
[ "$prefix_size" -gt 0 ] &&
    cmp -s -n "$prefix_size" "$OUT/on/state" "$OUT/off/state" &&
    prefix_equal=1

[ "$queued" -eq 6 ] &&
[ "$reply_equal" -eq "$CONTINUATION_TURNS" ] &&
[ "$prefix_equal" -eq 1 ] &&
[ "$final_scored" -eq 32 ] &&
[ "$final_confirmed" -eq 16 ] &&
[ "$sources" -eq 7 ] &&
[ "$max_source" -eq 5 ] &&
[ "$eligible" -gt 0 ] && [ "$abstained" -gt 0 ] &&
[ "$supported" -gt 0 ] && [ "$overreach" -gt 0 ] &&
[ "$missed" -gt 0 ] && [ "$restraint" -gt 0 ] &&
[ "$terminal" -eq 2 ] && [ "$terminal_records" -eq 2 ] &&
[ "$first_status" = aggregate-shifted ] &&
[ "$second_status" = aggregate-shifted ] &&
[ "$first_sources" -eq 7 ] && [ "$second_sources" -eq 7 ] &&
[ "$first_max_source" -le 8 ] &&
[ "$second_max_source" -le 8 ] &&
[ "$first_early_sources" -ge 2 ] &&
[ "$first_recent_sources" -ge 2 ] &&
[ "$second_early_sources" -ge 2 ] &&
[ "$second_recent_sources" -ge 2 ] &&
[ "$first_early_eligible" -ge 4 ] &&
[ "$first_early_abstained" -ge 4 ] &&
[ "$first_recent_eligible" -ge 4 ] &&
[ "$first_recent_abstained" -ge 4 ] &&
[ "$second_early_eligible" -ge 4 ] &&
[ "$second_early_abstained" -ge 4 ] &&
[ "$second_recent_eligible" -ge 4 ] &&
[ "$second_recent_abstained" -ge 4 ] &&
[ "$persistent" -eq 1 ] &&
[ "$sequences" = \
  "u62-70:2/aggregate-shifted/aggregate-shifted/1/persistent-shift" ] || {
    printf 'source-cadence observation contract failed\n' >&2
    exit 1
}

OBSERVED="$OUT/observed.tsv"
printf 'case\tacquisition_queued\tcontinuation_turns\treply_equal\tbody_prefix_equal\tfinal_pending\tfinal_scored\tfinal_confirmed\tfinal_brier\tpolicy_sources\tpolicy_max_source\teligible\tabstained\tsupported\toverreach\tmissed\trestraint\tcheckpoint_budget\tcheckpoint_epochs\tcheckpoint_history\tcheckpoint_active\tcheckpoint_terminal\tcheckpoint_blocked\tfirst_status\tfirst_sources\tfirst_max_source\tfirst_early_eligible\tfirst_early_abstained\tfirst_recent_eligible\tfirst_recent_abstained\tsecond_status\tsecond_sources\tsecond_max_source\tsecond_early_eligible\tsecond_early_abstained\tsecond_recent_eligible\tsecond_recent_abstained\tsequence_one\tsequence_stable\tsequence_emerging\tsequence_persistent\tsequence_recovered\tsequence_insufficient\tsequence_incompatible\tcheckpoint_cells\tsequence_cells\n' \
    > "$OBSERVED"
printf 'source-cadence\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$queued" "$CONTINUATION_TURNS" "$reply_equal" "$prefix_equal" \
    "$final_pending" "$final_scored" "$final_confirmed" "$final_brier" \
    "$sources" "$max_source" "$eligible" "$abstained" \
    "$supported" "$overreach" "$missed" "$restraint" \
    "$budget" "$epochs" "$history" "$active" "$terminal" "$blocked" \
    "$first_status" "$first_sources" "$first_max_source" \
    "$first_early_eligible" "$first_early_abstained" \
    "$first_recent_eligible" "$first_recent_abstained" \
    "$second_status" "$second_sources" "$second_max_source" \
    "$second_early_eligible" "$second_early_abstained" \
    "$second_recent_eligible" "$second_recent_abstained" \
    "$one" "$stable" "$emerging" "$persistent" "$recovered" \
    "$insufficient" "$incompatible" "$cells" "$sequences" \
    >> "$OBSERVED"

cat "$OBSERVED"
printf '\nsealed plan: %s\ncalibration: %s\npolicy: %s\ncheckpoints: %s\n' \
    "$PLAN" "$CALIBRATION" "$POLICY" "$CHECKPOINTS"
