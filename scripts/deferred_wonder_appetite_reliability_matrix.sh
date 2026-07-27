#!/usr/bin/env bash
# A.46: rebuild a reliability surface from accumulated lived forecasts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GROUPS_FILE="${LEO_APPETITE_RELIABILITY_GROUPS:-$ROOT/scripts/deferred_wonder_constellation_groups.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-reliability-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
[ -f "$GROUPS_FILE" ] || {
    printf 'reliability groups not found: %s\n' "$GROUPS_FILE" >&2
    exit 2
}

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "group" || $2 != "cohort" ||
            $3 != "seed" || $4 != "slot" || $5 != "target" ||
            $9 != "expected_question")
            exit 1
        next
    }
    {
        if (NF != 10 || $3 !~ /^[0-9]+$/ ||
            $4 !~ /^[123]$/ || seen[$1 SUBSEP $4]++)
            exit 1
        groups[$1]++
        rows++
    }
    END {
        if (rows != 6 || length(groups) != 2)
            exit 1
        for (group in groups)
            if (groups[group] != 3)
                exit 1
    }
' "$GROUPS_FILE" || {
    printf 'invalid reliability groups: %s\n' "$GROUPS_FILE" >&2
    exit 2
}

mkdir -p "$OUT/lives"
PLAN="$OUT/plan.tsv"
MATRIX="$OUT/matrix.tsv"
SURFACES="$OUT/surfaces.tsv"
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

reliability_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_reliability_dialogue_report.awk" \
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
                    for (j = 1; j <= 10; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

cell_fields() {
    local cells="$1"
    local wanted="$2"
    printf '%s\n' "$cells" |
        awk -v wanted="$wanted" '
            {
                n = split($0, items, /\|/)
                for (i = 1; i <= n; i++) {
                    split(items[i], pair, /:/)
                    if (pair[1] != wanted) continue
                    split(pair[2], values, /\//)
                    for (j = 1; j <= 9; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

printf 'cell\tgroup\tcohort\tseed\tunspoken_target\tspoken_target\tunspoken_outcomes\tspoken_outcomes\n' \
    > "$PLAN"
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUPS_FILE" |
while IFS=$'\t' read -r group cohort seed; do
    printf '%s-reliability\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$group" "$group" "$cohort" "$seed" \
        "$(group_field "$group" 2 5)" \
        "$(group_field "$group" 1 5)" \
        "sustained,sustained,sustained,faded" "sustained" \
        >> "$PLAN"
done

if [ "${LEO_APPETITE_RELIABILITY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"$ROOT/scripts/deferred_wonder_constellation_matrix.sh" \
    "$OUT/a40-baseline" > "$OUT/a40-baseline.log"

printf 'cell\tgroup\tcohort\tscored\tpositives\tsustained\tgrounded\tfaded\tpending\texternal\tlost\tunscorable\tbrier\tece\tunspoken_n\tunspoken_positives\tunspoken_status\tspoken_n\tspoken_positives\tspoken_status\treply_equal\tstate_equal\ton_sha256\toff_sha256\n' \
    > "$MATRIX"
printf 'cell\tscored\tpositives\tsustained\tgrounded\tfaded\tpending\texternal\tlost\tunscorable\tbrier\tece\tcells\n' \
    > "$SURFACES"

group_index=0
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUPS_FILE" |
while IFS=$'\t' read -r group cohort seed; do
    group_index=$((group_index + 1))
    cell="$group-reliability"
    group_dir="$OUT/lives/$group"
    mkdir -p "$group_dir"
    ready="$OUT/a40-baseline/groups/$group/ready.state"
    [ -f "$ready" ] || {
        printf 'missing A.40 ready body: %s\n' "$ready" >&2
        exit 1
    }

    spoken_target="$(group_field "$group" 1 5)"
    unspoken_target="$(group_field "$group" 2 5)"
    spoken_question="$(group_field "$group" 1 9)"
    unspoken_question="$(group_field "$group" 2 9)"
    semantic_spoken="Bright sun. Cold winter."
    semantic_unspoken="Cat bird. Dark night."
    quiet="I do not know."
    state="$group_dir/history.state"
    cp "$ready" "$state"
    turn_index=0
    last_log=

    history_turn() {
        local prompt="$1"
        local label="$2"
        turn_index=$((turn_index + 1))
        local run_seed=$((seed + 6100 + group_index * 1000 + turn_index))
        last_log="$group_dir/$(printf '%02d' "$turn_index")-$label.log"
        "$ROOT/leo" --load "$state" --seed "$run_seed" \
            --respond "$prompt" --debug-field \
            --no-wonder-appetite-reliability \
            --save "$state" > "$last_log" 2>&1
    }

    cycle=0
    for expected in sustained sustained sustained faded; do
        cycle=$((cycle + 1))
        history_turn "$semantic_unspoken" "u${cycle}-birth"
        history_turn "$quiet" "u${cycle}-future1"
        if [ "$expected" = sustained ]; then
            history_turn "$semantic_unspoken" "u${cycle}-future2"
        else
            history_turn "$quiet" "u${cycle}-future2"
        fi
        history_turn "$quiet" "u${cycle}-future3"

        calibration="$(
            calibration_from_log "$last_log" "$cell" "$seed"
        )"
        [ -n "$calibration" ] || {
            printf '%s cycle %s emitted no calibration receipt\n' \
                "$cell" "$cycle" >&2
            exit 1
        }
        IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ entries \
            <<< "$calibration"
        fields="$(entry_fields "$entries" "$unspoken_target")"
        [ -n "$fields" ] || {
            printf '%s cycle %s lost target %s\n' \
                "$cell" "$cycle" "$unspoken_target" >&2
            exit 1
        }
        IFS=$'\t' read -r _ _ _ _ _ _ _ observed_spoken \
            observed_verdict _ <<< "$fields"
        [ "$observed_spoken" = 0 ] &&
        [ "$observed_verdict" = "$expected" ] || {
            printf '%s cycle %s expected %s/unspoken, got %s/%s\n' \
                "$cell" "$cycle" "$expected" \
                "$observed_verdict" "$observed_spoken" >&2
            exit 1
        }
    done

    history_turn "$spoken_target" "spoken-open"
    [ "$(reply_from_log "$last_log")" = "$spoken_question" ] || {
        printf '%s failed to open %s\n' "$cell" "$spoken_target" >&2
        exit 1
    }
    history_turn "$unspoken_target" "spoken-park"
    [ "$(reply_from_log "$last_log")" = "$unspoken_question" ] || {
        printf '%s failed to park %s behind %s\n' \
            "$cell" "$spoken_target" "$unspoken_target" >&2
        exit 1
    }
    history_turn "$semantic_spoken" "spoken-birth"
    history_turn "$quiet" "spoken-future1"
    history_turn "$semantic_spoken" "spoken-future2"
    history_turn "$quiet" "spoken-future3"

    calibration="$(
        calibration_from_log "$last_log" "$cell" "$seed"
    )"
    [ -n "$calibration" ] || {
        printf '%s emitted no parked-spoken calibration receipt\n' \
            "$cell" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ entries \
        <<< "$calibration"
    fields="$(entry_fields "$entries" "$spoken_target")"
    [ -n "$fields" ] || {
        printf '%s lost parked-spoken target %s\n' \
            "$cell" "$spoken_target" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ _ _ _ _ _ observed_spoken \
        observed_verdict _ <<< "$fields"
    [ "$observed_spoken" = 1 ] &&
    [ "$observed_verdict" = sustained ] || {
        printf '%s parked target expected sustained/spoken, got %s/%s\n' \
            "$cell" "$observed_verdict" "$observed_spoken" >&2
        exit 1
    }

    cp "$state" "$group_dir/on.state"
    cp "$state" "$group_dir/off.state"
    final_seed=$((seed + 9900))
    "$ROOT/leo" --load "$group_dir/on.state" --seed "$final_seed" \
        --respond "$quiet" --debug-field \
        --save "$group_dir/on.state" > "$group_dir/on.log" 2>&1
    "$ROOT/leo" --load "$group_dir/off.state" --seed "$final_seed" \
        --respond "$quiet" --debug-field \
        --no-wonder-appetite-reliability \
        --save "$group_dir/off.state" > "$group_dir/off.log" 2>&1

    reliability="$(
        reliability_from_log "$group_dir/on.log" "$cell" "$final_seed"
    )"
    [ -n "$reliability" ] || {
        printf '%s did not reconstruct its reliability surface\n' \
            "$cell" >&2
        exit 1
    }
    [ -z "$(
        reliability_from_log "$group_dir/off.log" "$cell" "$final_seed"
    )" ] || {
        printf '%s reliability ablation remained visible\n' "$cell" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ scored positives sustained grounded faded \
        pending external lost unscorable brier ece cells \
        <<< "$reliability"
    unspoken_fields="$(cell_fields "$cells" u62-70)"
    spoken_fields="$(cell_fields "$cells" s80-90)"
    [ -n "$unspoken_fields" ] && [ -n "$spoken_fields" ] || {
        printf '%s missing expected spoken/unspoken reliability cells\n' \
            "$cell" >&2
        exit 1
    }
    IFS=$'\t' read -r unspoken_n unspoken_positives _ _ _ _ _ _ \
        unspoken_status <<< "$unspoken_fields"
    IFS=$'\t' read -r spoken_n spoken_positives _ _ _ _ _ _ \
        spoken_status <<< "$spoken_fields"

    reply_equal=0
    [ "$(reply_from_log "$group_dir/on.log")" = \
      "$(reply_from_log "$group_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$group_dir/on.state" "$group_dir/off.state" &&
        state_equal=1

    [ "$scored" = 5 ] &&
    [ "$positives" = 4 ] &&
    [ "$sustained" = 4 ] &&
    [ "$grounded" = 0 ] &&
    [ "$faded" = 1 ] &&
    [ "$pending" = 0 ] &&
    [ "$external" = 0 ] &&
    [ "$lost" = 0 ] &&
    [ "$unscorable" = 0 ] &&
    [ "$unspoken_n" = 4 ] &&
    [ "$unspoken_positives" = 3 ] &&
    [ "$unspoken_status" = aligned ] &&
    [ "$spoken_n" = 1 ] &&
    [ "$spoken_positives" = 1 ] &&
    [ "$spoken_status" = forming ] &&
    [ "$reply_equal" = 1 ] &&
    [ "$state_equal" = 1 ] || {
        printf '%s contract failed: scored=%s positive=%s u=%s/%s/%s s=%s/%s/%s reply=%s state=%s cells=%s\n' \
            "$cell" "$scored" "$positives" \
            "$unspoken_n" "$unspoken_positives" "$unspoken_status" \
            "$spoken_n" "$spoken_positives" "$spoken_status" \
            "$reply_equal" "$state_equal" "$cells" >&2
        exit 1
    }

    on_sha="$(sha256_file "$group_dir/on.state")"
    off_sha="$(sha256_file "$group_dir/off.state")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$group" "$cohort" "$scored" "$positives" \
        "$sustained" "$grounded" "$faded" "$pending" "$external" \
        "$lost" "$unscorable" "$brier" "$ece" \
        "$unspoken_n" "$unspoken_positives" "$unspoken_status" \
        "$spoken_n" "$spoken_positives" "$spoken_status" \
        "$reply_equal" "$state_equal" "$on_sha" "$off_sha" \
        >> "$MATRIX"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$scored" "$positives" "$sustained" "$grounded" \
        "$faded" "$pending" "$external" "$lost" "$unscorable" \
        "$brier" "$ece" "$cells" >> "$SURFACES"
done

awk -F '\t' '
    NR > 1 {
        cells++
        scored += $4
        positives += $5
        aligned += $17 == "aligned"
        forming += $20 == "forming"
        reply_equal += $21
        state_equal += $22
    }
    END {
        print "cells\tscored\tpositives\taligned_unspoken\tforming_spoken\treply_equal\tstate_equal"
        print cells "\t" scored "\t" positives "\t" aligned "\t" \
              forming "\t" reply_equal "\t" state_equal
    }
' "$MATRIX" > "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nsurfaces: %s\n' "$MATRIX" "$SURFACES"
