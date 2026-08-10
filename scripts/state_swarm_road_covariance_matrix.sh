#!/usr/bin/env bash
# A.100: ask whether a double-centered shadow road learns temporal direction.
set -Eeuo pipefail

trap 'rc=$?; printf "road covariance runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
A89="${LEO_STATE_COVARIANCE_A89_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
A94="${LEO_STATE_COVARIANCE_A94_SOURCE:-/private/tmp/leo-state-swarm-transition-consequence-a94-r1-20260809}"
A96="${LEO_STATE_COVARIANCE_A96_SOURCE:-/private/tmp/leo-state-swarm-road-readout-a96-r1-20260810}"
A98="${LEO_STATE_COVARIANCE_A98_SOURCE:-/private/tmp/leo-state-swarm-road-prequential-a98-r1-20260810}"
JOBS="${LEO_STATE_COVARIANCE_JOBS:-3}"
AGGREGATE_ONLY="${LEO_STATE_COVARIANCE_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-covariance-$STAMP}"

SCREEN_PLAN="$A89/screen-plan.tsv"
WARM_RECEIPTS="$A89/warm-receipts.tsv"
ENROLLMENT="$A89/enrollment.tsv"
WRITER_PLAN="$A89/writer-plan.tsv"
WRITER_RECEIPTS="$A89/writer-receipts.tsv"
A94_PLAN="$A94/plan.tsv"
A96_VALIDATION="$A96/validation-witnesses.tsv"
A98_PLAN="$A98/plan.tsv"
A98_LOCKS="$A98/replay-locks.tsv"
A98_WITNESSES="$A98/turn-witnesses.tsv"
A98_VERDICT="$A98/verdict.txt"

EXPECTED_SCREEN_SHA="${LEO_STATE_COVARIANCE_SCREEN_SHA:-017ab2f9239ca20cc51f1691cf9175f4a5ca36e7e337a654654791f86a81ea8f}"
EXPECTED_WARM_SHA="${LEO_STATE_COVARIANCE_WARM_SHA:-02a7a18552ed850b3f7844ee75ca9bfedff5f9f6b750db293fbe81e271c51840}"
EXPECTED_ENROLLMENT_SHA="${LEO_STATE_COVARIANCE_ENROLLMENT_SHA:-d4f32d34a89819edb7428c06185889dfeb6648911571f4234f9ecdc5354df1fc}"
EXPECTED_WRITER_PLAN_SHA="${LEO_STATE_COVARIANCE_WRITER_PLAN_SHA:-1cb1301c20e5124bc9e0493a354c6eb83347eea6c14665181c366ef629df43b3}"
EXPECTED_WRITER_SHA="${LEO_STATE_COVARIANCE_WRITER_SHA:-10bf4251848f4edaec4a34d66d3d811afff187df9f10aeb71ff761a342c0e833}"
EXPECTED_A94_PLAN_SHA="${LEO_STATE_COVARIANCE_A94_PLAN_SHA:-9b0434bfa9bcc4c5cb6051cf7a6133f3fe0f51add036b5273721ece327e5ca2a}"
EXPECTED_A96_VALIDATION_SHA="${LEO_STATE_COVARIANCE_A96_VALIDATION_SHA:-6d155803cca27adb117b908575bfeac206c3096fdf05bba3c974fee306692303}"
EXPECTED_A98_PLAN_SHA="${LEO_STATE_COVARIANCE_A98_PLAN_SHA:-8e1d1183c308c51e2a29a69ecd9d97af19b7c8329f3aed849f53800d95e8d29c}"
EXPECTED_A98_LOCKS_SHA="${LEO_STATE_COVARIANCE_A98_LOCKS_SHA:-916ffa9776342f27c9e14f25678d904ab5878b5c438a6da9235176c9758bf18e}"
EXPECTED_A98_WITNESSES_SHA="${LEO_STATE_COVARIANCE_A98_WITNESSES_SHA:-74069ab543365399cbe369164d2d41530d274b25223632c1f8ca6f8fc8c3cde1}"
EXPECTED_A98_VERDICT_SHA="${LEO_STATE_COVARIANCE_A98_VERDICT_SHA:-d2a0a96ddd0e44e65de19f36d5d0628bc107381550c9f084070b85794a92547a}"

case "$JOBS" in
    ''|*[!0-9]*|0) printf 'invalid road covariance jobs: %s\n' "$JOBS" >&2; exit 2 ;;
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
seal "$A94_PLAN" "$EXPECTED_A94_PLAN_SHA" "A.94 used-life plan"
seal "$A96_VALIDATION" "$EXPECTED_A96_VALIDATION_SHA" "A.96 validation witnesses"
seal "$A98_PLAN" "$EXPECTED_A98_PLAN_SHA" "A.98 replay plan"
seal "$A98_LOCKS" "$EXPECTED_A98_LOCKS_SHA" "A.98 replay locks"
seal "$A98_WITNESSES" "$EXPECTED_A98_WITNESSES_SHA" "A.98 turn witnesses"
seal "$A98_VERDICT" "$EXPECTED_A98_VERDICT_SHA" "A.98 verdict"

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
    ' "$A98_PLAN"
}

write_validation_roster() {
    printf 'validation\tp20\tprimary\n'
    printf 'validation\tp21\tprimary\n'
    printf 'validation\tp28\tprimary\n'
    printf 'validation\tp29\tprimary\n'
    printf 'validation\tp30\tprimary\n'
    printf 'validation\th13\tholdout\n'
    printf 'validation\th19\tholdout\n'
    printf 'validation\th20\tholdout\n'
    printf 'validation\th21\tholdout\n'
    printf 'validation\th23\tholdout\n'
}

write_validation_plan() {
    awk -F '\t' -v OFS='\t' '
        FILENAME == ARGV[1] {
            if (FNR == 1) { if (NF != 19 || $4 != "life") exit 2; next }
            used[$4] = 1; next
        }
        FILENAME == ARGV[2] {
            if (FNR == 1) { if (NF != 28 || $4 != "life") exit 2; next }
            used[$4] = 1; next
        }
        FILENAME == ARGV[3] {
            if (FNR == 1) { if (NF != 6 || $2 != "life") exit 2; next }
            used[$2] = 1; next
        }
        FILENAME == ARGV[4] {
            if (FNR == 1) {
                if (NF != 5 || $1 != "life" || $5 != "enrollment_rank") exit 2
                next
            }
            if (enrolled[$1]++) exit 2
            split_name[$1] = $2; base[$1] = $3
            candidate_order[$1] = $4; rank[$1] = $5
            next
        }
        {
            if (NF != 3 || $1 != "validation" ||
                $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
                split_name[$2] != $3 || ($2 in used) || chosen[$2]++) exit 2
            if (!rows++)
                print "cohort", "life", "split", "base_seed", \
                    "candidate_order", "enrollment_rank"
            print $1, $2, $3, base[$2], candidate_order[$2], rank[$2]
            split_count[$3]++
        }
        END {
            if (rows != 10 || split_count["primary"] != 5 ||
                split_count["holdout"] != 5) exit 2
        }
    ' "$A94_PLAN" "$A96_VALIDATION" "$A98_PLAN" "$ENROLLMENT" \
        <(write_validation_roster)
}

write_policies() {
    printf 'candidate\tdecay\tstrength\tprior_alpha\tvariance_ridge\trank\n'
    printf 'cov-cumulative-gentle\t1.00\t0.25\t1\t1\t1\n'
    printf 'cov-cumulative-full\t1.00\t1\t1\t1\t2\n'
    printf 'cov-slow-gentle\t0.97\t0.25\t1\t1\t3\n'
    printf 'cov-slow-full\t0.97\t1\t1\t1\t4\n'
    printf 'cov-fast-gentle\t0.90\t0.25\t1\t1\t5\n'
    printf 'cov-fast-full\t0.90\t1\t1\t1\t6\n'
}

write_source_receipt() {
    printf 'source\tsha256\n'
    printf 'a89-screen-plan\t%s\n' "$EXPECTED_SCREEN_SHA"
    printf 'a89-warm-receipts\t%s\n' "$EXPECTED_WARM_SHA"
    printf 'a89-enrollment\t%s\n' "$EXPECTED_ENROLLMENT_SHA"
    printf 'a89-writer-plan\t%s\n' "$EXPECTED_WRITER_PLAN_SHA"
    printf 'a89-writer-receipts\t%s\n' "$EXPECTED_WRITER_SHA"
    printf 'a94-plan\t%s\n' "$EXPECTED_A94_PLAN_SHA"
    printf 'a96-validation\t%s\n' "$EXPECTED_A96_VALIDATION_SHA"
    printf 'a98-plan\t%s\n' "$EXPECTED_A98_PLAN_SHA"
    printf 'a98-locks\t%s\n' "$EXPECTED_A98_LOCKS_SHA"
    printf 'a98-witnesses\t%s\n' "$EXPECTED_A98_WITNESSES_SHA"
    printf 'a98-verdict\t%s\n' "$EXPECTED_A98_VERDICT_SHA"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$DISCOVERY_PLAN" "$VALIDATION_PLAN" "$POLICIES" \
        "$SOURCE_RECEIPT" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES"; do
        [ -s "$path" ] || {
            printf 'incomplete road covariance run: %s\n' "$OUT" >&2
            exit 2
        }
    done
    write_discovery_plan | cmp -s - "$DISCOVERY_PLAN" || {
        printf 'A.100 discovery plan diverged\n' >&2; exit 2;
    }
    write_validation_plan | cmp -s - "$VALIDATION_PLAN" || {
        printf 'A.100 validation plan diverged\n' >&2; exit 2;
    }
    write_policies | cmp -s - "$POLICIES" || {
        printf 'A.100 policy ledger diverged\n' >&2; exit 2;
    }
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT" || {
        printf 'A.100 source receipt diverged\n' >&2; exit 2;
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
    awk -F '\t' 'NR == 1 || $1 == "discovery"' "$A98_LOCKS" > "$DISCOVERY_LOCKS"
    awk -F '\t' 'NR == 1 || $1 == "discovery"' "$A98_WITNESSES" > "$DISCOVERY_WITNESSES"
fi

if [ "${LEO_STATE_COVARIANCE_PLAN_ONLY:-0}" = 1 ]; then
    cat "$DISCOVERY_PLAN"
    printf '\n'
    cat "$VALIDATION_PLAN"
    printf '\n'
    cat "$POLICIES"
    exit 0
fi

awk -v policy_expected=6 -v life_expected=6 -v writer_expected=64 \
    -v evaluation_start=49 -v score_min=32 \
    -f "$ROOT/scripts/state_swarm_road_covariance_report.awk" \
    "$POLICIES" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES" \
    > "$DISCOVERY_SCORES"
awk -v policy_expected=6 -v life_expected=6 -v min_turns=32 \
    -f "$ROOT/scripts/state_swarm_road_covariance_life.awk" \
    "$DISCOVERY_SCORES" > "$DISCOVERY_LIFE"
awk -v policy_expected=6 -v discovery_expected=6 -v validation_expected=10 \
    -f "$ROOT/scripts/state_swarm_road_covariance_summary.awk" \
    "$DISCOVERY_LIFE" > "$DISCOVERY_SUMMARY"
awk -v policy_expected=6 \
    -f "$ROOT/scripts/state_swarm_road_covariance_select.awk" \
    "$DISCOVERY_SUMMARY" > "$SELECTION"

selected="$(awk -F '\t' 'NR == 2 { print $1 }' "$SELECTION")"
[ -n "$selected" ] || {
    printf 'A.100 selection is empty\n' >&2
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
        printf 'selected covariance policy is not unique\n' >&2
        exit 2
    }

    if [ "$AGGREGATE_ONLY" != 1 ]; then
        make -C "$ROOT" leo >/dev/null
        FIXTURE="$OUT/road-covariance-fixture"
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
        -f "$ROOT/scripts/state_swarm_road_covariance_report.awk" \
        "$SELECTED_POLICY" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES" \
        > "$VALIDATION_SCORES"
    awk -v policy_expected=1 -v life_expected=10 -v min_turns=32 \
        -f "$ROOT/scripts/state_swarm_road_covariance_life.awk" \
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
    -f "$ROOT/scripts/state_swarm_road_covariance_summary.awk" \
    "$LIFE_SUMMARY" > "$CANDIDATE_SUMMARY"
awk -f "$ROOT/scripts/state_swarm_road_covariance_verdict.awk" \
    "$SELECTION" "$CANDIDATE_SUMMARY" > "$VERDICT"

cat "$CANDIDATE_SUMMARY"
printf '\n'
cat "$SELECTION"
printf '\n'
cat "$VERDICT"
printf '\nsource-a98: %s\nrun: %s\n' "$A98" "$OUT"
