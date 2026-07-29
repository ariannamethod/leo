#!/usr/bin/env bash
# A.68: estimate paired semantic lift over every directed external invitation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INTERVENTIONS="$ROOT/scripts/deferred_wonder_population_interventions.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-appetite-population-causal-lift-$STAMP}"
SEEDS=(307 401)
ARMS=(side-a side-b)
TURNS=32
HORIZON=4

if [ "${LEO_APPETITE_POPULATION_PLAN_ONLY:-0}" = 1 ]; then
    printf 'arm\tlives\tturns\tcases\tvariants\thorizon\tcontract\n'
    for arm in "${ARMS[@]}"; do
        printf '%s\t%d\t%d\t%d\t4\t%d\texact-state-all-invitations\n' \
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

EXTERNAL="$OUT/external-life"
"$ROOT/scripts/deferred_wonder_appetite_external_life.sh" "$EXTERNAL" \
    > "$OUT/external-life.out"
BODY="$EXTERNAL/body-source/body/state"
cp "$INTERVENTIONS" "$OUT/interventions.tsv"

PLAN="$OUT/sealed-plan.tsv"
LEO_APPETITE_POPULATION_PLAN_ONLY=1 "$0" > "$PLAN"
(
    cd "$OUT"
    shasum -a 256 interventions.tsv sealed-plan.tsv \
        external-life/prompts-side-a.txt \
        external-life/prompts-side-b.txt \
        > sealed-inputs.sha256
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

# Some sealed prompts carry the same glyph twice ("man ... he",
# "light ... morning"). A neutral or opposite intervention must remove the
# whole source-side dose, not merely its headline anchor. Target remains the
# byte-identical lived prompt; synonym deliberately preserves that dose.
neutralize_secondary_aliases() {
    local arm="$1"
    local word="$2"
    local prompt="$3"
    case "$arm:$word" in
        side-a:flom)
            prompt="${prompt// he / they }"
            ;;
        side-a:nareth)
            prompt="${prompt//morning/time}"
            ;;
        side-b:lume)
            prompt="${prompt//wind/place}"
            prompt="${prompt//air/place}"
            ;;
        side-b:flom)
            prompt="${prompt// she / they }"
            ;;
        side-b:nareth)
            prompt="${prompt//night/time}"
            ;;
    esac
    printf '%s\n' "$prompt"
}

# Seal every case and intervention before any branch outcome is generated.
MANIFEST="$OUT/manifest.tsv"
printf 'case\tarm\tseed\tturn\tobserve\tword\tanchor\texternal_side\tself_side\ttarget\tsynonym\tneutral\topposite\n' \
    > "$MANIFEST"
for arm in "${ARMS[@]}"; do
    prompts="$EXTERNAL/prompts-$arm.txt"
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
                ' "$OUT/interventions.tsv"
            )"
            IFS=$'\t' read -r anchor word synonym_word neutral_word \
                opposite_word external_side self_side <<< "$mapping"
            target_prompt="$(sed -n "${turn}p" "$prompts")"
            synonym_prompt="$(
                replace_anchor "$target_prompt" "$anchor" "$synonym_word"
            )"
            neutral_base="$(
                neutralize_secondary_aliases "$arm" "$word" "$target_prompt"
            )"
            neutral_prompt="$(
                replace_anchor "$neutral_base" "$anchor" "$neutral_word"
            )"
            opposite_prompt="$(
                replace_anchor "$neutral_base" "$anchor" "$opposite_word"
            )"
            observe=$((turn + HORIZON - 1))
            [ "$observe" -le "$TURNS" ] || observe="$TURNS"
            case_id="$(printf '%s-%s-t%02d-%s' \
                "$arm" "$seed" "$turn" "$word")"
            printf '%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$case_id" "$arm" "$seed" "$turn" "$observe" \
                "$word" "$anchor" "$external_side" "$self_side" \
                "$target_prompt" "$synonym_prompt" "$neutral_prompt" \
                "$opposite_prompt" >> "$MANIFEST"
            turn=$((turn + 1))
        done
    done
done
[ "$(($(wc -l < "$MANIFEST") - 1))" -eq 128 ] || {
    printf 'manifest does not contain 128 cases\n' >&2
    exit 1
}
shasum -a 256 "$MANIFEST" > "$OUT/manifest.sha256"

# Replay each directed life once and keep the exact state before every turn.
for arm in "${ARMS[@]}"; do
    prompts="$EXTERNAL/prompts-$arm.txt"
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
        cmp "$bank/replies.txt" "$EXTERNAL/$arm-$seed/replies.txt"
        (
            cd "$bank"
            shasum -a 256 pre-*.state > snapshots.sha256
        )
    done
done

RESULTS="$OUT/results.tsv"
printf 'case\tarm\tseed\tturn\tobserve\tword\texternal_side\tself_side\tvariant\tschool_outcome\tschool_candidate\tcause_external_a\tcause_external_b\timmediate_self_a\timmediate_self_b\tany_self_a\tany_self_b\tcompleted_w1\tcompleted_w2\tcompleted_w4\tcompleted_w8\n' \
    > "$RESULTS"
REPLIES="$OUT/branch-replies.tsv"
printf 'case\tvariant\trelative_turn\treply\n' > "$REPLIES"

tail -n +2 "$MANIFEST" |
while IFS=$'\t' read -r case_id arm seed cause observe word anchor \
        external_side self_side target synonym neutral opposite; do
    case_dir="$OUT/cases/$case_id"
    mkdir -p "$case_dir"
    prompts="$EXTERNAL/prompts-$arm.txt"
    bank="$OUT/states/$arm-$seed"
    cp "$bank/pre-$cause.state" "$case_dir/pre.state"

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
            -v variant="$variant" -v word="$word" -v school="$school" \
            -v external_side="$external_side" \
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
                printf "%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s",
                       case_id, arm, seed, cause, observe, word,
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

[ "$(($(wc -l < "$RESULTS") - 1))" -eq 512 ] || {
    printf 'results do not contain 512 branches\n' >&2
    exit 1
}

# Verify that only the declared semantic side changed at the cause turn.
awk -F '\t' '
    NR == 1 { next }
    {
        if ($9 == "target" || $9 == "synonym") {
            expected_a = ($7 == "a")
            expected_b = ($7 == "b")
        } else if ($9 == "neutral") {
            expected_a = 0
            expected_b = 0
        } else {
            expected_a = ($7 == "b")
            expected_b = ($7 == "a")
        }
        if ($12 != expected_a || $13 != expected_b) {
            printf "invalid prompt geometry: %s/%s got %s/%s expected %s/%s\n",
                   $1, $9, $12, $13, expected_a, expected_b > "/dev/stderr"
            bad = 1
        }
    }
    END { exit bad }
' "$RESULTS"

SUMMARY="$OUT/summary.tsv"
printf 'scope\tcases\tschool_diverged\ttarget_immediate\tsynonym_immediate\tneutral_immediate\ttarget_any\tsynonym_any\tneutral_any\ttarget_helped\ttarget_harmed\ttarget_lift\tsynonym_helped\tsynonym_harmed\tsynonym_lift\topposite_reverse_any\tstable_cases\tstable_target_helped\tstable_target_harmed\tstable_target_lift\n' \
    > "$SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        key = $1
        arm[key] = $2
        self_col = ($8 == "a") ? 16 : 17
        reverse_col = ($7 == "a") ? 16 : 17
        immediate_col = ($8 == "a") ? 14 : 15
        immediate[key, $9] = $immediate_col + 0
        any[key, $9] = $self_col + 0
        school[key, $9] = $10 SUBSEP $11
        if ($9 == "opposite")
            reverse[key] = $reverse_col + 0
        seen[key] = 1
    }
    END {
        for (key in seen) {
            scopes[1] = arm[key]
            scopes[2] = "pooled"
            for (s = 1; s <= 2; s++) {
                scope = scopes[s]
                cases[scope]++
                stable = school[key, "target"] == school[key, "synonym"] &&
                         school[key, "target"] == school[key, "neutral"] &&
                         school[key, "target"] == school[key, "opposite"]
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
                orv[scope] += reverse[key]
                if (stable) {
                    stable_cases[scope]++
                    if (any[key, "target"] && !any[key, "neutral"])
                        stable_helped[scope]++
                    if (!any[key, "target"] && any[key, "neutral"])
                        stable_harmed[scope]++
                }
            }
        }
        order[1] = "side-a"
        order[2] = "side-b"
        order[3] = "pooled"
        for (i = 1; i <= 3; i++) {
            scope = order[i]
            printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d",
                   scope, cases[scope], diverged[scope],
                   ti[scope], si[scope], ni[scope],
                   ta[scope], sa[scope], na[scope]
            stable_lift = 0
            if (stable_cases[scope] > 0)
                stable_lift = (stable_helped[scope] - stable_harmed[scope]) / stable_cases[scope]
            printf "\t%d\t%d\t%.6f\t%d\t%d\t%.6f\t%d\t%d\t%d\t%d\t%.6f\n",
                   th[scope], tm[scope],
                   (th[scope] - tm[scope]) / cases[scope],
                   sh[scope], sm[scope],
                   (sh[scope] - sm[scope]) / cases[scope],
                   orv[scope], stable_cases[scope],
                   stable_helped[scope], stable_harmed[scope], stable_lift
        }
    }
' "$RESULTS" >> "$SUMMARY"

BY_WORD="$OUT/by-word.tsv"
printf 'arm\tword\tcases\tschool_diverged\ttarget_any\tsynonym_any\tneutral_any\ttarget_helped\ttarget_harmed\ttarget_lift\tsynonym_helped\tsynonym_harmed\tsynonym_lift\topposite_reverse_any\n' \
    > "$BY_WORD"
awk -F '\t' '
    NR == 1 { next }
    {
        key = $1
        group[key] = $2 "\t" $6
        self_col = ($8 == "a") ? 16 : 17
        reverse_col = ($7 == "a") ? 16 : 17
        any[key, $9] = $self_col + 0
        school[key, $9] = $10 SUBSEP $11
        if ($9 == "opposite")
            reverse[key] = $reverse_col + 0
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
            opposite[group_name] += reverse[key]
            stable = school[key, "target"] == school[key, "synonym"] &&
                     school[key, "target"] == school[key, "neutral"] &&
                     school[key, "target"] == school[key, "opposite"]
            if (!stable) diverged[group_name]++
        }
        for (group_name in cases) {
            printf "%s\t%d\t%d\t%d\t%d\t%d",
                   group_name, cases[group_name], diverged[group_name],
                   target[group_name], synonym[group_name],
                   neutral[group_name]
            printf "\t%d\t%d\t%.6f\t%d\t%d\t%.6f\t%d\n",
                   target_helped[group_name], target_harmed[group_name],
                   (target_helped[group_name] - target_harmed[group_name]) / cases[group_name],
                   synonym_helped[group_name], synonym_harmed[group_name],
                   (synonym_helped[group_name] - synonym_harmed[group_name]) / cases[group_name],
                   opposite[group_name]
        }
    }
' "$RESULTS" | sort >> "$BY_WORD"

expected_summary=$'side-a\t64\t8\t1\t5\t0\t4\t8\t3\t2\t1\t0.015625\t6\t1\t0.078125\t23\t56\t2\t1\t0.017857\nside-b\t64\t8\t19\t19\t17\t26\t25\t27\t2\t3\t-0.015625\t3\t5\t-0.031250\t5\t56\t2\t2\t0.000000\npooled\t128\t16\t20\t24\t17\t30\t33\t30\t4\t4\t0.000000\t9\t6\t0.023438\t28\t112\t4\t3\t0.008929'
got_summary="$(tail -n +2 "$SUMMARY")"
[ "$got_summary" = "$expected_summary" ] || {
    printf 'unexpected population causal summary:\n%s\n' \
        "$got_summary" >&2
    exit 1
}

expected_by_word=$'side-a\tcavin\t16\t0\t0\t0\t0\t0\t0\t0.000000\t0\t0\t0.000000\t2\nside-a\tflom\t16\t0\t3\t5\t2\t2\t1\t0.062500\t4\t1\t0.187500\t16\nside-a\tlume\t16\t8\t0\t0\t0\t0\t0\t0.000000\t0\t0\t0.000000\t3\nside-a\tnareth\t16\t0\t1\t3\t1\t0\t0\t0.000000\t2\t0\t0.125000\t2\nside-b\tcavin\t16\t0\t4\t4\t3\t1\t0\t0.062500\t2\t1\t0.062500\t0\nside-b\tflom\t16\t0\t16\t16\t16\t0\t0\t0.000000\t0\t0\t0.000000\t2\nside-b\tlume\t16\t8\t0\t0\t1\t0\t1\t-0.062500\t0\t1\t-0.062500\t2\nside-b\tnareth\t16\t0\t6\t5\t7\t1\t2\t-0.062500\t1\t3\t-0.125000\t1'
got_by_word="$(tail -n +2 "$BY_WORD")"
[ "$got_by_word" = "$expected_by_word" ] || {
    printf 'unexpected population causal by-word result:\n%s\n' \
        "$got_by_word" >&2
    exit 1
}

(
    cd "$OUT"
    shasum -a 256 -c source-body.sha256 > /dev/null
    shasum -a 256 -c manifest.sha256 > /dev/null
    for bank in states/side-a-307 states/side-a-401 \
                states/side-b-307 states/side-b-401; do
        (cd "$bank" && shasum -a 256 -c snapshots.sha256 > /dev/null)
    done
)

cat "$SUMMARY"
printf '\nsealed manifest: %s\nresults: %s\n' "$MANIFEST" "$RESULTS"
