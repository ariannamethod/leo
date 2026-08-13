#!/usr/bin/env bash
# A.101: let a shadow remember only the raw road's completed forecast errors.
set -Eeuo pipefail

trap 'rc=$?; printf "road error-memory runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
A89="${LEO_STATE_ERROR_MEMORY_A89_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
A100="${LEO_STATE_ERROR_MEMORY_A100_SOURCE:-/private/tmp/leo-state-swarm-road-covariance-a100-r1-20260810}"
JOBS="${LEO_STATE_ERROR_MEMORY_JOBS:-3}"
AGGREGATE_ONLY="${LEO_STATE_ERROR_MEMORY_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-error-memory-$STAMP}"

SCREEN_PLAN="$A89/screen-plan.tsv"
WARM_RECEIPTS="$A89/warm-receipts.tsv"
ENROLLMENT="$A89/enrollment.tsv"
WRITER_PLAN="$A89/writer-plan.tsv"
WRITER_RECEIPTS="$A89/writer-receipts.tsv"
A100_DISCOVERY_PLAN="$A100/discovery-plan.tsv"
A100_VALIDATION_PLAN="$A100/validation-plan.tsv"
A100_SOURCE_RECEIPT="$A100/source-receipt.tsv"
A100_LOCKS="$A100/discovery-locks.tsv"
A100_WITNESSES="$A100/discovery-witnesses.tsv"
A100_VERDICT="$A100/verdict.txt"

EXPECTED_SCREEN_SHA="${LEO_STATE_ERROR_MEMORY_SCREEN_SHA:-017ab2f9239ca20cc51f1691cf9175f4a5ca36e7e337a654654791f86a81ea8f}"
EXPECTED_WARM_SHA="${LEO_STATE_ERROR_MEMORY_WARM_SHA:-02a7a18552ed850b3f7844ee75ca9bfedff5f9f6b750db293fbe81e271c51840}"
EXPECTED_ENROLLMENT_SHA="${LEO_STATE_ERROR_MEMORY_ENROLLMENT_SHA:-d4f32d34a89819edb7428c06185889dfeb6648911571f4234f9ecdc5354df1fc}"
EXPECTED_WRITER_PLAN_SHA="${LEO_STATE_ERROR_MEMORY_WRITER_PLAN_SHA:-1cb1301c20e5124bc9e0493a354c6eb83347eea6c14665181c366ef629df43b3}"
EXPECTED_WRITER_SHA="${LEO_STATE_ERROR_MEMORY_WRITER_SHA:-10bf4251848f4edaec4a34d66d3d811afff187df9f10aeb71ff761a342c0e833}"
EXPECTED_A100_DISCOVERY_PLAN_SHA="${LEO_STATE_ERROR_MEMORY_A100_DISCOVERY_PLAN_SHA:-ebe356a8b3055c6467a163a38e3893c115bfd39ca13ab6cff56ac802f013b860}"
EXPECTED_A100_VALIDATION_PLAN_SHA="${LEO_STATE_ERROR_MEMORY_A100_VALIDATION_PLAN_SHA:-259be3140c58c7706f985283734cc0c57b99d2d46f6221c17ee0adad6c026a82}"
EXPECTED_A100_SOURCE_RECEIPT_SHA="${LEO_STATE_ERROR_MEMORY_A100_SOURCE_RECEIPT_SHA:-9c594e83aedf793735a4f0e17db3d978f2a07c47f4351e067a8cf38720d1a75f}"
EXPECTED_A100_LOCKS_SHA="${LEO_STATE_ERROR_MEMORY_A100_LOCKS_SHA:-3db813ce82d3481fd0358bdb797aaa150859014eff443c682753738e53c755b9}"
EXPECTED_A100_WITNESSES_SHA="${LEO_STATE_ERROR_MEMORY_A100_WITNESSES_SHA:-aafd3e9acae3af18905dd0e75a98acffe0e0d447f86775b0c30eba56d7adec1b}"
EXPECTED_A100_VERDICT_SHA="${LEO_STATE_ERROR_MEMORY_A100_VERDICT_SHA:-cb05dbde98131e6c2d4cf0631d571646289f531f7af80385cb2bc4ab589c4d46}"

case "$JOBS" in
    ''|*[!0-9]*|0) printf 'invalid road error-memory jobs: %s\n' "$JOBS" >&2; exit 2 ;;
esac
case "$AGGREGATE_ONLY" in
    0|1) ;;
    *) printf 'invalid aggregate-only value: %s\n' "$AGGREGATE_ONLY" >&2; exit 2 ;;
esac

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

seal "$SCREEN_PLAN" "$EXPECTED_SCREEN_SHA" "A.89 screen plan"
seal "$WARM_RECEIPTS" "$EXPECTED_WARM_SHA" "A.89 warm receipts"
seal "$ENROLLMENT" "$EXPECTED_ENROLLMENT_SHA" "A.89 enrollment"
seal "$WRITER_PLAN" "$EXPECTED_WRITER_PLAN_SHA" "A.89 writer plan"
seal "$WRITER_RECEIPTS" "$EXPECTED_WRITER_SHA" "A.89 writer receipts"
seal "$A100_DISCOVERY_PLAN" "$EXPECTED_A100_DISCOVERY_PLAN_SHA" "A.100 discovery plan"
seal "$A100_VALIDATION_PLAN" "$EXPECTED_A100_VALIDATION_PLAN_SHA" "A.100 unopened validation plan"
seal "$A100_SOURCE_RECEIPT" "$EXPECTED_A100_SOURCE_RECEIPT_SHA" "A.100 source receipt"
seal "$A100_LOCKS" "$EXPECTED_A100_LOCKS_SHA" "A.100 discovery locks"
seal "$A100_WITNESSES" "$EXPECTED_A100_WITNESSES_SHA" "A.100 discovery witnesses"
seal "$A100_VERDICT" "$EXPECTED_A100_VERDICT_SHA" "A.100 verdict"
for forbidden in validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A100/$forbidden" ] || {
        printf 'A.100 validation was already opened: %s\n' "$A100/$forbidden" >&2
        exit 2
    }
done

DISCOVERY_PLAN="$OUT/discovery-plan.tsv"
VALIDATION_PLAN="$OUT/validation-plan.tsv"
POLICIES="$OUT/policies.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
DISCOVERY_LOCKS="$OUT/discovery-locks.tsv"
DISCOVERY_WITNESSES="$OUT/discovery-witnesses.tsv"
DISCOVERY_SCORES="$OUT/discovery-scores.tsv"
DISCOVERY_LIFE="$OUT/discovery-life-summary.tsv"
DISCOVERY_SUMMARY="$OUT/discovery-summary.tsv"
SELECTION="$OUT/selection.tsv"
SELECTED_POLICY="$OUT/selected-policy.tsv"
VALIDATION_LOCKS="$OUT/validation-locks.tsv"
VALIDATION_WITNESSES="$OUT/validation-witnesses.tsv"
VALIDATION_SCORES="$OUT/validation-scores.tsv"
VALIDATION_LIFE="$OUT/validation-life-summary.tsv"
LIFE_SUMMARY="$OUT/life-summary.tsv"
CANDIDATE_SUMMARY="$OUT/candidate-summary.tsv"
VERDICT="$OUT/verdict.txt"

write_discovery_plan() {
    awk -F '\t' -v OFS='\t' '
        NR == 1 {
            if (NF != 6 || $1 != "cohort" || $6 != "enrollment_rank") exit 2
            print
            next
        }
        $1 == "discovery" {
            if ($2 != sprintf("p%02d", 5 + ++rows) || $3 != "primary") exit 2
            print
        }
        END { if (rows != 6) exit 2 }
    ' "$A100_DISCOVERY_PLAN"
}

write_validation_plan() {
    awk -F '\t' -v OFS='\t' '
        BEGIN {
            split("p20 p21 p28 p29 p30 h13 h19 h20 h21 h23", life, " ")
            split("primary primary primary primary primary holdout holdout holdout holdout holdout", split_name, " ")
        }
        NR == 1 {
            if (NF != 6 || $1 != "cohort" || $6 != "enrollment_rank") exit 2
            print
            next
        }
        {
            rows++
            if (rows > 10 || $1 != "validation" || $2 != life[rows] ||
                $3 != split_name[rows]) exit 2
            print
        }
        END { if (rows != 10) exit 2 }
    ' "$A100_VALIDATION_PLAN"
}

write_policies() {
    printf 'candidate\tdecay\tstrength\tprior_alpha\tvariance_ridge\trank\n'
    printf 'err-cumulative-gentle\t1.00\t0.25\t1\t1\t1\n'
    printf 'err-cumulative-full\t1.00\t1\t1\t1\t2\n'
    printf 'err-slow-gentle\t0.97\t0.25\t1\t1\t3\n'
    printf 'err-slow-full\t0.97\t1\t1\t1\t4\n'
    printf 'err-fast-gentle\t0.90\t0.25\t1\t1\t5\n'
    printf 'err-fast-full\t0.90\t1\t1\t1\t6\n'
}

write_source_receipt() {
    printf 'source\tsha256\n'
    printf 'a89-screen-plan\t%s\n' "$EXPECTED_SCREEN_SHA"
    printf 'a89-warm-receipts\t%s\n' "$EXPECTED_WARM_SHA"
    printf 'a89-enrollment\t%s\n' "$EXPECTED_ENROLLMENT_SHA"
    printf 'a89-writer-plan\t%s\n' "$EXPECTED_WRITER_PLAN_SHA"
    printf 'a89-writer-receipts\t%s\n' "$EXPECTED_WRITER_SHA"
    printf 'a100-discovery-plan\t%s\n' "$EXPECTED_A100_DISCOVERY_PLAN_SHA"
    printf 'a100-validation-plan\t%s\n' "$EXPECTED_A100_VALIDATION_PLAN_SHA"
    printf 'a100-source-receipt\t%s\n' "$EXPECTED_A100_SOURCE_RECEIPT_SHA"
    printf 'a100-discovery-locks\t%s\n' "$EXPECTED_A100_LOCKS_SHA"
    printf 'a100-discovery-witnesses\t%s\n' "$EXPECTED_A100_WITNESSES_SHA"
    printf 'a100-verdict\t%s\n' "$EXPECTED_A100_VERDICT_SHA"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$DISCOVERY_PLAN" "$VALIDATION_PLAN" "$POLICIES" \
        "$SOURCE_RECEIPT" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES"; do
        [ -s "$path" ] || {
            printf 'incomplete road error-memory run: %s\n' "$OUT" >&2
            exit 2
        }
    done
    write_discovery_plan | cmp -s - "$DISCOVERY_PLAN" || {
        printf 'A.101 discovery plan diverged\n' >&2; exit 2;
    }
    write_validation_plan | cmp -s - "$VALIDATION_PLAN" || {
        printf 'A.101 validation plan diverged\n' >&2; exit 2;
    }
    write_policies | cmp -s - "$POLICIES" || {
        printf 'A.101 policy ledger diverged\n' >&2; exit 2;
    }
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT" || {
        printf 'A.101 source receipt diverged\n' >&2; exit 2;
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT/replays"
    write_discovery_plan > "$DISCOVERY_PLAN"
    write_validation_plan > "$VALIDATION_PLAN"
    write_policies > "$POLICIES"
    write_source_receipt > "$SOURCE_RECEIPT"
    awk -F '\t' '{ print }' "$A100_LOCKS" > "$DISCOVERY_LOCKS"
    awk -F '\t' '{ print }' "$A100_WITNESSES" > "$DISCOVERY_WITNESSES"
fi

if [ "${LEO_STATE_ERROR_MEMORY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$DISCOVERY_PLAN"
    printf '\n'
    cat "$VALIDATION_PLAN"
    printf '\n'
    cat "$POLICIES"
    exit 0
fi

awk -v policy_expected=6 -v life_expected=6 -v writer_expected=64 \
    -v evaluation_start=49 -v score_min=32 \
    -f "$ROOT/scripts/state_swarm_road_error_memory_report.awk" \
    "$POLICIES" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES" \
    > "$DISCOVERY_SCORES"
awk -v policy_expected=6 -v life_expected=6 -v min_turns=32 \
    -f "$ROOT/scripts/state_swarm_road_error_memory_life.awk" \
    "$DISCOVERY_SCORES" > "$DISCOVERY_LIFE"
awk -v policy_expected=6 -v discovery_expected=6 -v validation_expected=10 \
    -f "$ROOT/scripts/state_swarm_road_error_memory_summary.awk" \
    "$DISCOVERY_LIFE" > "$DISCOVERY_SUMMARY"
awk -v policy_expected=6 \
    -f "$ROOT/scripts/state_swarm_road_error_memory_select.awk" \
    "$DISCOVERY_SUMMARY" > "$SELECTION"

selected="$(awk -F '\t' 'NR == 2 { print $1 }' "$SELECTION")"
[ -n "$selected" ] || {
    printf 'A.101 selection is empty\n' >&2
    exit 2
}

normalize_log() {
    sed -E \
        -e 's|^\[leo step0\] ingest corpus .*$|[leo step0] ingest corpus NORMALIZED|' \
        -e 's|^\[leo\] loaded state from .*$|[leo] loaded state from BODY|' \
        -e 's|^\[leo\] saved state to .* \(step=|[leo] saved state to BODY (step=|' \
        "$1"
}

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

run_life() {
    local cohort="$1" wanted_life="$2" wanted_split="$3" base_seed="$4"
    local life_dir="$OUT/replays/$wanted_life"
    local state="$life_dir/leo.state"
    local source_body="$A89/candidates/$wanted_life/leo.state"
    local generated_all="$life_dir/generated.normalized"
    local source_all="$life_dir/source.normalized"
    local life_witnesses="$life_dir/witnesses.tsv"
    local life_lock="$life_dir/lock.tsv"
    local rows=0
    mkdir -p "$life_dir"
    : > "$generated_all"
    : > "$source_all"
    : > "$life_witnesses"

    while IFS=$'\t' read -r life split warm_base phase session order \
        texture run_seed prompt; do
        [ "$life" = "$wanted_life" ] || continue
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local generated="$life_dir/current.log"
        local canonical="$A89/candidates/$life/warm-logs/$stem.log"
        local args=("$ROOT/leo" --corpus "$ROOT/leo.txt")
        [ -s "$state" ] && args+=(--load "$state")
        args+=(--seed "$run_seed" --respond "$prompt" --debug-field \
               --save "$state")
        "${args[@]}" > "$generated" 2>&1
        normalize_log "$generated" >> "$generated_all"
        normalize_log "$canonical" >> "$source_all"
        rows=$((rows + 1))
    done < "$SCREEN_PLAN"
    [ "$rows" -eq 32 ] || return 1

    rows=0
    while IFS=$'\t' read -r life split writer_base phase session order \
        texture run_seed prompt; do
        [ "$life" = "$wanted_life" ] || continue
        local turn=$((32 + (session - 1) * 8 + order))
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local generated="$life_dir/current.log"
        local canonical="$A89/candidates/$life/writer-logs/$stem.log"
        local geometry="$life_dir/geometry.tsv"
        local generated_receipt="$life_dir/generated-receipt.tsv"
        local source_receipt="$life_dir/source-receipt.tsv"
        local reply
        "$FIXTURE" "$state" > "$geometry"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$state" \
            --seed "$run_seed" --respond "$prompt" --debug-field \
            --save "$state" > "$generated" 2>&1
        normalize_log "$generated" >> "$generated_all"
        normalize_log "$canonical" >> "$source_all"
        reply="$(reply_from_log "$generated")"
        [ -n "$reply" ] || return 1
        awk -v cell="$life" -v cohort="$split" \
            -v base_seed="$base_seed" -v phase=writer \
            -v session="$session" -v order="$order" \
            -v texture="$texture" -v run_seed="$run_seed" \
            -v prompt="$prompt" -v reply="$reply" \
            -f "$ROOT/scripts/state_swarm_dialogue_report.awk" \
            "$generated" > "$generated_receipt"
        awk -F '\t' -v life="$life" -v turn="$turn" \
            'NR == 1 { next } $1 == life && $9 == turn { print; rows++ }
             END { if (rows != 1) exit 2 }' \
            "$WRITER_RECEIPTS" > "$source_receipt"
        cmp -s "$generated_receipt" "$source_receipt" || return 1
        IFS=$'\t' read -r pre_turn pre_ids source transition \
            transition_total < "$geometry"
        awk -F '\t' -v OFS='\t' -v cohort="$cohort" \
            -v pre_turn="$pre_turn" -v pre_ids="$pre_ids" \
            -v transition="$transition" -v source="$source" \
            -v transition_total="$transition_total" '
            {
                print cohort, $1, $2, $9, $5, $6, $7, $13, pre_turn, \
                    pre_ids, $16, transition, source, transition_total, \
                    $12, $19, $20, $21, $22, $23, $24, $33, $34
            }
        ' "$generated_receipt" >> "$life_witnesses"
        rows=$((rows + 1))
    done < "$WRITER_PLAN"
    [ "$rows" -eq 64 ] || return 1
    cmp -s "$generated_all" "$source_all" || return 1
    cmp -s "$state" "$source_body" || return 1
    printf '%s\t%s\t%s\t64\ttrue\ttrue\t%s\t%s\n' \
        "$cohort" "$wanted_life" "$wanted_split" \
        "$(sha256_file "$generated_all")" "$(sha256_file "$state")" \
        > "$life_lock"
    rm -f "$life_dir/current.log" "$life_dir/geometry.tsv" \
        "$life_dir/generated-receipt.tsv" "$life_dir/source-receipt.tsv"
}

if [ "$selected" != none ]; then
    {
        sed -n '1p' "$POLICIES"
        awk -F '\t' -v selected="$selected" '$1 == selected' "$POLICIES"
    } > "$SELECTED_POLICY"
    [ "$(wc -l < "$SELECTED_POLICY" | tr -d ' ')" -eq 2 ] || {
        printf 'selected error-memory policy is not unique\n' >&2
        exit 2
    }

    if [ "$AGGREGATE_ONLY" != 1 ]; then
        make -C "$ROOT" leo >/dev/null
        FIXTURE="$OUT/road-error-memory-fixture"
        "$CC" "$ROOT/tests/state_swarm_road_prequential_fixture.c" \
            -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread

        pids=()
        running=0
        while IFS=$'\t' read -r cohort life split base_seed candidate_order \
            enrollment_rank; do
            run_life "$cohort" "$life" "$split" "$base_seed" &
            pids+=("$!")
            running=$((running + 1))
            if [ "$running" -ge "$JOBS" ]; then
                for pid in "${pids[@]}"; do wait "$pid"; done
                pids=()
                running=0
            fi
        done < <(tail -n +2 "$VALIDATION_PLAN")
        if [ "$running" -gt 0 ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
        fi

        printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$VALIDATION_LOCKS"
        printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$VALIDATION_WITNESSES"
        while IFS=$'\t' read -r cohort life split base_seed candidate_order \
            enrollment_rank; do
            cat "$OUT/replays/$life/lock.tsv" >> "$VALIDATION_LOCKS"
            cat "$OUT/replays/$life/witnesses.tsv" >> "$VALIDATION_WITNESSES"
        done < <(tail -n +2 "$VALIDATION_PLAN")
        rm -f "$FIXTURE"
    else
        for path in "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES"; do
            [ -s "$path" ] || {
                printf 'selected candidate lacks validation evidence: %s\n' "$path" >&2
                exit 2
            }
        done
    fi

    awk -v policy_expected=1 -v life_expected=10 -v writer_expected=64 \
        -v evaluation_start=49 -v score_min=32 \
        -f "$ROOT/scripts/state_swarm_road_error_memory_report.awk" \
        "$SELECTED_POLICY" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES" \
        > "$VALIDATION_SCORES"
    awk -v policy_expected=1 -v life_expected=10 -v min_turns=32 \
        -f "$ROOT/scripts/state_swarm_road_error_memory_life.awk" \
        "$VALIDATION_SCORES" > "$VALIDATION_LIFE"
    {
        sed -n '1p' "$DISCOVERY_LIFE"
        tail -n +2 "$DISCOVERY_LIFE"
        tail -n +2 "$VALIDATION_LIFE"
    } > "$LIFE_SUMMARY"
else
    for path in "$SELECTED_POLICY" "$VALIDATION_LOCKS" \
        "$VALIDATION_WITNESSES" "$VALIDATION_SCORES" "$VALIDATION_LIFE"; do
        [ ! -e "$path" ] || {
            printf 'no-candidate run exposed validation artifact: %s\n' "$path" >&2
            exit 2
        }
    done
    cp "$DISCOVERY_LIFE" "$LIFE_SUMMARY"
fi

awk -v policy_expected=6 -v discovery_expected=6 -v validation_expected=10 \
    -f "$ROOT/scripts/state_swarm_road_error_memory_summary.awk" \
    "$LIFE_SUMMARY" > "$CANDIDATE_SUMMARY"
awk -f "$ROOT/scripts/state_swarm_road_error_memory_verdict.awk" \
    "$SELECTION" "$CANDIDATE_SUMMARY" > "$VERDICT"

cat "$CANDIDATE_SUMMARY"
printf '\n'
cat "$SELECTION"
printf '\n'
cat "$VERDICT"
printf '\nsource-a100: %s\nrun: %s\n' "$A100" "$OUT"
