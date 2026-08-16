#!/usr/bin/env bash
# A.111: paired population trial of bounded transition-surprise plasticity.
set -Eeuo pipefail

trap 'rc=$?; printf "transition-plasticity runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
SOURCE="${LEO_STATE_TRANSITION_PLASTICITY_SOURCE:-/private/tmp/leo-state-swarm-susceptibility-reservoir-a110-r2-20260816}"
AGGREGATE_ONLY="${LEO_STATE_TRANSITION_PLASTICITY_AGGREGATE_ONLY:-0}"
JOBS="${LEO_STATE_TRANSITION_PLASTICITY_JOBS:-4}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-transition-plasticity-$STAMP}"

ENROLLMENT="$SOURCE/enrollment.tsv"
SOURCE_VERDICT="$SOURCE/verdict.txt"
CASES="$ROOT/scripts/state_swarm_road_cases.tsv"
DIALOGUE_REPORTER="$ROOT/scripts/state_swarm_dialogue_report.awk"
REPORTER="$ROOT/scripts/state_swarm_transition_plasticity_report.awk"
LIFE_REPORTER="$ROOT/scripts/state_swarm_transition_plasticity_life.awk"
VERDICT_REPORTER="$ROOT/scripts/state_swarm_transition_plasticity_verdict.awk"
FIXTURE_SOURCE="$ROOT/tests/state_swarm_road_prequential_fixture.c"
FIXTURE="$OUT/state-swarm-geometry-fixture"

EXPECTED_ENROLLMENT_SHA=f0259bc36686bdc72242e3d4fa0d87d427f4b3e49a6c12db5dd481d5e7c553d5
EXPECTED_SOURCE_VERDICT_SHA=7457b2260ef4deddc88ecefff574be72af46535488ab0a4fa00405efcbb4dc28
EXPECTED_CASES_SHA=13df7a1a84c4e822d8b4d5810630bc5f456b894353c82ab2f70b7e1467e871b1
EXPECTED_DIALOGUE_REPORTER_SHA=35e393658785740430eec603459dac5ec3bfc1dc8bbac37f531de16582fe4c5e
EXPECTED_FIXTURE_SOURCE_SHA=6876954c90540ed92aa91a8beb47b433cee231207796b7d84c42c9f2dd9afa47

DISCOVERY_PLAN="$OUT/discovery-plan.tsv"
VALIDATION_PLAN="$OUT/validation-plan.tsv"
DESIGN="$OUT/design.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
DISCOVERY_RAW="$OUT/discovery-raw.tsv"
DISCOVERY_SCORES="$OUT/discovery-scores.tsv"
DISCOVERY_LIFE="$OUT/discovery-life-summary.tsv"
DISCOVERY_VERDICT="$OUT/discovery-verdict.txt"
VALIDATION_RAW="$OUT/validation-raw.tsv"
VALIDATION_SCORES="$OUT/validation-scores.tsv"
VALIDATION_LIFE="$OUT/validation-life-summary.tsv"
VALIDATION_VERDICT="$OUT/validation-verdict.txt"
VERDICT="$OUT/verdict.txt"

case "$JOBS" in ''|*[!0-9]*) printf 'invalid jobs: %s\n' "$JOBS" >&2; exit 2;; esac
[ "$JOBS" -ge 1 ] || { printf 'jobs must be positive\n' >&2; exit 2; }

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
seal() {
    local path="$1" expected="$2" label="$3" actual
    [ -s "$path" ] || { printf 'missing %s: %s\n' "$label" "$path" >&2; exit 2; }
    actual="$(sha256_file "$path")"
    [ "$actual" = "$expected" ] || {
        printf '%s SHA mismatch: expected=%s actual=%s\n' "$label" "$expected" "$actual" >&2
        exit 2
    }
}

seal "$ENROLLMENT" "$EXPECTED_ENROLLMENT_SHA" "A.110 enrollment"
seal "$SOURCE_VERDICT" "$EXPECTED_SOURCE_VERDICT_SHA" "A.110 reservoir verdict"
seal "$CASES" "$EXPECTED_CASES_SHA" "A.80 road cases"
seal "$DIALOGUE_REPORTER" "$EXPECTED_DIALOGUE_REPORTER_SHA" "state dialogue reporter"
seal "$FIXTURE_SOURCE" "$EXPECTED_FIXTURE_SOURCE_SHA" "state geometry fixture"
grep -q '^result=balanced-reservoir-anatomy-admissible$' "$SOURCE_VERDICT"

write_plan() {
    local cohort="$1"
    awk -F '\t' -v OFS='\t' -v cohort="$cohort" '
        NR == 1 { print "cohort", $0; next }
        cohort == "discovery" && $5 >= 1 && $5 <= 16 { print cohort, $0; rows++; split_count[$2]++ }
        cohort == "validation" && $5 >= 17 && $5 <= 32 { print cohort, $0; rows++; split_count[$2]++ }
        END { if (rows != 32 || split_count["primary"] != 16 || split_count["holdout"] != 16) exit 2 }
    ' "$ENROLLMENT"
}

write_design() {
    printf 'field\tvalue\n'
    printf 'mechanism\ttransition-surprise-plasticity\n'
    printf 'plasticity_gain\t0.25\n'
    printf 'source\tA.110-final-writer-bodies\n'
    printf 'life_turns\t48\n'
    printf 'adaptation_turns\t24\n'
    printf 'evaluation_turns\t24\n'
    printf 'minimum_eligible_turns_per_life\t16\n'
    printf 'required_life_wins\t22\n'
    printf 'required_split_wins\t10\n'
    printf 'required_surprise_gain\t0.001\n'
    printf 'required_brier_gain\t0.00025\n'
    printf 'required_texture_sign\tpositive-all-four\n'
    printf 'entropy_delta_floor\t-0.01\n'
    printf 'validation_rule\tdiscovery-pass-only\n'
}

write_source_receipt() {
    printf 'life\tsplit\tenrollment_rank\tstate_sha\n'
    while IFS=$'\t' read -r life split base_seed candidate_order rank; do
        [ "$life" = life ] && continue
        local body="$SOURCE/candidates/$life/leo.state"
        [ -s "$body" ] || { printf 'missing source body: %s\n' "$body" >&2; exit 2; }
        printf '%s\t%s\t%s\t%s\n' "$life" "$split" "$rank" "$(sha256_file "$body")"
    done < "$ENROLLMENT"
}

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); gsub(/\t/, "\\t"); print; exit }' "$1"
}

run_life() {
    local cohort="$1" life="$2" split="$3" base_seed="$4" rank="$6"
    local life_dir="$OUT/replays/$cohort-$split-$life"
    local raw="$life_dir/raw.tsv"
    local source_body="$SOURCE/candidates/$life/leo.state"
    mkdir -p "$life_dir/on" "$life_dir/off"
    : > "$raw"

    for arm in on off; do
        local state="$life_dir/$arm/leo.state"
        cp "$source_body" "$state"
        local rows=0
        while IFS=$'\t' read -r kind session order texture prompt; do
            [ "$kind" = writer ] || continue
            rows=$((rows + 1))
            local run_seed=$((base_seed + 20000 + session * 100 + order))
            local stem="s${session}-$(printf '%02d' "$order")-${texture}"
            local log="$life_dir/$arm/$stem.log"
            local receipt="$life_dir/$arm/$stem.receipt.tsv"
            local pre post pre_turn pre_ids source transition transition_total
            local post_turn post_ids target ignored_transition ignored_total
            local reply event has_prediction
            pre="$("$FIXTURE" "$state")"
            local args=("$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$state"
                --seed "$run_seed" --respond "$prompt" --debug-field --save "$state")
            if [ "$arm" = on ]; then
                args+=(--state-transition-plasticity)
            else
                args+=(--no-state-transition-plasticity)
            fi
            "${args[@]}" > "$log" 2>&1
            post="$("$FIXTURE" "$state")"
            reply="$(reply_from_log "$log")"
            [ -n "$reply" ] || return 1
            awk -v cell="$life" -v cohort="$split" -v base_seed="$base_seed" \
                -v phase=plasticity -v session="$session" -v order="$order" \
                -v texture="$texture" -v run_seed="$run_seed" -v prompt="$prompt" \
                -v reply="$reply" -f "$DIALOGUE_REPORTER" "$log" > "$receipt"
            event="$(awk -F '\t' '{print $13}' "$receipt")"
            has_prediction="$(awk -F '\t' '{print $20}' "$receipt")"
            IFS=$'\t' read -r pre_turn pre_ids source transition transition_total <<< "$pre"
            IFS=$'\t' read -r post_turn post_ids target ignored_transition ignored_total <<< "$post"
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$cohort" "$life" "$split" "$rank" "$arm" "$session" "$order" \
                "$texture" "$event" "$reply" "$pre_turn" "$pre_ids" "$source" \
                "$transition" "$transition_total" "$post_turn" "$post_ids" "$target" \
                "$has_prediction" >> "$raw"
        done < "$CASES"
        [ "$rows" -eq 48 ] || return 1
    done
}

replay_plan() {
    local plan="$1" raw_out="$2"
    local running=0
    local -a pids=()
    printf 'cohort\tlife\tsplit\trank\tarm\tsession\torder\ttexture\tevent\treply\tpre_turn\tpre_ids\tsource\ttransition\ttransition_total\tpost_turn\tpost_ids\ttarget\thas_prediction\n' > "$raw_out"
    while IFS=$'\t' read -r cohort life split base_seed candidate_order rank; do
        [ "$cohort" = cohort ] && continue
        run_life "$cohort" "$life" "$split" "$base_seed" "$candidate_order" "$rank" &
        pids+=("$!")
        running=$((running + 1))
        if [ "$running" -ge "$JOBS" ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
            pids=()
            running=0
        fi
    done < "$plan"
    if [ "$running" -gt 0 ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
    fi
    while IFS=$'\t' read -r cohort life split base_seed candidate_order rank; do
        [ "$cohort" = cohort ] && continue
        cat "$OUT/replays/$cohort-$split-$life/raw.tsv" >> "$raw_out"
    done < "$plan"
}

aggregate() {
    local cohort="$1" raw="$2" scores="$3" life="$4" verdict="$5"
    awk -f "$REPORTER" "$raw" > "$scores"
    awk -f "$LIFE_REPORTER" "$scores" > "$life"
    awk -v cohort="$cohort" -f "$VERDICT_REPORTER" "$life" > "$verdict"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$DISCOVERY_PLAN" "$VALIDATION_PLAN" "$DESIGN" "$SOURCE_RECEIPT" \
        "$DISCOVERY_RAW"; do
        [ -s "$path" ] || { printf 'incomplete A.111 aggregate source: %s\n' "$path" >&2; exit 2; }
    done
    write_plan discovery | cmp -s - "$DISCOVERY_PLAN"
    write_plan validation | cmp -s - "$VALIDATION_PLAN"
    write_design | cmp -s - "$DESIGN"
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT"
else
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
    mkdir -p "$OUT/replays"
    write_plan discovery > "$DISCOVERY_PLAN"
    write_plan validation > "$VALIDATION_PLAN"
    write_design > "$DESIGN"
    write_source_receipt > "$SOURCE_RECEIPT"
    make -C "$ROOT" leo >/dev/null
    "$CC" "$FIXTURE_SOURCE" -O2 -lm -Wall -Wextra -Wno-unused-function \
        -o "$FIXTURE" -lpthread
    replay_plan "$DISCOVERY_PLAN" "$DISCOVERY_RAW"
fi

aggregate discovery "$DISCOVERY_RAW" "$DISCOVERY_SCORES" \
    "$DISCOVERY_LIFE" "$DISCOVERY_VERDICT"

if grep -q '^result transition-surprise-plasticity-candidate$' "$DISCOVERY_VERDICT"; then
    if [ "$AGGREGATE_ONLY" != 1 ]; then
        replay_plan "$VALIDATION_PLAN" "$VALIDATION_RAW"
    else
        [ -s "$VALIDATION_RAW" ] || { printf 'A.111 validation was selected but is absent\n' >&2; exit 2; }
    fi
    aggregate validation "$VALIDATION_RAW" "$VALIDATION_SCORES" \
        "$VALIDATION_LIFE" "$VALIDATION_VERDICT"
    cp "$VALIDATION_VERDICT" "$VERDICT"
else
    for forbidden in "$VALIDATION_RAW" "$VALIDATION_SCORES" \
        "$VALIDATION_LIFE" "$VALIDATION_VERDICT"; do
        [ ! -e "$forbidden" ] || { printf 'validation opened without discovery admission: %s\n' "$forbidden" >&2; exit 2; }
    done
    cp "$DISCOVERY_VERDICT" "$VERDICT"
fi

cat "$VERDICT"
