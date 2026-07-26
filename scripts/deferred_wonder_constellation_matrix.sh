#!/usr/bin/env bash
# A.40: three withheld questions coexist and open in every order.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GROUP_CASES="${LEO_CONSTELLATION_GROUPS:-$ROOT/scripts/deferred_wonder_constellation_groups.tsv}"
ORDERS="${LEO_CONSTELLATION_ORDERS:-$ROOT/scripts/deferred_wonder_constellation_orders.tsv}"
ECOLOGY="${LEO_CONSTELLATION_ECOLOGY:-$ROOT/scripts/deferred_wonder_ecology_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-constellation-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
for fixture in "$GROUP_CASES" "$ORDERS" "$ECOLOGY"; do
    [ -f "$fixture" ] || {
        printf 'constellation fixture not found: %s\n' "$fixture" >&2
        exit 2
    }
done

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "group" || $2 != "cohort" ||
            $3 != "seed" || $4 != "slot" || $5 != "target" ||
            $6 != "birth_prompt" || $7 != "primary_glyph" ||
            $8 != "alt_glyph" || $9 != "expected_question" ||
            $10 != "grounding")
            exit 1
        next
    }
    {
        if (NF != 10 || $3 !~ /^[0-9]+$/ || $4 !~ /^[123]$/ ||
            seen[$1 SUBSEP $4]++ || targets[$5]++)
            exit 1
        groups[$1]++
        cohorts[$1] = $2
        seeds[$1] = $3
        if (index(tolower($6), tolower($5)) == 0 ||
            index(tolower($9), tolower($5)) == 0 ||
            index(tolower($10), tolower($5)) == 0)
            exit 1
    }
    END {
        if (length(groups) != 2 || length(targets) != 6)
            exit 1
        for (group in groups)
            if (groups[group] != 3)
                exit 1
    }
' "$GROUP_CASES" || {
    printf 'invalid constellation groups: %s\n' "$GROUP_CASES" >&2
    exit 2
}

awk -F '\t' '
    NR == 1 {
        if (NF != 4 || $1 != "order" || $2 != "first_slot" ||
            $3 != "second_slot" || $4 != "third_slot")
            exit 1
        next
    }
    {
        if (NF != 4 || $1 !~ /^[123]{3}$/ || orders[$1]++)
            exit 1
        delete slots
        for (i = 2; i <= 4; i++) {
            if ($i !~ /^[123]$/ || slots[$i]++)
                exit 1
        }
        rows++
    }
    END {
        if (rows != 6)
            exit 1
    }
' "$ORDERS" || {
    printf 'invalid constellation orders: %s\n' "$ORDERS" >&2
    exit 2
}

mkdir -p "$OUT/groups" "$OUT/lives"
PLAN="$OUT/plan.tsv"
BASE_RECEIPTS="$OUT/base_receipts.tsv"
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
    ' "$GROUP_CASES"
}

group_entries() {
    local group="$1"
    local remaining="$2"
    awk -F '\t' -v group="$group" -v remaining="$remaining" '
        NR > 1 && $1 == group &&
        index(remaining, "|" $5 "|") {
            printf "%s%s@1:%s/%s", found ? "|" : "", $5, $7, $8
            found = 1
        }
        END {
            if (!found) printf "none"
        }
    ' "$GROUP_CASES"
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

append_receipt() {
    local file="$1"
    local cell="$2"
    local phase="$3"
    local prompt="$4"
    local reply="$5"
    local curiosity="$6"
    local inventory="$7"
    local c_turn outcome candidate deferred deferred_heard distress gate
    local i_turn count pending episodes resolved entries
    IFS=$'\t' read -r _ _ c_turn outcome candidate deferred \
        deferred_heard distress gate <<< "$curiosity"
    IFS=$'\t' read -r _ _ i_turn count pending episodes resolved entries \
        <<< "$inventory"
    [ "$c_turn" = "$i_turn" ] || {
        printf '%s turn disagreement between curiosity and inventory\n' \
            "$cell" >&2
        exit 1
    }
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$phase" "$c_turn" "$outcome" "$candidate" "$deferred" \
        "$deferred_heard" "$distress" "$gate" "$count" "$pending" \
        "$episodes" "$resolved" "$entries" "$prompt" "$reply" \
        >> "$file"
}

printf 'cell\tgroup\tcohort\tseed\torder\ttarget_order\n' > "$PLAN"
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUP_CASES" |
while IFS=$'\t' read -r group cohort seed; do
    tail -n +2 "$ORDERS" |
    while IFS=$'\t' read -r order first second third; do
        t1="$(group_field "$group" "$first" 5)"
        t2="$(group_field "$group" "$second" 5)"
        t3="$(group_field "$group" "$third" 5)"
        printf '%s-%s\t%s\t%s\t%s\t%s\t%s,%s,%s\n' \
            "$group" "$order" "$group" "$cohort" "$seed" "$order" \
            "$t1" "$t2" "$t3" >> "$PLAN"
    done
done

if [ "${LEO_CONSTELLATION_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null

printf 'cell\tphase\tturn\toutcome\tcandidate\tdeferred\tdeferred_heard\tdistress\tgate\tcount\tpending\tepisodes\tresolved\tentries\tprompt\treply\n' \
    > "$BASE_RECEIPTS"
cp "$BASE_RECEIPTS" "$RECEIPTS"
printf 'cell\tgroup\tcohort\tseed\torder\ttarget_order\tquestions_exact\toccupied_preserved\tgroundings_resolved\tlearned_quiet\tfinal_count\tfinal_pending\tfinal_episodes\tfinal_resolved\ttranscript_sha256\toutput\n' \
    > "$MATRIX"

# Build one common three-question body and one common lived-safe body per group.
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUP_CASES" |
while IFS=$'\t' read -r group cohort seed; do
    group_dir="$OUT/groups/$group"
    mkdir -p "$group_dir/turns"
    state="$group_dir/body.state"
    transcript="$group_dir/prefix.tsv"
    printf 'role\tturn\ttext\n' > "$transcript"
    turn=0
    born='|'

    while IFS=$'\t' read -r slot target prompt primary alt question grounding; do
        turn=$((turn + 1))
        log="$group_dir/turns/turn-$(printf '%02d' "$turn")-birth.log"
        if [ "$turn" -eq 1 ]; then
            "$ROOT/leo" --seed "$seed" --respond "$prompt" --debug-field \
                --no-wonder-redirection \
                --save "$state" > "$log" 2>&1
        else
            "$ROOT/leo" --load "$state" --seed "$((seed + turn - 1))" \
                --respond "$prompt" --debug-field --no-wonder-redirection \
                --save "$state" \
                > "$log" 2>&1
        fi
        curiosity="$(curiosity_from_log "$log" "$group-birth" "$seed")"
        inventory="$(inventory_from_log "$log" "$group-birth" "$seed")"
        reply="$(reply_from_log "$log")"
        IFS=$'\t' read -r _ _ _ outcome candidate _ _ _ _ <<< "$curiosity"
        IFS=$'\t' read -r _ _ _ count pending episodes resolved entries \
            <<< "$inventory"
        born="${born}${target}|"
        expected_entries="$(group_entries "$group" "$born")"
        [ "$outcome" = blocked-distress ] &&
        [ "$candidate" = "$target" ] &&
        [ "$count" -eq "$slot" ] &&
        [ "$pending" = none ] &&
        [ "$episodes" -eq 0 ] &&
        [ "$resolved" -eq 0 ] &&
        [ "$entries" = "$expected_entries" ] || {
            printf '%s birth slot %s violated constellation identity\n' \
                "$group" "$slot" >&2
            exit 1
        }
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$prompt" "$turn" "$reply" >> "$transcript"
        append_receipt "$BASE_RECEIPTS" "$group" birth "$prompt" "$reply" \
            "$curiosity" "$inventory"
    done < <(awk -F '\t' -v group="$group" '
        NR > 1 && $1 == group {
            print $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9 "\t" $10
        }
    ' "$GROUP_CASES" | sort -t $'\t' -k1,1n)
    cp "$state" "$group_dir/born.state"

    while IFS=$'\t' read -r order prompt; do
        turn=$((turn + 1))
        log="$group_dir/turns/turn-$(printf '%02d' "$turn")-life.log"
        "$ROOT/leo" --load "$state" --seed "$((seed + turn - 1))" \
            --respond "$prompt" --debug-field --no-wonder-redirection \
            --save "$state" \
            > "$log" 2>&1
        curiosity="$(curiosity_from_log "$log" "$group-life" "$seed")"
        inventory="$(inventory_from_log "$log" "$group-life" "$seed")"
        reply="$(reply_from_log "$log")"
        IFS=$'\t' read -r _ _ _ outcome candidate _ _ _ _ <<< "$curiosity"
        IFS=$'\t' read -r _ _ _ count pending episodes resolved entries \
            <<< "$inventory"
        expected_entries="$(group_entries "$group" "$born")"
        [ "$outcome" = no-candidate ] &&
        [ "$candidate" = none ] &&
        [ "$count" -eq 3 ] &&
        [ "$pending" = none ] &&
        [ "$episodes" -eq 0 ] &&
        [ "$resolved" -eq 0 ] &&
        [ "$entries" = "$expected_entries" ] || {
            printf '%s life turn %s changed the constellation\n' \
                "$group" "$order" >&2
            exit 1
        }
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$prompt" "$turn" "$reply" >> "$transcript"
        append_receipt "$BASE_RECEIPTS" "$group" life "$prompt" "$reply" \
            "$curiosity" "$inventory"
    done < <(awk -F '\t' '
        NR > 1 && $1 == "varied-safe" && $3 > 0 {
            print $3 "\t" $4
        }
    ' "$ECOLOGY" | sort -t $'\t' -k1,1n)
    cp "$state" "$group_dir/ready.state"
done

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r cell group cohort seed order target_order; do
    life="$OUT/lives/$cell"
    mkdir -p "$life/turns"
    state="$life/leo.state"
    transcript="$life/transcript.tsv"
    cp "$OUT/groups/$group/ready.state" "$state"
    cp "$OUT/groups/$group/prefix.tsv" "$transcript"
    turn="$(awk -F '\t' '$1 == "human" && $2 > max { max = $2 }
                       END { print max + 0 }' "$transcript")"
    order_row="$(awk -F '\t' -v order="$order" \
        'NR > 1 && $1 == order { print $2 "\t" $3 "\t" $4 }' "$ORDERS")"
    IFS=$'\t' read -r first second third <<< "$order_row"
    slots=("$first" "$second" "$third")
    remaining='|'
    for slot in 1 2 3; do
        remaining="${remaining}$(group_field "$group" "$slot" 5)|"
    done

    questions_exact=0
    occupied_preserved=0
    groundings_resolved=0
    for idx in 0 1 2; do
        slot="${slots[$idx]}"
        target="$(group_field "$group" "$slot" 5)"
        expected_question="$(group_field "$group" "$slot" 9)"
        grounding="$(group_field "$group" "$slot" 10)"

        turn=$((turn + 1))
        log="$life/turns/turn-$(printf '%02d' "$turn")-open.log"
        "$ROOT/leo" --load "$state" --seed "$((seed + 100 + turn))" \
            --respond "$target" --debug-field --no-wonder-redirection \
            --save "$state" \
            > "$log" 2>&1
        curiosity="$(curiosity_from_log "$log" "$cell-open" "$seed")"
        inventory="$(inventory_from_log "$log" "$cell-open" "$seed")"
        reply="$(reply_from_log "$log")"
        IFS=$'\t' read -r _ _ _ outcome candidate _ _ _ _ <<< "$curiosity"
        IFS=$'\t' read -r _ _ _ count pending episodes resolved entries \
            <<< "$inventory"
        remaining="${remaining/|$target|/|}"
        expected_entries="$(group_entries "$group" "$remaining")"
        expected_count="$((2 - idx))"
        [ "$outcome" = asked-deferred ] &&
        [ "$candidate" = "$target" ] &&
        [ "$reply" = "$expected_question" ] &&
        [ "$count" -eq "$expected_count" ] &&
        [ "$pending" = "$target" ] &&
        [ "$episodes" -eq "$((idx + 1))" ] &&
        [ "$resolved" -eq "$idx" ] &&
        [ "$entries" = "$expected_entries" ] || {
            printf '%s failed to open slot %s with its own identity\n' \
                "$cell" "$slot" >&2
            exit 1
        }
        questions_exact=$((questions_exact + 1))
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$target" "$turn" "$reply" >> "$transcript"
        append_receipt "$RECEIPTS" "$cell" open "$target" "$reply" \
            "$curiosity" "$inventory"

        if [ "$idx" -lt 2 ]; then
            next_slot="${slots[$((idx + 1))]}"
            next_target="$(group_field "$group" "$next_slot" 5)"
            turn=$((turn + 1))
            log="$life/turns/turn-$(printf '%02d' "$turn")-occupied.log"
            "$ROOT/leo" --load "$state" --seed "$((seed + 100 + turn))" \
                --respond "$next_target" --debug-field \
                --no-wonder-redirection --save "$state" \
                > "$log" 2>&1
            curiosity="$(curiosity_from_log "$log" "$cell-occupied" "$seed")"
            inventory="$(inventory_from_log "$log" "$cell-occupied" "$seed")"
            reply="$(reply_from_log "$log")"
            IFS=$'\t' read -r _ _ _ outcome candidate _ _ _ _ <<< "$curiosity"
            IFS=$'\t' read -r _ _ _ count pending episodes resolved entries \
                <<< "$inventory"
            [ "$outcome" = continued ] &&
            [ "$candidate" = none ] &&
            [ "$count" -eq "$expected_count" ] &&
            [ "$pending" = "$target" ] &&
            [ "$episodes" -eq "$((idx + 1))" ] &&
            [ "$resolved" -eq "$idx" ] &&
            [ "$entries" = "$expected_entries" ] || {
                printf '%s let %s displace or mutate occupied %s\n' \
                    "$cell" "$next_target" "$target" >&2
                exit 1
            }
            occupied_preserved=$((occupied_preserved + 1))
            printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
                "$turn" "$next_target" "$turn" "$reply" >> "$transcript"
            append_receipt "$RECEIPTS" "$cell" occupied "$next_target" \
                "$reply" "$curiosity" "$inventory"
        fi

        turn=$((turn + 1))
        log="$life/turns/turn-$(printf '%02d' "$turn")-ground.log"
        "$ROOT/leo" --load "$state" --seed "$((seed + 100 + turn))" \
            --respond "$grounding" --debug-field --no-wonder-redirection \
            --save "$state" \
            > "$log" 2>&1
        curiosity="$(curiosity_from_log "$log" "$cell-ground" "$seed")"
        inventory="$(inventory_from_log "$log" "$cell-ground" "$seed")"
        reply="$(reply_from_log "$log")"
        IFS=$'\t' read -r _ _ _ outcome candidate _ _ _ _ <<< "$curiosity"
        IFS=$'\t' read -r _ _ _ count pending episodes resolved entries \
            <<< "$inventory"
        [ "$outcome" = resolved ] &&
        [ "$candidate" = none ] &&
        [ "$count" -eq "$expected_count" ] &&
        [ "$pending" = none ] &&
        [ "$episodes" -eq "$((idx + 1))" ] &&
        [ "$resolved" -eq "$((idx + 1))" ] &&
        [ "$entries" = "$expected_entries" ] || {
            printf '%s grounding slot %s harmed a sibling\n' \
                "$cell" "$slot" >&2
            exit 1
        }
        groundings_resolved=$((groundings_resolved + 1))
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$grounding" "$turn" "$reply" >> "$transcript"
        append_receipt "$RECEIPTS" "$cell" ground "$grounding" "$reply" \
            "$curiosity" "$inventory"
    done

    learned_quiet=0
    for slot in 1 2 3; do
        target="$(group_field "$group" "$slot" 5)"
        turn=$((turn + 1))
        log="$life/turns/turn-$(printf '%02d' "$turn")-learned.log"
        "$ROOT/leo" --load "$state" --seed "$((seed + 100 + turn))" \
            --respond "$target" --debug-field --no-wonder-redirection \
            --save "$state" \
            > "$log" 2>&1
        curiosity="$(curiosity_from_log "$log" "$cell-learned" "$seed")"
        inventory="$(inventory_from_log "$log" "$cell-learned" "$seed")"
        reply="$(reply_from_log "$log")"
        IFS=$'\t' read -r _ _ _ outcome candidate _ _ _ _ <<< "$curiosity"
        IFS=$'\t' read -r _ _ _ final_count final_pending \
            final_episodes final_resolved entries <<< "$inventory"
        [ "$outcome" = no-candidate ] &&
        [ "$candidate" = none ] &&
        [ "$final_count" -eq 0 ] &&
        [ "$final_pending" = none ] &&
        [ "$final_episodes" -eq 3 ] &&
        [ "$final_resolved" -eq 3 ] &&
        [ "$entries" = none ] || {
            printf '%s relearned or reopened completed target %s\n' \
                "$cell" "$target" >&2
            exit 1
        }
        learned_quiet=$((learned_quiet + 1))
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$target" "$turn" "$reply" >> "$transcript"
        append_receipt "$RECEIPTS" "$cell" learned "$target" "$reply" \
            "$curiosity" "$inventory"
    done

    transcript_sha="$(sha256_file "$transcript")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$group" "$cohort" "$seed" "$order" "$target_order" \
        "$questions_exact" "$occupied_preserved" "$groundings_resolved" \
        "$learned_quiet" "$final_count" "$final_pending" \
        "$final_episodes" "$final_resolved" "$transcript_sha" "$life" \
        >> "$MATRIX"
done

expected_cells=$(($(wc -l < "$PLAN") - 1))
actual_cells=$(($(wc -l < "$MATRIX") - 1))
[ "$actual_cells" -eq "$expected_cells" ] || {
    printf 'constellation matrix has %d of %d expected cells\n' \
        "$actual_cells" "$expected_cells" >&2
    exit 1
}

printf 'cells\tquestions_exact\toccupied_preserved\tgroundings_resolved\tlearned_quiet\tcomplete\n' \
    > "$SUMMARY"
awk -F '\t' '
    NR > 1 {
        cells++
        questions += $7
        occupied += $8
        groundings += $9
        learned += $10
        if ($7 == 3 && $8 == 2 && $9 == 3 && $10 == 3 &&
            $11 == 0 && $12 == "none" && $13 == 3 && $14 == 3)
            complete++
    }
    END {
        printf "%d\t%d\t%d\t%d\t%d\t%d\n",
               cells, questions, occupied, groundings, learned, complete
    }
' "$MATRIX" >> "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nreceipts: %s\nbase receipts: %s\n' \
    "$MATRIX" "$RECEIPTS" "$BASE_RECEIPTS"
