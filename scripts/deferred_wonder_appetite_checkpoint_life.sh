#!/usr/bin/env bash
# A.56: prove one naturally recurring Wonder cannot become a transport life.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-checkpoint-life-$STAMP}"
TARGET=suvin
TURNS=145

if [ "${LEO_APPETITE_CHECKPOINT_LIFE_PLAN_ONLY:-0}" = 1 ]; then
    printf 'case\ttarget\tturns\texpected_status\texpected_sources\texpected_max_source\n'
    printf 'one-wonder-cycle\t%s\t%d\tsource-starved\t1\t32\n' \
        "$TARGET" "$TURNS"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/on" "$OUT/off"

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_holdout_fixture.c" -lm \
    -o "$OUT/holdout-fixture"
"$OUT/holdout-fixture" "$OUT/base.state" confirmed
cp "$OUT/base.state" "$OUT/on/state"
cp "$OUT/base.state" "$OUT/off/state"

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
    awk -v scenario=one-wonder-cycle -v seed=9101 \
        -f "$ROOT/scripts/wonder_appetite_checkpoint_dialogue_report.awk" \
        "$1"
}

cell_values() {
    local cells="$1"
    printf '%s\n' "$cells" |
        awk '
            {
                n = split($0, items, /\|/)
                for (i = 1; i <= n; i++) {
                    split(items[i], pair, /:/)
                    if (pair[1] != "u62-70") continue
                    split(pair[2], values, /\//)
                    for (j = 1; j <= 51; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

reply_equal=0
for turn in $(seq 1 "$TURNS"); do
    if [ "$turn" -eq 1 ]; then
        prompt="Does $TARGET feel like bright sun or cold winter?"
    elif [ $(( (turn - 2) % 4 )) -eq 0 ]; then
        prompt="Bright sun. Cold winter."
    else
        prompt="I do not know."
    fi
    seed=$((9100 + turn))
    "$ROOT/leo" --load "$OUT/on/state" --seed "$seed" \
        --respond "$prompt" --debug-field --save "$OUT/on/state" \
        > "$OUT/on/turn-$turn.log" 2>&1
    "$ROOT/leo" --load "$OUT/off/state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-checkpoint --save "$OUT/off/state" \
        > "$OUT/off/turn-$turn.log" 2>&1
    [ "$(reply_from_log "$OUT/on/turn-$turn.log")" = \
      "$(reply_from_log "$OUT/off/turn-$turn.log")" ] || {
        printf 'checkpoint writer changed Leo reply at turn %d\n' \
            "$turn" >&2
        exit 1
    }
    reply_equal=$((reply_equal + 1))
done

report="$(report_from_log "$OUT/on/turn-$TURNS.log")"
[ -n "$report" ] || {
    printf 'natural life emitted no checkpoint receipt\n' >&2
    exit 1
}
[ -z "$(report_from_log "$OUT/off/turn-$TURNS.log")" ] || {
    printf 'checkpoint receipt survived writer ablation\n' >&2
    exit 1
}
IFS=$'\t' read -r _ _ budget epochs history active terminal blocked \
    checkpoint_cells one stable emerging persistent recovered \
    insufficient incompatible sequence_cells <<< "$report"
cell="$(cell_values "$checkpoint_cells")"
[ -n "$cell" ] || {
    printf 'natural life lost its u62-70 lane\n' >&2
    exit 1
}
IFS=$'\t' read -r next_after blocked_cell active_after active_through \
    active_attempts active_status active_sources active_max \
    active_early_sources active_early_max active_recent_sources \
    active_recent_max n first_after first_through first_status \
    first_sources first_max first_early_sources first_early_max \
    first_recent_sources first_recent_max \
    _ _ _ _ _ _ _ _ _ _ \
    _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ extra <<< "$cell"

sequence_status="$(
    printf '%s\n' "$sequence_cells" |
        awk -F '[:/]' '$1 == "u62-70" { print $6 }'
)"
checkpoint_tail="$("$OUT/holdout-fixture" --checkpoint-tail-size)"
state_size="$(wc -c < "$OUT/on/state" | tr -d ' ')"
prefix_size=$((state_size - checkpoint_tail))
prefix_equal=0
[ "$prefix_size" -gt 0 ] &&
    cmp -s -n "$prefix_size" "$OUT/on/state" "$OUT/off/state" &&
    prefix_equal=1
state_distinct=0
cmp -s "$OUT/on/state" "$OUT/off/state" ||
    state_distinct=1

[ -z "${extra:-}" ] &&
[ "$budget" = 32 ] && [ "$epochs" = 2 ] && [ "$history" = 2 ] &&
[ "$terminal" = 1 ] && [ "$blocked" = 0 ] &&
[ "$blocked_cell" = 0 ] && [ "$n" = 1 ] &&
[ "$first_status" = source-starved ] &&
[ "$first_sources" = 1 ] && [ "$first_max" = 32 ] &&
[ "$first_early_sources" = 1 ] && [ "$first_early_max" = 16 ] &&
[ "$first_recent_sources" = 1 ] && [ "$first_recent_max" = 16 ] &&
[ "$insufficient" = 1 ] && [ "$sequence_status" = insufficient ] &&
[ "$reply_equal" = "$TURNS" ] && [ "$prefix_equal" = 1 ] &&
[ "$state_distinct" = 1 ] || {
    printf 'natural checkpoint contract failed: terminal=%s n=%s status=%s sources=%s/%s epochs=%s/%s|%s/%s sequence=%s replies=%s prefix=%s distinct=%s\n' \
        "$terminal" "$n" "$first_status" "$first_sources" \
        "$first_max" "$first_early_sources" "$first_early_max" \
        "$first_recent_sources" "$first_recent_max" "$sequence_status" \
        "$reply_equal" "$prefix_equal" "$state_distinct" >&2
    exit 1
}

MATRIX="$OUT/matrix.tsv"
printf 'case\ttarget\tturns\tterminal\tstatus\tsources\tmax_source\tearly_sources\tearly_max_source\trecent_sources\trecent_max_source\treply_equal\tbody_prefix_equal\tcheckpoint_tail_distinct\n' > "$MATRIX"
printf 'one-wonder-cycle\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$TARGET" "$TURNS" "$terminal" "$first_status" \
    "$first_sources" "$first_max" "$first_early_sources" \
    "$first_early_max" "$first_recent_sources" "$first_recent_max" \
    "$reply_equal" "$prefix_equal" "$state_distinct" >> "$MATRIX"

cat "$MATRIX"
printf '\nfinal receipt: %s/on/turn-%d.log\n' "$OUT" "$TURNS"
