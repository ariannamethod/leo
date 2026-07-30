#!/usr/bin/env bash
# A.71: localize the measured father surface without changing Leo's body.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARMS="$ROOT/scripts/deferred_wonder_father_path_arms.tsv"
ACCEPTANCE="$ROOT/scripts/deferred_wonder_father_path_acceptance.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-father-path-localization-$STAMP}"
HORIZON=4

if [ "${LEO_FATHER_PATH_PLAN_ONLY:-0}" = 1 ]; then
    printf 'source\tcases\twitnesses\tarms\tvariants\thorizon\tcontract\n'
    printf 'A.70\t64\t9\t%d\t3\t%d\texact-state-conditional-localization\n' \
        "$(($(wc -l < "$ARMS") - 1))" "$HORIZON"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/bin" "$OUT/branches"
cp "$ARMS" "$OUT/arms.tsv"
cp "$ACCEPTANCE" "$OUT/acceptance.tsv"
LEO_FATHER_PATH_PLAN_ONLY=1 "$0" > "$OUT/sealed-plan.tsv"
(
    cd "$OUT"
    shasum -a 256 arms.tsv acceptance.tsv sealed-plan.tsv \
        > sealed-inputs.sha256
)

SOURCE="$OUT/source-a70"
"$ROOT/scripts/deferred_wonder_appetite_flom_third_life.sh" "$SOURCE" \
    > "$OUT/source-a70.out"

expected_source=$'64\t0\t1\t5\t0\t13\t19\t12\t2\t1\t0.015625\t1.000000\t8\t1\t0.109375\t0.039062\t64\t2\t1\t0.015625'
got_source="$(tail -n +2 "$SOURCE/summary.tsv")"
[ "$got_source" = "$expected_source" ] || {
    printf 'A.70 source summary changed:\n%s\n' "$got_source" >&2
    exit 1
}

WITNESSES="$OUT/witnesses.tsv"
awk -F '\t' '
    FILENAME == ARGV[1] && FNR > 1 {
        any[$1, $8] = $16 + 0
        next
    }
    FILENAME == ARGV[2] && FNR == 1 {
        printf "case\tseed\tcause\tobserve\ttarget\tfather\tperson\t"
        print "target_any\tfather_any\tperson_any\tcomplement_delta\tsurface_delta"
        next
    }
    FILENAME == ARGV[2] && FNR > 1 &&
            any[$1, "synonym"] != any[$1, "neutral"] {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\n",
               $1, $2, $3, $4, $8, $9, $10,
               any[$1, "target"], any[$1, "synonym"], any[$1, "neutral"],
               any[$1, "synonym"] - any[$1, "neutral"],
               any[$1, "synonym"] - any[$1, "target"]
    }
' "$SOURCE/results.tsv" "$SOURCE/manifest.tsv" > "$WITNESSES"

expected_witnesses=$'flom-907-t05\t907\t5\t8\tWhat might a man notice beside an empty table?\tWhat might a father notice beside an empty table?\tWhat might a person notice beside an empty table?\t0\t1\t0\t1\t1\nflom-907-t17\t907\t17\t20\tHow does a man listen to something unnamed?\tHow does a father listen to something unnamed?\tHow does a person listen to something unnamed?\t0\t1\t0\t1\t1\nflom-1013-t17\t1013\t17\t20\tHow does a man listen to something unnamed?\tHow does a father listen to something unnamed?\tHow does a person listen to something unnamed?\t0\t1\t0\t1\t1\nflom-1109-t09\t1109\t9\t12\tWhen does a man know that a question matters?\tWhen does a father know that a question matters?\tWhen does a person know that a question matters?\t0\t1\t0\t1\t1\nflom-1109-t21\t1109\t21\t24\tWhat does a man keep from a forgotten song?\tWhat does a father keep from a forgotten song?\tWhat does a person keep from a forgotten song?\t1\t0\t1\t-1\t-1\nflom-1307-t17\t1307\t17\t20\tHow does a man listen to something unnamed?\tHow does a father listen to something unnamed?\tHow does a person listen to something unnamed?\t0\t1\t0\t1\t1\nflom-1511-t13\t1511\t13\t16\tWhat would a man ask an unopened letter?\tWhat would a father ask an unopened letter?\tWhat would a person ask an unopened letter?\t1\t1\t0\t1\t0\nflom-1511-t21\t1511\t21\t24\tWhat does a man keep from a forgotten song?\tWhat does a father keep from a forgotten song?\tWhat does a person keep from a forgotten song?\t0\t1\t0\t1\t1\nflom-1601-t17\t1601\t17\t20\tHow does a man listen to something unnamed?\tHow does a father listen to something unnamed?\tHow does a person listen to something unnamed?\t0\t1\t0\t1\t1'
got_witnesses="$(tail -n +2 "$WITNESSES")"
[ "$got_witnesses" = "$expected_witnesses" ] || {
    printf 'A.70 witness set changed:\n%s\n' "$got_witnesses" >&2
    exit 1
}

"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/father_path_cartography_fixture.c" -lm \
    -o "$OUT/bin/father-path-cartography"
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/father_path_branch_fixture.c" -lm \
    -o "$OUT/bin/father-path-branch"

CARTOGRAPHY="$OUT/cartography.tsv"
printf 'case\tvariant\tphase\tman_sum\tman_max\tman_words\twoman_sum\twoman_max\twoman_words\ttop\n' \
    > "$CARTOGRAPHY"
tail -n +2 "$SOURCE/manifest.tsv" |
while IFS=$'\t' read -r case_id seed cause observe word \
        external_side self_side target father person; do
    state="$SOURCE/states/$seed/pre-$cause.state"
    "$OUT/bin/father-path-cartography" \
        "$state" "$case_id" target "$target" >> "$CARTOGRAPHY"
    "$OUT/bin/father-path-cartography" \
        "$state" "$case_id" father "$father" >> "$CARTOGRAPHY"
    "$OUT/bin/father-path-cartography" \
        "$state" "$case_id" person "$person" >> "$CARTOGRAPHY"
done
[ "$(($(wc -l < "$CARTOGRAPHY") - 1))" -eq 384 ] || {
    printf 'cartography does not contain 384 rows\n' >&2
    exit 1
}

CARTOGRAPHY_SUMMARY="$OUT/cartography-summary.tsv"
printf 'phase\tcases\tfather_woman_mean\ttarget_woman_mean\tperson_woman_mean\tfather_gt_person\tfather_eq_person\tfather_lt_person\tfather_gt_target\tfather_eq_target\tfather_lt_target\n' \
    > "$CARTOGRAPHY_SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        key = $1 SUBSEP $3
        value[key, $2] = $7 + 0
        phase[key] = $3
        seen[key] = 1
    }
    END {
        for (key in seen) {
            p = phase[key]
            cases[p]++
            father[p] += value[key, "father"]
            target[p] += value[key, "target"]
            person[p] += value[key, "person"]
            if (value[key, "father"] > value[key, "person"]) fgp[p]++
            else if (value[key, "father"] == value[key, "person"]) fep[p]++
            else flp[p]++
            if (value[key, "father"] > value[key, "target"]) fgt[p]++
            else if (value[key, "father"] == value[key, "target"]) fet[p]++
            else flt[p]++
        }
        order[1] = "pre"
        order[2] = "post"
        for (i = 1; i <= 2; i++) {
            p = order[i]
            printf "%s\t%d\t%.6f\t%.6f\t%.6f\t%d\t%d\t%d\t%d\t%d\t%d\n",
                   p, cases[p], father[p] / cases[p],
                   target[p] / cases[p], person[p] / cases[p],
                   fgp[p], fep[p], flp[p], fgt[p], fet[p], flt[p]
        }
    }
' "$CARTOGRAPHY" >> "$CARTOGRAPHY_SUMMARY"

BRANCH_ROWS="$OUT/branch-rows.tsv"
printf 'case\tarm\tvariant\trelative\tprompt\treply\tschool_outcome\tschool_candidate\tself_man\tself_woman\tconfounded\n' \
    > "$BRANCH_ROWS"

tail -n +2 "$WITNESSES" |
while IFS=$'\t' read -r case_id seed cause observe \
        target father person source_target source_father source_person \
        source_complement source_surface; do
    source_case="$SOURCE/cases/$case_id"
    while IFS=$'\t' read -r arm flag family; do
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
            sed -n "$((cause + 1)),${observe}p" "$SOURCE/prompts.txt" \
                >> "$branch/prompts.txt"
            [ "$(wc -l < "$branch/prompts.txt" | tr -d ' ')" -eq "$HORIZON" ] || {
                printf '%s/%s/%s prompt horizon is not %d\n' \
                    "$case_id" "$arm" "$variant" "$HORIZON" >&2
                exit 1
            }
            cp "$source_case/pre.state" "$branch/state"
            "$OUT/bin/father-path-branch" \
                "$branch/state" "$case_id" "$arm" "$variant" \
                "$seed" "$cause" "$branch/prompts.txt" "$branch/state" \
                > "$branch/rows.tsv"
            cat "$branch/rows.tsv" >> "$BRANCH_ROWS"
            if [ "$arm" = default ]; then
                cut -f6 "$branch/rows.tsv" > "$branch/replies.txt"
                cmp "$branch/replies.txt" \
                    "$source_case/$source_variant/replies.txt"
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
printf 'arm\tfamily\tcases\tfather_any\ttarget_any\tperson_any\tcomplement_helped\tcomplement_harmed\tcomplement_lift\tcomplement_exact_p\tsurface_helped\tsurface_harmed\tsurface_lift\tsurface_exact_p\tcomplement_positive_preserved\tcomplement_positive_erased\tcomplement_positive_reversed\tcomplement_negative_preserved\tcomplement_class\tsurface_positive_preserved\tsurface_positive_erased\tsurface_positive_reversed\tsurface_negative_preserved\tsurface_class\n' \
    > "$SUMMARY"

while IFS=$'\t' read -r selected_arm flag family; do
    [ "$selected_arm" != arm ] || continue
    awk -F '\t' -v selected_arm="$selected_arm" -v family="$family" '
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
                if (any[key, "father"] && !any[key, "target"]) fth++
                if (!any[key, "father"] && any[key, "target"]) ftm++
                surface_delta = any[key, "father"] - any[key, "target"]
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
            printf "%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f",
                   selected_arm, family, cases, father, target, person,
                   helped, harmed, (helped - harmed) / cases,
                   exact_p(helped, harmed)
            printf "\t%d\t%d\t%.6f\t%.6f",
                   fth, ftm, (fth - ftm) / cases, exact_p(fth, ftm)
            printf "\t%d\t%d\t%d\t%d\t%s",
                   cp_preserved, cp_erased, cp_reversed,
                   cn_preserved, complement_verdict
            printf "\t%d\t%d\t%d\t%d\t%s\n",
                   sp_preserved, sp_erased, sp_reversed,
                   sn_preserved, surface_verdict
        }
    ' "$WITNESSES" "$RESULTS" >> "$SUMMARY"
done < "$OUT/arms.tsv"

default_row="$(awk -F '\t' '$1 == "default" {print}' "$SUMMARY")"
expected_default=$'default\tbaseline\t9\t8\t2\t1\t8\t1\t0.777778\t0.039062\t7\t1\t0.666667\t0.070312\t8\t0\t0\t1\tnot-necessary\t7\t0\t0\t1\tnot-necessary'
[ "$default_row" = "$expected_default" ] || {
    printf 'default fixture result does not reproduce A.70 witnesses:\n%s\n' \
        "$default_row" >&2
    exit 1
}

expected_cartography=$'pre\t64\t0.011639\t0.004176\t0.004230\t56\t0\t8\t56\t0\t8\npost\t64\t0.011639\t0.004176\t0.004230\t56\t0\t8\t56\t0\t8'
got_cartography="$(tail -n +2 "$CARTOGRAPHY_SUMMARY")"
[ "$got_cartography" = "$expected_cartography" ] || {
    printf 'unexpected father field cartography:\n%s\n' \
        "$got_cartography" >&2
    exit 1
}

expected_summary=$'default\tbaseline\t9\t8\t2\t1\t8\t1\t0.777778\t0.039062\t7\t1\t0.666667\t0.070312\t8\t0\t0\t1\tnot-necessary\t7\t0\t0\t1\tnot-necessary\nno-presence\tpresence-root\t9\t7\t7\t5\t3\t1\t0.222222\t0.625000\t0\t0\t0.000000\t1.000000\t3\t4\t1\t0\tmixed\t0\t7\t0\t0\tcandidate-conduit\nno-dario\tpresence-boundary\t9\t5\t2\t0\t5\t0\t0.555556\t0.062500\t4\t1\t0.333333\t0.375000\t5\t3\t0\t0\tmixed\t4\t3\t0\t1\tmixed\nno-heard\tremembered-surface\t9\t5\t1\t1\t4\t0\t0.444444\t0.125000\t4\t0\t0.444444\t0.125000\t4\t4\t0\t0\tmixed\t4\t3\t0\t0\tmixed\nno-cont-theme\tpresence-continuation\t9\t6\t1\t1\t6\t1\t0.555556\t0.125000\t6\t1\t0.555556\t0.125000\t6\t2\t0\t1\tnot-necessary\t6\t1\t0\t1\tnot-necessary\nno-leash\tpresence-restoring-force\t9\t7\t2\t1\t7\t1\t0.666667\t0.070312\t6\t1\t0.555556\t0.125000\t7\t1\t0\t1\tnot-necessary\t6\t1\t0\t1\tnot-necessary\nno-spa\tcross-sentence-rewrite\t9\t8\t2\t1\t8\t1\t0.777778\t0.039062\t7\t1\t0.666667\t0.070312\t8\t0\t0\t1\tnot-necessary\t7\t0\t0\t1\tnot-necessary\nno-santaclaus\tspore-recall\t9\t5\t2\t2\t5\t2\t0.333333\t0.453125\t4\t1\t0.333333\t0.375000\t5\t2\t1\t1\tmixed\t4\t2\t1\t0\tmixed\nno-capsule\tglyph-capsule\t9\t3\t1\t1\t2\t0\t0.222222\t0.500000\t2\t0\t0.222222\t0.500000\t2\t6\t0\t0\tcandidate-conduit\t2\t5\t0\t0\tcandidate-conduit\nno-consolidation\tshard-memory\t9\t7\t3\t2\t6\t1\t0.555556\t0.125000\t5\t1\t0.444444\t0.218750\t6\t1\t1\t0\tnot-necessary\t5\t1\t1\t0\tnot-necessary\nno-breath\tlexical-breath\t9\t8\t2\t1\t8\t1\t0.777778\t0.039062\t7\t1\t0.666667\t0.070312\t8\t0\t0\t1\tnot-necessary\t7\t0\t0\t1\tnot-necessary\nno-register\tchamber-voice\t9\t5\t0\t0\t5\t0\t0.555556\t0.062500\t5\t0\t0.555556\t0.062500\t5\t3\t0\t0\tmixed\t5\t2\t0\t0\tnot-necessary'
got_summary="$(tail -n +2 "$SUMMARY")"
[ "$got_summary" = "$expected_summary" ] || {
    printf 'unexpected father path summary:\n%s\n' "$got_summary" >&2
    exit 1
}

(
    cd "$OUT"
    shasum -a 256 -c sealed-inputs.sha256 > /dev/null
    shasum -a 256 source-a70/manifest.tsv source-a70/results.tsv \
        witnesses.tsv cartography.tsv cartography-summary.tsv \
        branch-rows.tsv results.tsv summary.tsv > receipt.sha256
)

cat "$CARTOGRAPHY_SUMMARY"
printf '\n'
cat "$SUMMARY"
printf '\nwitnesses: %s\ncartography: %s\nresults: %s\n' \
    "$WITNESSES" "$CARTOGRAPHY" "$RESULTS"
