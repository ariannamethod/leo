#!/usr/bin/env bash
# A.41: read-only semantic echoes among withheld questions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GROUPS_FILE="${LEO_SEMANTIC_GROUPS:-$ROOT/scripts/deferred_wonder_constellation_groups.tsv}"
CASES_FILE="${LEO_SEMANTIC_CASES:-$ROOT/scripts/deferred_wonder_semantic_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-semantics-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
for fixture in "$GROUPS_FILE" "$CASES_FILE"; do
    [ -f "$fixture" ] || {
        printf 'semantic fixture not found: %s\n' "$fixture" >&2
        exit 2
    }
done

awk -F '\t' '
    NR == 1 {
        if (NF != 11 || $1 != "case" || $2 != "kind" ||
            $3 != "target_slot" || $4 != "prompt" ||
            $5 != "expected_status" || $6 != "expected_winner_slot" ||
            $7 != "expected_curiosity" || $8 != "expected_count" ||
            $9 != "expected_pending_slot" || $10 != "expected_resolved" ||
            $11 != "cross_attribution")
            exit 1
        next
    }
    {
        if (NF != 11 || seen[$1]++ || $3 !~ /^[0-3]$/ ||
            $6 !~ /^[0-3]$/ || $8 !~ /^[0-3]$/ ||
            $9 !~ /^[0-3]$/ || $10 !~ /^[01]$/ ||
            $11 !~ /^[01]$/)
            exit 1
        kinds[$2]++
        rows++
    }
    END {
        if (rows != 8 || kinds["semantic"] != 3 ||
            kinds["occupied"] != 1 || kinds["literal"] != 1)
            exit 1
    }
' "$CASES_FILE" || {
    printf 'invalid semantic cases: %s\n' "$CASES_FILE" >&2
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

shadow_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/prewonder_shadow_dialogue_report.awk" "$1"
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

printf 'cell\tgroup\tcohort\tseed\tcase\tkind\ttarget\tprompt\texpected_status\texpected_winner\n' \
    > "$PLAN"
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUPS_FILE" |
while IFS=$'\t' read -r group cohort seed; do
    while IFS=$'\t' read -r case kind target_slot prompt status winner_slot \
        curiosity count pending_slot resolved cross; do
        [ "$case" = "case" ] && continue
        target="none"
        winner="none"
        if [ "$target_slot" -gt 0 ]; then
            target="$(group_field "$group" "$target_slot" 5)"
        fi
        if [ "$winner_slot" -gt 0 ]; then
            winner="$(group_field "$group" "$winner_slot" 5)"
        fi
        if [ "$prompt" = "{target}" ]; then prompt="$target"; fi
        printf '%s-%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$group" "$case" "$group" "$cohort" "$seed" "$case" \
            "$kind" "$target" "$prompt" "$status" "$winner" >> "$PLAN"
    done < "$CASES_FILE"
done

if [ "${LEO_SEMANTIC_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"$ROOT/scripts/deferred_wonder_constellation_matrix.sh" "$OUT/a40-baseline" \
    > "$OUT/a40-baseline.log"

printf 'cell\tturn\tstatus\twinner\tmargin\tshadow_pending\tshadow_entries\tcuriosity\tcount\tpending\tepisodes\tresolved\tinventory\tprompt\treply\n' \
    > "$RECEIPTS"
printf 'cell\tgroup\tcohort\tcase\tkind\ttarget\tstatus\twinner\tmargin\tcuriosity\tcount\tpending\tresolved\treply_equal\tstate_equal\tcross_attribution\tstate_sha256\toutput\n' \
    > "$MATRIX"

case_index=0
while IFS=$'\t' read -r cell group cohort seed case kind target prompt \
    expected_status expected_winner; do
    [ "$cell" = "cell" ] && continue
    case_index=$((case_index + 1))
    cell_dir="$OUT/lives/$cell"
    mkdir -p "$cell_dir"
    base="$OUT/a40-baseline/groups/$group/ready.state"
    [ -f "$base" ] || {
        printf 'missing A.40 ready body: %s\n' "$base" >&2
        exit 1
    }

    row="$(awk -F '\t' -v case="$case" 'NR > 1 && $1 == case { print; exit }' "$CASES_FILE")"
    IFS=$'\t' read -r _ _ target_slot _ _ winner_slot expected_curiosity \
        expected_count expected_pending_slot expected_resolved \
        expected_cross <<< "$row"
    expected_pending="none"
    if [ "$expected_pending_slot" -gt 0 ]; then
        expected_pending="$(group_field "$group" "$expected_pending_slot" 5)"
    fi

    run_base="$base"
    if [ "$kind" = "occupied" ]; then
        opened="$(group_field "$group" 1 5)"
        expected_question="$(group_field "$group" 1 9)"
        cp "$base" "$cell_dir/pre.state"
        "$ROOT/leo" --load "$cell_dir/pre.state" --seed "$((seed + 700))" \
            --respond "$opened" --debug-field --no-prewonder-shadow \
            --save "$cell_dir/pre.state" > "$cell_dir/pre.log" 2>&1
        [ "$(reply_from_log "$cell_dir/pre.log")" = "$expected_question" ] || {
            printf '%s failed to open occupied control\n' "$cell" >&2
            exit 1
        }
        run_base="$cell_dir/pre.state"
    fi

    cp "$run_base" "$cell_dir/on.state"
    cp "$run_base" "$cell_dir/off.state"
    run_seed=$((seed + 1000 + case_index))
    "$ROOT/leo" --load "$cell_dir/on.state" --seed "$run_seed" \
        --respond "$prompt" --debug-field --save "$cell_dir/on.state" \
        > "$cell_dir/on.log" 2>&1
    "$ROOT/leo" --load "$cell_dir/off.state" --seed "$run_seed" \
        --respond "$prompt" --debug-field --no-prewonder-shadow \
        --save "$cell_dir/off.state" > "$cell_dir/off.log" 2>&1

    shadow="$(shadow_from_log "$cell_dir/on.log" "$cell" "$run_seed")"
    curiosity="$(curiosity_from_log "$cell_dir/on.log" "$cell" "$run_seed")"
    inventory="$(inventory_from_log "$cell_dir/on.log" "$cell" "$run_seed")"
    [ -n "$shadow" ] && [ -n "$curiosity" ] && [ -n "$inventory" ] || {
        printf '%s missing diagnostic receipt\n' "$cell" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ turn status winner margin shadow_pending \
        shadow_entries <<< "$shadow"
    IFS=$'\t' read -r _ _ curiosity_turn curiosity_outcome _ _ _ _ _ \
        <<< "$curiosity"
    IFS=$'\t' read -r _ _ inventory_turn count pending episodes resolved \
        entries <<< "$inventory"
    [ "$turn" = "$curiosity_turn" ] && [ "$turn" = "$inventory_turn" ] || {
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

    cross=0
    if [ "$kind" = "occupied" ] &&
        [ "$status" = "confident" ] &&
        [ "$winner" = "$expected_winner" ] &&
        [ "$curiosity_outcome" = "resolved" ]; then
        cross=1
    fi

    [ "$status" = "$expected_status" ] &&
    [ "$winner" = "$expected_winner" ] &&
    [ "$curiosity_outcome" = "$expected_curiosity" ] &&
    [ "$count" = "$expected_count" ] &&
    [ "$pending" = "$expected_pending" ] &&
    [ "$resolved" = "$expected_resolved" ] &&
    [ "$reply_equal" -eq 1 ] &&
    [ "$state_equal" -eq 1 ] &&
    [ "$cross" = "$expected_cross" ] || {
        printf '%s contract failed: status=%s winner=%s curiosity=%s count=%s pending=%s resolved=%s reply_equal=%s state_equal=%s cross=%s\n' \
            "$cell" "$status" "$winner" "$curiosity_outcome" "$count" \
            "$pending" "$resolved" "$reply_equal" "$state_equal" "$cross" >&2
        exit 1
    }

    if [ "$kind" = "literal" ]; then
        expected_question="$(group_field "$group" "$target_slot" 9)"
        [ "$on_reply" = "$expected_question" ] || {
            printf '%s literal return changed its real question\n' "$cell" >&2
            exit 1
        }
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$turn" "$status" "$winner" "$margin" "$shadow_pending" \
        "$shadow_entries" "$curiosity_outcome" "$count" "$pending" \
        "$episodes" "$resolved" "$entries" "$prompt" "$on_reply" \
        >> "$RECEIPTS"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$group" "$cohort" "$case" "$kind" "$target" "$status" \
        "$winner" "$margin" "$curiosity_outcome" "$count" "$pending" \
        "$resolved" "$reply_equal" "$state_equal" "$cross" "$on_sha" \
        "$cell_dir" >> "$MATRIX"
done < "$PLAN"

awk -F '\t' '
    NR > 1 {
        cells++
        status[$7]++
        if ($14 == 1) replies++
        if ($15 == 1) states++
        if ($16 == 1) cross++
    }
    END {
        print "cells\tconfident\tambiguous\tquiet\tliteral\treply_equal\tstate_equal\tcross_attribution"
        print cells "\t" status["confident"] "\t" status["ambiguous"] "\t" \
              status["quiet"] "\t" status["literal"] "\t" replies "\t" \
              states "\t" cross
    }
' "$MATRIX" > "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nreceipts: %s\n' "$MATRIX" "$RECEIPTS"
