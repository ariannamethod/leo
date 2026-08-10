#!/usr/bin/env bash
# A.98: let road authority depend only on forecasts completed in the past.
set -Eeuo pipefail

trap 'rc=$?; printf "road prequential runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
A89="${LEO_STATE_PREQUENTIAL_A89_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
A94="${LEO_STATE_PREQUENTIAL_A94_SOURCE:-/private/tmp/leo-state-swarm-transition-consequence-a94-r1-20260809}"
A96="${LEO_STATE_PREQUENTIAL_A96_SOURCE:-/private/tmp/leo-state-swarm-road-readout-a96-r1-20260810}"
JOBS="${LEO_STATE_PREQUENTIAL_JOBS:-3}"
AGGREGATE_ONLY="${LEO_STATE_PREQUENTIAL_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-prequential-$STAMP}"

SCREEN_PLAN="$A89/screen-plan.tsv"
WARM_RECEIPTS="$A89/warm-receipts.tsv"
ENROLLMENT="$A89/enrollment.tsv"
WRITER_PLAN="$A89/writer-plan.tsv"
WRITER_RECEIPTS="$A89/writer-receipts.tsv"
A94_PLAN="$A94/plan.tsv"
A96_VALIDATION="$A96/validation-witnesses.tsv"

EXPECTED_SCREEN_SHA="${LEO_STATE_PREQUENTIAL_SCREEN_SHA:-017ab2f9239ca20cc51f1691cf9175f4a5ca36e7e337a654654791f86a81ea8f}"
EXPECTED_WARM_SHA="${LEO_STATE_PREQUENTIAL_WARM_SHA:-02a7a18552ed850b3f7844ee75ca9bfedff5f9f6b750db293fbe81e271c51840}"
EXPECTED_ENROLLMENT_SHA="${LEO_STATE_PREQUENTIAL_ENROLLMENT_SHA:-d4f32d34a89819edb7428c06185889dfeb6648911571f4234f9ecdc5354df1fc}"
EXPECTED_WRITER_PLAN_SHA="${LEO_STATE_PREQUENTIAL_WRITER_PLAN_SHA:-1cb1301c20e5124bc9e0493a354c6eb83347eea6c14665181c366ef629df43b3}"
EXPECTED_WRITER_SHA="${LEO_STATE_PREQUENTIAL_WRITER_SHA:-10bf4251848f4edaec4a34d66d3d811afff187df9f10aeb71ff761a342c0e833}"
EXPECTED_A94_PLAN_SHA="${LEO_STATE_PREQUENTIAL_A94_PLAN_SHA:-9b0434bfa9bcc4c5cb6051cf7a6133f3fe0f51add036b5273721ece327e5ca2a}"
EXPECTED_A96_VALIDATION_SHA="${LEO_STATE_PREQUENTIAL_A96_VALIDATION_SHA:-6d155803cca27adb117b908575bfeac206c3096fdf05bba3c974fee306692303}"

case "$JOBS" in
    ''|*[!0-9]*|0) printf 'invalid road prequential jobs: %s\n' "$JOBS" >&2; exit 2 ;;
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

PLAN="$OUT/plan.tsv"
POLICIES="$OUT/policies.tsv"
LOCKS="$OUT/replay-locks.tsv"
WITNESSES="$OUT/turn-witnesses.tsv"
SCORES="$OUT/prequential-scores.tsv"
LIFE_SUMMARY="$OUT/life-summary.tsv"
CANDIDATE_SUMMARY="$OUT/candidate-summary.tsv"
SELECTION="$OUT/selection.tsv"
VERDICT="$OUT/verdict.txt"

write_cohorts() {
    printf 'cohort\tlife\tsplit\n'
    printf 'discovery\tp06\tprimary\n'
    printf 'discovery\tp07\tprimary\n'
    printf 'discovery\tp08\tprimary\n'
    printf 'discovery\tp09\tprimary\n'
    printf 'discovery\tp10\tprimary\n'
    printf 'discovery\tp11\tprimary\n'
    printf 'validation\tp12\tprimary\n'
    printf 'validation\tp14\tprimary\n'
    printf 'validation\tp16\tprimary\n'
    printf 'validation\tp17\tprimary\n'
    printf 'validation\tp18\tprimary\n'
    printf 'validation\tp19\tprimary\n'
    printf 'validation\th01\tholdout\n'
    printf 'validation\th03\tholdout\n'
    printf 'validation\th06\tholdout\n'
    printf 'validation\th07\tholdout\n'
    printf 'validation\th10\tholdout\n'
    printf 'validation\th12\tholdout\n'
}

write_policies() {
    printf 'candidate\tdecay\tstrength\trank\n'
    printf 'cumulative-1\t1.00\t1\t1\n'
    printf 'cumulative-3\t1.00\t3\t2\n'
    printf 'slow-1\t0.97\t1\t3\n'
    printf 'slow-3\t0.97\t3\t4\n'
    printf 'fast-1\t0.90\t1\t5\n'
    printf 'fast-3\t0.90\t3\t6\n'
}

write_plan() {
    awk -F '\t' -v OFS='\t' '
        FILENAME == ARGV[1] {
            if (FNR == 1) { if (NF != 19 || $4 != "life") exit 2; next }
            used[$4] = 1
            next
        }
        FILENAME == ARGV[2] {
            if (FNR == 1) { if (NF != 28 || $4 != "life") exit 2; next }
            used[$4] = 1
            next
        }
        FILENAME == ARGV[3] {
            if (FNR == 1) {
                if (NF != 5 || $1 != "life" || $5 != "enrollment_rank") exit 2
                next
            }
            if (enrolled[$1]++) exit 2
            split_name[$1] = $2; base[$1] = $3
            candidate_order[$1] = $4; rank[$1] = $5
            next
        }
        FNR == 1 {
            if (NF != 3 || $1 != "cohort" || $3 != "split") exit 2
            print "cohort", "life", "split", "base_seed", \
                "candidate_order", "enrollment_rank"
            next
        }
        {
            if (NF != 3 || $1 !~ /^(discovery|validation)$/ ||
                $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
                split_name[$2] != $3 || ($2 in used) || chosen[$2]++) exit 2
            print $1, $2, $3, base[$2], candidate_order[$2], rank[$2]
            cohort[$1]++; split_count[$1 SUBSEP $3]++; rows++
        }
        END {
            if (rows != 18 || cohort["discovery"] != 6 ||
                cohort["validation"] != 12 ||
                split_count["discovery" SUBSEP "primary"] != 6 ||
                split_count["validation" SUBSEP "primary"] != 6 ||
                split_count["validation" SUBSEP "holdout"] != 6) exit 2
        }
    ' "$A94_PLAN" "$A96_VALIDATION" "$ENROLLMENT" <(write_cohorts)
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$PLAN" "$POLICIES" "$LOCKS" "$WITNESSES"; do
        [ -s "$path" ] || {
            printf 'incomplete road prequential run: %s\n' "$OUT" >&2
            exit 2
        }
    done
    write_plan | cmp -s - "$PLAN" || {
        printf 'A.98 replay plan diverged\n' >&2
        exit 2
    }
    write_policies | cmp -s - "$POLICIES" || {
        printf 'A.98 policy ledger diverged\n' >&2
        exit 2
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT/replays"
    write_plan > "$PLAN"
    write_policies > "$POLICIES"
fi

if [ "${LEO_STATE_PREQUENTIAL_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    printf '\n'
    cat "$POLICIES"
    exit 0
fi

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

if [ "$AGGREGATE_ONLY" != 1 ]; then
    make -C "$ROOT" leo >/dev/null
    FIXTURE="$OUT/road-prequential-fixture"
    "$CC" "$ROOT/tests/state_swarm_road_prequential_fixture.c" \
        -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread

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
    done < <(tail -n +2 "$PLAN")
    if [ "$running" -gt 0 ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
    fi

    printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$LOCKS"
    printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$WITNESSES"
    while IFS=$'\t' read -r cohort life split base_seed candidate_order \
        enrollment_rank; do
        cat "$OUT/replays/$life/lock.tsv" >> "$LOCKS"
        cat "$OUT/replays/$life/witnesses.tsv" >> "$WITNESSES"
    done < <(tail -n +2 "$PLAN")
    rm -f "$FIXTURE"
fi

awk -f "$ROOT/scripts/state_swarm_road_prequential_report.awk" \
    "$POLICIES" "$LOCKS" "$WITNESSES" > "$SCORES"
awk -f "$ROOT/scripts/state_swarm_road_prequential_life.awk" \
    "$SCORES" > "$LIFE_SUMMARY"
awk -f "$ROOT/scripts/state_swarm_road_prequential_summary.awk" \
    "$LIFE_SUMMARY" > "$CANDIDATE_SUMMARY"
awk -f "$ROOT/scripts/state_swarm_road_prequential_select.awk" \
    "$CANDIDATE_SUMMARY" > "$SELECTION"
awk -f "$ROOT/scripts/state_swarm_road_prequential_verdict.awk" \
    "$SELECTION" "$CANDIDATE_SUMMARY" > "$VERDICT"

cat "$CANDIDATE_SUMMARY"
printf '\n'
cat "$SELECTION"
printf '\n'
cat "$VERDICT"
printf '\nsource-a89: %s\nrun: %s\n' "$A89" "$OUT"
