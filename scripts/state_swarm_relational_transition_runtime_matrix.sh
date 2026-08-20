#!/usr/bin/env bash
# A.114: embody the sealed A.113 law and compare every runtime matrix byte
# against an independent shadow replay over the complete overflow population.
set -Eeuo pipefail

trap 'rc=$?; printf "relational-transition runtime runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
SOURCE="${LEO_STATE_RELATIONAL_RUNTIME_SOURCE:-/private/tmp/leo-state-swarm-susceptibility-reservoir-a110-r2-20260816}"
A113="${LEO_STATE_RELATIONAL_RUNTIME_A113:-/private/tmp/leo-state-swarm-relational-transition-a113-r1-20260818}"
AGGREGATE_ONLY="${LEO_STATE_RELATIONAL_RUNTIME_AGGREGATE_ONLY:-0}"
JOBS="${LEO_STATE_RELATIONAL_RUNTIME_JOBS:-4}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-relational-transition-runtime-$STAMP}"

A113_DESIGN="$A113/design.tsv"
A113_PLAN="$A113/validation-plan.tsv"
A113_SOURCE_RECEIPT="$A113/source-receipt.tsv"
A113_VERDICT="$A113/verdict.txt"
FIXTURE_SOURCE="$ROOT/tests/state_swarm_relational_transition_runtime_fixture.c"
REPORTER="$ROOT/scripts/state_swarm_relational_transition_runtime_verdict.awk"
PLAN="$OUT/runtime-plan.tsv"
DESIGN="$OUT/design.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
RAW="$OUT/runtime-raw.tsv"
VERDICT="$OUT/verdict.txt"
FIXTURE="$OUT/state-swarm-relational-transition-runtime-fixture"

EXPECTED_A113_DESIGN_SHA=74c3a9350d65dec5e89fe710c314e3a39e164ea8fe24f7819664666bc8cd5d21
EXPECTED_A113_PLAN_SHA=02b87539322ddafbcf2f7c9959019dcbacf53595120223f1c72ed8edd59b6d92
EXPECTED_A113_SOURCE_RECEIPT_SHA=c35df9a6dbfbc1a8b5b4f1e7a53817a35573cc01d453a818a444b0f7987ddaa2
EXPECTED_A113_VERDICT_SHA=bf77884723d4abd760e84fa8819749ea9692de8259877dc4aa8ffa977c0432d5

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

seal "$A113_DESIGN" "$EXPECTED_A113_DESIGN_SHA" "A.113 design"
seal "$A113_PLAN" "$EXPECTED_A113_PLAN_SHA" "A.113 validation plan"
seal "$A113_SOURCE_RECEIPT" "$EXPECTED_A113_SOURCE_RECEIPT_SHA" "A.113 source receipt"
seal "$A113_VERDICT" "$EXPECTED_A113_VERDICT_SHA" "A.113 verdict"
grep -q '^result[[:space:]]relational-transition-redistribution-confirmed$' \
    "$A113_VERDICT"

write_plan() {
    awk -F '\t' -v OFS='\t' '
        NR == 1 { print; next }
        $5 == 0 { print; rows++; life[$1]++ }
        END {
            if (rows != 528 || length(life) != 11) exit 2
            for (name in life) if (life[name] != 48) exit 2
        }
    ' "$A113_PLAN"
}

write_design() {
    printf 'field\tvalue\n'
    printf 'mechanism\trelational-transition-runtime\n'
    printf 'source_law\tA.113 sealed confirmation\n'
    printf 'semantic_share\tpositive(gap_relief)/max(positive(gap_relief),positive(distress_relief))\n'
    printf 'candidate_alpha\talpha*(1+0.50*miss*semantic_share)\n'
    printf 'default\toff\n'
    printf 'runtime_lives\t11 (5 primary + 6 holdout)\n'
    printf 'runtime_turns_per_life\t48\n'
    printf 'rotation\tA.113 rotation 0\n'
    printf 'reference\tindependent exact-float C shadow\n'
    printf 'matrix_comparison\tfull transition memcmp after every uncensored turn\n'
    printf 'persisted_boundary\tall saved bytes except transition must match control\n'
    printf 'voice_boundary\tcandidate and control reply exact after every turn\n'
    printf 'default_ablation\t48-turn default versus explicit-off body/reply cmp\n'
    printf 'prototype_plasticity\texplicitly off in every arm\n'
}

write_source_receipt() {
    printf 'life\tsplit\tcandidate_order\tstate_sha\n'
    awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $4 }' \
        "$PLAN" | while IFS=$'\t' read -r life split candidate_order; do
        local body="$SOURCE/candidates/$life/leo.state"
        [ -s "$body" ] || { printf 'missing source body: %s\n' "$body" >&2; exit 2; }
        printf '%s\t%s\t%s\t%s\n' "$life" "$split" "$candidate_order" \
            "$(sha256_file "$body")"
    done
}

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); gsub(/\t/, "\\t"); print; exit }' "$1"
}

run_life() {
    local life="$1" split="$2"
    local life_dir="$OUT/replays/$split-$life"
    local source_body="$SOURCE/candidates/$life/leo.state"
    local candidate="$life_dir/candidate.state"
    local control="$life_dir/control.state"
    local raw="$life_dir/raw.tsv"
    mkdir -p "$life_dir/candidate" "$life_dir/control"
    cp "$source_body" "$candidate"
    cp "$source_body" "$control"
    : > "$raw"

    while IFS=$'\t' read -r plan_life plan_split base_seed candidate_order \
            rotation session order source_order texture run_seed prompt; do
        [ "$plan_life" = life ] && continue
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local before="$life_dir/candidate/$stem.before.state"
        local candidate_log="$life_dir/candidate/$stem.log"
        local control_log="$life_dir/control/$stem.log"
        cp "$candidate" "$before"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$candidate" \
            --seed "$run_seed" --respond "$prompt" --save "$candidate" \
            --state-relational-transition --no-state-transition-plasticity \
            > "$candidate_log" 2>&1
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$control" \
            --seed "$run_seed" --respond "$prompt" --save "$control" \
            --no-state-relational-transition --no-state-transition-plasticity \
            > "$control_log" 2>&1

        local reference status overlap semantic_share candidate_changed
        reference="$("$FIXTURE" reference "$before" "$candidate")"
        IFS=$'\t' read -r status overlap semantic_share candidate_changed \
            <<< "$reference"
        [ "$status" = exact ] || [ "$status" = censored ]
        [ "$("$FIXTURE" transition-only "$candidate" "$control")" = \
            transition-only ]
        local candidate_reply control_reply same_reply=0
        candidate_reply="$(reply_from_log "$candidate_log")"
        control_reply="$(reply_from_log "$control_log")"
        [ -n "$candidate_reply" ] && [ "$candidate_reply" = "$control_reply" ] && \
            same_reply=1
        printf 'runtime\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t1\t%s\n' \
            "$life" "$split" "$session" "$order" "$texture" "$status" \
            "$overlap" "$semantic_share" "$candidate_changed" "$same_reply" \
            >> "$raw"
    done < <(awk -F '\t' -v life="$life" 'NR == 1 || $1 == life' "$PLAN")
    [ "$(wc -l < "$raw" | tr -d ' ')" -eq 48 ]
}

run_default_ablation() {
    local life=p36 split=primary
    local life_dir="$OUT/replays/default-$life"
    local source_body="$SOURCE/candidates/$life/leo.state"
    local ordinary="$life_dir/default.state"
    local ablation="$life_dir/ablation.state"
    local raw="$life_dir/raw.tsv"
    mkdir -p "$life_dir/default" "$life_dir/ablation"
    cp "$source_body" "$ordinary"
    cp "$source_body" "$ablation"
    : > "$raw"

    while IFS=$'\t' read -r plan_life plan_split base_seed candidate_order \
            rotation session order source_order texture run_seed prompt; do
        [ "$plan_life" = life ] && continue
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local ordinary_log="$life_dir/default/$stem.log"
        local ablation_log="$life_dir/ablation/$stem.log"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$ordinary" \
            --seed "$run_seed" --respond "$prompt" --save "$ordinary" \
            --no-state-transition-plasticity > "$ordinary_log" 2>&1
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$ablation" \
            --seed "$run_seed" --respond "$prompt" --save "$ablation" \
            --no-state-relational-transition --no-state-transition-plasticity \
            > "$ablation_log" 2>&1
        cmp -s "$ordinary" "$ablation"
        local ordinary_reply ablation_reply same_reply=0
        ordinary_reply="$(reply_from_log "$ordinary_log")"
        ablation_reply="$(reply_from_log "$ablation_log")"
        [ -n "$ordinary_reply" ] && [ "$ordinary_reply" = "$ablation_reply" ] && \
            same_reply=1
        printf 'default\t%s\t%s\t%s\t%s\t%s\tdefault-exact\t0\t0\t0\t1\t%s\n' \
            "$life" "$split" "$session" "$order" "$texture" "$same_reply" \
            >> "$raw"
    done < <(awk -F '\t' -v life="$life" 'NR == 1 || $1 == life' "$PLAN")
    [ "$(wc -l < "$raw" | tr -d ' ')" -eq 48 ]
}

replay() {
    local running=0
    local -a pids=()
    while IFS=$'\t' read -r life split; do
        run_life "$life" "$split" &
        pids+=("$!")
        running=$((running + 1))
        if [ "$running" -ge "$JOBS" ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
            pids=()
            running=0
        fi
    done < <(awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 }' "$PLAN")
    if [ "$running" -gt 0 ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
    fi
    run_default_ablation

    printf 'kind\tlife\tsplit\tsession\torder\ttexture\treference\toverlap\tsemantic_share\tcandidate_changed\ttransition_only\tsame_reply\n' > "$RAW"
    while IFS=$'\t' read -r life split; do
        cat "$OUT/replays/$split-$life/raw.tsv" >> "$RAW"
    done < <(awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 }' "$PLAN")
    cat "$OUT/replays/default-p36/raw.tsv" >> "$RAW"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$PLAN" "$DESIGN" "$SOURCE_RECEIPT" "$RAW"; do
        [ -s "$path" ] || { printf 'incomplete A.114 aggregate source: %s\n' "$path" >&2; exit 2; }
    done
    write_plan | cmp -s - "$PLAN"
    write_design | cmp -s - "$DESIGN"
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT"
else
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
    mkdir -p "$OUT/replays"
    write_plan > "$PLAN"
    write_design > "$DESIGN"
    write_source_receipt > "$SOURCE_RECEIPT"
    cmp -s "$SOURCE_RECEIPT" "$A113_SOURCE_RECEIPT"
    make -C "$ROOT" leo >/dev/null
    "$CC" "$FIXTURE_SOURCE" -O2 -lm -Wall -Wextra -Wno-unused-function \
        -o "$FIXTURE" -lpthread
    replay
fi

awk -f "$REPORTER" "$RAW" > "$VERDICT"
cat "$VERDICT"
