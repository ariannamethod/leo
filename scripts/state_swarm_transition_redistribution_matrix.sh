#!/usr/bin/env bash
# A.112: counterbalanced shadow trial of transition-surprise redistribution.
set -Eeuo pipefail

trap 'rc=$?; printf "transition-redistribution runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
SOURCE="${LEO_STATE_TRANSITION_REDISTRIBUTION_SOURCE:-/private/tmp/leo-state-swarm-susceptibility-reservoir-a110-r2-20260816}"
A111="${LEO_STATE_TRANSITION_REDISTRIBUTION_A111:-/private/tmp/leo-state-swarm-transition-plasticity-a111-r3-20260817}"
AGGREGATE_ONLY="${LEO_STATE_TRANSITION_REDISTRIBUTION_AGGREGATE_ONLY:-0}"
PLAN_ONLY="${LEO_STATE_TRANSITION_REDISTRIBUTION_PLAN_ONLY:-0}"
JOBS="${LEO_STATE_TRANSITION_REDISTRIBUTION_JOBS:-4}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-transition-redistribution-$STAMP}"

ENROLLMENT="$SOURCE/enrollment.tsv"
SOURCE_VERDICT="$SOURCE/verdict.txt"
A111_VALIDATION_PLAN="$A111/validation-plan.tsv"
A111_VERDICT="$A111/verdict.txt"
CASES="$ROOT/scripts/state_swarm_road_cases.tsv"
DIALOGUE_REPORTER="$ROOT/scripts/state_swarm_dialogue_report.awk"
REPORTER="$ROOT/scripts/state_swarm_transition_redistribution_report.awk"
LIFE_REPORTER="$ROOT/scripts/state_swarm_transition_redistribution_life.awk"
VERDICT_REPORTER="$ROOT/scripts/state_swarm_transition_redistribution_verdict.awk"
FIXTURE_SOURCE="$ROOT/tests/state_swarm_road_prequential_fixture.c"
FIXTURE="$OUT/state-swarm-geometry-fixture"

EXPECTED_ENROLLMENT_SHA=f0259bc36686bdc72242e3d4fa0d87d427f4b3e49a6c12db5dd481d5e7c553d5
EXPECTED_SOURCE_VERDICT_SHA=7457b2260ef4deddc88ecefff574be72af46535488ab0a4fa00405efcbb4dc28
EXPECTED_A111_VALIDATION_PLAN_SHA=e4caec4e8ed71445b28773272c26abb7449bde661e880c036ef5dc8a9ce16eed
EXPECTED_A111_VERDICT_SHA=c8c7bd2a6c6ad966c8c94738bf9c37192e71fab951b3d8e03b7e93dd247c2c60
EXPECTED_CASES_SHA=13df7a1a84c4e822d8b4d5810630bc5f456b894353c82ab2f70b7e1467e871b1
EXPECTED_DIALOGUE_REPORTER_SHA=35e393658785740430eec603459dac5ec3bfc1dc8bbac37f531de16582fe4c5e
EXPECTED_FIXTURE_SOURCE_SHA=6876954c90540ed92aa91a8beb47b433cee231207796b7d84c42c9f2dd9afa47

PLAN="$OUT/discovery-plan.tsv"
DESIGN="$OUT/design.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
RAW="$OUT/discovery-raw.tsv"
SCORES="$OUT/discovery-scores.tsv"
LIFE="$OUT/discovery-life-summary.tsv"
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
seal "$A111_VALIDATION_PLAN" "$EXPECTED_A111_VALIDATION_PLAN_SHA" "sealed A.111 validation plan"
seal "$A111_VERDICT" "$EXPECTED_A111_VERDICT_SHA" "A.111 refusal"
seal "$CASES" "$EXPECTED_CASES_SHA" "A.80 road cases"
seal "$DIALOGUE_REPORTER" "$EXPECTED_DIALOGUE_REPORTER_SHA" "state dialogue reporter"
seal "$FIXTURE_SOURCE" "$EXPECTED_FIXTURE_SOURCE_SHA" "state geometry fixture"
grep -q '^result=balanced-reservoir-anatomy-admissible$' "$SOURCE_VERDICT"
grep -q '^result no-transition-surprise-plasticity-candidate$' "$A111_VERDICT"
for forbidden in "$A111/validation-raw.tsv" "$A111/validation-scores.tsv" \
    "$A111/validation-life-summary.tsv" "$A111/validation-verdict.txt"; do
    [ ! -e "$forbidden" ] || {
        printf 'A.111 validation is no longer sealed: %s\n' "$forbidden" >&2
        exit 2
    }
done

write_plan() {
    awk -F '\t' -v OFS='\t' '
        FNR == NR {
            if (FNR == 1) {
                if (NF != 5 || $1 != "kind" || $2 != "session" ||
                    $3 != "order" || $4 != "texture" || $5 != "prompt")
                    exit 2
                next
            }
            if ($1 == "writer") {
                if ($2 < 1 || $2 > 6 || $3 < 1 || $3 > 8 ||
                    $4 !~ /^(home|storm|wonder|social)$/ ||
                    writer[$2 SUBSEP $3]++) exit 2
                texture[$2 SUBSEP $3] = $4
                prompt[$2 SUBSEP $3] = $5
                writer_rows++
            }
            next
        }
        FNR == 1 {
            if (writer_rows != 48 || NF != 5 || $1 != "life" ||
                $2 != "split" || $3 != "base_seed" ||
                $5 != "enrollment_rank") exit 2
            print "life", "split", "base_seed", "source_rank", "rotation", \
                "session", "order", "source_order", "texture", "run_seed", \
                "prompt"
            next
        }
        $5 >= 17 && $5 <= 32 {
            life = $1
            split_name = $2
            base_seed = $3
            rank = $5
            rotation = (rank - 17) % 8
            selected[split_name]++
            rotation_count[split_name SUBSEP rotation]++
            for (session = 1; session <= 6; session++)
                for (order = 1; order <= 8; order++) {
                    source_order = ((order - 1 + rotation) % 8) + 1
                    key = session SUBSEP source_order
                    run_seed = base_seed + 30000 + session * 100 + order
                    print life, split_name, base_seed, rank, rotation, \
                        session, order, source_order, texture[key], run_seed, \
                        prompt[key]
                    position_source[split_name SUBSEP order SUBSEP source_order]++
                    output_rows++
                }
        }
        END {
            if (writer_rows != 48 || selected["primary"] != 16 ||
                selected["holdout"] != 16 || output_rows != 1536) exit 2
            for (s = 1; s <= 2; s++) {
                name = s == 1 ? "primary" : "holdout"
                for (r = 0; r <= 7; r++)
                    if (rotation_count[name SUBSEP r] != 2) exit 2
                for (position = 1; position <= 8; position++)
                    for (source_order = 1; source_order <= 8; source_order++)
                        if (position_source[name SUBSEP position SUBSEP source_order] != 12)
                            exit 2
            }
        }
    ' "$CASES" "$ENROLLMENT"
}

write_design() {
    printf 'field\tvalue\n'
    printf 'mechanism\ttransition-surprise-redistribution\n'
    printf 'plasticity_gain\t0.25\n'
    printf 'edge_mass\tA.79-exact\n'
    printf 'source\tA.111-sealed-validation-bodies\n'
    printf 'counterbalance\teight cyclic position rotations twice per split\n'
    printf 'life_turns\t48\n'
    printf 'adaptation_turns\t24\n'
    printf 'evaluation_turns\t24\n'
    printf 'minimum_eligible_turns_per_life\t16\n'
    printf 'required_life_wins\t22\n'
    printf 'required_split_wins\t10\n'
    printf 'required_surprise_gain\t0.001\n'
    printf 'required_brier_gain\t0.00025\n'
    printf 'required_texture_sign\tpositive-all-four\n'
    printf 'required_position_sign\tpositive-all-eight\n'
    printf 'validation_rule\tfresh-population-after-discovery-pass-only\n'
}

write_source_receipt() {
    printf 'life\tsplit\tsource_rank\trotation\tstate_sha\n'
    awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $4 "\t" $5 }' \
        "$PLAN" | while IFS=$'\t' read -r life split rank rotation; do
        local body="$SOURCE/candidates/$life/leo.state"
        [ -s "$body" ] || { printf 'missing source body: %s\n' "$body" >&2; exit 2; }
        printf '%s\t%s\t%s\t%s\t%s\n' "$life" "$split" "$rank" \
            "$rotation" "$(sha256_file "$body")"
    done
}

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); gsub(/\t/, "\\t"); print; exit }' "$1"
}

run_life() {
    local life="$1" split="$2" base_seed="$3" rank="$4" rotation="$5"
    local life_dir="$OUT/replays/$split-$life"
    local raw="$life_dir/raw.tsv"
    local state="$life_dir/leo.state"
    local source_body="$SOURCE/candidates/$life/leo.state"
    mkdir -p "$life_dir"
    cp "$source_body" "$state"
    : > "$raw"
    local rows=0
    while IFS=$'\t' read -r plan_life plan_split plan_seed plan_rank \
        plan_rotation session order source_order texture run_seed prompt; do
        rows=$((rows + 1))
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local log="$life_dir/$stem.log"
        local receipt="$life_dir/$stem.receipt.tsv"
        local pre post pre_turn pre_ids source transition transition_total
        local post_turn post_ids target ignored_transition ignored_total
        local reply event has_prediction
        pre="$("$FIXTURE" "$state")"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$state" \
            --seed "$run_seed" --respond "$prompt" --debug-field --save "$state" \
            --no-state-transition-plasticity > "$log" 2>&1
        post="$("$FIXTURE" "$state")"
        reply="$(reply_from_log "$log")"
        [ -n "$reply" ] || return 1
        awk -v cell="$life" -v cohort="$split" -v base_seed="$base_seed" \
            -v phase=redistribution -v session="$session" -v order="$order" \
            -v texture="$texture" -v run_seed="$run_seed" -v prompt="$prompt" \
            -v reply="$reply" -f "$DIALOGUE_REPORTER" "$log" > "$receipt"
        event="$(awk -F '\t' '{print $13}' "$receipt")"
        has_prediction="$(awk -F '\t' '{print $20}' "$receipt")"
        IFS=$'\t' read -r pre_turn pre_ids source transition transition_total <<< "$pre"
        IFS=$'\t' read -r post_turn post_ids target ignored_transition ignored_total <<< "$post"
        printf 'discovery\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$life" "$split" "$rank" "$rotation" "$session" "$order" \
            "$source_order" "$texture" "$event" "$reply" "$pre_turn" \
            "$pre_ids" "$source" "$transition" "$transition_total" \
            "$post_turn" "$post_ids" "$target" "$has_prediction" >> "$raw"
    done < <(awk -F '\t' -v life="$life" 'NR > 1 && $1 == life' "$PLAN")
    [ "$rows" -eq 48 ] || return 1
}

replay_plan() {
    local running=0
    local -a pids=()
    printf 'cohort\tlife\tsplit\trank\trotation\tsession\torder\tsource_order\ttexture\tevent\treply\tpre_turn\tpre_ids\tsource\ttransition\ttransition_total\tpost_turn\tpost_ids\ttarget\thas_prediction\n' > "$RAW"
    while IFS=$'\t' read -r life split base_seed rank rotation; do
        run_life "$life" "$split" "$base_seed" "$rank" "$rotation" &
        pids+=("$!")
        running=$((running + 1))
        if [ "$running" -ge "$JOBS" ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
            pids=()
            running=0
        fi
    done < <(awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 }' "$PLAN")
    if [ "$running" -gt 0 ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
    fi
    while IFS=$'\t' read -r life split; do
        cat "$OUT/replays/$split-$life/raw.tsv" >> "$RAW"
    done < <(awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 }' "$PLAN")
}

aggregate() {
    awk -f "$REPORTER" "$RAW" > "$SCORES"
    awk -f "$LIFE_REPORTER" "$SCORES" > "$LIFE"
    awk -f "$VERDICT_REPORTER" "$LIFE" > "$VERDICT"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$PLAN" "$DESIGN" "$SOURCE_RECEIPT" "$RAW"; do
        [ -s "$path" ] || { printf 'incomplete A.112 aggregate source: %s\n' "$path" >&2; exit 2; }
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
    if [ "$PLAN_ONLY" = 1 ]; then
        printf 'A.112 counterbalanced discovery plan: %s\n' "$OUT"
        exit 0
    fi
    make -C "$ROOT" leo >/dev/null
    "$CC" "$FIXTURE_SOURCE" -O2 -lm -Wall -Wextra -Wno-unused-function \
        -o "$FIXTURE" -lpthread
    replay_plan
fi

aggregate
cat "$VERDICT"
