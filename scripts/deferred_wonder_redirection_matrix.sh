#!/usr/bin/env bash
# A.43: explicit address switching between one active and waiting Wonders.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GROUPS_FILE="${LEO_REDIRECTION_GROUPS:-$ROOT/scripts/deferred_wonder_constellation_groups.tsv}"
CASES_FILE="${LEO_REDIRECTION_CASES:-$ROOT/scripts/deferred_wonder_redirection_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-redirection-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
for fixture in "$GROUPS_FILE" "$CASES_FILE"; do
    [ -f "$fixture" ] || {
        printf 'redirection fixture not found: %s\n' "$fixture" >&2
        exit 2
    }
done

awk -F '\t' '
    NR == 1 {
        if (NF != 16 || $1 != "case" || $2 != "kind" ||
            $3 != "prompt" || $4 != "expected_status" ||
            $5 != "expected_winner_slot" || $6 != "expected_redirected" ||
            $7 != "on_curiosity" || $8 != "on_pending_slot" ||
            $9 != "on_resolved" || $10 != "off_curiosity" ||
            $11 != "off_pending_slot" || $12 != "off_resolved" ||
            $13 != "expect_reply_equal" || $14 != "expect_state_equal" ||
            $15 != "expected_on_reply_slot" || $16 != "continuation")
            exit 1
        next
    }
    {
        if (NF != 16 || seen[$1]++ || $5 !~ /^[0-3]$/ ||
            $6 !~ /^[01]$/ || $8 !~ /^[0-3]$/ || $9 !~ /^[01]$/ ||
            $11 !~ /^[0-3]$/ || $12 !~ /^[01]$/ ||
            $13 !~ /^(0|1|any)$/ || $14 !~ /^[01]$/ ||
            $15 !~ /^[0-3]$/ || $16 !~ /^[01]$/)
            exit 1
        kinds[$2]++
        continuations += $16
        rows++
    }
    END {
        if (rows != 5 || kinds["redirect"] != 3 ||
            kinds["control"] != 2 || continuations != 1)
            exit 1
    }
' "$CASES_FILE" || {
    printf 'invalid redirection cases: %s\n' "$CASES_FILE" >&2
    exit 2
}

mkdir -p "$OUT/lives"
PLAN="$OUT/plan.tsv"
MATRIX="$OUT/matrix.tsv"
CONTINUATIONS="$OUT/continuations.tsv"
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

if [ "${LEO_REDIRECTION_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"$ROOT/scripts/deferred_wonder_constellation_matrix.sh" "$OUT/a40-baseline" \
    > "$OUT/a40-baseline.log"

printf 'cell\tgroup\tcohort\tcase\tkind\tstatus\twinner\tguarded\tredirected\ton_curiosity\ton_pending\ton_resolved\toff_curiosity\toff_pending\toff_resolved\treply_equal\tstate_equal\ton_sha256\toff_sha256\n' \
    > "$MATRIX"
printf 'cell\tgroup\tcohort\treply\tcuriosity\tpending\tresolved\tstate_sha256\n' \
    > "$CONTINUATIONS"

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
    expected_active_question="$(group_field "$group" 1 9)"
    cp "$ready" "$group_dir/open.state"
    "$ROOT/leo" --load "$group_dir/open.state" \
        --seed "$((seed + 2700))" --respond "$active" --debug-field \
        --no-wonder-appetite \
        --save "$group_dir/open.state" > "$group_dir/open.log" 2>&1
    [ "$(reply_from_log "$group_dir/open.log")" = "$expected_active_question" ] || {
        printf '%s failed to open the active control\n' "$group" >&2
        exit 1
    }

    case_index=0
    while IFS=$'\t' read -r case kind raw_prompt expected_status \
        winner_slot expected_redirected expected_on_curiosity \
        expected_on_pending_slot expected_on_resolved \
        expected_off_curiosity expected_off_pending_slot \
        expected_off_resolved expected_reply_equal expected_state_equal \
        expected_on_reply_slot continuation; do
        [ "$case" = "case" ] && continue
        case_index=$((case_index + 1))
        cell="$group-$case"
        cell_dir="$group_dir/$case"
        mkdir -p "$cell_dir"
        slot2="$(group_field "$group" 2 5)"
        prompt="${raw_prompt//\{slot1\}/$active}"
        prompt="${prompt//\{slot2\}/$slot2}"

        expected_winner="none"
        [ "$winner_slot" -eq 0 ] ||
            expected_winner="$(group_field "$group" "$winner_slot" 5)"
        expected_on_pending="none"
        [ "$expected_on_pending_slot" -eq 0 ] ||
            expected_on_pending="$(
                group_field "$group" "$expected_on_pending_slot" 5
            )"
        expected_off_pending="none"
        [ "$expected_off_pending_slot" -eq 0 ] ||
            expected_off_pending="$(
                group_field "$group" "$expected_off_pending_slot" 5
            )"
        expected_on_reply=""
        [ "$expected_on_reply_slot" -eq 0 ] ||
            expected_on_reply="$(
                group_field "$group" "$expected_on_reply_slot" 9
            )"

        cp "$group_dir/open.state" "$cell_dir/on.state"
        cp "$group_dir/open.state" "$cell_dir/off.state"
        run_seed=$((seed + 3000 + group_index * 100 + case_index))
        "$ROOT/leo" --load "$cell_dir/on.state" --seed "$run_seed" \
            --respond "$prompt" --debug-field --no-wonder-appetite \
            --save "$cell_dir/on.state" \
            > "$cell_dir/on.log" 2>&1
        "$ROOT/leo" --load "$cell_dir/off.state" --seed "$run_seed" \
            --respond "$prompt" --debug-field --no-wonder-redirection \
            --no-wonder-appetite \
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
        [ "$redirected" = "$expected_redirected" ] &&
        [ "$on_outcome" = "$expected_on_curiosity" ] &&
        [ "$on_pending" = "$expected_on_pending" ] &&
        [ "$on_resolved" = "$expected_on_resolved" ] &&
        [ "$off_outcome" = "$expected_off_curiosity" ] &&
        [ "$off_pending" = "$expected_off_pending" ] &&
        [ "$off_resolved" = "$expected_off_resolved" ] &&
        { [ "$expected_reply_equal" = "any" ] ||
          [ "$reply_equal" = "$expected_reply_equal" ]; } &&
        [ "$state_equal" = "$expected_state_equal" ] &&
        { [ -z "$expected_on_reply" ] ||
          [ "$on_reply" = "$expected_on_reply" ]; } || {
            printf '%s contract failed: status=%s winner=%s active=%s guarded=%s redirected=%s on=%s/%s/%s off=%s/%s/%s reply_equal=%s state_equal=%s\n' \
                "$cell" "$status" "$winner" "$address_active" "$guarded" \
                "$redirected" "$on_outcome" "$on_pending" "$on_resolved" \
                "$off_outcome" "$off_pending" "$off_resolved" \
                "$reply_equal" "$state_equal" >&2
            exit 1
        }

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$group" "$cohort" "$case" "$kind" "$status" \
            "$winner" "$guarded" "$redirected" "$on_outcome" \
            "$on_pending" "$on_resolved" "$off_outcome" \
            "$off_pending" "$off_resolved" "$reply_equal" "$state_equal" \
            "$on_sha" "$off_sha" >> "$MATRIX"

        if [ "$continuation" -eq 1 ]; then
            continuation_seed=$((run_seed + 5000))
            cp "$cell_dir/on.state" "$cell_dir/continuation.state"
            "$ROOT/leo" --load "$cell_dir/continuation.state" \
                --seed "$continuation_seed" --respond "$active" \
                --debug-field --no-wonder-appetite \
                --save "$cell_dir/continuation.state" \
                > "$cell_dir/continuation.log" 2>&1
            continuation_reply="$(
                reply_from_log "$cell_dir/continuation.log"
            )"
            continuation_curiosity="$(
                curiosity_from_log "$cell_dir/continuation.log" \
                    "$cell-continuation" "$continuation_seed"
            )"
            continuation_inventory="$(
                inventory_from_log "$cell_dir/continuation.log" \
                    "$cell-continuation" "$continuation_seed"
            )"
            IFS=$'\t' read -r _ _ _ continuation_outcome _ _ _ _ _ \
                <<< "$continuation_curiosity"
            IFS=$'\t' read -r _ _ _ continuation_count \
                continuation_pending continuation_episodes \
                continuation_resolved continuation_entries \
                <<< "$continuation_inventory"
            [ "$continuation_reply" = "$expected_active_question" ] &&
            [ "$continuation_outcome" = "asked-deferred" ] &&
            [ "$continuation_pending" = "$active" ] &&
            [ "$continuation_resolved" = 1 ] || {
                printf '%s failed exact displaced-Wonder continuation\n' \
                    "$cell" >&2
                exit 1
            }
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$cell" "$group" "$cohort" "$continuation_reply" \
                "$continuation_outcome" "$continuation_pending" \
                "$continuation_resolved" \
                "$(sha256_file "$cell_dir/continuation.state")" \
                >> "$CONTINUATIONS"
        fi
    done < "$CASES_FILE"
done

awk -F '\t' '
    NR > 1 {
        cells++
        redirected += $9
        controls += ($5 == "control")
        redirect_cells += ($5 == "redirect")
        reply_equal += $16
        state_equal += $17
        if ($5 == "control" && $17 == 1) control_state_equal++
        if ($9 == 1 && $17 == 0) redirected_state_diverged++
    }
    END {
        print "cells\tredirect_cells\tcontrols\tredirected\tcontinuations\treply_equal\tstate_equal\tcontrol_state_equal\tredirected_state_diverged"
        print cells "\t" redirect_cells "\t" controls "\t" redirected \
              "\t2\t" reply_equal "\t" state_equal "\t" \
              control_state_equal "\t" redirected_state_diverged
    }
' "$MATRIX" > "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\ncontinuations: %s\n' "$MATRIX" "$CONTINUATIONS"
