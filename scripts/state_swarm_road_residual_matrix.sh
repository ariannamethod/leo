#!/usr/bin/env bash
# A.99: compare a destination-centered Hebbian road with matched readout controls.
set -Eeuo pipefail

trap 'rc=$?; printf "road residual runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
A98="${LEO_STATE_RESIDUAL_A98_SOURCE:-/private/tmp/leo-state-swarm-road-prequential-a98-r1-20260810}"
AGGREGATE_ONLY="${LEO_STATE_RESIDUAL_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-residual-$STAMP}"

SOURCE_PLAN="$A98/plan.tsv"
SOURCE_LOCKS="$A98/replay-locks.tsv"
SOURCE_WITNESSES="$A98/turn-witnesses.tsv"
SOURCE_VERDICT="$A98/verdict.txt"

EXPECTED_PLAN_SHA="${LEO_STATE_RESIDUAL_PLAN_SHA:-8e1d1183c308c51e2a29a69ecd9d97af19b7c8329f3aed849f53800d95e8d29c}"
EXPECTED_LOCKS_SHA="${LEO_STATE_RESIDUAL_LOCKS_SHA:-916ffa9776342f27c9e14f25678d904ab5878b5c438a6da9235176c9758bf18e}"
EXPECTED_WITNESSES_SHA="${LEO_STATE_RESIDUAL_WITNESSES_SHA:-74069ab543365399cbe369164d2d41530d274b25223632c1f8ca6f8fc8c3cde1}"
EXPECTED_VERDICT_SHA="${LEO_STATE_RESIDUAL_VERDICT_SHA:-d2a0a96ddd0e44e65de19f36d5d0628bc107381550c9f084070b85794a92547a}"

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

seal() {
    local path="$1" expected="$2" label="$3"
    [ -s "$path" ] && [ "$(sha256_file "$path")" = "$expected" ] || {
        printf '%s is not the sealed source: %s\n' "$label" "$path" >&2
        exit 2
    }
}

seal "$SOURCE_PLAN" "$EXPECTED_PLAN_SHA" "A.98 plan"
seal "$SOURCE_LOCKS" "$EXPECTED_LOCKS_SHA" "A.98 replay locks"
seal "$SOURCE_WITNESSES" "$EXPECTED_WITNESSES_SHA" "A.98 turn witnesses"
seal "$SOURCE_VERDICT" "$EXPECTED_VERDICT_SHA" "A.98 verdict"

PLAN="$OUT/plan.tsv"
POLICIES="$OUT/policies.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
SCORES="$OUT/residual-scores.tsv"
LIFE_SUMMARY="$OUT/life-summary.tsv"
CANDIDATE_SUMMARY="$OUT/candidate-summary.tsv"
SELECTION="$OUT/selection.tsv"
VERDICT="$OUT/verdict.txt"

write_plan() {
    awk -F '\t' -v OFS='\t' '
        NR == 1 {
            if (NF != 6 || $1 != "cohort" || $2 != "life" ||
                $3 != "split" || $6 != "enrollment_rank") exit 2
            print
            next
        }
        {
            if (NF != 6 || $1 !~ /^(discovery|validation)$/ ||
                $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
                seen[$2]++) exit 2
            print
            cohort[$1]++; split_count[$1 SUBSEP $3]++
        }
        END {
            if (cohort["discovery"] != 6 || cohort["validation"] != 12 ||
                split_count["discovery" SUBSEP "primary"] != 6 ||
                split_count["discovery" SUBSEP "holdout"] != 0 ||
                split_count["validation" SUBSEP "primary"] != 6 ||
                split_count["validation" SUBSEP "holdout"] != 6) exit 2
        }
    ' "$SOURCE_PLAN"
}

write_policies() {
    printf 'candidate\tdecay\tstrength\tprior_alpha\trow_shrinkage\trank\n'
    printf 'excess-cumulative-1\t1.00\t1\t1\t1\t1\n'
    printf 'excess-cumulative-3\t1.00\t3\t1\t1\t2\n'
    printf 'excess-slow-1\t0.97\t1\t1\t1\t3\n'
    printf 'excess-slow-3\t0.97\t3\t1\t1\t4\n'
    printf 'excess-fast-1\t0.90\t1\t1\t1\t5\n'
    printf 'excess-fast-3\t0.90\t3\t1\t1\t6\n'
}

write_source_receipt() {
    printf 'artifact\tsha256\n'
    printf 'a98-plan\t%s\n' "$EXPECTED_PLAN_SHA"
    printf 'a98-replay-locks\t%s\n' "$EXPECTED_LOCKS_SHA"
    printf 'a98-turn-witnesses\t%s\n' "$EXPECTED_WITNESSES_SHA"
    printf 'a98-verdict\t%s\n' "$EXPECTED_VERDICT_SHA"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$PLAN" "$POLICIES" "$SOURCE_RECEIPT"; do
        [ -s "$path" ] || {
            printf 'incomplete road residual run: %s\n' "$OUT" >&2
            exit 2
        }
    done
    write_plan | cmp -s - "$PLAN" || {
        printf 'A.99 plan diverged\n' >&2
        exit 2
    }
    write_policies | cmp -s - "$POLICIES" || {
        printf 'A.99 policy ledger diverged\n' >&2
        exit 2
    }
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT" || {
        printf 'A.99 source receipt diverged\n' >&2
        exit 2
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT"
    write_plan > "$PLAN"
    write_policies > "$POLICIES"
    write_source_receipt > "$SOURCE_RECEIPT"
fi

if [ "${LEO_STATE_RESIDUAL_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    printf '\n'
    cat "$POLICIES"
    exit 0
fi

awk -f "$ROOT/scripts/state_swarm_road_residual_report.awk" \
    "$POLICIES" "$SOURCE_LOCKS" "$SOURCE_WITNESSES" > "$SCORES"
awk -f "$ROOT/scripts/state_swarm_road_residual_life.awk" \
    "$SCORES" > "$LIFE_SUMMARY"
awk -f "$ROOT/scripts/state_swarm_road_residual_summary.awk" \
    "$LIFE_SUMMARY" > "$CANDIDATE_SUMMARY"
awk -f "$ROOT/scripts/state_swarm_road_residual_select.awk" \
    "$CANDIDATE_SUMMARY" > "$SELECTION"
awk -f "$ROOT/scripts/state_swarm_road_residual_verdict.awk" \
    "$SELECTION" "$CANDIDATE_SUMMARY" > "$VERDICT"

cat "$CANDIDATE_SUMMARY"
printf '\n'
cat "$SELECTION"
printf '\n'
cat "$VERDICT"
printf '\nsource-a98: %s\nrun: %s\n' "$A98" "$OUT"
