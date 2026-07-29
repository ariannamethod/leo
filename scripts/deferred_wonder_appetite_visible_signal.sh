#!/usr/bin/env bash
# A.61: test whether appetite separates a visible proposal-side history.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-visible-signal-$STAMP}"

ACQUISITION_TARGETS=(suvin nareth flom lume tavin merel porel cavin)
ACQUISITION_ANCHORS_A=(
    "bright sun"
    "rock mountain"
    "morning sun"
    "tree forest"
    "bread cake"
    "warm fire"
    "ground soil"
    "night shadow"
)
ACQUISITION_ANCHORS_B=(
    "cold winter"
    "dog bird"
    "rain ocean"
    "fire flame"
    "sea rain"
    "bread soup"
    "sky wind"
    "walk travel"
)
EXPERIMENT_TARGETS=(suvin lume porel cavin)
EXPERIMENT_GROUPS=(high high low low)
EXPERIMENT_ANCHORS_A=(
    "bright sun"
    "tree forest"
    "ground soil"
    "night shadow"
)
EXPERIMENT_ANCHORS_B=(
    "cold winter"
    "fire flame"
    "sky wind"
    "walk travel"
)
EMBODY_PROMPTS=(
    "suvin."
    "lume."
    "suvin."
    "lume."
    "suvin."
    "lume."
    "nareth."
)
ACQUISITION_TURNS_PER_SOURCE=26
ACQUISITION_TURNS=$((
    ${#ACQUISITION_TARGETS[@]} * ACQUISITION_TURNS_PER_SOURCE
))
SETTLE_TURNS=8
PRELUDE_TURNS=$((${#EMBODY_PROMPTS[@]} + SETTLE_TURNS))
TRIALS=8
TURNS_PER_TRIAL=4
EXPERIMENT_TURNS=$((
    ${#EXPERIMENT_TARGETS[@]} * TRIALS * TURNS_PER_TRIAL
))
TOTAL_TURNS=$((ACQUISITION_TURNS + PRELUDE_TURNS + EXPERIMENT_TURNS))

if [ "${LEO_APPETITE_VISIBLE_SIGNAL_PLAN_ONLY:-0}" = 1 ]; then
    printf 'case\tlife_turns\tforecasts\thigh_sources\tlow_sources\tproposal_signal\toutcome_schedule\tplan_visibility\n'
    printf 'visible-history\t%d\t%d\t2\t2\tspoken-open-vs-unspoken-deferred\t7/8-vs-5/8\tsealed-before-replies\n' \
        "$TOTAL_TURNS" "$(( ${#EXPERIMENT_TARGETS[@]} * TRIALS ))"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/acquire" "$OUT/prelude" "$OUT/on" "$OUT/off"

PLAN="$OUT/sealed-plan.tsv"
printf 'turn\tstage\tsource\tgroup\tphase\ttrial\tintended_outcome\tprompt\n' \
    > "$PLAN"
turn=0
for source_index in "${!ACQUISITION_TARGETS[@]}"; do
    target="${ACQUISITION_TARGETS[$source_index]}"
    anchor_a="${ACQUISITION_ANCHORS_A[$source_index]}"
    anchor_b="${ACQUISITION_ANCHORS_B[$source_index]}"
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
        printf '%d\tacquire\t%s\tbase\t%d\t0\tacquire\t%s\n' \
            "$turn" "$target" "$phase" "$prompt" >> "$PLAN"
    done
done

for prompt in "${EMBODY_PROMPTS[@]}"; do
    turn=$((turn + 1))
    source="${prompt%.}"
    printf '%d\tembody\t%s\thigh\t0\t0\tembody\t%s\n' \
        "$turn" "$source" "$prompt" >> "$PLAN"
done
for phase in $(seq 1 "$SETTLE_TURNS"); do
    turn=$((turn + 1))
    printf '%d\tsettle\tnone\tbase\t%d\t0\tsettle\tI do not know.\n' \
        "$turn" "$phase" >> "$PLAN"
done

for source_index in "${!EXPERIMENT_TARGETS[@]}"; do
    target="${EXPERIMENT_TARGETS[$source_index]}"
    group="${EXPERIMENT_GROUPS[$source_index]}"
    anchor_a="${EXPERIMENT_ANCHORS_A[$source_index]}"
    anchor_b="${EXPERIMENT_ANCHORS_B[$source_index]}"
    for trial in $(seq 1 "$TRIALS"); do
        intended=faded
        if [ "$group" = high ] && [ "$trial" -lt "$TRIALS" ]; then
            intended=sustained
        elif [ "$group" = low ]; then
            case "$trial" in
                1|2|4|6|8) intended=sustained ;;
            esac
        fi
        for phase in $(seq 1 "$TURNS_PER_TRIAL"); do
            turn=$((turn + 1))
            prompt="I do not know."
            if [ "$phase" -eq 1 ] ||
               { [ "$phase" -eq "$TURNS_PER_TRIAL" ] &&
                 [ "$intended" = sustained ]; }; then
                prompt="$anchor_a. $anchor_b."
            fi
            printf '%d\tforecast\t%s\t%s\t%d\t%d\t%s\t%s\n' \
                "$turn" "$target" "$group" "$phase" "$trial" \
                "$intended" "$prompt" >> "$PLAN"
        done
    done
done

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

while IFS=$'\t' read -r plan_turn stage source group phase trial \
        intended prompt; do
    [ "$plan_turn" = turn ] && continue
    [ "$stage" = acquire ] || continue
    seed=$((9700 + plan_turn))
    "$ROOT/leo" --load "$OUT/acquire/state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$OUT/acquire/state" \
        > "$OUT/acquire/turn-$plan_turn.log" 2>&1
done < "$PLAN"

cp "$OUT/acquire/state" "$OUT/prelude/state"
while IFS=$'\t' read -r plan_turn stage source group phase trial \
        intended prompt; do
    [ "$plan_turn" = turn ] && continue
    { [ "$stage" = embody ] || [ "$stage" = settle ]; } || continue
    seed=$((9700 + plan_turn))
    local_turn=$((plan_turn - ACQUISITION_TURNS))
    "$ROOT/leo" --load "$OUT/prelude/state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$OUT/prelude/state" \
        > "$OUT/prelude/turn-$local_turn.log" 2>&1
done < "$PLAN"

cp "$OUT/prelude/state" "$OUT/on/state"
cp "$OUT/prelude/state" "$OUT/off/state"
reply_equal=0
while IFS=$'\t' read -r plan_turn stage source group phase trial \
        intended prompt; do
    [ "$plan_turn" = turn ] && continue
    [ "$stage" = forecast ] || continue
    seed=$((9700 + plan_turn))
    local_turn=$((plan_turn - ACQUISITION_TURNS - PRELUDE_TURNS))
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
        printf 'checkpoint writer changed Leo reply at experiment turn %d\n' \
            "$local_turn" >&2
        exit 1
    }
    reply_equal=$((reply_equal + 1))
done < "$PLAN"

FIRST_CLOCK="$(
    awk '
        /\[wonder-appetite: turn=/ {
            if (match($0, /turn=[0-9]+/)) {
                print substr($0, RSTART + 5, RLENGTH - 5)
                exit
            }
        }
    ' "$OUT/on/turn-1.log"
)"
PROPOSAL_OFFSET=$((FIRST_CLOCK - 1))

SETTLED="$OUT/settled.tsv"
printf 'group\tword\tproposed_turn\tdeadline_turn\tobserved_turn\tappetite\tpeak_recurrence\tsemantic_hits\tobservations\tspoken\tverdict\tbrier\n' \
    > "$SETTLED"
for experiment_turn in $(seq 1 "$EXPERIMENT_TURNS"); do
    awk -v offset="$PROPOSAL_OFFSET" '
        /\[wonder-appetite-calibration:/ &&
        /\/(sustained|faded)\// {
            line = $0
            sub(/^.*entries=/, "", line)
            sub(/\].*$/, "", line)
            split(line, values, /[:\/]/)
            if (values[2] <= offset) next
            group = "low"
            if (values[1] == "suvin" || values[1] == "lume")
                group = "high"
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                   group, values[1], values[2], values[3], values[4],
                   values[5], values[6], values[7], values[8],
                   values[9], values[10], values[11]
        }
    ' "$OUT/on/turn-$experiment_turn.log" >> "$SETTLED"
done

PROPOSALS="$OUT/proposal-outcomes.tsv"
printf 'group\tword\tproposed_turn\tverdict\treceipt_appetite\tstatus\tmargin\trecurrence\tsilence\tunfinished\tflow_gap\tcandidate_appetite\tspoken\tliteral\n' \
    > "$PROPOSALS"
while IFS=$'\t' read -r group word proposed deadline observed \
        receipt_appetite peak hits observations spoken verdict brier; do
    [ "$group" = group ] && continue
    local_turn=$((proposed - PROPOSAL_OFFSET))
    awk -v group="$group" -v word="$word" -v proposed="$proposed" \
        -v verdict="$verdict" -v receipt_appetite="$receipt_appetite" '
        /\[wonder-appetite: turn=/ {
            line = $0
            status = margin = ""
            if (match(line, /status=[^ ]+/))
                status = substr(line, RSTART + 7, RLENGTH - 7)
            if (match(line, /margin=[^ ]+/))
                margin = substr(line, RSTART + 7, RLENGTH - 7)
            sub(/^.*entries=/, "", line)
            sub(/\].*$/, "", line)
            n = split(line, items, /\|/)
            for (i = 1; i <= n; i++) {
                split(items[i], values, /[:\/]/)
                if (values[1] != word) continue
                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                       group, word, proposed, verdict, receipt_appetite,
                       status, margin, values[2], values[3],
                       values[4], values[5], values[6],
                       values[7], values[8]
            }
        }
    ' "$OUT/on/turn-$local_turn.log" >> "$PROPOSALS"
done < "$SETTLED"

EXPECTED="$OUT/expected-outcomes.tsv"
printf 'group\tword\tproposed_turn\tverdict\n' > "$EXPECTED"
awk -F '\t' -v offset="$PROPOSAL_OFFSET" \
        -v prelude_end="$((ACQUISITION_TURNS + PRELUDE_TURNS))" '
    NR > 1 && $2 == "forecast" && $5 == 1 {
        local_turn = $1 - prelude_end
        printf "%s\t%s\t%d\t%s\n",
               $4, $3, offset + local_turn, $7
    }
' "$PLAN" >> "$EXPECTED"
ACTUAL="$OUT/actual-outcomes.tsv"
printf 'group\tword\tproposed_turn\tverdict\n' > "$ACTUAL"
awk -F '\t' '
    NR > 1 { printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $11 }
' "$SETTLED" >> "$ACTUAL"
outcomes_match=0
cmp -s "$EXPECTED" "$ACTUAL" && outcomes_match=1

group_stats() {
    local group="$1"
    awk -F '\t' -v group="$group" '
        NR > 1 && $1 == group {
            n++
            sustained += ($4 == "sustained")
            faded += ($4 == "faded")
            p += $12
            y = ($4 == "sustained")
            brier += ($12 - y) * ($12 - y)
        }
        END {
            printf "%d\t%d\t%d\t%.3f\t%.3f\t%.3f\n",
                   n + 0, sustained + 0, faded + 0,
                   p / n, sustained / n, brier / n
        }
    ' "$PROPOSALS"
}

IFS=$'\t' read -r high_rows high_sustained high_faded \
    high_probability high_rate high_brier < <(group_stats high)
IFS=$'\t' read -r low_rows low_sustained low_faded \
    low_probability low_rate low_brier < <(group_stats low)
proposal_rows=$(( $(wc -l < "$PROPOSALS") - 1 ))
score_gap="$(
    awk -v high="$high_probability" -v low="$low_probability" \
        'BEGIN { printf "%.3f", high - low }'
)"
outcome_auc="$(
    awk -F '\t' '
        NR > 1 {
            n++
            score[n] = $12 + 0
            outcome[n] = ($4 == "sustained")
        }
        END {
            for (i = 1; i <= n; i++) {
                if (!outcome[i]) continue
                for (j = 1; j <= n; j++) {
                    if (outcome[j]) continue
                    pairs++
                    if (score[i] > score[j]) wins++
                    else if (score[i] == score[j]) ties++
                }
            }
            printf "%.3f", (wins + 0.5 * ties) / pairs
        }
    ' "$PROPOSALS"
)"
distinct_vectors="$(
    awk -F '\t' '
        NR > 1 {
            key = $6 FS $8 FS $9 FS $10 FS $11 FS $12 FS $13 FS $14
            seen[key] = 1
        }
        END { for (key in seen) n++; print n + 0 }
    ' "$PROPOSALS"
)"
receipt_mismatches="$(
    awk -F '\t' '
        NR > 1 && $5 != $12 { n++ }
        END { print n + 0 }
    ' "$PROPOSALS"
)"
high_vector="$(
    awk -F '\t' '
        NR > 1 && $1 == "high" {
            printf "%s/%s/%s/%s/%s/%s/%s/%s",
                   $6, $8, $9, $10, $11, $12, $13, $14
            exit
        }
    ' "$PROPOSALS"
)"
low_vector="$(
    awk -F '\t' '
        NR > 1 && $1 == "low" {
            printf "%s/%s/%s/%s/%s/%s/%s/%s",
                   $6, $8, $9, $10, $11, $12, $13, $14
            exit
        }
    ' "$PROPOSALS"
)"
high_margins="$(
    awk -F '\t' '
        NR > 1 && $1 == "high" { count[$7]++ }
        END {
            for (margin in count) {
                printf "%s%s:%d", separator, margin, count[margin]
                separator = "|"
            }
        }
    ' "$PROPOSALS"
)"
low_margins="$(
    awk -F '\t' '
        NR > 1 && $1 == "low" { count[$7]++ }
        END {
            for (margin in count) {
                printf "%s%s:%d", separator, margin, count[margin]
                separator = "|"
            }
        }
    ' "$PROPOSALS"
)"

FINAL_LOG="$OUT/on/turn-$EXPERIMENT_TURNS.log"
IFS=$'\t' read -r low_live_n low_live_sustained low_live_probability \
    low_live_rate low_live_brier low_live_status high_live_n \
    high_live_sustained high_live_probability high_live_rate \
    high_live_brier high_live_status < <(
        awk '
            /\[wonder-appetite-reliability:/ {
                line = $0
                sub(/^.*cells=/, "", line)
                sub(/\].*$/, "", line)
                n = split(line, cells, /\|/)
                for (i = 1; i <= n; i++) {
                    split(cells[i], pair, /:/)
                    split(pair[2], values, /\//)
                    if (pair[1] == "u62-70") {
                        low_n = values[1]
                        low_yes = values[2]
                        low_p = values[3]
                        low_rate = values[4]
                        low_brier = values[7]
                        low_status = values[9]
                    } else if (pair[1] == "s80-90") {
                        high_n = values[1]
                        high_yes = values[2]
                        high_p = values[3]
                        high_rate = values[4]
                        high_brier = values[7]
                        high_status = values[9]
                    }
                }
                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                       low_n, low_yes, low_p, low_rate, low_brier,
                       low_status, high_n, high_yes, high_p,
                       high_rate, high_brier, high_status
            }
        ' "$FINAL_LOG"
    )

checkpoint_tail="$("$OUT/holdout-fixture" --checkpoint-tail-size)"
state_size="$(wc -c < "$OUT/on/state" | tr -d ' ')"
prefix_size=$((state_size - checkpoint_tail))
prefix_equal=0
[ "$prefix_size" -gt 0 ] &&
    cmp -s -n "$prefix_size" "$OUT/on/state" "$OUT/off/state" &&
    prefix_equal=1

[ "$proposal_rows" -eq 32 ] &&
[ "$high_rows" -eq 16 ] &&
[ "$high_sustained" -eq 14 ] &&
[ "$high_faded" -eq 2 ] &&
[ "$high_probability" = 0.890 ] &&
[ "$high_rate" = 0.875 ] &&
[ "$high_brier" = 0.110 ] &&
[ "$low_rows" -eq 16 ] &&
[ "$low_sustained" -eq 10 ] &&
[ "$low_faded" -eq 6 ] &&
[ "$low_probability" = 0.690 ] &&
[ "$low_rate" = 0.625 ] &&
[ "$low_brier" = 0.239 ] &&
[ "$score_gap" = 0.200 ] &&
[ "$outcome_auc" = 0.667 ] &&
[ "$distinct_vectors" -eq 2 ] &&
[ "$receipt_mismatches" -eq 0 ] &&
[ "$outcomes_match" -eq 1 ] &&
[ "$high_vector" = \
  "salient/0.800/1.000/1.000/1.000/0.890/1/0" ] &&
[ "$low_vector" = \
  "salient/0.800/1.000/0.500/0.000/0.690/0/0" ] &&
[ "$high_margins" = "0.420:16" ] &&
[ "$low_margins" = "0.240:16" ] &&
[ "$low_live_n" -eq 16 ] &&
[ "$low_live_sustained" -eq 10 ] &&
[ "$low_live_probability" = "$low_probability" ] &&
[ "$low_live_rate" = "$low_rate" ] &&
[ "$low_live_brier" = "$low_brier" ] &&
[ "$low_live_status" = aligned ] &&
[ "$high_live_n" -eq 16 ] &&
[ "$high_live_sustained" -eq 14 ] &&
[ "$high_live_probability" = "$high_probability" ] &&
[ "$high_live_rate" = "$high_rate" ] &&
[ "$high_live_brier" = "$high_brier" ] &&
[ "$high_live_status" = aligned ] &&
[ "$reply_equal" -eq "$EXPERIMENT_TURNS" ] &&
[ "$prefix_equal" -eq 1 ] || {
    printf 'visible-signal observation contract failed\n' >&2
    exit 1
}

OBSERVED="$OUT/observed.tsv"
printf 'case\tforecasts\thigh_sources\thigh_sustained\thigh_faded\thigh_probability\thigh_rate\thigh_brier\tlow_sources\tlow_sustained\tlow_faded\tlow_probability\tlow_rate\tlow_brier\tscore_gap\toutcome_auc\tdistinct_vectors\treceipt_mismatches\toutcomes_match\thigh_margins\tlow_margins\thigh_vector\tlow_vector\thigh_reliability\tlow_reliability\treply_equal\tbody_prefix_equal\n' \
    > "$OBSERVED"
printf 'visible-history\t%d\t2\t%d\t%d\t%s\t%s\t%s\t2\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\n' \
    "$proposal_rows" "$high_sustained" "$high_faded" \
    "$high_probability" "$high_rate" "$high_brier" \
    "$low_sustained" "$low_faded" "$low_probability" "$low_rate" \
    "$low_brier" "$score_gap" "$outcome_auc" "$distinct_vectors" \
    "$receipt_mismatches" "$outcomes_match" "$high_margins" \
    "$low_margins" "$high_vector" "$low_vector" "$high_live_status" \
    "$low_live_status" "$reply_equal" "$prefix_equal" >> "$OBSERVED"

cat "$OBSERVED"
printf '\nsealed plan: %s\nsettled receipts: %s\nproposal/outcome join: %s\nexpected/actual outcomes: %s / %s\n' \
    "$PLAN" "$SETTLED" "$PROPOSALS" "$EXPECTED" "$ACTUAL"
