#!/usr/bin/env bash
# A.45: fixed three-turn calibration of A.44 return-appetite forecasts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GROUPS_FILE="${LEO_APPETITE_CALIBRATION_GROUPS:-$ROOT/scripts/deferred_wonder_constellation_groups.tsv}"
CASES_FILE="${LEO_APPETITE_CALIBRATION_CASES:-$ROOT/scripts/deferred_wonder_appetite_calibration_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-calibration-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
for fixture in "$GROUPS_FILE" "$CASES_FILE"; do
    [ -f "$fixture" ] || {
        printf 'appetite calibration fixture not found: %s\n' \
            "$fixture" >&2
        exit 2
    }
done

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "case" || $2 != "kind" ||
            $3 != "initial" || $4 != "future_1" ||
            $5 != "future_2" || $6 != "future_3" ||
            $7 != "expected_verdict" ||
            $8 != "expected_spoken" ||
            $9 != "expected_forecast" ||
            $10 != "expected_full_equal")
            exit 1
        next
    }
    {
        if (NF != 10 || seen[$1]++ ||
            $8 !~ /^[01]$/ || $9 !~ /^[01]$/ ||
            $10 !~ /^[01]$/)
            exit 1
        kinds[$2]++
        verdicts[$7]++
        rows++
    }
    END {
        if (rows != 5 || kinds["unspoken"] != 3 ||
            kinds["parked"] != 1 || kinds["control"] != 1 ||
            verdicts["sustained"] != 2 ||
            verdicts["faded"] != 1 ||
            verdicts["external"] != 1 ||
            verdicts["none"] != 1)
            exit 1
    }
' "$CASES_FILE" || {
    printf 'invalid appetite calibration cases: %s\n' \
        "$CASES_FILE" >&2
    exit 2
}

mkdir -p "$OUT/lives"
PLAN="$OUT/plan.tsv"
MATRIX="$OUT/matrix.tsv"
RECEIPTS="$OUT/receipts.tsv"
SUMMARY="$OUT/summary.txt"

group_field() {
    local group="$1"
    local slot="$2"
    local field="$3"
    awk -F '\t' -v group="$group" -v slot="$slot" -v field="$field" '
        NR > 1 && $1 == group && $4 == slot {
            print $field
            exit
        }
    ' "$GROUPS_FILE"
}

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

calibration_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_calibration_dialogue_report.awk" \
        "$1"
}

entry_fields() {
    local entries="$1"
    local wanted="$2"
    printf '%s\n' "$entries" |
        awk -v wanted="$wanted" '
            {
                n = split($0, items, /\|/)
                for (i = 1; i <= n; i++) {
                    split(items[i], pair, /:/)
                    if (pair[1] != wanted) continue
                    split(pair[2], values, /\//)
                    print values[1] "\t" values[2] "\t" values[3] \
                          "\t" values[4] "\t" values[5] "\t" \
                          values[6] "\t" values[7] "\t" values[8] \
                          "\t" values[9] "\t" values[10]
                    exit
                }
            }
        '
}

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

prompt_for() {
    local token="$1"
    local target="$2"
    case "$token" in
        quiet) printf '%s' 'I do not know.' ;;
        semantic-slot1) printf '%s' 'Bright sun. Cold winter.' ;;
        semantic-slot2) printf '%s' 'Cat bird. Dark night.' ;;
        target) printf '%s' "$target" ;;
        -) printf '%s' '-' ;;
        *)
            printf 'unknown future prompt token: %s\n' "$token" >&2
            return 1
            ;;
    esac
}

printf 'cell\tgroup\tcohort\tseed\tcase\tkind\ttarget\texpected_verdict\texpected_spoken\texpected_forecast\texpected_full_equal\n' \
    > "$PLAN"
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUPS_FILE" |
while IFS=$'\t' read -r group cohort seed; do
    while IFS=$'\t' read -r case kind initial future_1 future_2 \
        future_3 verdict spoken forecast full_equal; do
        [ "$case" = "case" ] && continue
        target=none
        [ "$kind" != "unspoken" ] ||
            target="$(group_field "$group" 2 5)"
        [ "$kind" != "parked" ] ||
            target="$(group_field "$group" 1 5)"
        printf '%s-%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$group" "$case" "$group" "$cohort" "$seed" "$case" \
            "$kind" "$target" "$verdict" "$spoken" "$forecast" \
            "$full_equal" >> "$PLAN"
    done < "$CASES_FILE"
done

if [ "${LEO_APPETITE_CALIBRATION_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"$ROOT/scripts/deferred_wonder_constellation_matrix.sh" \
    "$OUT/a40-baseline" > "$OUT/a40-baseline.log"

printf 'cell\tgroup\tcohort\tcase\tkind\ttarget\tverdict\tproposed\tdeadline\tobserved\tappetite\tpeak_recurrence\tsemantic_hits\tobservations\tspoken\tbrier\tturns\treply_equal_turns\tcore_equal\tfull_equal\ton_sha256\toff_sha256\n' \
    > "$MATRIX"
printf 'cell\tturn\tpending\tscored\tconfirmed\texternal\tlost\tunscorable\tbrier\tentries\n' \
    > "$RECEIPTS"

group_index=0
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUPS_FILE" |
while IFS=$'\t' read -r group cohort seed; do
    group_index=$((group_index + 1))
    group_dir="$OUT/lives/$group"
    mkdir -p "$group_dir"
    ready="$OUT/a40-baseline/groups/$group/ready.state"
    [ -f "$ready" ] || {
        printf 'missing A.40 ready body: %s\n' "$ready" >&2
        exit 1
    }

    slot1="$(group_field "$group" 1 5)"
    slot2="$(group_field "$group" 2 5)"
    slot1_question="$(group_field "$group" 1 9)"
    slot2_question="$(group_field "$group" 2 9)"
    cp "$ready" "$group_dir/parked-base.state"
    "$ROOT/leo" --load "$group_dir/parked-base.state" \
        --seed "$((seed + 5100))" --respond "$slot1" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$group_dir/parked-base.state" \
        > "$group_dir/parked-open.log" 2>&1
    [ "$(reply_from_log "$group_dir/parked-open.log")" = \
      "$slot1_question" ] || {
        printf '%s failed to open parked calibration control\n' \
            "$group" >&2
        exit 1
    }
    "$ROOT/leo" --load "$group_dir/parked-base.state" \
        --seed "$((seed + 5101))" --respond "$slot2" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$group_dir/parked-base.state" \
        > "$group_dir/parked-switch.log" 2>&1
    [ "$(reply_from_log "$group_dir/parked-switch.log")" = \
      "$slot2_question" ] || {
        printf '%s failed to switch parked calibration control\n' \
            "$group" >&2
        exit 1
    }

    case_index=0
    while IFS=$'\t' read -r case kind initial future_1 future_2 \
        future_3 expected_verdict expected_spoken expected_forecast \
        expected_full_equal; do
        [ "$case" = "case" ] && continue
        case_index=$((case_index + 1))
        cell="$group-$case"
        cell_dir="$group_dir/$case"
        mkdir -p "$cell_dir"
        base="$ready"
        target=none
        if [ "$kind" = "unspoken" ]; then
            target="$slot2"
        elif [ "$kind" = "parked" ]; then
            target="$slot1"
            base="$group_dir/parked-base.state"
        fi
        cp "$base" "$cell_dir/on.state"
        cp "$base" "$cell_dir/off.state"

        prompts=("$initial")
        for token in "$future_1" "$future_2" "$future_3"; do
            [ "$token" = "-" ] ||
                prompts+=("$(prompt_for "$token" "$target")")
        done
        turns=${#prompts[@]}
        reply_equal_turns=0
        last_on_log=
        for ((turn_index = 0; turn_index < turns; turn_index++)); do
            turn_number=$((turn_index + 1))
            prompt="${prompts[$turn_index]}"
            run_seed=$((seed + 5400 + group_index * 1000 +
                        case_index * 20 + turn_number))
            on_log="$cell_dir/on-turn-$turn_number.log"
            off_log="$cell_dir/off-turn-$turn_number.log"
            "$ROOT/leo" --load "$cell_dir/on.state" \
                --seed "$run_seed" --respond "$prompt" --debug-field \
                --save "$cell_dir/on.state" > "$on_log" 2>&1
            "$ROOT/leo" --load "$cell_dir/off.state" \
                --seed "$run_seed" --respond "$prompt" --debug-field \
                --no-wonder-appetite-calibration \
                --save "$cell_dir/off.state" > "$off_log" 2>&1
            [ -z "$(calibration_from_log \
                "$off_log" "$cell" "$run_seed")" ] || {
                printf '%s calibration ablation emitted a receipt\n' \
                    "$cell" >&2
                exit 1
            }
            if [ "$(reply_from_log "$on_log")" = \
                 "$(reply_from_log "$off_log")" ]; then
                reply_equal_turns=$((reply_equal_turns + 1))
            fi
            last_on_log="$on_log"
        done

        calibration="$(
            calibration_from_log "$last_on_log" "$cell" "$run_seed"
        )"
        proposed=0
        deadline=0
        observed=0
        appetite=0
        peak=0
        semantic_hits=0
        observations=0
        spoken=0
        verdict=none
        receipt_brier=0
        pending=0
        scored=0
        confirmed=0
        external=0
        lost=0
        unscorable=0
        entries=
        if [ "$expected_forecast" -eq 1 ]; then
            [ -n "$calibration" ] || {
                printf '%s missing final calibration receipt\n' \
                    "$cell" >&2
                exit 1
            }
            IFS=$'\t' read -r _ _ receipt_turn pending scored \
                confirmed external lost unscorable aggregate_brier \
                entries <<< "$calibration"
            fields="$(entry_fields "$entries" "$target")"
            [ -n "$fields" ] || {
                printf '%s target missing from calibration entries\n' \
                    "$cell" >&2
                exit 1
            }
            IFS=$'\t' read -r proposed deadline observed appetite \
                peak semantic_hits observations spoken verdict \
                receipt_brier <<< "$fields"
        else
            [ -z "$calibration" ] || {
                printf '%s invented a forecast for diffuse evidence\n' \
                    "$cell" >&2
                exit 1
            }
        fi

        on_sha="$(sha256_file "$cell_dir/on.state")"
        off_sha="$(sha256_file "$cell_dir/off.state")"
        full_equal=0
        [ "$on_sha" = "$off_sha" ] && full_equal=1
        off_size="$(wc -c < "$cell_dir/off.state")"
        core_size=$((off_size - 2 * 4))
        [ "$core_size" -gt 0 ] || {
            printf '%s invalid empty-diary state size\n' "$cell" >&2
            exit 1
        }
        head -c "$core_size" "$cell_dir/on.state" \
            > "$cell_dir/on.core"
        head -c "$core_size" "$cell_dir/off.state" \
            > "$cell_dir/off.core"
        core_equal=0
        cmp -s "$cell_dir/on.core" "$cell_dir/off.core" &&
            core_equal=1

        expected_observations=$((turns - 1))
        verdict_contract=0
        if [ "$expected_verdict" = "none" ]; then
            [ "$verdict" = none ] && verdict_contract=1
        elif [ "$verdict" = "$expected_verdict" ] &&
             [ "$spoken" = "$expected_spoken" ] &&
             [ "$observations" = "$expected_observations" ] &&
             (( observed == proposed + observations )) &&
             (( deadline == proposed + 3 )); then
            case "$verdict" in
                sustained)
                    [ "$semantic_hits" -ge 1 ] &&
                    awk -v peak="$peak" \
                        'BEGIN { exit !((peak + 0) >= 0.75) }' &&
                    awk -v score="$appetite" -v brier="$receipt_brier" \
                        'BEGIN {
                            error = score - 1
                            exit !(brier >= error * error - 0.002 &&
                                   brier <= error * error + 0.002)
                        }' &&
                    [ "$pending" = 0 ] &&
                    [ "$scored" = 1 ] &&
                    [ "$confirmed" = 1 ] &&
                    verdict_contract=1
                    ;;
                faded)
                    [ "$semantic_hits" = 0 ] &&
                    awk -v score="$appetite" -v brier="$receipt_brier" \
                        'BEGIN {
                            want = score * score
                            exit !(brier >= want - 0.002 &&
                                   brier <= want + 0.002)
                        }' &&
                    [ "$pending" = 0 ] &&
                    [ "$scored" = 1 ] &&
                    [ "$confirmed" = 0 ] &&
                    verdict_contract=1
                    ;;
                external)
                    [ "$receipt_brier" = "0.000" ] &&
                    [ "$external" = 1 ] &&
                    [ "$scored" = 0 ] &&
                    verdict_contract=1
                    ;;
            esac
        fi

        [ "$verdict_contract" = 1 ] &&
        [ "$reply_equal_turns" = "$turns" ] &&
        [ "$core_equal" = 1 ] &&
        [ "$full_equal" = "$expected_full_equal" ] || {
            printf '%s contract failed: verdict=%s turns=%s replies=%s core=%s full=%s spoken=%s hits=%s observations=%s\n' \
                "$cell" "$verdict" "$turns" "$reply_equal_turns" \
                "$core_equal" "$full_equal" "$spoken" \
                "$semantic_hits" "$observations" >&2
            exit 1
        }

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$group" "$cohort" "$case" "$kind" "$target" \
            "$verdict" "$proposed" "$deadline" "$observed" \
            "$appetite" "$peak" "$semantic_hits" "$observations" \
            "$spoken" "$receipt_brier" "$turns" \
            "$reply_equal_turns" "$core_equal" "$full_equal" \
            "$on_sha" "$off_sha" >> "$MATRIX"
        if [ -n "$calibration" ]; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$cell" "$receipt_turn" "$pending" "$scored" \
                "$confirmed" "$external" "$lost" "$unscorable" \
                "$aggregate_brier" "$entries" >> "$RECEIPTS"
        fi
    done < "$CASES_FILE"
done

awk -F '\t' '
    NR > 1 {
        cells++
        verdict[$7]++
        spoken += $15
        reply_turns += $18
        core_equal += $19
        full_equal += $20
        full_diverged += !$20
    }
    END {
        print "cells\tsustained\tfaded\texternal\tnone\tspoken\treply_equal_turns\tcore_equal\tfull_equal\tfull_diverged"
        print cells "\t" verdict["sustained"] "\t" verdict["faded"] \
              "\t" verdict["external"] "\t" verdict["none"] \
              "\t" spoken "\t" reply_turns "\t" core_equal \
              "\t" full_equal "\t" full_diverged
    }
' "$MATRIX" > "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nreceipts: %s\n' "$MATRIX" "$RECEIPTS"
