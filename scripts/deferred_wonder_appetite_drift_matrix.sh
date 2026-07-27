#!/usr/bin/env bash
# A.47: equal pooled reliability, opposite chronological return lives.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GROUPS_FILE="${LEO_APPETITE_DRIFT_GROUPS:-$ROOT/scripts/deferred_wonder_constellation_groups.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-drift-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
[ -f "$GROUPS_FILE" ] || {
    printf 'drift groups not found: %s\n' "$GROUPS_FILE" >&2
    exit 2
}

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "group" || $2 != "cohort" ||
            $3 != "seed" || $4 != "slot" || $5 != "target")
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
        if (rows != 6 || length(groups) != 2 ||
            !("old" in groups) || !("new" in groups))
            exit 1
        for (group in groups)
            if (groups[group] != 3)
                exit 1
    }
' "$GROUPS_FILE" || {
    printf 'invalid drift groups: %s\n' "$GROUPS_FILE" >&2
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

drift_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_drift_dialogue_report.awk" \
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

reliability_cell_fields() {
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

drift_cell_fields() {
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
                    for (j = 1; j <= 18; j++)
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

printf 'cell\tgroup\tcohort\tseed\ttarget\tearly_outcomes\trecent_outcomes\texpected_drift\n' \
    > "$PLAN"
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUPS_FILE" |
while IFS=$'\t' read -r group cohort seed; do
    if [ "$group" = old ]; then
        early="faded,faded,faded,faded"
        recent="sustained,sustained,sustained,sustained"
        expected="rising"
    else
        early="sustained,sustained,sustained,sustained"
        recent="faded,faded,faded,faded"
        expected="falling"
    fi
    printf '%s-drift\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$group" "$group" "$cohort" "$seed" \
        "$(group_field "$group" 2 5)" \
        "$early" "$recent" "$expected" >> "$PLAN"
done

if [ "${LEO_APPETITE_DRIFT_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"$ROOT/scripts/deferred_wonder_constellation_matrix.sh" \
    "$OUT/a40-baseline" > "$OUT/a40-baseline.log"

printf 'cell\tgroup\tcohort\tscored\tpositives\treliability_status\tdrift_status\tearly_positives\trecent_positives\treturn_shift\tappetite_shift\tgap_shift\tbrier_shift\treply_equal\tstate_equal\ton_sha256\toff_sha256\n' \
    > "$MATRIX"
printf 'cell\tmeasured\tforming\tstable\trising\tfalling\tcells\n' \
    > "$SURFACES"

group_index=0
awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }' \
    "$GROUPS_FILE" |
while IFS=$'\t' read -r group cohort seed; do
    group_index=$((group_index + 1))
    cell="$group-drift"
    group_dir="$OUT/lives/$group"
    mkdir -p "$group_dir"
    ready="$OUT/a40-baseline/groups/$group/ready.state"
    [ -f "$ready" ] || {
        printf 'missing A.40 ready body: %s\n' "$ready" >&2
        exit 1
    }

    target="$(group_field "$group" 2 5)"
    semantic="Cat bird. Dark night."
    quiet="I do not know."
    state="$group_dir/history.state"
    cp "$ready" "$state"
    turn_index=0
    last_log=

    history_turn() {
        local prompt="$1"
        local label="$2"
        turn_index=$((turn_index + 1))
        local run_seed=$((seed + 7200 +
            group_index * 1000 + turn_index))
        last_log="$group_dir/$(printf '%02d' "$turn_index")-$label.log"
        "$ROOT/leo" --load "$state" --seed "$run_seed" \
            --respond "$prompt" --debug-field \
            --no-wonder-appetite-reliability \
            --no-wonder-appetite-drift \
            --save "$state" > "$last_log" 2>&1
    }

    if [ "$group" = old ]; then
        outcomes=(
            faded faded faded faded
            sustained sustained sustained sustained
        )
        expected_drift=rising
    else
        outcomes=(
            sustained sustained sustained sustained
            faded faded faded faded
        )
        expected_drift=falling
    fi

    cycle=0
    for expected in "${outcomes[@]}"; do
        cycle=$((cycle + 1))
        history_turn "$semantic" "c${cycle}-birth"
        history_turn "$quiet" "c${cycle}-future1"
        if [ "$expected" = sustained ]; then
            history_turn "$semantic" "c${cycle}-future2"
        else
            history_turn "$quiet" "c${cycle}-future2"
        fi
        history_turn "$quiet" "c${cycle}-future3"

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
        fields="$(entry_fields "$entries" "$target")"
        [ -n "$fields" ] || {
            printf '%s cycle %s lost target %s\n' \
                "$cell" "$cycle" "$target" >&2
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

    cp "$state" "$group_dir/on.state"
    cp "$state" "$group_dir/off.state"
    final_seed=$((seed + 11900))
    "$ROOT/leo" --load "$group_dir/on.state" --seed "$final_seed" \
        --respond "$quiet" --debug-field \
        --save "$group_dir/on.state" > "$group_dir/on.log" 2>&1
    "$ROOT/leo" --load "$group_dir/off.state" --seed "$final_seed" \
        --respond "$quiet" --debug-field \
        --no-wonder-appetite-drift \
        --save "$group_dir/off.state" > "$group_dir/off.log" 2>&1

    reliability="$(
        reliability_from_log "$group_dir/on.log" "$cell" "$final_seed"
    )"
    drift="$(
        drift_from_log "$group_dir/on.log" "$cell" "$final_seed"
    )"
    [ -n "$reliability" ] && [ -n "$drift" ] || {
        printf '%s did not reconstruct both diagnostic surfaces\n' \
            "$cell" >&2
        exit 1
    }
    [ -z "$(
        drift_from_log "$group_dir/off.log" "$cell" "$final_seed"
    )" ] || {
        printf '%s drift ablation remained visible\n' "$cell" >&2
        exit 1
    }

    IFS=$'\t' read -r _ _ scored positives _ _ _ _ _ _ _ _ _ \
        reliability_cells <<< "$reliability"
    reliability_fields="$(
        reliability_cell_fields "$reliability_cells" u62-70
    )"
    [ -n "$reliability_fields" ] || {
        printf '%s missing pooled reliability cell\n' "$cell" >&2
        exit 1
    }
    IFS=$'\t' read -r reliability_n reliability_positives \
        _ _ _ _ _ _ reliability_status <<< "$reliability_fields"

    IFS=$'\t' read -r _ _ measured forming stable rising falling \
        drift_cells <<< "$drift"
    drift_fields="$(drift_cell_fields "$drift_cells" u62-70)"
    [ -n "$drift_fields" ] || {
        printf '%s missing chronological drift cell\n' "$cell" >&2
        exit 1
    }
    IFS=$'\t' read -r drift_n early_positives recent_positives \
        _ _ _ _ _ _ _ _ _ _ return_shift appetite_shift gap_shift brier_shift \
        drift_status <<< "$drift_fields"

    reply_equal=0
    [ "$(reply_from_log "$group_dir/on.log")" = \
      "$(reply_from_log "$group_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$group_dir/on.state" "$group_dir/off.state" &&
        state_equal=1

    [ "$scored" = 8 ] &&
    [ "$positives" = 4 ] &&
    [ "$reliability_n" = 8 ] &&
    [ "$reliability_positives" = 4 ] &&
    [ "$reliability_status" = aligned ] &&
    [ "$measured" = 1 ] &&
    [ "$forming" = 0 ] &&
    [ "$stable" = 0 ] &&
    [ "$drift_n" = 8 ] &&
    [ "$drift_status" = "$expected_drift" ] &&
    [ "$reply_equal" = 1 ] &&
    [ "$state_equal" = 1 ] || {
        printf '%s contract failed: pooled=%s/%s/%s drift=%s/%s counts=%s/%s/%s/%s/%s reply=%s state=%s\n' \
            "$cell" "$reliability_n" "$reliability_positives" \
            "$reliability_status" "$drift_n" "$drift_status" \
            "$measured" "$forming" "$stable" "$rising" "$falling" \
            "$reply_equal" "$state_equal" >&2
        exit 1
    }

    if [ "$expected_drift" = rising ]; then
        [ "$early_positives" = 0 ] &&
        [ "$recent_positives" = 4 ] &&
        [ "$rising" = 1 ] &&
        [ "$falling" = 0 ] || exit 1
    else
        [ "$early_positives" = 4 ] &&
        [ "$recent_positives" = 0 ] &&
        [ "$rising" = 0 ] &&
        [ "$falling" = 1 ] || exit 1
    fi

    on_sha="$(sha256_file "$group_dir/on.state")"
    off_sha="$(sha256_file "$group_dir/off.state")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$group" "$cohort" "$scored" "$positives" \
        "$reliability_status" "$drift_status" \
        "$early_positives" "$recent_positives" \
        "$return_shift" "$appetite_shift" "$gap_shift" \
        "$brier_shift" "$reply_equal" "$state_equal" \
        "$on_sha" "$off_sha" >> "$MATRIX"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$measured" "$forming" "$stable" \
        "$rising" "$falling" "$drift_cells" >> "$SURFACES"
done

awk -F '\t' '
    NR > 1 {
        cells++
        scored += $4
        positives += $5
        aligned += $6 == "aligned"
        rising += $7 == "rising"
        falling += $7 == "falling"
        reply_equal += $14
        state_equal += $15
    }
    END {
        print "cells\tscored\tpositives\taligned\trising\tfalling\treply_equal\tstate_equal"
        print cells "\t" scored "\t" positives "\t" aligned "\t" \
              rising "\t" falling "\t" reply_equal "\t" state_equal
    }
' "$MATRIX" > "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nsurfaces: %s\n' "$MATRIX" "$SURFACES"
