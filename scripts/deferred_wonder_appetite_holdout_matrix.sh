#!/usr/bin/env bash
# A.51: freeze candidacy, then let one fixed future accept or refute it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-holdout-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

PLAN="$OUT/plan.tsv"
MATRIX="$OUT/matrix.tsv"
printf 'case\texpected_overreach_rate\texpected_overreach_upper\texpected_missed_rate\texpected_missed_upper\texpected_status\n' \
    > "$PLAN"
printf 'confirmed\t0.125\t0.471\t0.125\t0.471\tconfirmed\n' >> "$PLAN"
printf 'motion-failed\t0.500\t0.785\t0.125\t0.471\tmotion-failed\n' >> "$PLAN"
printf 'restraint-failed\t0.125\t0.471\t0.500\t0.785\trestraint-failed\n' >> "$PLAN"
printf 'both-failed\t0.500\t0.785\t0.500\t0.785\tboth-failed\n' >> "$PLAN"
printf 'coverage-starved\t0.000\t0.242\t0.000\t0.000\tcoverage-starved\n' >> "$PLAN"

if [ "${LEO_APPETITE_HOLDOUT_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_holdout_fixture.c" -lm \
    -o "$OUT/holdout-fixture"
tail_size="$("$OUT/holdout-fixture" --tail-size)"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

holdout_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_holdout_dialogue_report.awk" \
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
                    for (j = 1; j <= 18; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

# The first real process pair proves arming is the only mutation: the same
# reply and body prefix, with one pending record only in the v23 tail.
mkdir -p "$OUT/arm"
"$OUT/holdout-fixture" "$OUT/arm/base.state" arm
cp "$OUT/arm/base.state" "$OUT/arm/on.state"
cp "$OUT/arm/base.state" "$OUT/arm/off.state"
seed=5101
prompt="The rain falls softly."
"$ROOT/leo" --load "$OUT/arm/on.state" --seed "$seed" \
    --respond "$prompt" --debug-field \
    --save "$OUT/arm/on.state" > "$OUT/arm/on.log" 2>&1
"$ROOT/leo" --load "$OUT/arm/off.state" --seed "$seed" \
    --respond "$prompt" --debug-field \
    --no-wonder-appetite-holdout \
    --save "$OUT/arm/off.state" > "$OUT/arm/off.log" 2>&1
arming="$(
    holdout_from_log "$OUT/arm/on.log" arm "$seed"
)"
[ -n "$arming" ] &&
[ -z "$(
    holdout_from_log "$OUT/arm/off.log" arm "$seed"
)" ] &&
[ "$(reply_from_log "$OUT/arm/on.log")" = \
  "$(reply_from_log "$OUT/arm/off.log")" ] &&
! cmp -s "$OUT/arm/on.state" "$OUT/arm/off.state" || {
    printf 'holdout arming did not remain an inert v23-tail mutation\n' >&2
    exit 1
}
IFS=$'\t' read -r _ _ budget min_arm ceiling pending confirmed \
    motion_failed restraint_failed both_failed coverage_starved \
    invalidated cells <<< "$arming"
[ "$budget" = 16 ] && [ "$min_arm" = 4 ] &&
[ "$ceiling" = 0.500 ] && [ "$pending" = 1 ] &&
[ "$confirmed" = 0 ] && [ "$motion_failed" = 0 ] &&
[ "$restraint_failed" = 0 ] && [ "$both_failed" = 0 ] &&
[ "$coverage_starved" = 0 ] && [ "$invalidated" = 0 ] || {
    printf 'holdout did not arm exactly one pending cell\n' >&2
    exit 1
}
state_size="$(wc -c < "$OUT/arm/on.state" | tr -d ' ')"
prefix_size=$((state_size - tail_size))
dd if="$OUT/arm/on.state" of="$OUT/arm/on.prefix" \
    bs=1 count="$prefix_size" 2>/dev/null
dd if="$OUT/arm/off.state" of="$OUT/arm/off.prefix" \
    bs=1 count="$prefix_size" 2>/dev/null
cmp -s "$OUT/arm/on.prefix" "$OUT/arm/off.prefix" || {
    printf 'holdout arming changed Leo outside the v23 tail\n' >&2
    exit 1
}

printf 'case\tattempts\tmatched\teligible\tabstained\tsupported\toverreach\tmissed\trestraint\tconfounded\tother\toverreach_rate\toverreach_upper\tmissed_rate\tmissed_upper\tstatus\treply_equal\tstate_equal\n' \
    > "$MATRIX"

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r case_name expected_over_rate \
        expected_over_upper expected_miss_rate expected_miss_upper \
        expected_status; do
    case_dir="$OUT/$case_name"
    mkdir -p "$case_dir"
    "$OUT/holdout-fixture" "$case_dir/base.state" "$case_name"
    cp "$case_dir/base.state" "$case_dir/on.state"
    cp "$case_dir/base.state" "$case_dir/off.state"
    seed=5102

    "$ROOT/leo" --load "$case_dir/on.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$case_dir/on.state" > "$case_dir/on.log" 2>&1
    "$ROOT/leo" --load "$case_dir/off.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --no-wonder-appetite-holdout \
        --save "$case_dir/off.state" > "$case_dir/off.log" 2>&1

    holdout="$(
        holdout_from_log "$case_dir/on.log" "$case_name" "$seed"
    )"
    [ -n "$holdout" ] || {
        printf '%s emitted no A.51 holdout ledger\n' \
            "$case_name" >&2
        exit 1
    }
    [ -z "$(
        holdout_from_log "$case_dir/off.log" "$case_name" "$seed"
    )" ] || {
        printf '%s holdout ablation remained visible\n' \
            "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ budget min_arm ceiling pending confirmed \
        motion_failed restraint_failed both_failed coverage_starved \
        invalidated cells <<< "$holdout"
    cell="$(cell_fields "$cells" u62-70)"
    [ -n "$cell" ] || {
        printf '%s lost its holdout cell\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r opened baseline attempts matched eligible abstained \
        supported overreach missed restraint confounded other over_rate \
        over_upper miss_rate miss_upper status seen <<< "$cell"

    reply_equal=0
    [ "$(reply_from_log "$case_dir/on.log")" = \
      "$(reply_from_log "$case_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$case_dir/on.state" "$case_dir/off.state" &&
        state_equal=1

    expected_confirmed=0
    expected_motion=0
    expected_restraint=0
    expected_both=0
    expected_starved=0
    case "$expected_status" in
        confirmed) expected_confirmed=1 ;;
        motion-failed) expected_motion=1 ;;
        restraint-failed) expected_restraint=1 ;;
        both-failed) expected_both=1 ;;
        coverage-starved) expected_starved=1 ;;
    esac

    [ "$budget" = 16 ] && [ "$min_arm" = 4 ] &&
    [ "$ceiling" = 0.500 ] && [ "$pending" = 0 ] &&
    [ "$confirmed" = "$expected_confirmed" ] &&
    [ "$motion_failed" = "$expected_motion" ] &&
    [ "$restraint_failed" = "$expected_restraint" ] &&
    [ "$both_failed" = "$expected_both" ] &&
    [ "$coverage_starved" = "$expected_starved" ] &&
    [ "$invalidated" = 0 ] &&
    [ "$attempts" = 16 ] &&
    [ "$over_rate" = "$expected_over_rate" ] &&
    [ "$over_upper" = "$expected_over_upper" ] &&
    [ "$miss_rate" = "$expected_miss_rate" ] &&
    [ "$miss_upper" = "$expected_miss_upper" ] &&
    [ "$status" = "$expected_status" ] &&
    [ "$reply_equal" = 1 ] && [ "$state_equal" = 1 ] || {
        printf '%s contract failed: attempts=%s bounds=%s/%s status=%s summary=%s/%s/%s/%s/%s reply=%s state=%s\n' \
            "$case_name" "$attempts" "$over_upper" "$miss_upper" \
            "$status" "$confirmed" "$motion_failed" \
            "$restraint_failed" "$both_failed" "$coverage_starved" \
            "$reply_equal" "$state_equal" >&2
        exit 1
    }

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "$attempts" "$matched" "$eligible" "$abstained" \
        "$supported" "$overreach" "$missed" "$restraint" \
        "$confounded" "$other" "$over_rate" "$over_upper" \
        "$miss_rate" "$miss_upper" "$status" "$reply_equal" \
        "$state_equal" >> "$MATRIX"
done

awk -F '\t' '
    NR > 1 {
        rows++
        replies += $17
        states += $18
    }
    END {
        print "cases\tarming_prefix_equal\treply_equal\tstate_equal"
        print rows "\t1\t" replies "\t" states
        if (rows != 5 || replies != 5 || states != 5)
            exit 1
    }
' "$MATRIX"
printf '\nmatrix: %s\n' "$MATRIX"
