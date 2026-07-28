#!/usr/bin/env bash
# A.54: split a pooled present into adjacent early and recent regimes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-transport-chronology-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

PLAN="$OUT/plan.tsv"
printf 'case\texpected_post_settled\texpected_early_attempts\texpected_recent_attempts\texpected_early_eligible\texpected_early_abstained\texpected_recent_eligible\texpected_recent_abstained\texpected_early_overreach_upper\texpected_early_missed_upper\texpected_recent_overreach_upper\texpected_recent_missed_upper\texpected_aggregate_provisional\texpected_epoch_coverage_compatible\texpected_status\n' > "$PLAN"
printf 'chronology-provisional\t32\t16\t16\t8\t8\t8\t8\t0.471\t0.471\t0.471\t0.471\t1\t1\tprovisional\n' >> "$PLAN"
printf 'chronology-early-shift\t32\t16\t16\t8\t8\t8\t8\t0.694\t0.324\t0.324\t0.324\t1\t1\tearly-shifted\n' >> "$PLAN"
printf 'chronology-recent-shift\t32\t16\t16\t8\t8\t8\t8\t0.324\t0.324\t0.694\t0.324\t1\t1\trecent-shifted\n' >> "$PLAN"
printf 'chronology-both-shift\t32\t16\t16\t8\t8\t8\t8\t0.694\t0.324\t0.324\t0.694\t1\t1\tboth-shifted\n' >> "$PLAN"
printf 'chronology-ecology-shift\t32\t16\t16\t12\t4\t4\t12\t0.354\t0.490\t0.490\t0.354\t1\t0\tecology-shifted\n' >> "$PLAN"
printf 'chronology-aggregate-shift\t32\t16\t16\t8\t8\t8\t8\t0.785\t0.324\t0.785\t0.324\t0\t1\taggregate-shifted\n' >> "$PLAN"
printf 'chronology-observing\t31\t16\t15\t8\t8\t8\t7\t0.000\t0.000\t0.000\t0.000\t0\t0\tobserving\n' >> "$PLAN"
printf 'chronology-coverage-starved\t32\t16\t16\t16\t0\t8\t8\t0.000\t0.000\t0.000\t0.000\t0\t0\tcoverage-starved\n' >> "$PLAN"
printf 'chronology-incompatible\t1\t1\t0\t0\t0\t0\t0\t0.000\t0.000\t0.000\t0.000\t0\t0\tincompatible\n' >> "$PLAN"

if [ "${LEO_APPETITE_TRANSPORT_CHRONOLOGY_PLAN_ONLY:-0}" = 1 ]; then
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

chronology_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_transport_chronology_dialogue_report.awk" \
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
                    for (j = 1; j <= 51; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

MATRIX="$OUT/matrix.tsv"
printf 'case\tpost_settled\tearly_attempts\trecent_attempts\tearly_eligible\tearly_abstained\trecent_eligible\trecent_abstained\tearly_overreach_upper\tearly_missed_upper\trecent_overreach_upper\trecent_missed_upper\taggregate_provisional\tepoch_coverage_compatible\tstatus\tchronological\treply_equal\tstate_equal\n' > "$MATRIX"

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r case_name expected_post \
        expected_early_attempts expected_recent_attempts \
        expected_early_eligible expected_early_abstained \
        expected_recent_eligible expected_recent_abstained \
        expected_early_over expected_early_miss \
        expected_recent_over expected_recent_miss \
        expected_aggregate expected_epoch_coverage expected_status; do
    case_dir="$OUT/$case_name"
    mkdir -p "$case_dir"
    "$OUT/holdout-fixture" "$case_dir/base.state" "$case_name"
    cp "$case_dir/base.state" "$case_dir/on.state"
    cp "$case_dir/base.state" "$case_dir/off.state"
    seed=5401
    prompt="The rain falls softly."

    "$ROOT/leo" --load "$case_dir/on.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$case_dir/on.state" > "$case_dir/on.log" 2>&1
    "$ROOT/leo" --load "$case_dir/off.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --no-wonder-appetite-transport-chronology \
        --save "$case_dir/off.state" > "$case_dir/off.log" 2>&1

    chronology="$(
        chronology_from_log "$case_dir/on.log" "$case_name" "$seed"
    )"
    [ -n "$chronology" ] || {
        printf '%s emitted no A.54 chronology witness\n' \
            "$case_name" >&2
        exit 1
    }
    [ -z "$(
        chronology_from_log "$case_dir/off.log" "$case_name" "$seed"
    )" ] || {
        printf '%s chronology ablation remained visible\n' \
            "$case_name" >&2
        exit 1
    }

    IFS=$'\t' read -r _ _ epochs attempts min_arm ceiling \
        unattested pending refuted incompatible observing coverage_starved \
        aggregate_shifted early_shifted recent_shifted both_shifted \
        ecology_shifted provisional cells <<< "$chronology"
    cell="$(cell_fields "$cells" u62-70)"
    [ -n "$cell" ] || {
        printf '%s lost its chronology cell\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r after post_settled aggregate epoch_coverage \
        early_first early_last early_attempts early_exact \
        early_eligible early_abstained early_supported early_overreach \
        early_missed early_restraint early_confounded early_other \
        early_incompatible early_coverage early_lower early_upper \
        early_over_rate early_over_upper early_miss_rate early_miss_upper \
        early_motion early_restraint_bounded early_history \
        recent_first recent_last recent_attempts recent_exact \
        recent_eligible recent_abstained recent_supported recent_overreach \
        recent_missed recent_restraint recent_confounded recent_other \
        recent_incompatible recent_coverage recent_lower recent_upper \
        recent_over_rate recent_over_upper recent_miss_rate recent_miss_upper \
        recent_motion recent_restraint_bounded recent_history status extra \
        <<< "$cell"

    expected_unattested=0
    expected_pending=0
    expected_refuted=0
    expected_incompatible=0
    expected_observing=0
    expected_coverage_starved=0
    expected_aggregate_shifted=0
    expected_early_shifted=0
    expected_recent_shifted=0
    expected_both_shifted=0
    expected_ecology_shifted=0
    expected_provisional=0
    case "$expected_status" in
        incompatible) expected_incompatible=1 ;;
        observing) expected_observing=1 ;;
        coverage-starved) expected_coverage_starved=1 ;;
        aggregate-shifted) expected_aggregate_shifted=1 ;;
        early-shifted) expected_early_shifted=1 ;;
        recent-shifted) expected_recent_shifted=1 ;;
        both-shifted) expected_both_shifted=1 ;;
        ecology-shifted) expected_ecology_shifted=1 ;;
        provisional) expected_provisional=1 ;;
    esac

    chronological=0
    if [ "$recent_attempts" = 0 ]; then
        chronological=1
    elif [ "$early_last" -lt "$recent_first" ]; then
        chronological=1
    fi
    reply_equal=0
    [ "$(reply_from_log "$case_dir/on.log")" = \
      "$(reply_from_log "$case_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$case_dir/on.state" "$case_dir/off.state" &&
        state_equal=1

    [ -z "${extra:-}" ] &&
    [ "$epochs" = 2 ] && [ "$attempts" = 16 ] &&
    [ "$min_arm" = 4 ] && [ "$ceiling" = 0.500 ] &&
    [ "$unattested" = "$expected_unattested" ] &&
    [ "$pending" = "$expected_pending" ] &&
    [ "$refuted" = "$expected_refuted" ] &&
    [ "$incompatible" = "$expected_incompatible" ] &&
    [ "$observing" = "$expected_observing" ] &&
    [ "$coverage_starved" = "$expected_coverage_starved" ] &&
    [ "$aggregate_shifted" = "$expected_aggregate_shifted" ] &&
    [ "$early_shifted" = "$expected_early_shifted" ] &&
    [ "$recent_shifted" = "$expected_recent_shifted" ] &&
    [ "$both_shifted" = "$expected_both_shifted" ] &&
    [ "$ecology_shifted" = "$expected_ecology_shifted" ] &&
    [ "$provisional" = "$expected_provisional" ] &&
    [ "$after" -gt 0 ] &&
    [ "$post_settled" = "$expected_post" ] &&
    [ "$early_attempts" = "$expected_early_attempts" ] &&
    [ "$recent_attempts" = "$expected_recent_attempts" ] &&
    [ "$early_eligible" = "$expected_early_eligible" ] &&
    [ "$early_abstained" = "$expected_early_abstained" ] &&
    [ "$recent_eligible" = "$expected_recent_eligible" ] &&
    [ "$recent_abstained" = "$expected_recent_abstained" ] &&
    [ "$early_over_upper" = "$expected_early_over" ] &&
    [ "$early_miss_upper" = "$expected_early_miss" ] &&
    [ "$recent_over_upper" = "$expected_recent_over" ] &&
    [ "$recent_miss_upper" = "$expected_recent_miss" ] &&
    [ "$aggregate" = "$expected_aggregate" ] &&
    [ "$epoch_coverage" = "$expected_epoch_coverage" ] &&
    [ "$status" = "$expected_status" ] &&
    [ "$chronological" = 1 ] &&
    [ "$reply_equal" = 1 ] && [ "$state_equal" = 1 ] || {
        printf '%s chronology contract failed: post=%s attempts=%s/%s arms=%s/%s|%s/%s bounds=%s/%s|%s/%s aggregate=%s ecology=%s status=%s order=%s reply=%s state=%s\n' \
            "$case_name" "$post_settled" "$early_attempts" \
            "$recent_attempts" "$early_eligible" "$early_abstained" \
            "$recent_eligible" "$recent_abstained" \
            "$early_over_upper" "$early_miss_upper" \
            "$recent_over_upper" "$recent_miss_upper" \
            "$aggregate" "$epoch_coverage" "$status" \
            "$chronological" "$reply_equal" "$state_equal" >&2
        exit 1
    }

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "$post_settled" "$early_attempts" \
        "$recent_attempts" "$early_eligible" "$early_abstained" \
        "$recent_eligible" "$recent_abstained" \
        "$early_over_upper" "$early_miss_upper" \
        "$recent_over_upper" "$recent_miss_upper" \
        "$aggregate" "$epoch_coverage" "$status" "$chronological" \
        "$reply_equal" "$state_equal" >> "$MATRIX"
done

awk -F '\t' '
    NR > 1 {
        rows++
        order += $16
        replies += $17
        states += $18
    }
    END {
        print "cases\tchronological\treply_equal\tstate_equal"
        print rows "\t" order "\t" replies "\t" states
        if (rows != 9 || order != 9 ||
            replies != 9 || states != 9)
            exit 1
    }
' "$MATRIX"
printf '\nmatrix: %s\n' "$MATRIX"
