#!/usr/bin/env bash
# A.72: factor the measured capsule path without changing Leo's default body.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARMS="$ROOT/scripts/deferred_wonder_capsule_path_arms.tsv"
ACCEPTANCE="$ROOT/scripts/deferred_wonder_capsule_path_acceptance.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-capsule-path-factorial-$STAMP}"
HORIZON=4

if [ "${LEO_CAPSULE_PATH_PLAN_ONLY:-0}" = 1 ]; then
    factorial_count="$(awk -F '\t' 'NR > 1 && $8 == "factorial" {n++} END {print n + 0}' "$ARMS")"
    closure_count="$(awk -F '\t' 'NR > 1 && $8 == "closure-control" {n++} END {print n + 0}' "$ARMS")"
    unique_count="$(awk -F '\t' '
        NR > 1 && $8 == "factorial" {
            key = $2 $3 $4 $5 $6
            seen[key]++
        }
        END {
            for (key in seen) if (seen[key] == 1) n++
            print n + 0
        }
    ' "$ARMS")"
    [ "$factorial_count" -eq 32 ] &&
        [ "$unique_count" -eq 32 ] &&
        [ "$closure_count" -eq 1 ] || {
        printf 'capsule arm table is not a complete 2^5 factorial\n' >&2
        exit 1
    }
    printf 'source\tselected_states\tfactorial_arms\tclosure_arms\tvariants\thorizon\tpaired_contexts_per_factor\tcontract\n'
    printf 'A.71\t9\t%d\t%d\t3\t%d\t16\texact-state-capsule-factorization\n' \
        "$factorial_count" "$closure_count" "$HORIZON"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/bin" "$OUT/branches"
cp "$ARMS" "$OUT/arms.tsv"
cp "$ACCEPTANCE" "$OUT/acceptance.tsv"
LEO_CAPSULE_PATH_PLAN_ONLY=1 "$0" > "$OUT/sealed-plan.tsv"
(
    cd "$OUT"
    shasum -a 256 arms.tsv acceptance.tsv sealed-plan.tsv \
        > sealed-inputs.sha256
)

SOURCE="$OUT/source-a71"
"$ROOT/scripts/deferred_wonder_father_path_localization.sh" "$SOURCE" \
    > "$OUT/source-a71.out"

WITNESSES="$SOURCE/witnesses.tsv"
[ "$(($(wc -l < "$WITNESSES") - 1))" -eq 9 ] || {
    printf 'A.71 source does not contain nine selected states\n' >&2
    exit 1
}

"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/capsule_path_branch_fixture.c" -lm \
    -o "$OUT/bin/capsule-path-branch"

BRANCH_ROWS="$OUT/branch-rows.tsv"
printf 'case\tarm\tvariant\trelative\tprompt\treply\tschool_outcome\tschool_candidate\tself_man\tself_woman\tconfounded\tgamma_primed\tgamma_gap\tdebt\tspores\n' \
    > "$BRANCH_ROWS"

tail -n +2 "$WITNESSES" |
while IFS=$'\t' read -r case_id seed cause observe \
        target father person source_target source_father source_person \
        source_complement source_surface; do
    source_case="$SOURCE/source-a70/cases/$case_id"
    while IFS=$'\t' read -r arm pull be ask meaning diary capsule family; do
        [ "$arm" != arm ] || continue
        for variant in target father person; do
            case "$variant" in
                target) cause_prompt="$target"; source_variant=target ;;
                father) cause_prompt="$father"; source_variant=synonym ;;
                person) cause_prompt="$person"; source_variant=neutral ;;
            esac
            branch="$OUT/branches/$case_id/$arm/$variant"
            mkdir -p "$branch"
            printf '%s\n' "$cause_prompt" > "$branch/prompts.txt"
            sed -n "$((cause + 1)),${observe}p" \
                "$SOURCE/source-a70/prompts.txt" >> "$branch/prompts.txt"
            [ "$(wc -l < "$branch/prompts.txt" | tr -d ' ')" -eq "$HORIZON" ] || {
                printf '%s/%s/%s prompt horizon is not %d\n' \
                    "$case_id" "$arm" "$variant" "$HORIZON" >&2
                exit 1
            }
            cp "$source_case/pre.state" "$branch/state"
            "$OUT/bin/capsule-path-branch" \
                "$branch/state" "$case_id" "$arm" "$variant" \
                "$seed" "$cause" "$branch/prompts.txt" "$branch/state" \
                "$pull" "$be" "$ask" "$meaning" "$diary" "$capsule" \
                > "$branch/rows.tsv"
            cat "$branch/rows.tsv" >> "$BRANCH_ROWS"

            cut -f6 "$branch/rows.tsv" > "$branch/replies.txt"
            if [ "$arm" = f11111 ]; then
                cmp "$branch/replies.txt" \
                    "$source_case/$source_variant/replies.txt"
            elif [ "$arm" = no-capsule ]; then
                cut -f6 \
                    "$SOURCE/branches/$case_id/no-capsule/$variant/rows.tsv" \
                    > "$branch/a71-no-capsule-replies.txt"
                cmp "$branch/replies.txt" \
                    "$branch/a71-no-capsule-replies.txt"
                cmp "$branch/replies.txt" \
                    "$OUT/branches/$case_id/f00000/$variant/replies.txt"
            fi
        done
    done < "$OUT/arms.tsv"
done

arm_count="$(($(wc -l < "$OUT/arms.tsv") - 1))"
expected_rows="$((9 * arm_count * 3 * HORIZON))"
[ "$(($(wc -l < "$BRANCH_ROWS") - 1))" -eq "$expected_rows" ] || {
    printf 'branch trace does not contain %d rows\n' "$expected_rows" >&2
    exit 1
}

RESULTS="$OUT/results.tsv"
printf 'case\tarm\tvariant\timmediate_man\timmediate_woman\tany_man\tany_woman\tschool_outcome\tschool_candidate\tconfounded\tfinal_gamma_primed\tfinal_gamma_gap\tfinal_debt\tfinal_spores\n' \
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
        if ($4 == 4) {
            final_primed[key] = $12 + 0
            final_gap[key] = $13 + 0
            final_debt[key] = $14 + 0
            final_spores[key] = $15 + 0
        }
    }
    END {
        for (key in seen)
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\t%s\t%d\t%d\t%.9g\t%.9g\t%d\n",
                   case_id[key], arm[key], variant[key],
                   immediate_man[key] + 0, immediate_woman[key] + 0,
                   any_man[key] + 0, any_woman[key] + 0,
                   school_outcome[key], school_candidate[key],
                   confounded[key] + 0, final_primed[key] + 0,
                   final_gap[key] + 0, final_debt[key] + 0,
                   final_spores[key] + 0
    }
' "$BRANCH_ROWS" | sort -t $'\t' -k1,1 -k2,2 -k3,3 >> "$RESULTS"
[ "$(($(wc -l < "$RESULTS") - 1))" -eq "$((9 * arm_count * 3))" ] || {
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

SUMMARY="$OUT/summary.tsv"
printf 'arm\tpull\tbe\task\tmeaning\tdiary\tcapsule\tfamily\tcases\tfather_any\ttarget_any\tperson_any\tcomplement_helped\tcomplement_harmed\tcomplement_lift\tcomplement_exact_p\tsurface_helped\tsurface_harmed\tsurface_lift\tsurface_exact_p\tcomplement_positive_preserved\tcomplement_positive_erased\tcomplement_positive_reversed\tcomplement_negative_preserved\tcomplement_class\tsurface_positive_preserved\tsurface_positive_erased\tsurface_positive_reversed\tsurface_negative_preserved\tsurface_class\n' \
    > "$SUMMARY"

while IFS=$'\t' read -r selected_arm pull be ask meaning diary capsule family; do
    [ "$selected_arm" != arm ] || continue
    awk -F '\t' \
        -v selected_arm="$selected_arm" \
        -v pull="$pull" -v be="$be" -v ask="$ask" \
        -v meaning="$meaning" -v diary="$diary" \
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
        FILENAME == ARGV[1] && FNR > 1 {
            base_complement[$1] = $11 + 0
            base_surface[$1] = $12 + 0
            next
        }
        FILENAME == ARGV[2] && FNR > 1 && $2 == selected_arm {
            any[$1, $3] = $7 + 0
            seen[$1] = 1
        }
        END {
            for (key in seen) {
                cases++
                father += any[key, "father"]
                target += any[key, "target"]
                person += any[key, "person"]
                delta = any[key, "father"] - any[key, "person"]
                if (delta == 1) helped++
                else if (delta == -1) harmed++
                surface_delta = any[key, "father"] - any[key, "target"]
                if (surface_delta == 1) surface_helped++
                else if (surface_delta == -1) surface_harmed++
                if (base_complement[key] == 1) {
                    if (delta == 1) cp_preserved++
                    else if (delta == 0) cp_erased++
                    else cp_reversed++
                } else if (base_complement[key] == -1 && delta == -1) {
                    cn_preserved++
                }
                if (base_surface[key] == 1) {
                    if (surface_delta == 1) sp_preserved++
                    else if (surface_delta == 0) sp_erased++
                    else sp_reversed++
                } else if (base_surface[key] == -1 &&
                           surface_delta == -1) {
                    sn_preserved++
                }
            }
            if (cp_erased + cp_reversed >= 6)
                complement_verdict = "candidate-conduit"
            else if (cp_preserved >= 6)
                complement_verdict = "not-necessary"
            else
                complement_verdict = "mixed"
            if (sp_erased + sp_reversed >= 5)
                surface_verdict = "candidate-conduit"
            else if (sp_preserved >= 5)
                surface_verdict = "not-necessary"
            else
                surface_verdict = "mixed"
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s",
                   selected_arm, pull, be, ask, meaning, diary,
                   capsule, family
            printf "\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f",
                   cases, father, target, person, helped, harmed,
                   (helped - harmed) / cases, exact_p(helped, harmed)
            printf "\t%d\t%d\t%.6f\t%.6f",
                   surface_helped, surface_harmed,
                   (surface_helped - surface_harmed) / cases,
                   exact_p(surface_helped, surface_harmed)
            printf "\t%d\t%d\t%d\t%d\t%s",
                   cp_preserved, cp_erased, cp_reversed,
                   cn_preserved, complement_verdict
            printf "\t%d\t%d\t%d\t%d\t%s\n",
                   sp_preserved, sp_erased, sp_reversed,
                   sn_preserved, surface_verdict
        }
    ' "$WITNESSES" "$RESULTS" >> "$SUMMARY"
done < "$OUT/arms.tsv"

expected_default=$'f11111\t1\t1\t1\t1\t1\t1\tfactorial\t9\t8\t2\t1\t8\t1\t0.777778\t0.039062\t7\t1\t0.666667\t0.070312\t8\t0\t0\t1\tnot-necessary\t7\t0\t0\t1\tnot-necessary'
got_default="$(awk -F '\t' '$1 == "f11111" {print}' "$SUMMARY")"
[ "$got_default" = "$expected_default" ] || {
    printf 'factorial default does not reproduce A.71:\n%s\n' \
        "$got_default" >&2
    exit 1
}

expected_no_capsule=$'no-capsule\t0\t0\t0\t0\t0\t0\tclosure-control\t9\t3\t1\t1\t2\t0\t0.222222\t0.500000\t2\t0\t0.222222\t0.500000\t2\t6\t0\t0\tcandidate-conduit\t2\t5\t0\t0\tcandidate-conduit'
got_no_capsule="$(awk -F '\t' '$1 == "no-capsule" {print}' "$SUMMARY")"
[ "$got_no_capsule" = "$expected_no_capsule" ] || {
    printf 'no-capsule control does not reproduce A.71:\n%s\n' \
        "$got_no_capsule" >&2
    exit 1
}

SINGLES="$OUT/single-ablation.tsv"
printf 'channel\tarm\tcomplement_positive_preserved\tcomplement_positive_erased\tcomplement_positive_reversed\tcomplement_class\tsurface_positive_preserved\tsurface_positive_erased\tsurface_positive_reversed\tsurface_class\n' \
    > "$SINGLES"
awk -F '\t' '
    BEGIN {
        channel["f01111"] = "gamma-pull"
        channel["f10111"] = "BE"
        channel["f11011"] = "ASK"
        channel["f11101"] = "meaning-resonance"
        channel["f11110"] = "gamma-diary"
    }
    NR > 1 && ($1 in channel) {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
               channel[$1], $1, $21, $22, $23, $25,
               $26, $27, $28, $30
    }
' "$SUMMARY" | sort >> "$SINGLES"

MARGINAL="$OUT/marginal-effects.tsv"
printf 'channel\tcontrast\tpaired_cases\ton_greater\toff_greater\tequal\tmean_on\tmean_off\tmean_marginal\n' \
    > "$MARGINAL"
awk -F '\t' '
    function config_key(a, replace, value,    i, key, v) {
        key = ""
        for (i = 1; i <= 5; i++) {
            v = (i == replace) ? value : bit[a, i]
            key = key v
        }
        return key
    }
    function contrast_delta(a, c, contrast) {
        if (contrast == "father-person")
            return any[a, c, "father"] - any[a, c, "person"]
        return any[a, c, "father"] - any[a, c, "target"]
    }
    function emit(fi, name, contrast,    a, on, c, on_d, off_d,
                  pairs, on_gt, off_gt, equal, sum_on, sum_off) {
        for (a in factorial) {
            if (bit[a, fi] != 0) continue
            on = by_config[config_key(a, fi, 1)]
            if (on == "") {
                printf "missing opposite arm for %s/%s\n", name, a \
                    > "/dev/stderr"
                bad = 1
                continue
            }
            for (c in cases) {
                off_d = contrast_delta(a, c, contrast)
                on_d = contrast_delta(on, c, contrast)
                pairs++
                sum_on += on_d
                sum_off += off_d
                if (on_d > off_d) on_gt++
                else if (off_d > on_d) off_gt++
                else equal++
            }
        }
        printf "%s\t%s\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%.6f\n",
               name, contrast, pairs, on_gt, off_gt, equal,
               sum_on / pairs, sum_off / pairs,
               (sum_on - sum_off) / pairs
    }
    FILENAME == ARGV[1] && FNR > 1 && $8 == "factorial" {
        factorial[$1] = 1
        for (i = 1; i <= 5; i++) bit[$1, i] = $(i + 1) + 0
        by_config[$2 $3 $4 $5 $6] = $1
        next
    }
    FILENAME == ARGV[2] && FNR > 1 {
        any[$2, $1, $3] = $7 + 0
        cases[$1] = 1
        next
    }
    END {
        names[1] = "gamma-pull"
        names[2] = "BE"
        names[3] = "ASK"
        names[4] = "meaning-resonance"
        names[5] = "gamma-diary"
        for (i = 1; i <= 5; i++) {
            emit(i, names[i], "father-person")
            emit(i, names[i], "father-man")
        }
        exit bad
    }
' "$OUT/arms.tsv" "$RESULTS" >> "$MARGINAL"

expected_analysis_hashes=$'151b8255b77da359064f9fdad30d240c5902bff8f4e88585077d807a06f51b78  summary.tsv\n109a60193caa4cdcce5665ab5a9fad0078fa58ffb744fe179f0c7ecfdf595c51  single-ablation.tsv\n0efe5d96ce8e0144ffe0c263f04eed577701448d90fc920d15dbbcbf042853e1  marginal-effects.tsv'
got_analysis_hashes="$(
    cd "$OUT"
    shasum -a 256 summary.tsv single-ablation.tsv marginal-effects.tsv
)"
[ "$got_analysis_hashes" = "$expected_analysis_hashes" ] || {
    printf 'capsule factorial analysis changed:\n%s\n' \
        "$got_analysis_hashes" >&2
    exit 1
}

(
    cd "$OUT"
    shasum -a 256 -c sealed-inputs.sha256 > /dev/null
    shasum -a 256 source-a71/witnesses.tsv \
        branch-rows.tsv results.tsv summary.tsv \
        single-ablation.tsv marginal-effects.tsv > receipt.sha256
)

cat "$SINGLES"
printf '\n'
cat "$MARGINAL"
printf '\nsummary: %s\nbranch rows: %s\n' "$SUMMARY" "$BRANCH_ROWS"
