#!/usr/bin/env bash
# A.48: a frozen abstention decision is judged without gaining a voice.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-policy-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

PLAN="$OUT/plan.tsv"
MATRIX="$OUT/matrix.tsv"
printf 'case\thistory\tfuture\texpected_policy\texpected_result\n' > "$PLAN"
printf 'stable-return\tstable\tsustained\teligible\tsupported\n' >> "$PLAN"
printf 'stable-fade\tstable\tfaded\teligible\toverreach\n' >> "$PLAN"
printf 'moving-return\trising\tsustained\tdrifting\tmissed\n' >> "$PLAN"
printf 'moving-fade\trising\tfaded\tdrifting\trestraint\n' >> "$PLAN"

if [ "${LEO_APPETITE_POLICY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_policy_fixture.c" -lm \
    -o "$OUT/policy-fixture"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

policy_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/wonder_appetite_policy_dialogue_report.awk" \
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
                    for (j = 1; j <= 8; j++)
                        printf "%s%s", (j == 1 ? "" : "\t"), values[j]
                    printf "\n"
                    exit
                }
            }
        '
}

printf 'case\thistory\tfuture\tpolicy\tresult\tn\treliability\tdrift\treply_equal\tstate_equal\ton_sha256\toff_sha256\n' \
    > "$MATRIX"

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r case_name history future expected_policy expected_result; do
    case_dir="$OUT/$case_name"
    mkdir -p "$case_dir"
    "$OUT/policy-fixture" "$case_dir/base.state" "$history" "$future"
    cp "$case_dir/base.state" "$case_dir/on.state"
    cp "$case_dir/base.state" "$case_dir/off.state"
    seed=4801
    prompt="The rain falls softly."

    "$ROOT/leo" --load "$case_dir/on.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --save "$case_dir/on.state" > "$case_dir/on.log" 2>&1
    "$ROOT/leo" --load "$case_dir/off.state" --seed "$seed" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --no-wonder-appetite-policy \
        --save "$case_dir/off.state" > "$case_dir/off.log" 2>&1

    policy="$(policy_from_log "$case_dir/on.log" "$case_name" "$seed")"
    [ -n "$policy" ] || {
        printf '%s emitted no A.48 policy surface\n' "$case_name" >&2
        exit 1
    }
    [ -z "$(policy_from_log "$case_dir/off.log" "$case_name" "$seed")" ] || {
        printf '%s policy ablation remained visible\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ entries \
        <<< "$policy"
    fields="$(entry_fields "$entries" policy)"
    [ -n "$fields" ] || {
        printf '%s lost its frozen policy receipt\n' "$case_name" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ _ n reliability drift observed_policy result \
        <<< "$fields"

    reply_equal=0
    [ "$(reply_from_log "$case_dir/on.log")" = \
      "$(reply_from_log "$case_dir/off.log")" ] &&
        reply_equal=1
    state_equal=0
    cmp -s "$case_dir/on.state" "$case_dir/off.state" &&
        state_equal=1
    [ "$n" = 8 ] &&
    [ "$reliability" = aligned ] &&
    [ "$observed_policy" = "$expected_policy" ] &&
    [ "$result" = "$expected_result" ] &&
    [ "$reply_equal" = 1 ] &&
    [ "$state_equal" = 1 ] || {
        printf '%s contract failed: n=%s reliability=%s drift=%s policy=%s result=%s reply=%s state=%s\n' \
            "$case_name" "$n" "$reliability" "$drift" \
            "$observed_policy" "$result" "$reply_equal" \
            "$state_equal" >&2
        exit 1
    }

    on_sha="$(shasum -a 256 "$case_dir/on.state" | awk '{print $1}')"
    off_sha="$(shasum -a 256 "$case_dir/off.state" | awk '{print $1}')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "$history" "$future" "$observed_policy" \
        "$result" "$n" "$reliability" "$drift" "$reply_equal" \
        "$state_equal" "$on_sha" "$off_sha" >> "$MATRIX"
done

awk -F '\t' '
    NR > 1 {
        rows++
        eligible += $4 == "eligible"
        drifting += $4 == "drifting"
        replies += $9
        states += $10
    }
    END {
        print "cases\teligible\tdrifting\treply_equal\tstate_equal"
        print rows "\t" eligible "\t" drifting "\t" replies "\t" states
        if (rows != 4 || eligible != 2 || drifting != 2 ||
            replies != 4 || states != 4)
            exit 1
    }
' "$MATRIX"
printf '\nmatrix: %s\n' "$MATRIX"
