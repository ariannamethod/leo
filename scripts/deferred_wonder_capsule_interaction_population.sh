#!/usr/bin/env bash
# A.73: test A.72 capsule interactions on new, unselected persisted lives.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMPTS="$ROOT/scripts/deferred_wonder_capsule_interaction_fresh.txt"
ARMS="$ROOT/scripts/deferred_wonder_capsule_interaction_arms.tsv"
ACCEPTANCE="$ROOT/scripts/deferred_wonder_capsule_interaction_acceptance.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-capsule-interaction-population-$STAMP}"
SEEDS=(1709 1811 1907 2011)
TURNS=32
HORIZON=4

if [ "${LEO_CAPSULE_INTERACTION_PLAN_ONLY:-0}" = 1 ]; then
    factorial_count="$(awk -F '\t' 'NR > 1 && $6 == "factorial" {n++} END {print n + 0}' "$ARMS")"
    closure_count="$(awk -F '\t' 'NR > 1 && $6 == "closure-control" {n++} END {print n + 0}' "$ARMS")"
    unique_count="$(awk -F '\t' '
        NR > 1 && $6 == "factorial" {
            key = $2 $3 $4
            seen[key]++
        }
        END {
            for (key in seen) if (seen[key] == 1) n++
            print n + 0
        }
    ' "$ARMS")"
    anchor_count="$(awk '
        (NR - 1) % 4 == 0 && / man / {anchors++}
        END {print anchors + 0}
    ' "$PROMPTS")"
    [ "$factorial_count" -eq 8 ] &&
        [ "$unique_count" -eq 8 ] &&
        [ "$closure_count" -eq 1 ] &&
        [ "$(wc -l < "$PROMPTS" | tr -d ' ')" -eq "$TURNS" ] &&
        [ "$anchor_count" -eq 8 ] || {
        printf 'fresh interaction inputs do not satisfy the sealed design\n' >&2
        exit 1
    }
    printf 'source\tlives\tturns\tcases\tfactorial_arms\tclosure_arms\tvariants\thorizon\tschedule\tcontract\n'
    printf 'A.72\t%d\t%d\t%d\t%d\t%d\t3\t%d\tblock-rotated\tfresh-population-interaction\n' \
        "${#SEEDS[@]}" "$TURNS" "$((8 * ${#SEEDS[@]}))" \
        "$factorial_count" "$closure_count" "$HORIZON"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/bin" "$OUT/branches" "$OUT/states"
cp "$PROMPTS" "$OUT/prompts.txt"
cp "$ARMS" "$OUT/arms.tsv"
cp "$ACCEPTANCE" "$OUT/acceptance.tsv"
LEO_CAPSULE_INTERACTION_PLAN_ONLY=1 "$0" > "$OUT/sealed-plan.tsv"
(
    cd "$OUT"
    shasum -a 256 prompts.txt arms.tsv acceptance.tsv sealed-plan.tsv \
        > sealed-inputs.sha256
)

NATURAL="$OUT/body-source"
"$ROOT/scripts/deferred_wonder_appetite_natural_life.sh" "$NATURAL" \
    > "$OUT/body-source.out"
BODY="$NATURAL/body/state"
shasum -a 256 "$BODY" > "$OUT/source-body.sha256"

"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/capsule_path_branch_fixture.c" -lm \
    -o "$OUT/bin/capsule-path-branch"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
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
printf 'case\tseed\tturn\tobserve\ttarget\tfather\tperson\n' > "$MANIFEST"
for seed in "${SEEDS[@]}"; do
    cause=1
    while [ "$cause" -le 29 ]; do
        target="$(sed -n "${cause}p" "$OUT/prompts.txt")"
        father="$(replace_anchor "$target" father)"
        person="$(replace_anchor "$target" person)"
        observe=$((cause + HORIZON - 1))
        case_id="$(printf 'capsule-fresh-%s-t%02d' "$seed" "$cause")"
        printf '%s\t%s\t%d\t%d\t%s\t%s\t%s\n' \
            "$case_id" "$seed" "$cause" "$observe" \
            "$target" "$father" "$person" >> "$MANIFEST"
        cause=$((cause + 4))
    done
done
[ "$(($(wc -l < "$MANIFEST") - 1))" -eq 32 ] || {
    printf 'fresh manifest does not contain 32 cases\n' >&2
    exit 1
}
if grep -Eiq '(^|[^[:alpha:]])flom([^[:alpha:]]|$)' \
    "$OUT/prompts.txt" "$MANIFEST"; then
    printf 'fresh interaction population names Flom\n' >&2
    exit 1
fi
shasum -a 256 "$MANIFEST" > "$OUT/manifest.sha256"

# Grow each target life once and bank its exact pre-turn body.
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

BRANCH_ROWS="$OUT/branch-rows.tsv"
printf 'case\tarm\tvariant\trelative\tprompt\treply\tschool_outcome\tschool_candidate\tself_man\tself_woman\tconfounded\tgamma_primed\tgamma_gap\tdebt\tspores\n' \
    > "$BRANCH_ROWS"

tail -n +2 "$MANIFEST" |
while IFS=$'\t' read -r case_id seed cause observe target father person; do
    bank="$OUT/states/$seed"
    while IFS=$'\t' read -r arm ask be meaning capsule family; do
        [ "$arm" != arm ] || continue
        for variant in target father person; do
            case "$variant" in
                target) cause_prompt="$target" ;;
                father) cause_prompt="$father" ;;
                person) cause_prompt="$person" ;;
            esac
            branch="$OUT/branches/$case_id/$arm/$variant"
            mkdir -p "$branch"
            printf '%s\n' "$cause_prompt" > "$branch/prompts.txt"
            sed -n "$((cause + 1)),${observe}p" "$OUT/prompts.txt" \
                >> "$branch/prompts.txt"
            [ "$(wc -l < "$branch/prompts.txt" | tr -d ' ')" -eq "$HORIZON" ] || {
                printf '%s/%s/%s prompt horizon is not %d\n' \
                    "$case_id" "$arm" "$variant" "$HORIZON" >&2
                exit 1
            }
            cp "$bank/pre-$cause.state" "$branch/state"
            "$OUT/bin/capsule-path-branch" \
                "$branch/state" "$case_id" "$arm" "$variant" \
                "$seed" "$cause" "$branch/prompts.txt" "$branch/state" \
                1 "$be" "$ask" "$meaning" 1 "$capsule" \
                > "$branch/rows.tsv"
            cat "$branch/rows.tsv" >> "$BRANCH_ROWS"
            cut -f6 "$branch/rows.tsv" > "$branch/replies.txt"
            if [ "$arm" = abm111 ] && [ "$variant" = target ]; then
                sed -n "${cause},${observe}p" "$bank/replies.txt" \
                    > "$branch/expected-target.replies"
                cmp "$branch/replies.txt" \
                    "$branch/expected-target.replies"
            fi
        done
    done < "$OUT/arms.tsv"
done

arm_count="$(($(wc -l < "$OUT/arms.tsv") - 1))"
expected_rows="$((32 * arm_count * 3 * HORIZON))"
[ "$(($(wc -l < "$BRANCH_ROWS") - 1))" -eq "$expected_rows" ] || {
    printf 'branch trace does not contain %d rows\n' "$expected_rows" >&2
    exit 1
}

RESULTS="$OUT/results.tsv"
printf 'case\tarm\tvariant\timmediate_man\timmediate_woman\tany_man\tany_woman\tschool_outcome\tschool_candidate\tconfounded\n' \
    > "$RESULTS"
awk -F '\t' '
    NR == 1 { next }
    {
        key = $1 SUBSEP $2 SUBSEP $3
        seen[key] = 1
        case_id[key] = $1
        arm[key] = $2
        variant[key] = $3
        if ($4 == 1) {
            immediate_man[key] = $9 + 0
            immediate_woman[key] = $10 + 0
            school_outcome[key] = $7
            school_candidate[key] = $8
        }
        if ($9) any_man[key] = 1
        if ($10) any_woman[key] = 1
        confounded[key] += $11
    }
    END {
        for (key in seen)
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\t%s\t%d\n",
                   case_id[key], arm[key], variant[key],
                   immediate_man[key] + 0, immediate_woman[key] + 0,
                   any_man[key] + 0, any_woman[key] + 0,
                   school_outcome[key], school_candidate[key],
                   confounded[key] + 0
    }
' "$BRANCH_ROWS" | sort -t $'\t' -k1,1 -k2,2 -k3,3 >> "$RESULTS"
[ "$(($(wc -l < "$RESULTS") - 1))" -eq "$((32 * arm_count * 3))" ] || {
    printf 'results row count is wrong\n' >&2
    exit 1
}

awk -F '\t' '
    NR == 1 { next }
    {
        key = $1 SUBSEP $2
        outcome[key, $3] = $8
        candidate[key, $3] = $9
        if ($10 != 0) {
            printf "confounded branch: %s/%s/%s\n", $1, $2, $3 \
                > "/dev/stderr"
            bad = 1
        }
        seen[key] = 1
    }
    END {
        for (key in seen)
            if (outcome[key, "target"] != outcome[key, "father"] ||
                outcome[key, "target"] != outcome[key, "person"] ||
                candidate[key, "target"] != candidate[key, "father"] ||
                candidate[key, "target"] != candidate[key, "person"]) {
                printf "School geometry diverged: %s\n", key > "/dev/stderr"
                bad = 1
            }
        exit bad
    }
' "$RESULTS"

ARM_SUMMARY="$OUT/arm-summary.tsv"
printf 'arm\task\tbe\tmeaning\tcapsule\tfamily\tcases\tfather_any\ttarget_any\tperson_any\tcomplement_helped\tcomplement_harmed\tcomplement_lift\tcomplement_exact_p\tsurface_helped\tsurface_harmed\tsurface_lift\tsurface_exact_p\n' \
    > "$ARM_SUMMARY"
while IFS=$'\t' read -r selected_arm ask be meaning capsule family; do
    [ "$selected_arm" != arm ] || continue
    awk -F '\t' \
        -v selected_arm="$selected_arm" \
        -v ask="$ask" -v be="$be" -v meaning="$meaning" \
        -v capsule="$capsule" -v family="$family" '
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
        NR > 1 && $2 == selected_arm {
            any[$1, $3] = $7 + 0
            seen[$1] = 1
        }
        END {
            for (key in seen) {
                cases++
                father += any[key, "father"]
                target += any[key, "target"]
                person += any[key, "person"]
                cp = any[key, "father"] - any[key, "person"]
                sf = any[key, "father"] - any[key, "target"]
                if (cp > 0) cph++
                else if (cp < 0) cpm++
                if (sf > 0) sfh++
                else if (sf < 0) sfm++
            }
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d",
                   selected_arm, ask, be, meaning, capsule, family,
                   cases, father, target, person
            printf "\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%.6f\t%.6f\n",
                   cph, cpm, (cph - cpm) / cases, exact_p(cph, cpm),
                   sfh, sfm, (sfh - sfm) / cases, exact_p(sfh, sfm)
        }
    ' "$RESULTS" >> "$ARM_SUMMARY"
done < "$OUT/arms.tsv"

EFFECTS="$OUT/effects.tsv"
printf 'case\tseed\tturn\tcontrast\tASK_main\tBE_main\tmeaning_main\tASKxBE\tASKxmeaning\n' \
    > "$EFFECTS"
awk -F '\t' '
    function cfg(a, b, m) {
        return by_config[a b m]
    }
    function delta(a, c, contrast) {
        if (contrast == "father-person")
            return any[a, c, "father"] - any[a, c, "person"]
        return any[a, c, "father"] - any[a, c, "target"]
    }
    function emit(c, contrast,    a_main, b_main, m_main, ab, am, a, b, m) {
        for (b = 0; b <= 1; b++)
            for (m = 0; m <= 1; m++)
                a_main += (delta(cfg(1, b, m), c, contrast) - delta(cfg(0, b, m), c, contrast))
        for (a = 0; a <= 1; a++)
            for (m = 0; m <= 1; m++)
                b_main += (delta(cfg(a, 1, m), c, contrast) - delta(cfg(a, 0, m), c, contrast))
        for (a = 0; a <= 1; a++)
            for (b = 0; b <= 1; b++)
                m_main += (delta(cfg(a, b, 1), c, contrast) - delta(cfg(a, b, 0), c, contrast))
        for (m = 0; m <= 1; m++)
            ab += (delta(cfg(1, 1, m), c, contrast) - delta(cfg(0, 1, m), c, contrast) - delta(cfg(1, 0, m), c, contrast) + delta(cfg(0, 0, m), c, contrast))
        for (b = 0; b <= 1; b++)
            am += (delta(cfg(1, b, 1), c, contrast) - delta(cfg(0, b, 1), c, contrast) - delta(cfg(1, b, 0), c, contrast) + delta(cfg(0, b, 0), c, contrast))
        printf "%s\t%s\t%s\t%s\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\n",
               c, seed[c], turn[c], contrast,
               a_main / 4, b_main / 4, m_main / 4, ab / 2, am / 2
    }
    FILENAME == ARGV[1] && FNR > 1 && $6 == "factorial" {
        by_config[$2 $3 $4] = $1
        next
    }
    FILENAME == ARGV[2] && FNR > 1 {
        seed[$1] = $2
        turn[$1] = $3
        cases[$1] = 1
        next
    }
    FILENAME == ARGV[3] && FNR > 1 {
        any[$2, $1, $3] = $7 + 0
        next
    }
    END {
        for (c in cases) {
            emit(c, "father-person")
            emit(c, "father-man")
        }
    }
' "$OUT/arms.tsv" "$MANIFEST" "$RESULTS" |
    sort -t $'\t' -k1,1 -k4,4 >> "$EFFECTS"

BY_SEED="$OUT/effects-by-seed.tsv"
printf 'seed\thypothesis\tcontrast\tcases\tmean\tpositive\tnegative\tzero\n' \
    > "$BY_SEED"
awk -F '\t' '
    NR == 1 { next }
    {
        for (i = 1; i <= 3; i++) {
            if (i == 1) { h = "ASK-main"; v = $5 + 0 }
            else if (i == 2) { h = "ASKxBE"; v = $8 + 0 }
            else { h = "ASKxmeaning"; v = $9 + 0 }
            key = $2 SUBSEP h SUBSEP $4
            seed[key] = $2
            hypothesis[key] = h
            contrast[key] = $4
            cases[key]++
            sum[key] += v
            if (v > 0.0000001) positive[key]++
            else if (v < -0.0000001) negative[key]++
            else zero[key]++
            seen[key] = 1
        }
    }
    END {
        for (key in seen)
            printf "%s\t%s\t%s\t%d\t%.6f\t%d\t%d\t%d\n",
                   seed[key], hypothesis[key], contrast[key],
                   cases[key], sum[key] / cases[key],
                   positive[key], negative[key], zero[key]
    }
' "$EFFECTS" | sort -t $'\t' -k1,1n -k2,2 -k3,3 >> "$BY_SEED"

EFFECT_SUMMARY="$OUT/effects-summary.tsv"
printf 'hypothesis\tcontrast\tcases\tmean\tpositive\tnegative\tzero\texact_sign_p\tpositive_seeds\tnegative_seeds\tzero_seeds\tstatus\n' \
    > "$EFFECT_SUMMARY"
awk -F '\t' '
    function choose(n, k,    i, value) {
        if (k > n - k) k = n - k
        value = 1
        for (i = 1; i <= k; i++)
            value = value * (n - k + i) / i
        return value
    }
    function exact_p(positive, negative,    n, tail, i, p) {
        n = positive + negative
        if (n == 0) return 1
        tail = (positive < negative) ? positive : negative
        p = 0
        for (i = 0; i <= tail; i++)
            p += choose(n, i) / (2 ^ n)
        p *= 2
        return (p > 1) ? 1 : p
    }
    FILENAME == ARGV[1] && FNR > 1 {
        for (i = 1; i <= 3; i++) {
            if (i == 1) { h = "ASK-main"; v = $5 + 0 }
            else if (i == 2) { h = "ASKxBE"; v = $8 + 0 }
            else { h = "ASKxmeaning"; v = $9 + 0 }
            key = h SUBSEP $4
            cases[key]++
            sum[key] += v
            if (v > 0.0000001) positive[key]++
            else if (v < -0.0000001) negative[key]++
            else zero[key]++
        }
        next
    }
    FILENAME == ARGV[2] && FNR > 1 {
        key = $2 SUBSEP $3
        if ($5 > 0.0000001) positive_seeds[key]++
        else if ($5 < -0.0000001) negative_seeds[key]++
        else zero_seeds[key]++
        next
    }
    END {
        order[1] = "ASK-main"
        order[2] = "ASKxmeaning"
        order[3] = "ASKxBE"
        contrast[1] = "father-person"
        contrast[2] = "father-man"
        for (i = 1; i <= 3; i++)
            for (j = 1; j <= 2; j++) {
                key = order[i] SUBSEP contrast[j]
                mean = sum[key] / cases[key]
                if (mean > 0 && positive_seeds[key] >= 3)
                    status = "direction-breadth"
                else if (mean > 0)
                    status = "direction-only"
                else
                    status = "not-replicated"
                printf "%s\t%s\t%d\t%.6f\t%d\t%d\t%d\t%.6f",
                       order[i], contrast[j], cases[key], mean,
                       positive[key], negative[key], zero[key],
                       exact_p(positive[key], negative[key])
                printf "\t%d\t%d\t%d\t%s\n",
                       positive_seeds[key], negative_seeds[key],
                       zero_seeds[key], status
            }
    }
' "$EFFECTS" "$BY_SEED" >> "$EFFECT_SUMMARY"

VERDICT="$OUT/verdict.tsv"
printf 'hypothesis\tverdict\tfather_person_mean\tfather_man_mean\tfather_person_positive_seeds\tfather_man_positive_seeds\n' \
    > "$VERDICT"
awk -F '\t' '
    NR > 1 {
        mean[$1, $2] = $4
        seeds[$1, $2] = $9
        status[$1, $2] = $12
    }
    END {
        order[1] = "ASK-main"
        order[2] = "ASKxmeaning"
        order[3] = "ASKxBE"
        for (i = 1; i <= 3; i++) {
            h = order[i]
            if (status[h, "father-person"] == "direction-breadth" &&
                status[h, "father-man"] == "direction-breadth")
                verdict = (h == "ASKxBE") ? "generalized" : "replicated"
            else if (mean[h, "father-person"] > 0 &&
                     mean[h, "father-man"] > 0)
                verdict = "direction-only"
            else
                verdict = "not-replicated"
            printf "%s\t%s\t%.6f\t%.6f\t%d\t%d\n",
                   h, verdict,
                   mean[h, "father-person"], mean[h, "father-man"],
                   seeds[h, "father-person"], seeds[h, "father-man"]
        }
    }
' "$EFFECT_SUMMARY" >> "$VERDICT"

(
    cd "$OUT"
    shasum -a 256 -c sealed-inputs.sha256 > /dev/null
    shasum -a 256 -c source-body.sha256 > /dev/null
    shasum -a 256 -c manifest.sha256 > /dev/null
    for bank in states/1709 states/1811 states/1907 states/2011; do
        (cd "$bank" && shasum -a 256 -c snapshots.sha256 > /dev/null)
    done
    shasum -a 256 manifest.tsv branch-rows.tsv results.tsv \
        arm-summary.tsv effects.tsv effects-by-seed.tsv \
        effects-summary.tsv verdict.tsv > receipt.sha256
    printf '%s\n' \
        '451d8ea794cf391bf0ca4fe542eabfd2001c4775df12e19afba8aedcb4fd63fe  arm-summary.tsv' \
        '79875f9278430f15a753fb433b3ded3c7e5ac34e6e731a734646c64c21cd588b  effects-summary.tsv' \
        '7c16bbb8d606e9596e903a7d49e7d46dceaaf69c1f5629ed8d391af96dd4f109  verdict.tsv' \
        > expected-results.sha256
    shasum -a 256 -c expected-results.sha256 > /dev/null
)

cat "$ARM_SUMMARY"
printf '\n'
cat "$EFFECT_SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nmanifest: %s\nbranch rows: %s\n' "$MANIFEST" "$BRANCH_ROWS"
