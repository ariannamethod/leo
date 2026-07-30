#!/usr/bin/env bash
# A.70: test side-A/Flom on a third surface with life-level breadth.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMPTS="$ROOT/scripts/deferred_wonder_flom_third_life.txt"
ACCEPTANCE="$ROOT/scripts/deferred_wonder_flom_third_life_acceptance.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-appetite-flom-third-life-$STAMP}"
SEEDS=(907 1013 1109 1213 1307 1423 1511 1601)
TURNS=32
HORIZON=4

if [ "${LEO_APPETITE_FLOM_PLAN_ONLY:-0}" = 1 ]; then
    printf 'hypothesis\tlives\tturns\tcases\tvariants\thorizon\tschedule\tcontract\n'
    printf 'side-a/flom\t%d\t%d\t%d\t3\t%d\tthird-surface\tdual-surface-breadth\n' \
        "${#SEEDS[@]}" "$TURNS" "$((8 * ${#SEEDS[@]}))" "$HORIZON"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/cases" "$OUT/states"

NATURAL="$OUT/body-source"
"$ROOT/scripts/deferred_wonder_appetite_natural_life.sh" "$NATURAL" \
    > "$OUT/body-source.out"
BODY="$NATURAL/body/state"
cp "$PROMPTS" "$OUT/prompts.txt"
cp "$ACCEPTANCE" "$OUT/acceptance.tsv"
[ "$(wc -l < "$OUT/prompts.txt" | tr -d ' ')" -eq "$TURNS" ] || {
    printf 'prompt count is not %d\n' "$TURNS" >&2
    exit 1
}

PLAN="$OUT/sealed-plan.tsv"
LEO_APPETITE_FLOM_PLAN_ONLY=1 "$0" > "$PLAN"
(
    cd "$OUT"
    shasum -a 256 prompts.txt acceptance.tsv sealed-plan.tsv \
        > sealed-inputs.sha256
    shasum -a 256 body-source/body/state > source-body.sha256
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

school_from_log() {
    awk '
        /\[curiosity: / {
            outcome = $0
            candidate = $0
            sub(/^.*outcome=/, "", outcome)
            sub(/ .*/, "", outcome)
            sub(/^.*candidate=/, "", candidate)
            sub(/ .*/, "", candidate)
            printf "%s\t%s\n", outcome, candidate
            exit
        }
    ' "$1"
}

replace_anchor() {
    local prompt="$1"
    local replacement="$2"
    local changed="${prompt/man/$replacement}"
    [ "$changed" != "$prompt" ] || {
        printf 'man anchor absent from prompt: %s\n' "$prompt" >&2
        return 1
    }
    printf '%s\n' "$changed"
}

MANIFEST="$OUT/manifest.tsv"
printf 'case\tseed\tturn\tobserve\tword\texternal_side\tself_side\ttarget\tsynonym\tneutral\n' \
    > "$MANIFEST"
for seed in "${SEEDS[@]}"; do
    cause=1
    while [ "$cause" -le 29 ]; do
        target="$(sed -n "${cause}p" "$OUT/prompts.txt")"
        synonym="$(replace_anchor "$target" father)"
        neutral="$(replace_anchor "$target" person)"
        observe=$((cause + HORIZON - 1))
        case_id="$(printf 'flom-%s-t%02d' "$seed" "$cause")"
        printf '%s\t%s\t%d\t%d\tflom\ta\tb\t%s\t%s\t%s\n' \
            "$case_id" "$seed" "$cause" "$observe" \
            "$target" "$synonym" "$neutral" >> "$MANIFEST"
        cause=$((cause + 4))
    done
done
[ "$(($(wc -l < "$MANIFEST") - 1))" -eq 64 ] || {
    printf 'manifest does not contain 64 cases\n' >&2
    exit 1
}
shasum -a 256 "$MANIFEST" > "$OUT/manifest.sha256"

# Grow each target life once and preserve the state before every lived turn.
for seed in "${SEEDS[@]}"; do
    bank="$OUT/states/$seed"
    mkdir -p "$bank"
    cp "$BODY" "$bank/current.state"
    : > "$bank/replies.txt"
    turn=1
    while [ "$turn" -le "$TURNS" ]; do
        cp "$bank/current.state" "$bank/pre-$turn.state"
        prompt="$(sed -n "${turn}p" "$OUT/prompts.txt")"
        "$ROOT/leo" --load "$bank/current.state" \
            --seed "$((seed + turn - 1))" \
            --respond "$prompt" --debug-field \
            --no-wonder-appetite-calibration \
            --no-wonder-appetite-checkpoint \
            --save "$bank/current.state" \
            > "$bank/turn-$turn.log" 2>&1
        reply_from_log "$bank/turn-$turn.log" >> "$bank/replies.txt"
        turn=$((turn + 1))
    done
    (
        cd "$bank"
        shasum -a 256 pre-*.state > snapshots.sha256
    )
done

RESULTS="$OUT/results.tsv"
printf 'case\tseed\tturn\tobserve\tword\texternal_side\tself_side\tvariant\tschool_outcome\tschool_candidate\tcause_external_a\tcause_external_b\timmediate_self_a\timmediate_self_b\tany_self_a\tany_self_b\tcompleted_w1\tcompleted_w2\tcompleted_w4\tcompleted_w8\n' \
    > "$RESULTS"
REPLIES="$OUT/branch-replies.tsv"
printf 'case\tvariant\trelative_turn\treply\n' > "$REPLIES"

tail -n +2 "$MANIFEST" |
while IFS=$'\t' read -r case_id seed cause observe word \
        external_side self_side target synonym neutral; do
    case_dir="$OUT/cases/$case_id"
    mkdir -p "$case_dir"
    bank="$OUT/states/$seed"
    cp "$bank/pre-$cause.state" "$case_dir/pre.state"

    for variant in target synonym neutral; do
        case "$variant" in
            target) cause_prompt="$target" ;;
            synonym) cause_prompt="$synonym" ;;
            neutral) cause_prompt="$neutral" ;;
        esac
        branch="$case_dir/$variant"
        mkdir -p "$branch"
        cp "$case_dir/pre.state" "$branch/state"
        : > "$branch/replies.txt"
        : > "$branch/exchanges.tsv"

        turn="$cause"
        relative=0
        while [ "$turn" -le "$observe" ]; do
            relative=$((relative + 1))
            if [ "$turn" -eq "$cause" ]; then
                prompt="$cause_prompt"
            else
                prompt="$(sed -n "${turn}p" "$OUT/prompts.txt")"
            fi
            "$ROOT/leo" --load "$branch/state" \
                --seed "$((seed + turn - 1))" \
                --respond "$prompt" --debug-field \
                --no-wonder-appetite-calibration \
                --no-wonder-appetite-checkpoint \
                --save "$branch/state" \
                > "$branch/turn-$turn.log" 2>&1
            if [ "$turn" -eq "$cause" ]; then
                school="$(school_from_log "$branch/turn-$turn.log")"
                [ -n "$school" ] || {
                    printf '%s/%s has no School receipt\n' \
                        "$case_id" "$variant" >&2
                    exit 1
                }
            fi
            reply="$(reply_from_log "$branch/turn-$turn.log")"
            printf '%s\n' "$reply" >> "$branch/replies.txt"
            printf '%s\t%s\tnone\n' "$prompt" "$reply" \
                >> "$branch/exchanges.tsv"
            printf '%s\t%s\t%d\t%s\n' \
                "$case_id" "$variant" "$relative" "$reply" \
                >> "$REPLIES"
            turn=$((turn + 1))
        done

        "$OUT/provenance-shadow-fixture" "$BODY" \
            "$case_id-$variant" \
            < "$branch/exchanges.tsv" > "$branch/evidence.tsv"

        awk -F '\t' -v case_id="$case_id" -v seed="$seed" \
            -v cause="$cause" -v observe="$observe" \
            -v variant="$variant" -v school="$school" '
            NR > 1 && $3 == "flom" {
                if ($2 == 1) {
                    external_a = $5
                    external_b = $6
                    immediate_a = $9
                    immediate_b = $10
                }
                if ($9) any_a = 1
                if ($10) any_b = 1
                completed_w1 += $12
                completed_w2 += $19
                completed_w4 += $26
                completed_w8 += $33
            }
            END {
                printf "%s\t%s\t%d\t%d\tflom\ta\tb\t%s\t%s",
                       case_id, seed, cause, observe, variant, school
                printf "\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                       external_a + 0, external_b + 0,
                       immediate_a + 0, immediate_b + 0,
                       any_a + 0, any_b + 0,
                       completed_w1 + 0, completed_w2 + 0,
                       completed_w4 + 0, completed_w8 + 0
            }
        ' "$branch/evidence.tsv" >> "$RESULTS"
    done

    sed -n "${cause},${observe}p" "$bank/replies.txt" \
        > "$case_dir/expected-target.replies"
    cmp "$case_dir/expected-target.replies" \
        "$case_dir/target/replies.txt"
    (
        cd "$case_dir"
        shasum -a 256 pre.state > pre.state.sha256
    )
done

[ "$(($(wc -l < "$RESULTS") - 1))" -eq 192 ] || {
    printf 'results do not contain 192 branches\n' >&2
    exit 1
}

awk -F '\t' '
    NR == 1 { next }
    {
        expected_a = ($8 == "target" || $8 == "synonym")
        if ($11 != expected_a || $12 != 0) {
            printf "invalid Flom geometry: %s/%s got %s/%s expected %s/0\n",
                   $1, $8, $11, $12, expected_a > "/dev/stderr"
            bad = 1
        }
    }
    END { exit bad }
' "$RESULTS"

SUMMARY="$OUT/summary.tsv"
printf 'cases\tschool_diverged\ttarget_immediate\tsynonym_immediate\tneutral_immediate\ttarget_any\tsynonym_any\tneutral_any\ttarget_helped\ttarget_harmed\ttarget_lift\ttarget_exact_p\tsynonym_helped\tsynonym_harmed\tsynonym_lift\tsynonym_exact_p\tstable_cases\tstable_target_helped\tstable_target_harmed\tstable_target_lift\n' \
    > "$SUMMARY"
awk -F '\t' '
    function choose(n, k,    i, value) {
        if (k > n - k) k = n - k
        value = 1
        for (i = 1; i <= k; i++)
            value = value * (n - k + i) / i
        return value
    }
    function exact_p(helped, harmed,    n, tail, i, p) {
        n = helped + harmed
        if (n == 0) return 1
        tail = (helped < harmed) ? helped : harmed
        p = 0
        for (i = 0; i <= tail; i++)
            p += choose(n, i) / (2 ^ n)
        p *= 2
        return (p > 1) ? 1 : p
    }
    NR == 1 { next }
    {
        key = $1
        immediate[key, $8] = $14 + 0
        any[key, $8] = $16 + 0
        school[key, $8] = $9 SUBSEP $10
        seen[key] = 1
    }
    END {
        for (key in seen) {
            cases++
            stable = school[key, "target"] == school[key, "synonym"] &&
                     school[key, "target"] == school[key, "neutral"]
            if (!stable) diverged++
            ti += immediate[key, "target"]
            si += immediate[key, "synonym"]
            ni += immediate[key, "neutral"]
            ta += any[key, "target"]
            sa += any[key, "synonym"]
            na += any[key, "neutral"]
            if (any[key, "target"] && !any[key, "neutral"]) th++
            if (!any[key, "target"] && any[key, "neutral"]) tm++
            if (any[key, "synonym"] && !any[key, "neutral"]) sh++
            if (!any[key, "synonym"] && any[key, "neutral"]) sm++
            if (stable) {
                stable_cases++
                if (any[key, "target"] && !any[key, "neutral"])
                    stable_helped++
                if (!any[key, "target"] && any[key, "neutral"])
                    stable_harmed++
            }
        }
        stable_lift = 0
        if (stable_cases > 0)
            stable_lift = (stable_helped - stable_harmed) / stable_cases
        printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d",
               cases, diverged, ti, si, ni, ta, sa, na
        printf "\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%.6f\t%.6f",
               th, tm, (th - tm) / cases, exact_p(th, tm),
               sh, sm, (sh - sm) / cases, exact_p(sh, sm)
        printf "\t%d\t%d\t%d\t%.6f\n",
               stable_cases, stable_helped, stable_harmed, stable_lift
    }
' "$RESULTS" >> "$SUMMARY"

BY_SEED="$OUT/by-seed.tsv"
printf 'seed\tcases\ttarget_any\tsynonym_any\tneutral_any\ttarget_helped\ttarget_harmed\ttarget_lift\tsynonym_helped\tsynonym_harmed\tsynonym_lift\n' \
    > "$BY_SEED"
awk -F '\t' '
    NR == 1 { next }
    {
        key = $1
        seed[key] = $2
        any[key, $8] = $16 + 0
        seen[key] = 1
    }
    END {
        for (key in seen) {
            s = seed[key]
            cases[s]++
            target[s] += any[key, "target"]
            synonym[s] += any[key, "synonym"]
            neutral[s] += any[key, "neutral"]
            if (any[key, "target"] && !any[key, "neutral"])
                target_helped[s]++
            if (!any[key, "target"] && any[key, "neutral"])
                target_harmed[s]++
            if (any[key, "synonym"] && !any[key, "neutral"])
                synonym_helped[s]++
            if (!any[key, "synonym"] && any[key, "neutral"])
                synonym_harmed[s]++
        }
        for (s in cases) {
            printf "%s\t%d\t%d\t%d\t%d",
                   s, cases[s], target[s], synonym[s], neutral[s]
            printf "\t%d\t%d\t%.6f\t%d\t%d\t%.6f\n",
                   target_helped[s], target_harmed[s],
                   (target_helped[s] - target_harmed[s]) / cases[s],
                   synonym_helped[s], synonym_harmed[s],
                   (synonym_helped[s] - synonym_harmed[s]) / cases[s]
        }
    }
' "$RESULTS" | sort -n >> "$BY_SEED"

VERDICT="$OUT/verdict.tsv"
awk -F '\t' '
    FILENAME == ARGV[1] && FNR == 2 {
        target_lift = $11
        target_p = $12
        synonym_lift = $15
        synonym_p = $16
        next
    }
    FILENAME == ARGV[2] && FNR > 1 {
        if ($8 > 0) target_positive++
        if ($11 > 0) synonym_positive++
    }
    END {
        direction = target_lift > 0 && synonym_lift > 0 &&
                    target_positive >= 4 && synonym_positive >= 4
        measured = direction && target_p <= 0.05 && synonym_p <= 0.05
        if (measured)
            verdict = "measured-replication"
        else if (direction)
            verdict = "direction-only"
        else
            verdict = "not-replicated"
        printf "verdict\ttarget_lift\tsynonym_lift\t"
        printf "target_exact_p\tsynonym_exact_p\t"
        printf "target_positive_seeds\tsynonym_positive_seeds\n"
        printf "%s\t%.6f\t%.6f\t%.6f\t%.6f\t%d\t%d\n",
               verdict, target_lift, synonym_lift,
               target_p, synonym_p, target_positive, synonym_positive
    }
' "$SUMMARY" "$BY_SEED" > "$VERDICT"

expected_summary=$'64\t0\t1\t5\t0\t13\t19\t12\t2\t1\t0.015625\t1.000000\t8\t1\t0.109375\t0.039062\t64\t2\t1\t0.015625'
got_summary="$(tail -n +2 "$SUMMARY")"
[ "$got_summary" = "$expected_summary" ] || {
    printf 'unexpected Flom third-life summary:\n%s\n' \
        "$got_summary" >&2
    exit 1
}

expected_by_seed=$'907\t8\t2\t5\t3\t0\t1\t-0.125000\t2\t0\t0.250000\n1013\t8\t1\t2\t1\t0\t0\t0.000000\t1\t0\t0.125000\n1109\t8\t2\t2\t2\t0\t0\t0.000000\t1\t1\t0.000000\n1213\t8\t2\t1\t1\t1\t0\t0.125000\t0\t0\t0.000000\n1307\t8\t1\t2\t1\t0\t0\t0.000000\t1\t0\t0.125000\n1423\t8\t2\t2\t2\t0\t0\t0.000000\t0\t0\t0.000000\n1511\t8\t1\t2\t0\t1\t0\t0.125000\t2\t0\t0.250000\n1601\t8\t2\t3\t2\t0\t0\t0.000000\t1\t0\t0.125000'
got_by_seed="$(tail -n +2 "$BY_SEED")"
[ "$got_by_seed" = "$expected_by_seed" ] || {
    printf 'unexpected Flom third-life by-seed result:\n%s\n' \
        "$got_by_seed" >&2
    exit 1
}

expected_verdict=$'not-replicated\t0.015625\t0.109375\t1.000000\t0.039062\t2\t5'
got_verdict="$(tail -n +2 "$VERDICT")"
[ "$got_verdict" = "$expected_verdict" ] || {
    printf 'unexpected Flom third-life verdict:\n%s\n' \
        "$got_verdict" >&2
    exit 1
}

(
    cd "$OUT"
    shasum -a 256 -c source-body.sha256 > /dev/null
    shasum -a 256 -c manifest.sha256 > /dev/null
    for bank in states/907 states/1013 states/1109 states/1213 \
                states/1307 states/1423 states/1511 states/1601; do
        (cd "$bank" && shasum -a 256 -c snapshots.sha256 > /dev/null)
    done
)

cat "$SUMMARY"
printf '\n'
cat "$BY_SEED"
printf '\n'
cat "$VERDICT"
printf '\nsealed manifest: %s\nresults: %s\n' "$MANIFEST" "$RESULTS"
