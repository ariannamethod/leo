#!/usr/bin/env bash
# A.56: persist non-overlapping, source-aware transport lives.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-checkpoint-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

PLAN="$OUT/plan.tsv"
printf 'case\texpected_n\texpected_recent\texpected_sequence\n' > "$PLAN"
printf 'checkpoint-one\t1\tprovisional\tone\n' >> "$PLAN"
printf 'checkpoint-stable\t2\tprovisional\tstable-provisional\n' >> "$PLAN"
printf 'checkpoint-emerging\t2\tearly-shifted\temerging-shift\n' >> "$PLAN"
printf 'checkpoint-persistent\t2\trecent-shifted\tpersistent-shift\n' >> "$PLAN"
printf 'checkpoint-recovered\t2\tprovisional\trecovered\n' >> "$PLAN"
printf 'checkpoint-insufficient\t2\tcoverage-starved\tinsufficient\n' >> "$PLAN"
printf 'checkpoint-source-starved\t1\tsource-starved\tinsufficient\n' >> "$PLAN"
printf 'checkpoint-incompatible\t1\tincompatible\tincompatible\n' >> "$PLAN"
printf 'checkpoint-pending\t0\tpending\tempty\n' >> "$PLAN"

if [ "${LEO_APPETITE_CHECKPOINT_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_holdout_fixture.c" -lm \
    -o "$OUT/holdout-fixture"

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
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_checkpoint_dialogue_report.awk" \
        "$1"
}

cell_values() {
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
                    for (j = 1; j <= 51; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

sequence_status() {
    local cells="$1"
    local wanted="$2"
    if [ -z "$cells" ]; then
        printf 'empty\n'
        return
    fi
    printf '%s\n' "$cells" |
        awk -v wanted="$wanted" '
            {
                n = split($0, items, /\|/)
                for (i = 1; i <= n; i++) {
                    split(items[i], pair, /:/)
                    if (pair[1] != wanted) continue
                    split(pair[2], values, /\//)
                    print values[5]
                    exit
                }
            }
        '
}

# Writer isolation: identical evidence with the organ on/off may differ only
# in the checkpoint-and-later fixed tail, and the distinct states must still
# speak identically. v27 appends the passive state swarm after the v26 ledger.
"$OUT/holdout-fixture" "$OUT/writer-on.state" checkpoint-one
"$OUT/holdout-fixture" "$OUT/writer-off.state" checkpoint-ablated
checkpoint_tail="$("$OUT/holdout-fixture" --checkpoint-tail-size)"
writer_size="$(wc -c < "$OUT/writer-on.state" | tr -d ' ')"
writer_prefix=$((writer_size - checkpoint_tail))
[ "$writer_prefix" -gt 0 ] &&
    cmp -s -n "$writer_prefix" \
        "$OUT/writer-on.state" "$OUT/writer-off.state" &&
    ! cmp -s "$OUT/writer-on.state" "$OUT/writer-off.state" || {
        printf 'checkpoint writer escaped its checkpoint tail\n' >&2
        exit 1
    }
for side in on off; do
    cp "$OUT/writer-$side.state" "$OUT/writer-$side-run.state"
    "$ROOT/leo" --load "$OUT/writer-$side-run.state" \
        --seed 5599 --respond "The rain falls softly." \
        --no-wonder-appetite-calibration \
        --save "$OUT/writer-$side-run.state" \
        > "$OUT/writer-$side.log" 2>&1
done
writer_reply_equal=0
[ "$(reply_from_log "$OUT/writer-on.log")" = \
  "$(reply_from_log "$OUT/writer-off.log")" ] &&
    writer_reply_equal=1
[ "$writer_reply_equal" = 1 ] || {
    printf 'checkpoint-only state changed Leo voice\n' >&2
    exit 1
}

MATRIX="$OUT/matrix.tsv"
printf 'case\tn\tactive_attempts\trecent\tsequence\tsources\tmax_source\tearly_sources\tearly_max_source\trecent_sources\trecent_max_source\tchronological\treply_equal\tstate_equal\n' > "$MATRIX"

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r case_name expected_n \
        expected_recent expected_sequence; do
    case_dir="$OUT/$case_name"
    mkdir -p "$case_dir"
    "$OUT/holdout-fixture" "$case_dir/base.state" "$case_name"
    cp "$case_dir/base.state" "$case_dir/on.state"
    cp "$case_dir/base.state" "$case_dir/off.state"
    seed=5501
    prompt="The rain falls softly."

    "$ROOT/leo" --load "$case_dir/on.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$case_dir/on.state" > "$case_dir/on.log" 2>&1
    "$ROOT/leo" --load "$case_dir/off.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --no-wonder-appetite-checkpoint \
        --save "$case_dir/off.state" > "$case_dir/off.log" 2>&1

    report="$(report_from_log "$case_dir/on.log" "$case_name" "$seed")"
    [ -n "$report" ] || {
        printf '%s emitted no A.56 checkpoint witness\n' \
            "$case_name" >&2
        exit 1
    }
    [ -z "$(report_from_log \
        "$case_dir/off.log" "$case_name" "$seed")" ] || {
        printf '%s checkpoint ablation remained visible\n' \
            "$case_name" >&2
        exit 1
    }

    IFS=$'\t' read -r _ _ budget epochs history active terminal \
        blocked checkpoint_cells one stable emerging persistent \
        recovered insufficient incompatible sequence_cells <<< "$report"
    cell="$(cell_values "$checkpoint_cells" u62-70)"
    [ -n "$cell" ] || {
        printf '%s lost its checkpoint cell\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r next_after blocked_cell active_after \
        active_through active_attempts active_status \
        active_sources active_max active_early_sources active_early_max \
        active_recent_sources active_recent_max n \
        first_after first_through first_status \
        first_sources first_max first_early_sources first_early_max \
        first_recent_sources first_recent_max \
        _ _ _ _ _ _ _ _ _ _ \
        second_after second_through second_status \
        second_sources second_max second_early_sources second_early_max \
        second_recent_sources second_recent_max \
        _ _ _ _ _ _ _ _ _ _ extra <<< "$cell"

    if [ "$n" = 0 ]; then
        recent="$active_status"
        sources="$active_sources"
        max_source="$active_max"
        early_sources="$active_early_sources"
        early_max="$active_early_max"
        recent_sources="$active_recent_sources"
        recent_max="$active_recent_max"
    elif [ "$n" = 1 ]; then
        recent="$first_status"
        sources="$first_sources"
        max_source="$first_max"
        early_sources="$first_early_sources"
        early_max="$first_early_max"
        recent_sources="$first_recent_sources"
        recent_max="$first_recent_max"
    else
        recent="$second_status"
        sources="$second_sources"
        max_source="$second_max"
        early_sources="$second_early_sources"
        early_max="$second_early_max"
        recent_sources="$second_recent_sources"
        recent_max="$second_recent_max"
    fi
    actual_sequence="$(
        sequence_status "$sequence_cells" u62-70
    )"
    chronological=1
    if [ "$n" = 2 ] &&
       { [ "$first_through" != "$second_after" ] ||
         [ "$second_through" -le "$second_after" ]; }; then
        chronological=0
    fi
    reply_equal=0
    [ "$(reply_from_log "$case_dir/on.log")" = \
      "$(reply_from_log "$case_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$case_dir/on.state" "$case_dir/off.state" &&
        state_equal=1

    expected_active=0
    expected_terminal="$expected_n"
    expected_blocked=0
    if [ "$case_name" = checkpoint-pending ]; then
        expected_active=1
        expected_terminal=0
    fi
    if [ "$case_name" = checkpoint-incompatible ]; then
        expected_blocked=1
    fi
    expected_sources=32
    expected_max=1
    expected_early_sources=16
    expected_early_max=1
    expected_recent_sources=16
    expected_recent_max=1
    if [ "$case_name" = checkpoint-pending ]; then
        expected_sources=31
        expected_recent_sources=15
    elif [ "$case_name" = checkpoint-incompatible ]; then
        expected_sources=1
        expected_early_sources=1
        expected_recent_sources=0
        expected_recent_max=0
    elif [ "$case_name" = checkpoint-source-starved ]; then
        expected_sources=1
        expected_max=32
        expected_early_sources=1
        expected_early_max=16
        expected_recent_sources=1
        expected_recent_max=16
    fi

    [ -z "${extra:-}" ] &&
    [ "$budget" = 32 ] && [ "$epochs" = 2 ] &&
    [ "$history" = 2 ] &&
    [ "$active" = "$expected_active" ] &&
    [ "$terminal" = "$expected_terminal" ] &&
    [ "$blocked" = "$expected_blocked" ] &&
    [ "$blocked_cell" = "$expected_blocked" ] &&
    [ "$n" = "$expected_n" ] &&
    [ "$recent" = "$expected_recent" ] &&
    [ "$actual_sequence" = "$expected_sequence" ] &&
    [ "$sources" = "$expected_sources" ] &&
    [ "$max_source" = "$expected_max" ] &&
    [ "$early_sources" = "$expected_early_sources" ] &&
    [ "$early_max" = "$expected_early_max" ] &&
    [ "$recent_sources" = "$expected_recent_sources" ] &&
    [ "$recent_max" = "$expected_recent_max" ] &&
    [ "$chronological" = 1 ] &&
    [ "$reply_equal" = 1 ] && [ "$state_equal" = 1 ] || {
        printf '%s checkpoint contract failed: n=%s active=%s/%s recent=%s sequence=%s chronological=%s reply=%s state=%s\n' \
            "$case_name" "$n" "$active" "$active_attempts" \
            "$recent" "$actual_sequence" "$chronological" \
            "$reply_equal" "$state_equal" >&2
        exit 1
    }

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "$n" "$active_attempts" "$recent" \
        "$actual_sequence" "$sources" "$max_source" \
        "$early_sources" "$early_max" "$recent_sources" "$recent_max" \
        "$chronological" "$reply_equal" "$state_equal" >> "$MATRIX"
done

awk -F '\t' -v writer_reply_equal="$writer_reply_equal" '
    NR > 1 {
        rows++
        chronology += $12
        replies += $13
        states += $14
    }
    END {
        print "cases\tchronological\treply_equal\tstate_equal\twriter_prefix_equal\twriter_reply_equal"
        print rows "\t" chronology "\t" replies "\t" states \
              "\t1\t" writer_reply_equal
        if (rows != 9 || chronology != 9 ||
            replies != 9 || states != 9 ||
            writer_reply_equal != 1)
            exit 1
    }
' "$MATRIX"
printf '\nmatrix: %s\n' "$MATRIX"
