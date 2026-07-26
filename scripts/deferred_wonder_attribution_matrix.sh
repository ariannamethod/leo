#!/usr/bin/env bash
# A.42: pre-grounding ownership among one active and several waiting Wonders.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GROUPS_FILE="${LEO_ATTRIBUTION_GROUPS:-$ROOT/scripts/deferred_wonder_constellation_groups.tsv}"
CASES_FILE="${LEO_ATTRIBUTION_CASES:-$ROOT/scripts/deferred_wonder_attribution_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-attribution-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
for fixture in "$GROUPS_FILE" "$CASES_FILE"; do
    [ -f "$fixture" ] || {
        printf 'attribution fixture not found: %s\n' "$fixture" >&2
        exit 2
    }
done

awk -F '\t' '
    NR == 1 {
        if (NF != 14 || $1 != "case" || $2 != "kind" ||
            $3 != "prompt" || $4 != "expected_status" ||
            $5 != "expected_winner_slot" || $6 != "expected_guarded" ||
            $7 != "on_curiosity" || $8 != "on_pending_slot" ||
            $9 != "on_resolved" || $10 != "off_curiosity" ||
            $11 != "off_pending_slot" || $12 != "off_resolved" ||
            $13 != "expect_reply_equal" || $14 != "expect_state_equal")
            exit 1
        next
    }
    {
        if (NF != 14 || seen[$1]++ || $5 !~ /^[0-3]$/ ||
            $6 !~ /^[01]$/ || $8 !~ /^[0-3]$/ || $9 !~ /^[01]$/ ||
            $11 !~ /^[0-3]$/ || $12 !~ /^[01]$/ ||
            $13 !~ /^(0|1|any)$/ || $14 !~ /^[01]$/)
            exit 1
        kinds[$2]++
        rows++
    }
    END {
        if (rows != 7 || kinds["guard"] != 2 ||
            kinds["correction"] != 2 || kinds["question"] != 1)
            exit 1
    }
' "$CASES_FILE" || {
    printf 'invalid attribution cases: %s\n' "$CASES_FILE" >&2
    exit 2
}

mkdir -p "$OUT/lives"
PLAN="$OUT/plan.tsv"
RECEIPTS="$OUT/receipts.tsv"
MATRIX="$OUT/matrix.tsv"
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

address_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_address_dialogue_report.awk" "$1"
}

curiosity_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/curiosity_dialogue_report.awk" "$1"
}

inventory_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/prewonder_dialogue_report.awk" "$1"
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
        slot1="$(group_field "$group" 1 5)"
        slot2="$(group_field "$group" 2 5)"
        prompt="${prompt//\{slot1\}/$slot1}"
        prompt="${prompt//\{slot2\}/$slot2}"
        winner="none"
        if [ "$winner_slot" -gt 0 ]; then
            winner="$(group_field "$group" "$winner_slot" 5)"
        fi
        printf '%s-%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$group" "$case" "$group" "$cohort" "$seed" "$case" \
            "$kind" "$prompt" "$status" "$winner" >> "$PLAN"
    done < "$CASES_FILE"
done

if [ "${LEO_ATTRIBUTION_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"$ROOT/scripts/deferred_wonder_constellation_matrix.sh" "$OUT/a40-baseline" \
    > "$OUT/a40-baseline.log"

printf 'cell\tturn\tstatus\twinner\tactive\tmargin\tguarded\taddress_entries\ton_curiosity\ton_count\ton_pending\ton_resolved\toff_curiosity\toff_count\toff_pending\toff_resolved\tprompt\ton_reply\toff_reply\n' \
    > "$RECEIPTS"
printf 'cell\tgroup\tcohort\tcase\tkind\tstatus\twinner\tguarded\ton_curiosity\ton_pending\ton_resolved\toff_curiosity\toff_pending\toff_resolved\treply_equal\tstate_equal\ton_sha256\toff_sha256\toutput\n' \
    > "$MATRIX"

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
    expected_question="$(group_field "$group" 1 9)"
    cp "$ready" "$group_dir/open.state"
    "$ROOT/leo" --load "$group_dir/open.state" \
        --seed "$((seed + 1700))" --respond "$active" --debug-field \
        --no-wonder-redirection --no-wonder-appetite \
        --save "$group_dir/open.state" > "$group_dir/open.log" 2>&1
    [ "$(reply_from_log "$group_dir/open.log")" = "$expected_question" ] || {
        printf '%s failed to open the active control\n' "$group" >&2
        exit 1
    }

    case_index=0
    while IFS=$'\t' read -r case kind raw_prompt expected_status \
        winner_slot expected_guarded expected_on_curiosity \
        expected_on_pending_slot expected_on_resolved \
        expected_off_curiosity expected_off_pending_slot \
        expected_off_resolved expected_reply_equal expected_state_equal; do
        [ "$case" = "case" ] && continue
        case_index=$((case_index + 1))
        cell="$group-$case"
        cell_dir="$group_dir/$case"
        mkdir -p "$cell_dir"
        prompt="${raw_prompt//\{slot1\}/$active}"
        slot2="$(group_field "$group" 2 5)"
        prompt="${prompt//\{slot2\}/$slot2}"
        expected_winner="none"
        if [ "$winner_slot" -gt 0 ]; then
            expected_winner="$(group_field "$group" "$winner_slot" 5)"
        fi
        expected_on_pending="none"
        if [ "$expected_on_pending_slot" -gt 0 ]; then
            expected_on_pending="$(
                group_field "$group" "$expected_on_pending_slot" 5
            )"
        fi
        expected_off_pending="none"
        if [ "$expected_off_pending_slot" -gt 0 ]; then
            expected_off_pending="$(
                group_field "$group" "$expected_off_pending_slot" 5
            )"
        fi

        cp "$group_dir/open.state" "$cell_dir/on.state"
        cp "$group_dir/open.state" "$cell_dir/off.state"
        run_seed=$((seed + 2000 + group_index * 100 + case_index))
        "$ROOT/leo" --load "$cell_dir/on.state" --seed "$run_seed" \
            --respond "$prompt" --debug-field --no-wonder-redirection \
            --no-wonder-appetite \
            --save "$cell_dir/on.state" \
            > "$cell_dir/on.log" 2>&1
        "$ROOT/leo" --load "$cell_dir/off.state" --seed "$run_seed" \
            --respond "$prompt" --debug-field --no-wonder-attribution \
            --no-wonder-redirection --no-wonder-appetite \
            --save "$cell_dir/off.state" > "$cell_dir/off.log" 2>&1

        address="$(address_from_log "$cell_dir/on.log" "$cell" "$run_seed")"
        on_curiosity="$(
            curiosity_from_log "$cell_dir/on.log" "$cell" "$run_seed"
        )"
        off_curiosity="$(
            curiosity_from_log "$cell_dir/off.log" "$cell" "$run_seed"
        )"
        on_inventory="$(
            inventory_from_log "$cell_dir/on.log" "$cell" "$run_seed"
        )"
        off_inventory="$(
            inventory_from_log "$cell_dir/off.log" "$cell" "$run_seed"
        )"
        [ -n "$address" ] && [ -n "$on_curiosity" ] &&
        [ -n "$off_curiosity" ] && [ -n "$on_inventory" ] &&
        [ -n "$off_inventory" ] || {
            printf '%s missing diagnostic receipt\n' "$cell" >&2
            exit 1
        }

        IFS=$'\t' read -r _ _ turn status winner address_active margin \
            guarded address_entries redirected <<< "$address"
        IFS=$'\t' read -r _ _ on_turn on_outcome _ _ _ _ _ \
            <<< "$on_curiosity"
        IFS=$'\t' read -r _ _ off_turn off_outcome _ _ _ _ _ \
            <<< "$off_curiosity"
        IFS=$'\t' read -r _ _ on_inventory_turn on_count on_pending \
            on_episodes on_resolved on_entries <<< "$on_inventory"
        IFS=$'\t' read -r _ _ off_inventory_turn off_count off_pending \
            off_episodes off_resolved off_entries <<< "$off_inventory"
        [ "$turn" = "$on_turn" ] &&
        [ "$turn" = "$off_turn" ] &&
        [ "$turn" = "$on_inventory_turn" ] &&
        [ "$turn" = "$off_inventory_turn" ] || {
            printf '%s diagnostic turn disagreement\n' "$cell" >&2
            exit 1
        }

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
        [ "$address_active" = "$active" ] &&
        [ "$guarded" = "$expected_guarded" ] &&
        [ "$redirected" = 0 ] &&
        [ "$on_outcome" = "$expected_on_curiosity" ] &&
        [ "$on_pending" = "$expected_on_pending" ] &&
        [ "$on_resolved" = "$expected_on_resolved" ] &&
        [ "$off_outcome" = "$expected_off_curiosity" ] &&
        [ "$off_pending" = "$expected_off_pending" ] &&
        [ "$off_resolved" = "$expected_off_resolved" ] &&
        { [ "$expected_reply_equal" = "any" ] ||
          [ "$reply_equal" = "$expected_reply_equal" ]; } &&
        [ "$state_equal" = "$expected_state_equal" ] || {
            printf '%s contract failed: status=%s winner=%s active=%s guarded=%s on=%s/%s/%s off=%s/%s/%s reply_equal=%s state_equal=%s\n' \
                "$cell" "$status" "$winner" "$address_active" "$guarded" \
                "$on_outcome" "$on_pending" "$on_resolved" \
                "$off_outcome" "$off_pending" "$off_resolved" \
                "$reply_equal" "$state_equal" >&2
            exit 1
        }

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$turn" "$status" "$winner" "$address_active" \
            "$margin" "$guarded" "$address_entries" "$on_outcome" \
            "$on_count" "$on_pending" "$on_resolved" "$off_outcome" \
            "$off_count" "$off_pending" "$off_resolved" "$prompt" \
            "$on_reply" "$off_reply" >> "$RECEIPTS"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$group" "$cohort" "$case" "$kind" "$status" \
            "$winner" "$guarded" "$on_outcome" "$on_pending" \
            "$on_resolved" "$off_outcome" "$off_pending" \
            "$off_resolved" "$reply_equal" "$state_equal" "$on_sha" \
            "$off_sha" "$cell_dir" >> "$MATRIX"
    done < "$CASES_FILE"
done

awk -F '\t' '
    NR > 1 {
        cells++
        status[$6]++
        guarded += $8
        replies += $15
        states += $16
        if ($8 == 1 && $16 == 0) guarded_state_diverged++
    }
    END {
        print "cells\tguarded\tactive_semantic\tactive_explicit\tsibling_conflict\tsibling_explicit\tambiguous\tadjacent\treply_equal\tstate_equal\tguarded_state_diverged"
        print cells "\t" guarded "\t" status["active-semantic"] "\t" \
              status["active-explicit"] "\t" status["sibling-conflict"] "\t" \
              status["sibling-explicit"] "\t" status["ambiguous"] "\t" \
              status["adjacent"] "\t" replies "\t" states "\t" \
              guarded_state_diverged
    }
' "$MATRIX" > "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nreceipts: %s\n' "$MATRIX" "$RECEIPTS"
