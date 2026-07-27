#!/usr/bin/env bash
# A.53: ask whether one historical result still describes Leo's current life.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-transport-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

PLAN="$OUT/plan.tsv"
printf 'case\texpected_exact\texpected_eligible\texpected_abstained\texpected_overreach_upper\texpected_missed_upper\texpected_motion_bounded\texpected_restraint_bounded\texpected_coverage_compatible\texpected_status\n' \
    > "$PLAN"
printf 'transport-provisional\t16\t8\t8\t0.471\t0.471\t1\t1\t1\tprovisional\n' >> "$PLAN"
printf 'transport-motion-shift\t16\t8\t8\t0.785\t0.471\t0\t1\t1\tshifted\n' >> "$PLAN"
printf 'transport-restraint-shift\t16\t8\t8\t0.471\t0.785\t1\t0\t1\tshifted\n' >> "$PLAN"
printf 'transport-both-shift\t16\t8\t8\t0.785\t0.785\t0\t0\t1\tshifted\n' >> "$PLAN"
printf 'transport-coverage-shift\t32\t24\t8\t0.202\t0.471\t1\t1\t0\tshifted\n' >> "$PLAN"
printf 'transport-holdout-coverage-shift\t32\t24\t8\t0.202\t0.471\t1\t1\t0\tshifted\n' >> "$PLAN"
printf 'transport-observing\t7\t7\t0\t0.000\t0.000\t0\t0\t0\tobserving\n' >> "$PLAN"
printf 'transport-incompatible\t0\t0\t0\t0.000\t0.000\t0\t0\t0\tincompatible\n' >> "$PLAN"

if [ "${LEO_APPETITE_TRANSPORT_PLAN_ONLY:-0}" = 1 ]; then
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

transport_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_transport_dialogue_report.awk" \
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
                    for (j = 1; j <= 29; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

MATRIX="$OUT/matrix.tsv"
printf 'case\tpost_settled\texact\teligible\tabstained\toverreach_upper\tmissed_upper\tmotion_bounded\trestraint_bounded\tcoverage_compatible\tstatus\treply_equal\tstate_equal\n' \
    > "$MATRIX"

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r case_name expected_exact \
        expected_eligible expected_abstained expected_over_upper \
        expected_miss_upper expected_motion expected_restraint \
        expected_coverage expected_status; do
    case_dir="$OUT/$case_name"
    mkdir -p "$case_dir"
    "$OUT/holdout-fixture" "$case_dir/base.state" "$case_name"
    cp "$case_dir/base.state" "$case_dir/on.state"
    cp "$case_dir/base.state" "$case_dir/off.state"
    seed=5301
    prompt="The rain falls softly."

    "$ROOT/leo" --load "$case_dir/on.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$case_dir/on.state" > "$case_dir/on.log" 2>&1
    "$ROOT/leo" --load "$case_dir/off.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --no-wonder-appetite-transport \
        --save "$case_dir/off.state" > "$case_dir/off.log" 2>&1

    transport="$(
        transport_from_log "$case_dir/on.log" "$case_name" "$seed"
    )"
    [ -n "$transport" ] || {
        printf '%s emitted no A.53 transport witness\n' \
            "$case_name" >&2
        exit 1
    }
    [ -z "$(
        transport_from_log "$case_dir/off.log" "$case_name" "$seed"
    )" ] || {
        printf '%s transport ablation remained visible\n' \
            "$case_name" >&2
        exit 1
    }

    IFS=$'\t' read -r _ _ min_arm ceiling unattested pending refuted \
        incompatible observing shifted provisional cells \
        <<< "$transport"
    cell="$(cell_fields "$cells" u62-70)"
    [ -n "$cell" ] || {
        printf '%s lost its transport cell\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r after post_settled exact eligible abstained \
        supported overreach missed restraint confounded other incompatible_n \
        admission_coverage admission_lower admission_upper holdout_coverage \
        holdout_lower holdout_upper current_coverage current_lower \
        current_upper over_rate over_upper miss_rate miss_upper \
        motion_bounded restraint_bounded coverage_compatible status extra \
        <<< "$cell"

    expected_unattested=0
    expected_pending=0
    expected_refuted=0
    expected_incompatible=0
    expected_observing=0
    expected_shifted=0
    expected_provisional=0
    case "$expected_status" in
        incompatible) expected_incompatible=1 ;;
        observing) expected_observing=1 ;;
        shifted) expected_shifted=1 ;;
        provisional) expected_provisional=1 ;;
    esac

    reply_equal=0
    [ "$(reply_from_log "$case_dir/on.log")" = \
      "$(reply_from_log "$case_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$case_dir/on.state" "$case_dir/off.state" &&
        state_equal=1

    [ -z "${extra:-}" ] &&
    [ "$min_arm" = 8 ] && [ "$ceiling" = 0.500 ] &&
    [ "$unattested" = "$expected_unattested" ] &&
    [ "$pending" = "$expected_pending" ] &&
    [ "$refuted" = "$expected_refuted" ] &&
    [ "$incompatible" = "$expected_incompatible" ] &&
    [ "$observing" = "$expected_observing" ] &&
    [ "$shifted" = "$expected_shifted" ] &&
    [ "$provisional" = "$expected_provisional" ] &&
    [ "$after" -gt 0 ] &&
    [ "$exact" = "$expected_exact" ] &&
    [ "$eligible" = "$expected_eligible" ] &&
    [ "$abstained" = "$expected_abstained" ] &&
    [ "$over_upper" = "$expected_over_upper" ] &&
    [ "$miss_upper" = "$expected_miss_upper" ] &&
    [ "$motion_bounded" = "$expected_motion" ] &&
    [ "$restraint_bounded" = "$expected_restraint" ] &&
    [ "$coverage_compatible" = "$expected_coverage" ] &&
    [ "$status" = "$expected_status" ] &&
    [ "$reply_equal" = 1 ] && [ "$state_equal" = 1 ] || {
        printf '%s transport contract failed: exact=%s arms=%s/%s bounds=%s/%s axes=%s/%s/%s status=%s reply=%s state=%s\n' \
            "$case_name" "$exact" "$eligible" "$abstained" \
            "$over_upper" "$miss_upper" "$motion_bounded" \
            "$restraint_bounded" "$coverage_compatible" "$status" \
            "$reply_equal" "$state_equal" >&2
        exit 1
    }

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "$post_settled" "$exact" "$eligible" \
        "$abstained" "$over_upper" "$miss_upper" \
        "$motion_bounded" "$restraint_bounded" \
        "$coverage_compatible" "$status" "$reply_equal" \
        "$state_equal" >> "$MATRIX"
done

awk -F '\t' '
    NR > 1 {
        rows++
        replies += $12
        states += $13
    }
    END {
        print "cases\treply_equal\tstate_equal"
        print rows "\t" replies "\t" states
        if (rows != 8 || replies != 8 || states != 8)
            exit 1
    }
' "$MATRIX"
printf '\nmatrix: %s\n' "$MATRIX"
