#!/usr/bin/env bash
# A.67: branch exact pre-turn bodies to test semantic necessity.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/scripts/deferred_wonder_matched_counterfactual.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-appetite-matched-counterfactual-$STAMP}"

prompt_file() {
    case "$1" in
        blind)
            printf '%s\n' "$ROOT/scripts/deferred_wonder_external_blind.txt"
            ;;
        side-a)
            printf '%s\n' "$ROOT/scripts/deferred_wonder_external_side_a.txt"
            ;;
        *) return 2 ;;
    esac
}

if [ "${LEO_APPETITE_MATCHED_PLAN_ONLY:-0}" = 1 ]; then
    printf 'case\ttrace\tcause\tobserve\tvariants\tcontract\n'
    awk -F '\t' 'NR > 1 {
        printf "%s\t%s-%s\t%s\t%s\t4\texact-state-semantic-factorial\n",
               $1, $2, $3, $4, $5
    }' "$CASES"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/cases"

EXTERNAL="$OUT/external-life"
"$ROOT/scripts/deferred_wonder_appetite_external_life.sh" "$EXTERNAL" \
    > "$OUT/external-life.out"
BODY="$EXTERNAL/body-source/body/state"
cp "$CASES" "$OUT/cases.tsv"

PLAN="$OUT/sealed-plan.tsv"
LEO_APPETITE_MATCHED_PLAN_ONLY=1 "$0" > "$PLAN"
(
    cd "$OUT"
    shasum -a 256 cases.tsv \
        external-life/prompts-blind.txt \
        external-life/prompts-side-a.txt \
        > sealed-inputs.sha256
    shasum -a 256 sealed-plan.tsv > sealed-plan.sha256
    shasum -a 256 external-life/body-source/body/state \
        > source-body.sha256
)

"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_provenance_shadow_fixture.c" -lm \
    -o "$OUT/provenance-shadow-fixture"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

RESULTS="$OUT/results.tsv"
printf 'case\tvariant\tword\texternal_side\tself_side\tcause_external_a\tcause_external_b\tobserve_self_a\tobserve_self_b\tcompleted_w1\tcompleted_w2\tcompleted_w4\tcompleted_w8\n' \
    > "$RESULTS"
REPLIES="$OUT/observe-replies.tsv"
printf 'case\tvariant\treply\n' > "$REPLIES"

tail -n +2 "$OUT/cases.tsv" |
while IFS=$'\t' read -r case_id arm seed cause observe word \
        external_side self_side target synonym neutral opposite; do
    case_dir="$OUT/cases/$case_id"
    mkdir -p "$case_dir"
    prompts="$EXTERNAL/prompts-$arm.txt"
    original="$EXTERNAL/$arm-$seed"

    original_cause="$(sed -n "${cause}p" "$prompts")"
    [ "$target" = "$original_cause" ] || {
        printf '%s target does not match sealed original prompt\n' \
            "$case_id" >&2
        exit 1
    }

    cp "$BODY" "$case_dir/pre.state"
    turn=1
    while [ "$turn" -lt "$cause" ]; do
        prompt="$(sed -n "${turn}p" "$prompts")"
        "$ROOT/leo" --load "$case_dir/pre.state" \
            --seed "$((seed + turn - 1))" \
            --respond "$prompt" --debug-field \
            --no-wonder-appetite-calibration \
            --no-wonder-appetite-checkpoint \
            --save "$case_dir/pre.state" \
            > "$case_dir/pre-$turn.log" 2>&1
        turn=$((turn + 1))
    done
    (
        cd "$case_dir"
        shasum -a 256 pre.state > pre.state.sha256
    )

    for variant in target synonym neutral opposite; do
        case "$variant" in
            target) cause_prompt="$target" ;;
            synonym) cause_prompt="$synonym" ;;
            neutral) cause_prompt="$neutral" ;;
            opposite) cause_prompt="$opposite" ;;
        esac
        branch="$case_dir/$variant"
        mkdir -p "$branch"
        cp "$case_dir/pre.state" "$branch/state"
        : > "$branch/replies.txt"
        : > "$branch/exchanges.tsv"

        turn="$cause"
        while [ "$turn" -le "$observe" ]; do
            if [ "$turn" -eq "$cause" ]; then
                prompt="$cause_prompt"
            else
                prompt="$(sed -n "${turn}p" "$prompts")"
            fi
            "$ROOT/leo" --load "$branch/state" \
                --seed "$((seed + turn - 1))" \
                --respond "$prompt" --debug-field \
                --no-wonder-appetite-calibration \
                --no-wonder-appetite-checkpoint \
                --save "$branch/state" \
                > "$branch/turn-$turn.log" 2>&1
            if [ "$turn" -eq "$cause" ] &&
               ! grep -q '\[curiosity: .*candidate=none' \
                   "$branch/turn-$turn.log"; then
                printf '%s/%s changed School at the intervention\n' \
                    "$case_id" "$variant" >&2
                exit 1
            fi
            reply="$(reply_from_log "$branch/turn-$turn.log")"
            printf '%s\n' "$reply" >> "$branch/replies.txt"
            printf '%s\t%s\t%s\n' "$prompt" "$reply" none \
                >> "$branch/exchanges.tsv"
            turn=$((turn + 1))
        done

        "$OUT/provenance-shadow-fixture" "$BODY" \
            "$case_id-$variant" \
            < "$branch/exchanges.tsv" > "$branch/evidence.tsv"

        horizon=$((observe - cause + 1))
        awk -F '\t' -v case_id="$case_id" -v variant="$variant" \
            -v word="$word" -v external_side="$external_side" \
            -v self_side="$self_side" -v horizon="$horizon" '
            NR > 1 && $3 == word {
                if ($2 == 1) {
                    external_a = $5
                    external_b = $6
                }
                if ($2 == horizon) {
                    self_a = $9
                    self_b = $10
                }
                completed_w1 += $12
                completed_w2 += $19
                completed_w4 += $26
                completed_w8 += $33
            }
            END {
                printf "%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                       case_id, variant, word,
                       external_side, self_side,
                       external_a + 0, external_b + 0,
                       self_a + 0, self_b + 0,
                       completed_w1 + 0, completed_w2 + 0,
                       completed_w4 + 0, completed_w8 + 0
            }
        ' "$branch/evidence.tsv" >> "$RESULTS"
        printf '%s\t%s\t%s\n' "$case_id" "$variant" \
            "$(tail -n 1 "$branch/replies.txt")" >> "$REPLIES"
    done

    sed -n "${cause},${observe}p" "$original/replies.txt" \
        > "$case_dir/expected-target.replies"
    cmp "$case_dir/expected-target.replies" \
        "$case_dir/target/replies.txt"
    (
        cd "$case_dir"
        shasum -a 256 -c pre.state.sha256 > /dev/null
    )
done

expected_results=$'blind-307-nareth\ttarget\tnareth\tb\ta\t0\t1\t1\t0\t0\t0\t1\t1\nblind-307-nareth\tsynonym\tnareth\tb\ta\t0\t1\t1\t0\t0\t0\t1\t1\nblind-307-nareth\tneutral\tnareth\tb\ta\t0\t0\t1\t0\t0\t0\t0\t0\nblind-307-nareth\topposite\tnareth\tb\ta\t1\t0\t1\t0\t0\t0\t0\t0\nblind-401-nareth\ttarget\tnareth\ta\tb\t1\t0\t0\t1\t1\t1\t1\t1\nblind-401-nareth\tsynonym\tnareth\ta\tb\t1\t0\t0\t0\t0\t0\t0\t0\nblind-401-nareth\tneutral\tnareth\ta\tb\t0\t0\t0\t1\t0\t0\t0\t0\nblind-401-nareth\topposite\tnareth\ta\tb\t0\t1\t0\t0\t0\t0\t0\t0\nside-a-307-nareth\ttarget\tnareth\ta\tb\t1\t0\t0\t1\t0\t0\t1\t1\nside-a-307-nareth\tsynonym\tnareth\ta\tb\t1\t0\t0\t1\t0\t0\t1\t1\nside-a-307-nareth\tneutral\tnareth\ta\tb\t0\t0\t0\t1\t0\t0\t0\t0\nside-a-307-nareth\topposite\tnareth\ta\tb\t0\t1\t0\t0\t0\t0\t0\t0\nside-a-401-flom\ttarget\tflom\ta\tb\t1\t0\t0\t1\t0\t1\t1\t1\nside-a-401-flom\tsynonym\tflom\ta\tb\t1\t0\t0\t1\t0\t1\t1\t1\nside-a-401-flom\tneutral\tflom\ta\tb\t0\t0\t0\t1\t0\t0\t0\t0\nside-a-401-flom\topposite\tflom\ta\tb\t0\t1\t0\t1\t0\t0\t0\t0'
got_results="$(tail -n +2 "$RESULTS")"
[ "$got_results" = "$expected_results" ] || {
    printf 'unexpected matched counterfactual result:\n%s\n' \
        "$got_results" >&2
    exit 1
}

VERDICTS="$OUT/verdicts.tsv"
printf 'case\ttarget_self\tsynonym_self\tneutral_self\topposite_reverse\tverdict\n' \
    > "$VERDICTS"
awk -F '\t' '
    NR == 1 { next }
    {
        key = $1
        if ($5 == "a") self_hit = $8
        else self_hit = $9
        if ($4 == "a") reverse_hit = $8
        else reverse_hit = $9
        if ($2 == "target") target[key] = self_hit
        else if ($2 == "synonym") synonym[key] = self_hit
        else if ($2 == "neutral") neutral[key] = self_hit
        else if ($2 == "opposite") opposite[key] = reverse_hit
        seen[key] = 1
    }
    END {
        for (key in seen) {
            if (neutral[key])
                verdict = "not-necessary"
            else if (target[key] && synonym[key] && opposite[key])
                verdict = "direction-reversed"
            else
                verdict = "unresolved"
            printf "%s\t%d\t%d\t%d\t%d\t%s\n",
                   key, target[key] + 0, synonym[key] + 0,
                   neutral[key] + 0, opposite[key] + 0, verdict
        }
    }
' "$RESULTS" | sort >> "$VERDICTS"

expected_verdicts=$'blind-307-nareth\t1\t1\t1\t0\tnot-necessary\nblind-401-nareth\t1\t0\t1\t0\tnot-necessary\nside-a-307-nareth\t1\t1\t1\t0\tnot-necessary\nside-a-401-flom\t1\t1\t1\t0\tnot-necessary'
got_verdicts="$(tail -n +2 "$VERDICTS")"
[ "$got_verdicts" = "$expected_verdicts" ] || {
    printf 'unexpected matched counterfactual verdict:\n%s\n' \
        "$got_verdicts" >&2
    exit 1
}

(
    cd "$OUT"
    shasum -a 256 -c source-body.sha256 > /dev/null
)

cat "$RESULTS"
printf '\n'
cat "$VERDICTS"
printf '\n'
cat "$REPLIES"
printf '\nsealed plan: %s\nresults: %s\n' "$PLAN" "$RESULTS"
