#!/usr/bin/env bash
# A.69: test a discovery-derived susceptibility class on new lives.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$ROOT/scripts/deferred_wonder_susceptibility_contract.tsv"
ACCEPTANCE="$ROOT/scripts/deferred_wonder_susceptibility_acceptance.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-appetite-susceptibility-holdout-$STAMP}"
SEEDS=(509 613 719 823)
ARMS=(side-a side-b)
TURNS=32
HORIZON=4

prompt_file() {
    case "$1" in
        side-a)
            printf '%s\n' \
                "$ROOT/scripts/deferred_wonder_susceptibility_holdout_side_a.txt"
            ;;
        side-b)
            printf '%s\n' \
                "$ROOT/scripts/deferred_wonder_susceptibility_holdout_side_b.txt"
            ;;
        *) return 2 ;;
    esac
}

if [ "${LEO_APPETITE_SUSCEPTIBILITY_PLAN_ONLY:-0}" = 1 ]; then
    printf 'arm\tlives\tturns\tcases\tvariants\thorizon\tschedule\tcontract\n'
    for arm in "${ARMS[@]}"; do
        printf '%s\t%d\t%d\t%d\t3\t%d\tnew-surface\tdual-surface-susceptibility\n' \
            "$arm" "${#SEEDS[@]}" "$TURNS" \
            "$((TURNS * ${#SEEDS[@]}))" "$HORIZON"
    done
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
cp "$CONTRACT" "$OUT/contract.tsv"
cp "$ACCEPTANCE" "$OUT/acceptance.tsv"
for arm in "${ARMS[@]}"; do
    cp "$(prompt_file "$arm")" "$OUT/prompts-$arm.txt"
    [ "$(wc -l < "$OUT/prompts-$arm.txt" | tr -d ' ')" -eq "$TURNS" ] || {
        printf '%s prompt count is not %d\n' "$arm" "$TURNS" >&2
        exit 1
    }
done

PLAN="$OUT/sealed-plan.tsv"
LEO_APPETITE_SUSCEPTIBILITY_PLAN_ONLY=1 "$0" > "$PLAN"
(
    cd "$OUT"
    shasum -a 256 contract.tsv acceptance.tsv sealed-plan.tsv \
        prompts-side-a.txt prompts-side-b.txt > sealed-inputs.sha256
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
    local anchor="$2"
    local replacement="$3"
    local changed="${prompt/$anchor/$replacement}"
    [ "$changed" != "$prompt" ] || {
        printf 'anchor %s absent from prompt: %s\n' \
            "$anchor" "$prompt" >&2
        return 1
    }
    printf '%s\n' "$changed"
}

# The susceptibility class and every branch prompt are sealed before replies.
MANIFEST="$OUT/manifest.tsv"
printf 'case\tarm\tseed\tturn\tobserve\tword\tanchor\texternal_side\tself_side\tclass\ttarget\tsynonym\tneutral\n' \
    > "$MANIFEST"
for arm in "${ARMS[@]}"; do
    prompts="$OUT/prompts-$arm.txt"
    for seed in "${SEEDS[@]}"; do
        turn=1
        while [ "$turn" -le "$TURNS" ]; do
            slot=$(( (turn - 1) % 4 + 1 ))
            mapping="$(
                awk -F '\t' -v arm="$arm" -v slot="$slot" '
                    NR > 1 && $1 == arm {
                        found++
                        if (found == slot) {
                            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s",
                                   $2, $3, $4, $5, $6, $7, $8
                            exit
                        }
                    }
                ' "$OUT/contract.tsv"
            )"
            IFS=$'\t' read -r anchor word synonym_word neutral_word \
                external_side self_side class <<< "$mapping"
            target_prompt="$(sed -n "${turn}p" "$prompts")"
            synonym_prompt="$(
                replace_anchor "$target_prompt" "$anchor" "$synonym_word"
            )"
            neutral_prompt="$(
                replace_anchor "$target_prompt" "$anchor" "$neutral_word"
            )"
            observe=$((turn + HORIZON - 1))
            [ "$observe" -le "$TURNS" ] || observe="$TURNS"
            case_id="$(printf '%s-%s-t%02d-%s' \
                "$arm" "$seed" "$turn" "$word")"
            printf '%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$case_id" "$arm" "$seed" "$turn" "$observe" \
                "$word" "$anchor" "$external_side" "$self_side" "$class" \
                "$target_prompt" "$synonym_prompt" "$neutral_prompt" \
                >> "$MANIFEST"
            turn=$((turn + 1))
        done
    done
done
[ "$(($(wc -l < "$MANIFEST") - 1))" -eq 256 ] || {
    printf 'manifest does not contain 256 cases\n' >&2
    exit 1
}
shasum -a 256 "$MANIFEST" > "$OUT/manifest.sha256"

# Grow each new target life once and bank its exact state before every turn.
for arm in "${ARMS[@]}"; do
    prompts="$OUT/prompts-$arm.txt"
    for seed in "${SEEDS[@]}"; do
        bank="$OUT/states/$arm-$seed"
        mkdir -p "$bank"
        cp "$BODY" "$bank/current.state"
        : > "$bank/replies.txt"
        turn=1
        while [ "$turn" -le "$TURNS" ]; do
            cp "$bank/current.state" "$bank/pre-$turn.state"
            prompt="$(sed -n "${turn}p" "$prompts")"
            "$ROOT/leo" --load "$bank/current.state" \
                --seed "$((seed + turn - 1))" \
                --respond "$prompt" --debug-field \
                --no-wonder-appetite-calibration \
                --no-wonder-appetite-checkpoint \
                --save "$bank/current.state" \
                > "$bank/turn-$turn.log" 2>&1
            reply_from_log "$bank/turn-$turn.log" \
                >> "$bank/replies.txt"
            turn=$((turn + 1))
        done
        (
            cd "$bank"
            shasum -a 256 pre-*.state > snapshots.sha256
        )
    done
done

RESULTS="$OUT/results.tsv"
printf 'case\tarm\tseed\tturn\tobserve\tword\tclass\texternal_side\tself_side\tvariant\tschool_outcome\tschool_candidate\tcause_external_a\tcause_external_b\timmediate_self_a\timmediate_self_b\tany_self_a\tany_self_b\tcompleted_w1\tcompleted_w2\tcompleted_w4\tcompleted_w8\n' \
    > "$RESULTS"
REPLIES="$OUT/branch-replies.tsv"
printf 'case\tvariant\trelative_turn\treply\n' > "$REPLIES"

tail -n +2 "$MANIFEST" |
while IFS=$'\t' read -r case_id arm seed cause observe word anchor \
        external_side self_side class target synonym neutral; do
    case_dir="$OUT/cases/$case_id"
    mkdir -p "$case_dir"
    prompts="$OUT/prompts-$arm.txt"
    bank="$OUT/states/$arm-$seed"
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
                prompt="$(sed -n "${turn}p" "$prompts")"
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

        awk -F '\t' -v case_id="$case_id" -v arm="$arm" \
            -v seed="$seed" -v cause="$cause" -v observe="$observe" \
            -v variant="$variant" -v word="$word" -v class="$class" \
            -v school="$school" -v external_side="$external_side" \
            -v self_side="$self_side" '
            NR > 1 && $3 == word {
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
                printf "%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s",
                       case_id, arm, seed, cause, observe, word, class,
                       external_side, self_side, variant, school
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

[ "$(($(wc -l < "$RESULTS") - 1))" -eq 768 ] || {
    printf 'results do not contain 768 branches\n' >&2
    exit 1
}

awk -F '\t' '
    NR == 1 { next }
    {
        if ($10 == "target" || $10 == "synonym") {
            expected_a = ($8 == "a")
            expected_b = ($8 == "b")
        } else {
            expected_a = 0
            expected_b = 0
        }
        if ($13 != expected_a || $14 != expected_b) {
            printf "invalid prompt geometry: %s/%s got %s/%s expected %s/%s\n",
                   $1, $10, $13, $14, expected_a, expected_b > "/dev/stderr"
            bad = 1
        }
    }
    END { exit bad }
' "$RESULTS"

SUMMARY="$OUT/summary.tsv"
printf 'scope\tcases\tschool_diverged\ttarget_immediate\tsynonym_immediate\tneutral_immediate\ttarget_any\tsynonym_any\tneutral_any\ttarget_helped\ttarget_harmed\ttarget_lift\ttarget_exact_p\tsynonym_helped\tsynonym_harmed\tsynonym_lift\tsynonym_exact_p\tstable_cases\tstable_target_helped\tstable_target_harmed\tstable_target_lift\n' \
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
        class[key] = $7
        self_col = ($9 == "a") ? 17 : 18
        immediate_col = ($9 == "a") ? 15 : 16
        immediate[key, $10] = $immediate_col + 0
        any[key, $10] = $self_col + 0
        school[key, $10] = $11 SUBSEP $12
        seen[key] = 1
    }
    END {
        for (key in seen) {
            scopes[1] = class[key]
            scopes[2] = "pooled"
            for (s = 1; s <= 2; s++) {
                scope = scopes[s]
                cases[scope]++
                stable = school[key, "target"] == school[key, "synonym"] &&
                         school[key, "target"] == school[key, "neutral"]
                if (!stable) diverged[scope]++
                ti[scope] += immediate[key, "target"]
                si[scope] += immediate[key, "synonym"]
                ni[scope] += immediate[key, "neutral"]
                ta[scope] += any[key, "target"]
                sa[scope] += any[key, "synonym"]
                na[scope] += any[key, "neutral"]
                if (any[key, "target"] && !any[key, "neutral"])
                    th[scope]++
                if (!any[key, "target"] && any[key, "neutral"])
                    tm[scope]++
                if (any[key, "synonym"] && !any[key, "neutral"])
                    sh[scope]++
                if (!any[key, "synonym"] && any[key, "neutral"])
                    sm[scope]++
                if (stable) {
                    stable_cases[scope]++
                    if (any[key, "target"] && !any[key, "neutral"])
                        stable_helped[scope]++
                    if (!any[key, "target"] && any[key, "neutral"])
                        stable_harmed[scope]++
                }
            }
        }
        order[1] = "susceptible"
        order[2] = "control"
        order[3] = "pooled"
        for (i = 1; i <= 3; i++) {
            scope = order[i]
            stable_lift = 0
            if (stable_cases[scope] > 0)
                stable_lift = (stable_helped[scope] - stable_harmed[scope]) / stable_cases[scope]
            printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d",
                   scope, cases[scope], diverged[scope],
                   ti[scope], si[scope], ni[scope],
                   ta[scope], sa[scope], na[scope]
            printf "\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%.6f\t%.6f",
                   th[scope], tm[scope],
                   (th[scope] - tm[scope]) / cases[scope],
                   exact_p(th[scope], tm[scope]),
                   sh[scope], sm[scope],
                   (sh[scope] - sm[scope]) / cases[scope],
                   exact_p(sh[scope], sm[scope])
            printf "\t%d\t%d\t%d\t%.6f\n",
                   stable_cases[scope], stable_helped[scope],
                   stable_harmed[scope], stable_lift
        }
    }
' "$RESULTS" >> "$SUMMARY"

BY_CELL="$OUT/by-cell.tsv"
printf 'arm\tword\tclass\tcases\tschool_diverged\ttarget_any\tsynonym_any\tneutral_any\ttarget_helped\ttarget_harmed\ttarget_lift\tsynonym_helped\tsynonym_harmed\tsynonym_lift\n' \
    > "$BY_CELL"
awk -F '\t' '
    NR == 1 { next }
    {
        key = $1
        group[key] = $2 "\t" $6 "\t" $7
        self_col = ($9 == "a") ? 17 : 18
        any[key, $10] = $self_col + 0
        school[key, $10] = $11 SUBSEP $12
        seen[key] = 1
    }
    END {
        for (key in seen) {
            group_name = group[key]
            cases[group_name]++
            target[group_name] += any[key, "target"]
            synonym[group_name] += any[key, "synonym"]
            neutral[group_name] += any[key, "neutral"]
            if (any[key, "target"] && !any[key, "neutral"])
                target_helped[group_name]++
            if (!any[key, "target"] && any[key, "neutral"])
                target_harmed[group_name]++
            if (any[key, "synonym"] && !any[key, "neutral"])
                synonym_helped[group_name]++
            if (!any[key, "synonym"] && any[key, "neutral"])
                synonym_harmed[group_name]++
            stable = school[key, "target"] == school[key, "synonym"] &&
                     school[key, "target"] == school[key, "neutral"]
            if (!stable) diverged[group_name]++
        }
        for (group_name in cases) {
            printf "%s\t%d\t%d\t%d\t%d\t%d",
                   group_name, cases[group_name], diverged[group_name],
                   target[group_name], synonym[group_name],
                   neutral[group_name]
            printf "\t%d\t%d\t%.6f\t%d\t%d\t%.6f\n",
                   target_helped[group_name], target_harmed[group_name],
                   (target_helped[group_name] - target_harmed[group_name]) / cases[group_name],
                   synonym_helped[group_name], synonym_harmed[group_name],
                   (synonym_helped[group_name] - synonym_harmed[group_name]) / cases[group_name]
        }
    }
' "$RESULTS" | sort >> "$BY_CELL"

VERDICT="$OUT/verdict.tsv"
awk -F '\t' '
    FILENAME == ARGV[1] && NR > 1 {
        if ($1 == "susceptible") {
            target_lift = $12
            target_p = $13
            synonym_lift = $16
        }
        next
    }
    FILENAME == ARGV[2] && FNR > 1 {
        if ($1 == "side-a" && $2 == "flom")
            flom_lift = $11
        if ($1 == "side-b" && $2 == "cavin")
            cavin_lift = $11
    }
    END {
        direction = target_lift > 0 && synonym_lift > 0 &&
                    flom_lift >= 0 && cavin_lift >= 0
        if (!direction)
            verdict = "not-replicated"
        else if (target_p <= 0.05)
            verdict = "measured-replication"
        else
            verdict = "direction-only"
        printf "verdict\ttarget_lift\tsynonym_lift\ttarget_exact_p\t"
        printf "side_a_flom_lift\tside_b_cavin_lift\n"
        printf "%s\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\n",
               verdict, target_lift, synonym_lift, target_p,
               flom_lift, cavin_lift
    }
' "$SUMMARY" "$BY_CELL" > "$VERDICT"

expected_summary=$'susceptible\t64\t0\t1\t4\t0\t8\t10\t6\t3\t1\t0.031250\t0.625000\t5\t1\t0.062500\t0.218750\t64\t3\t1\t0.031250\ncontrol\t192\t32\t31\t31\t31\t45\t48\t48\t5\t8\t-0.015625\t0.581055\t4\t4\t0.000000\t1.000000\t160\t5\t7\t-0.012500\npooled\t256\t32\t32\t35\t31\t53\t58\t54\t8\t9\t-0.003906\t1.000000\t9\t5\t0.015625\t0.423950\t224\t8\t8\t0.000000'
got_summary="$(tail -n +2 "$SUMMARY")"
[ "$got_summary" = "$expected_summary" ] || {
    printf 'unexpected susceptibility holdout summary:\n%s\n' \
        "$got_summary" >&2
    exit 1
}

expected_by_cell=$'side-a\tcavin\tcontrol\t32\t0\t0\t0\t0\t0\t0\t0.000000\t0\t0\t0.000000\nside-a\tflom\tsusceptible\t32\t0\t8\t8\t5\t3\t0\t0.093750\t3\t0\t0.093750\nside-a\tlume\tcontrol\t32\t16\t1\t1\t1\t0\t0\t0.000000\t0\t0\t0.000000\nside-a\tnareth\tcontrol\t32\t0\t5\t4\t4\t2\t1\t0.031250\t1\t1\t0.000000\nside-b\tcavin\tsusceptible\t32\t0\t0\t2\t1\t0\t1\t-0.031250\t2\t1\t0.031250\nside-b\tflom\tcontrol\t32\t0\t32\t32\t32\t0\t0\t0.000000\t0\t0\t0.000000\nside-b\tlume\tcontrol\t32\t16\t1\t0\t1\t1\t1\t0.000000\t0\t1\t-0.031250\nside-b\tnareth\tcontrol\t32\t0\t6\t11\t10\t2\t6\t-0.125000\t3\t2\t0.031250'
got_by_cell="$(tail -n +2 "$BY_CELL")"
[ "$got_by_cell" = "$expected_by_cell" ] || {
    printf 'unexpected susceptibility holdout by-cell result:\n%s\n' \
        "$got_by_cell" >&2
    exit 1
}

expected_verdict=$'not-replicated\t0.031250\t0.062500\t0.625000\t0.093750\t-0.031250'
got_verdict="$(tail -n +2 "$VERDICT")"
[ "$got_verdict" = "$expected_verdict" ] || {
    printf 'unexpected susceptibility holdout verdict:\n%s\n' \
        "$got_verdict" >&2
    exit 1
}

(
    cd "$OUT"
    shasum -a 256 -c source-body.sha256 > /dev/null
    shasum -a 256 -c manifest.sha256 > /dev/null
    for bank in states/side-a-509 states/side-a-613 \
                states/side-a-719 states/side-a-823 \
                states/side-b-509 states/side-b-613 \
                states/side-b-719 states/side-b-823; do
        (cd "$bank" && shasum -a 256 -c snapshots.sha256 > /dev/null)
    done
)

cat "$SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nsealed manifest: %s\nresults: %s\n' "$MANIFEST" "$RESULTS"
