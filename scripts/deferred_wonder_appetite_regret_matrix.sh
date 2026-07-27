#!/usr/bin/env bash
# A.49: keep the costs of motion and restraint on separate axes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-regret-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

PLAN="$OUT/plan.tsv"
MATRIX="$OUT/matrix.tsv"
printf 'case\texpected_supported\texpected_overreach\texpected_missed\texpected_restraint\texpected_overreach_axis\texpected_missed_axis\n' \
    > "$PLAN"
printf 'motion-heavy\t5\t3\t3\t5\t0.375\t0.375\n' >> "$PLAN"
printf 'restraint-heavy\t7\t1\t5\t3\t0.125\t0.625\n' >> "$PLAN"

if [ "${LEO_APPETITE_REGRET_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_regret_fixture.c" -lm \
    -o "$OUT/regret-fixture"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

regret_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_regret_dialogue_report.awk" \
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

printf 'case\tscored\teligible\tabstained\tsupported\toverreach\tmissed\trestraint\tcoverage\toverreach_axis\tmissed_axis\tpaired_status\teligible_status\tabstention_status\treply_equal\tstate_equal\ton_sha256\toff_sha256\n' \
    > "$MATRIX"

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r case_name expected_supported expected_overreach \
        expected_missed expected_restraint expected_over_axis expected_miss_axis; do
    case_dir="$OUT/$case_name"
    mkdir -p "$case_dir"
    "$OUT/regret-fixture" "$case_dir/base.state" "$case_name"
    cp "$case_dir/base.state" "$case_dir/on.state"
    cp "$case_dir/base.state" "$case_dir/off.state"
    seed=4901
    prompt="The rain falls softly."

    "$ROOT/leo" --load "$case_dir/on.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$case_dir/on.state" > "$case_dir/on.log" 2>&1
    "$ROOT/leo" --load "$case_dir/off.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --no-wonder-appetite-regret \
        --save "$case_dir/off.state" > "$case_dir/off.log" 2>&1

    regret="$(regret_from_log "$case_dir/on.log" "$case_name" "$seed")"
    [ -n "$regret" ] || {
        printf '%s emitted no A.49 regret surface\n' "$case_name" >&2
        exit 1
    }
    [ -z "$(regret_from_log "$case_dir/off.log" "$case_name" "$seed")" ] || {
        printf '%s regret ablation remained visible\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ scored eligible abstained supported overreach \
        missed restraint policy_forming policy_uncalibrated policy_drifting \
        pending confounded legacy none coverage over_axis miss_axis \
        forming_cells eligible_cells abstention_cells paired_cells cells \
        <<< "$regret"

    paired="$(cell_fields "$cells" u62-70)"
    eligible_only="$(cell_fields "$cells" s80-90)"
    abstention_only="$(cell_fields "$cells" u80-90)"
    [ -n "$paired" ] && [ -n "$eligible_only" ] &&
    [ -n "$abstention_only" ] || {
        printf '%s lost a stratified arm\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ paired_status \
        <<< "$paired"
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ eligible_status \
        <<< "$eligible_only"
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ abstention_status \
        <<< "$abstention_only"

    reply_equal=0
    [ "$(reply_from_log "$case_dir/on.log")" = \
      "$(reply_from_log "$case_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$case_dir/on.state" "$case_dir/off.state" &&
        state_equal=1

    over_rate="${over_axis%%/*}"
    miss_rate="${miss_axis%%/*}"
    [ "$scored" = 16 ] &&
    [ "$eligible" = 8 ] &&
    [ "$abstained" = 8 ] &&
    [ "$supported" = "$expected_supported" ] &&
    [ "$overreach" = "$expected_overreach" ] &&
    [ "$missed" = "$expected_missed" ] &&
    [ "$restraint" = "$expected_restraint" ] &&
    [ "$policy_forming" = 4 ] &&
    [ "$policy_uncalibrated" = 0 ] &&
    [ "$policy_drifting" = 4 ] &&
    [ "$pending" = 0 ] &&
    [ "$confounded" = 0 ] &&
    [ "$legacy" = 0 ] &&
    [ "$none" = 0 ] &&
    [ "$coverage" = 0.500 ] &&
    [ "$over_rate" = "$expected_over_axis" ] &&
    [ "$miss_rate" = "$expected_miss_axis" ] &&
    [ "$forming_cells" = 0 ] &&
    [ "$eligible_cells" = 1 ] &&
    [ "$abstention_cells" = 1 ] &&
    [ "$paired_cells" = 1 ] &&
    [ "$paired_status" = paired ] &&
    [ "$eligible_status" = eligible-observed ] &&
    [ "$abstention_status" = abstention-observed ] &&
    [ "$reply_equal" = 1 ] &&
    [ "$state_equal" = 1 ] || {
        printf '%s contract failed: scored=%s arms=%s/%s outcomes=%s/%s/%s/%s axes=%s/%s statuses=%s/%s/%s reply=%s state=%s\n' \
            "$case_name" "$scored" "$eligible" "$abstained" \
            "$supported" "$overreach" "$missed" "$restraint" \
            "$over_axis" "$miss_axis" "$paired_status" \
            "$eligible_status" "$abstention_status" \
            "$reply_equal" "$state_equal" >&2
        exit 1
    }

    on_sha="$(shasum -a 256 "$case_dir/on.state" | awk '{print $1}')"
    off_sha="$(shasum -a 256 "$case_dir/off.state" | awk '{print $1}')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "$scored" "$eligible" "$abstained" \
        "$supported" "$overreach" "$missed" "$restraint" \
        "$coverage" "$over_axis" "$miss_axis" "$paired_status" \
        "$eligible_status" "$abstention_status" "$reply_equal" \
        "$state_equal" "$on_sha" "$off_sha" >> "$MATRIX"
done

awk -F '\t' '
    NR > 1 {
        rows++
        replies += $15
        states += $16
    }
    END {
        print "cases\treply_equal\tstate_equal"
        print rows "\t" replies "\t" states
        if (rows != 2 || replies != 2 || states != 2)
            exit 1
    }
' "$MATRIX"
printf '\nmatrix: %s\n' "$MATRIX"
