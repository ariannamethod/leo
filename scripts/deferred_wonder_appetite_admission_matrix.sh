#!/usr/bin/env bash
# A.52: preserve why A.50 admitted a trial, without changing its life.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-admission-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

PLAN="$OUT/plan.tsv"
printf 'case\texpected_scored\texpected_eligible\texpected_abstained\texpected_overreach_upper\texpected_missed_upper\texpected_status\n' \
    > "$PLAN"
printf 'attested\t16\t8\t8\t0.471\t0.471\tattested\n' >> "$PLAN"

if [ "${LEO_APPETITE_ADMISSION_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_holdout_fixture.c" -lm \
    -o "$OUT/holdout-fixture"
admission_tail_size="$("$OUT/holdout-fixture" --admission-tail-size)"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

admission_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_admission_dialogue_report.awk" \
        "$1"
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
                    for (j = 1; j <= 15; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

"$OUT/holdout-fixture" "$OUT/base.state" arm
cp "$OUT/base.state" "$OUT/on.state"
cp "$OUT/base.state" "$OUT/off.state"
seed=5201
prompt="The rain falls softly."

"$ROOT/leo" --load "$OUT/on.state" --seed "$seed" \
    --respond "$prompt" --debug-field \
    --save "$OUT/on.state" > "$OUT/on.log" 2>&1
"$ROOT/leo" --load "$OUT/off.state" --seed "$seed" \
    --respond "$prompt" --debug-field \
    --no-wonder-appetite-admission \
    --save "$OUT/off.state" > "$OUT/off.log" 2>&1

admission="$(admission_from_log "$OUT/on.log" attested "$seed")"
[ -n "$admission" ] || {
    printf 'A.52 emitted no admission receipt\n' >&2
    exit 1
}
[ -z "$(admission_from_log "$OUT/off.log" ablated "$seed")" ] || {
    printf 'A.52 admission ablation remained visible\n' >&2
    exit 1
}
[ "$(reply_from_log "$OUT/on.log")" = \
  "$(reply_from_log "$OUT/off.log")" ] || {
    printf 'A.52 admission changed Leo reply\n' >&2
    exit 1
}

IFS=$'\t' read -r _ _ attested legacy cells <<< "$admission"
cell="$(cell_fields "$cells" u62-70)"
[ -n "$cell" ] || {
    printf 'A.52 lost its exact admission stratum\n' >&2
    exit 1
}
IFS=$'\t' read -r opened baseline scored eligible abstained supported \
    overreach missed restraint over_rate over_upper miss_rate miss_upper \
    status extra <<< "$cell"
[ -z "${extra:-}" ] &&
[ "$attested" = 1 ] && [ "$legacy" = 0 ] &&
[ "$opened" -gt 0 ] && [ "$baseline" -gt 0 ] &&
[ "$scored" = 16 ] && [ "$eligible" = 8 ] &&
[ "$abstained" = 8 ] && [ "$supported" = 7 ] &&
[ "$overreach" = 1 ] && [ "$missed" = 1 ] &&
[ "$restraint" = 7 ] && [ "$over_rate" = 0.125 ] &&
[ "$over_upper" = 0.471 ] && [ "$miss_rate" = 0.125 ] &&
[ "$miss_upper" = 0.471 ] && [ "$status" = attested ] || {
    printf 'A.52 admission geometry was not the exact A.50 warrant\n' >&2
    exit 1
}

! cmp -s "$OUT/on.state" "$OUT/off.state" || {
    printf 'A.52 failed to persist its admission receipt\n' >&2
    exit 1
}
state_size="$(wc -c < "$OUT/on.state" | tr -d ' ')"
prefix_size=$((state_size - admission_tail_size))
dd if="$OUT/on.state" of="$OUT/on.prefix" \
    bs=1 count="$prefix_size" 2>/dev/null
dd if="$OUT/off.state" of="$OUT/off.prefix" \
    bs=1 count="$prefix_size" 2>/dev/null
cmp -s "$OUT/on.prefix" "$OUT/off.prefix" || {
    printf 'A.52 changed Leo or the A.51 trial outside its own tail\n' >&2
    exit 1
}

printf 'case\treply_equal\tbody_and_trial_equal\tstate_equal\tattested\tlegacy\tcell\n'
printf 'attested\t1\t1\t0\t%s\t%s\t%s\n' \
    "$attested" "$legacy" "$cells"
printf '\nmatrix: %s\n' "$OUT"
