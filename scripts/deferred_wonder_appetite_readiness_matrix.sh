#!/usr/bin/env bash
# A.50: candidacy requires both errors to be independently bounded.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-readiness-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

PLAN="$OUT/plan.tsv"
MATRIX="$OUT/matrix.tsv"
printf 'case\texpected_overreach_rate\texpected_overreach_upper\texpected_missed_rate\texpected_missed_upper\texpected_status\n' \
    > "$PLAN"
printf 'candidate\t0.125\t0.471\t0.125\t0.471\tcandidate\n' >> "$PLAN"
printf 'motion-unbounded\t0.500\t0.785\t0.125\t0.471\tmotion-unbounded\n' >> "$PLAN"
printf 'restraint-unbounded\t0.125\t0.471\t0.500\t0.785\trestraint-unbounded\n' >> "$PLAN"
printf 'both-unbounded\t0.500\t0.785\t0.500\t0.785\tboth-unbounded\n' >> "$PLAN"

if [ "${LEO_APPETITE_READINESS_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_readiness_fixture.c" -lm \
    -o "$OUT/readiness-fixture"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

readiness_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_readiness_dialogue_report.awk" \
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
                    for (j = 1; j <= 11; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

printf 'case\tscored\teligible\tabstained\tcoverage\toverreach_rate\toverreach_upper\tmissed_rate\tmissed_upper\tmotion_headroom\trestraint_headroom\tstatus\treply_equal\tstate_equal\ton_sha256\toff_sha256\n' \
    > "$MATRIX"

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r case_name expected_over_rate \
        expected_over_upper expected_miss_rate expected_miss_upper \
        expected_status; do
    case_dir="$OUT/$case_name"
    mkdir -p "$case_dir"
    "$OUT/readiness-fixture" "$case_dir/base.state" "$case_name"
    cp "$case_dir/base.state" "$case_dir/on.state"
    cp "$case_dir/base.state" "$case_dir/off.state"
    seed=5001
    prompt="The rain falls softly."

    "$ROOT/leo" --load "$case_dir/on.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$case_dir/on.state" > "$case_dir/on.log" 2>&1
    "$ROOT/leo" --load "$case_dir/off.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --no-wonder-appetite-readiness \
        --save "$case_dir/off.state" > "$case_dir/off.log" 2>&1

    readiness="$(
        readiness_from_log "$case_dir/on.log" "$case_name" "$seed"
    )"
    [ -n "$readiness" ] || {
        printf '%s emitted no A.50 readiness frontier\n' \
            "$case_name" >&2
        exit 1
    }
    [ -z "$(
        readiness_from_log "$case_dir/off.log" "$case_name" "$seed"
    )" ] || {
        printf '%s readiness ablation remained visible\n' \
            "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ ceiling min_arm forming unpaired \
        observing motion_unbounded restraint_unbounded both_unbounded \
        candidate cells <<< "$readiness"

    cell="$(cell_fields "$cells" u62-70)"
    [ -n "$cell" ] || {
        printf '%s lost its readiness cell\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r scored eligible abstained coverage over_rate \
        over_upper miss_rate miss_upper motion_headroom \
        restraint_headroom status <<< "$cell"

    reply_equal=0
    [ "$(reply_from_log "$case_dir/on.log")" = \
      "$(reply_from_log "$case_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$case_dir/on.state" "$case_dir/off.state" &&
        state_equal=1

    expected_motion=0
    expected_restraint=0
    expected_both=0
    expected_candidate=0
    case "$expected_status" in
        motion-unbounded) expected_motion=1 ;;
        restraint-unbounded) expected_restraint=1 ;;
        both-unbounded) expected_both=1 ;;
        candidate) expected_candidate=1 ;;
    esac

    [ "$ceiling" = 0.500 ] &&
    [ "$min_arm" = 8 ] &&
    [ "$forming" = 0 ] &&
    [ "$unpaired" = 0 ] &&
    [ "$observing" = 0 ] &&
    [ "$motion_unbounded" = "$expected_motion" ] &&
    [ "$restraint_unbounded" = "$expected_restraint" ] &&
    [ "$both_unbounded" = "$expected_both" ] &&
    [ "$candidate" = "$expected_candidate" ] &&
    [ "$scored" = 16 ] &&
    [ "$eligible" = 8 ] &&
    [ "$abstained" = 8 ] &&
    [ "$coverage" = 0.500 ] &&
    [ "$over_rate" = "$expected_over_rate" ] &&
    [ "$over_upper" = "$expected_over_upper" ] &&
    [ "$miss_rate" = "$expected_miss_rate" ] &&
    [ "$miss_upper" = "$expected_miss_upper" ] &&
    [ "$status" = "$expected_status" ] &&
    [ "$reply_equal" = 1 ] &&
    [ "$state_equal" = 1 ] || {
        printf '%s contract failed: bounds=%s/%s status=%s counts=%s/%s/%s/%s reply=%s state=%s\n' \
            "$case_name" "$over_upper" "$miss_upper" "$status" \
            "$motion_unbounded" "$restraint_unbounded" \
            "$both_unbounded" "$candidate" \
            "$reply_equal" "$state_equal" >&2
        exit 1
    }

    on_sha="$(shasum -a 256 "$case_dir/on.state" | awk '{print $1}')"
    off_sha="$(shasum -a 256 "$case_dir/off.state" | awk '{print $1}')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "$scored" "$eligible" "$abstained" \
        "$coverage" "$over_rate" "$over_upper" "$miss_rate" \
        "$miss_upper" "$motion_headroom" "$restraint_headroom" \
        "$status" "$reply_equal" "$state_equal" "$on_sha" "$off_sha" \
        >> "$MATRIX"
done

awk -F '\t' '
    NR > 1 {
        rows++
        replies += $13
        states += $14
    }
    END {
        print "cases\treply_equal\tstate_equal"
        print rows "\t" replies "\t" states
        if (rows != 4 || replies != 4 || states != 4)
            exit 1
    }
' "$MATRIX"
printf '\nmatrix: %s\n' "$MATRIX"
