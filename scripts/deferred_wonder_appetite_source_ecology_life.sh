#!/usr/bin/env bash
# A.57: observe whether a fixed broad life grows source-distinct Wonders.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-source-ecology-$STAMP}"
TURNS_PER_SOURCE=26
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
TURNS=$(( ${#TARGETS[@]} * TURNS_PER_SOURCE ))

if [ "${LEO_APPETITE_SOURCE_ECOLOGY_PLAN_ONLY:-0}" = 1 ]; then
    printf 'case\tsources\tturns_per_source\tturns\tplan_visibility\texpected_status\n'
    printf 'eight-wonder-blocks\t%d\t%d\t%d\tsealed-before-replies\tobserved-not-prescribed\n' \
        "${#TARGETS[@]}" "$TURNS_PER_SOURCE" "$TURNS"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/on" "$OUT/off" "$OUT/queue-off"

PLAN="$OUT/sealed-plan.tsv"
printf 'turn\tsource\tphase\tprompt\n' > "$PLAN"
turn=0
for source_index in "${!TARGETS[@]}"; do
    target="${TARGETS[$source_index]}"
    anchor_a="${ANCHORS_A[$source_index]}"
    anchor_b="${ANCHORS_B[$source_index]}"
    for phase in $(seq 1 "$TURNS_PER_SOURCE"); do
        turn=$((turn + 1))
        if [ "$phase" -eq 1 ]; then
            prompt="Does $target feel like $anchor_a or $anchor_b?"
        elif [ "$phase" -ge 5 ] &&
             [ $(( (phase - 5) % 4 )) -eq 0 ]; then
            prompt="$anchor_a. $anchor_b."
        else
            prompt="I do not know."
        fi
        printf '%d\t%s\t%d\t%s\n' \
            "$turn" "$target" "$phase" "$prompt" >> "$PLAN"
    done
done
[ "$turn" -eq "$TURNS" ] || {
    printf 'sealed plan has %d turns, expected %d\n' "$turn" "$TURNS" >&2
    exit 1
}
shasum -a 256 "$PLAN" > "$OUT/sealed-plan.sha256"

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_holdout_fixture.c" -lm \
    -o "$OUT/holdout-fixture"
"$OUT/holdout-fixture" "$OUT/base.state" confirmed
cp "$OUT/base.state" "$OUT/on/state"
cp "$OUT/base.state" "$OUT/off/state"
cp "$OUT/base.state" "$OUT/queue-off/state"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

report_from_log() {
    awk -v scenario=eight-wonder-blocks -v seed=9201 \
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

reply_equal=0
queue_off_reply_equal=0
while IFS=$'\t' read -r plan_turn target phase prompt; do
    [ "$plan_turn" = turn ] && continue
    seed=$((9200 + plan_turn))
    "$ROOT/leo" --load "$OUT/on/state" --seed "$seed" \
        --respond "$prompt" --debug-field --save "$OUT/on/state" \
        > "$OUT/on/turn-$plan_turn.log" 2>&1
    "$ROOT/leo" --load "$OUT/off/state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-checkpoint --save "$OUT/off/state" \
        > "$OUT/off/turn-$plan_turn.log" 2>&1
    "$ROOT/leo" --load "$OUT/queue-off/state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-occupied-wonder-queue \
        --save "$OUT/queue-off/state" \
        > "$OUT/queue-off/turn-$plan_turn.log" 2>&1
    [ "$(reply_from_log "$OUT/on/turn-$plan_turn.log")" = \
      "$(reply_from_log "$OUT/off/turn-$plan_turn.log")" ] || {
        printf 'checkpoint writer changed Leo reply at turn %d\n' \
            "$plan_turn" >&2
        exit 1
    }
    reply_equal=$((reply_equal + 1))
    [ "$(reply_from_log "$OUT/on/turn-$plan_turn.log")" = \
      "$(reply_from_log "$OUT/queue-off/turn-$plan_turn.log")" ] || {
        printf 'occupied queue changed Leo reply at turn %d\n' \
            "$plan_turn" >&2
        exit 1
    }
    queue_off_reply_equal=$((queue_off_reply_equal + 1))
done < "$PLAN"

REPORTS="$OUT/checkpoints.tsv"
printf 'scenario\tseed\tbudget\tepochs\thistory\tactive\tterminal\tblocked\tcells\tone\tstable\temerging\tpersistent\trecovered\tinsufficient\tincompatible\tsequences\n' \
    > "$REPORTS"
for report_turn in $(seq 1 "$TURNS"); do
    report_from_log \
        "$OUT/on/turn-$report_turn.log" >> "$REPORTS"
done

CALIBRATION="$OUT/calibration.tsv"
printf 'scenario\tseed\tturn\tpending\tscored\tconfirmed\texternal\tlost\tunscorable\tbrier\tentries\n' \
    > "$CALIBRATION"
for report_turn in $(seq 1 "$TURNS"); do
    awk -v scenario=eight-wonder-blocks -v seed=9201 \
        -f "$ROOT/scripts/wonder_appetite_calibration_dialogue_report.awk" \
        "$OUT/on/turn-$report_turn.log" >> "$CALIBRATION"
done

CURIOSITY="$OUT/curiosity.tsv"
printf 'scenario\tseed\tturn\toutcome\tcandidate\tdeferred\tdeferred_heard\tdistress\tgate\n' \
    > "$CURIOSITY"
for report_turn in $(seq 1 "$TURNS"); do
    awk -v scenario=eight-wonder-blocks -v seed=9201 \
        -f "$ROOT/scripts/curiosity_dialogue_report.awk" \
        "$OUT/on/turn-$report_turn.log" >> "$CURIOSITY"
done
queued="$(
    awk -F '\t' 'NR > 1 && $4 == "queued-occupied" { n++ }
                  END { print n + 0 }' "$CURIOSITY"
)"

checkpoint_tail="$("$OUT/holdout-fixture" --checkpoint-tail-size)"
state_size="$(wc -c < "$OUT/on/state" | tr -d ' ')"
prefix_size=$((state_size - checkpoint_tail))
prefix_equal=0
[ "$prefix_size" -gt 0 ] &&
    cmp -s -n "$prefix_size" "$OUT/on/state" "$OUT/off/state" &&
    prefix_equal=1

[ "$reply_equal" -eq "$TURNS" ] &&
[ "$queue_off_reply_equal" -eq "$TURNS" ] &&
[ "$prefix_equal" -eq 1 ] || {
    printf 'source ecology writer contract failed: checkpoint-replies=%d/%d queue-replies=%d/%d prefix=%d\n' \
        "$reply_equal" "$TURNS" "$queue_off_reply_equal" "$TURNS" \
        "$prefix_equal" >&2
    exit 1
}

last_report="$(tail -n 1 "$REPORTS")"
if [ "$(wc -l < "$REPORTS" | tr -d ' ')" -gt 1 ]; then
    IFS=$'\t' read -r _ _ budget epochs history active terminal blocked \
        cells one stable emerging persistent recovered insufficient \
        incompatible sequences <<< "$last_report"
else
    budget=32
    epochs=2
    history=0
    active=0
    terminal=0
    blocked=0
    cells=none
    sequences=none
fi
cell="$(cell_values "$cells")"
terminal_status=none
terminal_sources=0
terminal_max_source=0
terminal_early_sources=0
terminal_early_max_source=0
terminal_recent_sources=0
terminal_recent_max_source=0
if [ -n "$cell" ]; then
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ n \
        _ _ first_status first_sources first_max \
        first_early_sources first_early_max \
        first_recent_sources first_recent_max rest <<< "$cell"
    if [ "${n:-0}" -gt 0 ]; then
        terminal_status="$first_status"
        terminal_sources="$first_sources"
        terminal_max_source="$first_max"
        terminal_early_sources="$first_early_sources"
        terminal_early_max_source="$first_early_max"
        terminal_recent_sources="$first_recent_sources"
        terminal_recent_max_source="$first_recent_max"
    fi
fi
queue_off_report="$(
    report_from_log "$OUT/queue-off/turn-$TURNS.log"
)"
queue_off_active_status=none
queue_off_active_attempts=0
queue_off_active_sources=0
queue_off_status=none
queue_off_sources=0
if [ -n "$queue_off_report" ]; then
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ queue_off_cells \
        queue_off_rest <<< "$queue_off_report"
    queue_off_cell="$(cell_values "$queue_off_cells")"
    if [ -n "$queue_off_cell" ]; then
        IFS=$'\t' read -r _ _ _ _ queue_off_active_attempts \
            queue_off_active_status queue_off_active_sources \
            _ _ _ _ _ queue_off_n \
            _ _ queue_off_first_status queue_off_first_sources \
            queue_off_tail <<< "$queue_off_cell"
        if [ "${queue_off_n:-0}" -gt 0 ]; then
            queue_off_status="$queue_off_first_status"
            queue_off_sources="$queue_off_first_sources"
        fi
    fi
fi

OBSERVED="$OUT/observed.tsv"
printf 'case\tplanned_sources\tturns\tqueued_occupied\tcheckpoint_budget\tcheckpoint_epochs\thistory\tactive\tterminal\tblocked\tterminal_status\tterminal_sources\tterminal_max_source\tearly_sources\tearly_max_source\trecent_sources\trecent_max_source\tcheckpoint_reply_equal\tqueue_off_reply_equal\tbody_prefix_equal\tqueue_off_active_status\tqueue_off_active_attempts\tqueue_off_active_sources\tqueue_off_terminal_status\tqueue_off_terminal_sources\tcheckpoint_cells\tsequence_cells\n' \
    > "$OBSERVED"
printf 'eight-wonder-blocks\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${#TARGETS[@]}" "$TURNS" "$queued" "$budget" "$epochs" "$history" \
    "$active" "$terminal" "$blocked" "$terminal_status" \
    "$terminal_sources" "$terminal_max_source" \
    "$terminal_early_sources" "$terminal_early_max_source" \
    "$terminal_recent_sources" "$terminal_recent_max_source" \
    "$reply_equal" "$queue_off_reply_equal" "$prefix_equal" \
    "$queue_off_active_status" "$queue_off_active_attempts" \
    "$queue_off_active_sources" "$queue_off_status" "$queue_off_sources" \
    "$cells" "$sequences" >> "$OBSERVED"

cat "$OBSERVED"
printf '\nsealed plan: %s\ncuriosity: %s\ncalibration: %s\ncheckpoints: %s\n' \
    "$PLAN" "$CURIOSITY" "$CALIBRATION" "$REPORTS"
