#!/usr/bin/env bash
# A.44: read-only return appetite over deferred Wonders.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GROUPS_FILE="${LEO_APPETITE_GROUPS:-$ROOT/scripts/deferred_wonder_constellation_groups.tsv}"
CASES_FILE="${LEO_APPETITE_CASES:-$ROOT/scripts/deferred_wonder_appetite_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
for fixture in "$GROUPS_FILE" "$CASES_FILE"; do
    [ -f "$fixture" ] || {
        printf 'appetite fixture not found: %s\n' "$fixture" >&2
        exit 2
    }
done

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "case" || $2 != "kind" ||
            $3 != "prompt" || $4 != "expected_status" ||
            $5 != "expected_winner_slot" || $6 != "expected_spoken" ||
            $7 != "min_recurrence" || $8 != "min_flow_gap" ||
            $9 != "expected_count" || $10 != "expected_pending_slot")
            exit 1
        next
    }
    {
        if (NF != 10 || seen[$1]++ || $5 !~ /^[0-3]$/ ||
            $6 !~ /^[01]$/ || $7 !~ /^[01](\.[0-9]+)?$/ ||
            $8 !~ /^[01](\.[0-9]+)?$/ || $9 !~ /^[0-3]$/ ||
            $10 !~ /^[0-3]$/)
            exit 1
        kinds[$2]++
        statuses[$4]++
        rows++
    }
    END {
        if (rows != 5 || kinds["semantic"] != 1 ||
            kinds["weak"] != 1 || kinds["mixed"] != 1 ||
            kinds["quiet"] != 1 || kinds["parked"] != 1 ||
            statuses["salient"] != 2 ||
            statuses["diffuse"] != 2 || statuses["quiet"] != 1)
            exit 1
    }
' "$CASES_FILE" || {
    printf 'invalid appetite cases: %s\n' "$CASES_FILE" >&2
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

appetite_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_dialogue_report.awk" "$1"
}

inventory_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/prewonder_dialogue_report.awk" "$1"
}

candidate_fields() {
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
                          values[6] "\t" values[7]
                    exit
                }
            }
        '
}

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

printf 'cell\tgroup\tcohort\tseed\tcase\tkind\tprompt\texpected_status\texpected_winner\n' \
    > "$PLAN"
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUPS_FILE" |
while IFS=$'\t' read -r group cohort seed; do
    while IFS=$'\t' read -r case kind prompt status winner_slot _; do
        [ "$case" = "case" ] && continue
        winner="none"
        if [ "$winner_slot" -gt 0 ]; then
            winner="$(group_field "$group" "$winner_slot" 5)"
        fi
        printf '%s-%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$group" "$case" "$group" "$cohort" "$seed" "$case" \
            "$kind" "$prompt" "$status" "$winner" >> "$PLAN"
    done < "$CASES_FILE"
done

if [ "${LEO_APPETITE_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"$ROOT/scripts/deferred_wonder_constellation_matrix.sh" \
    "$OUT/a40-baseline" > "$OUT/a40-baseline.log"

printf 'cell\tgroup\tcohort\tcase\tkind\tstatus\twinner\tmargin\tpending\twinner_recurrence\twinner_silence\twinner_unfinished\twinner_flow_gap\twinner_appetite\twinner_spoken\tcount\treply_equal\tstate_equal\ton_sha256\toff_sha256\n' \
    > "$MATRIX"
printf 'cell\tturn\tstatus\twinner\tmargin\tpending\tentries\tprompt\treply\n' \
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

    active="$(group_field "$group" 1 5)"
    sibling="$(group_field "$group" 2 5)"
    active_question="$(group_field "$group" 1 9)"
    sibling_question="$(group_field "$group" 2 9)"
    cp "$ready" "$group_dir/parked-base.state"
    "$ROOT/leo" --load "$group_dir/parked-base.state" \
        --seed "$((seed + 4100))" --respond "$active" --debug-field \
        --no-wonder-appetite --save "$group_dir/parked-base.state" \
        > "$group_dir/parked-open.log" 2>&1
    [ "$(reply_from_log "$group_dir/parked-open.log")" = "$active_question" ] || {
        printf '%s failed to open parked control\n' "$group" >&2
        exit 1
    }
    "$ROOT/leo" --load "$group_dir/parked-base.state" \
        --seed "$((seed + 4101))" --respond "$sibling" --debug-field \
        --no-wonder-appetite --save "$group_dir/parked-base.state" \
        > "$group_dir/parked-switch.log" 2>&1
    [ "$(reply_from_log "$group_dir/parked-switch.log")" = "$sibling_question" ] || {
        printf '%s failed to switch the parked control\n' "$group" >&2
        exit 1
    }

    case_index=0
    while IFS=$'\t' read -r case kind prompt expected_status \
        winner_slot expected_spoken min_recurrence min_flow_gap \
        expected_count expected_pending_slot; do
        [ "$case" = "case" ] && continue
        case_index=$((case_index + 1))
        cell="$group-$case"
        cell_dir="$group_dir/$case"
        mkdir -p "$cell_dir"
        base="$ready"
        [ "$kind" != "parked" ] ||
            base="$group_dir/parked-base.state"

        expected_winner="none"
        if [ "$winner_slot" -gt 0 ]; then
            expected_winner="$(group_field "$group" "$winner_slot" 5)"
        fi
        expected_pending="none"
        if [ "$expected_pending_slot" -gt 0 ]; then
            expected_pending="$(
                group_field "$group" "$expected_pending_slot" 5
            )"
        fi

        cp "$base" "$cell_dir/on.state"
        cp "$base" "$cell_dir/off.state"
        run_seed=$((seed + 4400 + group_index * 100 + case_index))
        "$ROOT/leo" --load "$cell_dir/on.state" --seed "$run_seed" \
            --respond "$prompt" --debug-field --save "$cell_dir/on.state" \
            > "$cell_dir/on.log" 2>&1
        "$ROOT/leo" --load "$cell_dir/off.state" --seed "$run_seed" \
            --respond "$prompt" --debug-field --no-wonder-appetite \
            --save "$cell_dir/off.state" > "$cell_dir/off.log" 2>&1

        appetite="$(
            appetite_from_log "$cell_dir/on.log" "$cell" "$run_seed"
        )"
        off_appetite="$(
            appetite_from_log "$cell_dir/off.log" "$cell" "$run_seed"
        )"
        inventory="$(
            inventory_from_log "$cell_dir/on.log" "$cell" "$run_seed"
        )"
        [ -n "$appetite" ] && [ -z "$off_appetite" ] &&
        [ -n "$inventory" ] || {
            printf '%s appetite ablation surface failed\n' "$cell" >&2
            exit 1
        }

        IFS=$'\t' read -r _ _ turn status winner margin pending entries \
            <<< "$appetite"
        IFS=$'\t' read -r _ _ inventory_turn count inventory_pending \
            episodes resolved inventory_entries <<< "$inventory"
        [ "$turn" = "$inventory_turn" ] || {
            printf '%s diagnostic turn disagreement\n' "$cell" >&2
            exit 1
        }

        winner_recurrence=0
        winner_silence=0
        winner_unfinished=0
        winner_flow_gap=0
        winner_appetite=0
        winner_spoken=0
        winner_literal=0
        if [ "$winner" != "none" ]; then
            fields="$(candidate_fields "$entries" "$winner")"
            [ -n "$fields" ] || {
                printf '%s winner missing from entries\n' "$cell" >&2
                exit 1
            }
            IFS=$'\t' read -r winner_recurrence winner_silence \
                winner_unfinished winner_flow_gap winner_appetite \
                winner_spoken winner_literal <<< "$fields"
        fi

        if [ "$kind" = "quiet" ]; then
            fields="$(candidate_fields "$entries" "$active")"
            [ -n "$fields" ] || {
                printf '%s aged candidate missing from entries\n' "$cell" >&2
                exit 1
            }
            IFS=$'\t' read -r quiet_recurrence quiet_silence _ \
                <<< "$fields"
            [ "$quiet_silence" = "1.000" ] &&
            awk -v got="$quiet_recurrence" \
                'BEGIN { exit !((got + 0) < 0.15) }' || {
                printf '%s age-only guard failed: recurrence=%s silence=%s\n' \
                    "$cell" "$quiet_recurrence" "$quiet_silence" >&2
                exit 1
            }
        fi

        on_reply="$(reply_from_log "$cell_dir/on.log")"
        off_reply="$(reply_from_log "$cell_dir/off.log")"
        reply_equal=0
        state_equal=0
        [ "$on_reply" = "$off_reply" ] && reply_equal=1
        on_sha="$(sha256_file "$cell_dir/on.state")"
        off_sha="$(sha256_file "$cell_dir/off.state")"
        [ "$on_sha" = "$off_sha" ] && state_equal=1

        [ "$status" = "$expected_status" ] &&
        [ "$winner" = "$expected_winner" ] &&
        [ "$pending" = "$expected_pending" ] &&
        [ "$inventory_pending" = "$expected_pending" ] &&
        [ "$count" = "$expected_count" ] &&
        [ "$winner_spoken" = "$expected_spoken" ] &&
        [ "$winner_literal" = 0 ] &&
        [ "$reply_equal" = 1 ] &&
        [ "$state_equal" = 1 ] &&
        awk -v got="$winner_recurrence" -v want="$min_recurrence" \
            'BEGIN { exit !((got + 0) >= (want + 0)) }' &&
        awk -v got="$winner_flow_gap" -v want="$min_flow_gap" \
            'BEGIN { exit !((got + 0) >= (want + 0)) }' || {
            printf '%s contract failed: status=%s winner=%s pending=%s count=%s recurrence=%s flow_gap=%s spoken=%s reply_equal=%s state_equal=%s\n' \
                "$cell" "$status" "$winner" "$pending" "$count" \
                "$winner_recurrence" "$winner_flow_gap" \
                "$winner_spoken" "$reply_equal" "$state_equal" >&2
            exit 1
        }

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$group" "$cohort" "$case" "$kind" "$status" \
            "$winner" "$margin" "$pending" "$winner_recurrence" \
            "$winner_silence" "$winner_unfinished" "$winner_flow_gap" \
            "$winner_appetite" "$winner_spoken" "$count" \
            "$reply_equal" "$state_equal" "$on_sha" "$off_sha" \
            >> "$MATRIX"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$turn" "$status" "$winner" "$margin" "$pending" \
            "$entries" "$prompt" "$on_reply" >> "$RECEIPTS"
    done < "$CASES_FILE"
done

awk -F '\t' '
    NR > 1 {
        cells++
        status[$6]++
        spoken += $15
        reply_equal += $17
        state_equal += $18
    }
    END {
        print "cells\tsalient\tdiffuse\tquiet\tspoken_winners\treply_equal\tstate_equal"
        print cells "\t" status["salient"] "\t" status["diffuse"] \
              "\t" status["quiet"] "\t" spoken "\t" reply_equal \
              "\t" state_equal
    }
' "$MATRIX" > "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nreceipts: %s\n' "$MATRIX" "$RECEIPTS"
