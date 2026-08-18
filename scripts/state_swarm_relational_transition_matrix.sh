#!/usr/bin/env bash
# A.113: sealed confirmation of consequence-gated transition redistribution.
set -Eeuo pipefail

trap 'rc=$?; printf "relational-transition runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
SOURCE="${LEO_STATE_RELATIONAL_TRANSITION_SOURCE:-/private/tmp/leo-state-swarm-susceptibility-reservoir-a110-r2-20260816}"
A112="${LEO_STATE_RELATIONAL_TRANSITION_A112:-/private/tmp/leo-state-swarm-transition-redistribution-a112-r1-20260817}"
AGGREGATE_ONLY="${LEO_STATE_RELATIONAL_TRANSITION_AGGREGATE_ONLY:-0}"
PLAN_ONLY="${LEO_STATE_RELATIONAL_TRANSITION_PLAN_ONLY:-0}"
JOBS="${LEO_STATE_RELATIONAL_TRANSITION_JOBS:-4}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-relational-transition-$STAMP}"

SCREENING="$SOURCE/screening.tsv"
SOURCE_VERDICT="$SOURCE/verdict.txt"
A112_RAW="$A112/discovery-raw.tsv"
A112_SCORES="$A112/discovery-scores.tsv"
A112_VERDICT="$A112/verdict.txt"
CASES="$ROOT/scripts/state_swarm_road_cases.tsv"
DIALOGUE_REPORTER="$ROOT/scripts/state_swarm_dialogue_report.awk"
REPORTER="$ROOT/scripts/state_swarm_relational_transition_report.awk"
LIFE_REPORTER="$ROOT/scripts/state_swarm_relational_transition_life.awk"
VERDICT_REPORTER="$ROOT/scripts/state_swarm_relational_transition_verdict.awk"
FIXTURE_SOURCE="$ROOT/tests/state_swarm_relational_transition_fixture.c"
FIXTURE="$OUT/state-swarm-relational-transition-fixture"

EXPECTED_SCREENING_SHA=2cc815fc5243abe364ecf82f430f7156f17ba5b7d74de8f8768c27296fcc9d17
EXPECTED_SOURCE_VERDICT_SHA=7457b2260ef4deddc88ecefff574be72af46535488ab0a4fa00405efcbb4dc28
EXPECTED_A112_RAW_SHA=6a2b6552b723582d339897c8e4ebc785708c29157b01833e68eb8779f9ed69d7
EXPECTED_A112_SCORES_SHA=22b7575cb3feca27de94e911ec8af0e9a2be440455034819b70c81c1198db5b9
EXPECTED_A112_VERDICT_SHA=8dcd0c7346935df6d3384949b2a2641d6031f02dae171b43c65b6b4ab08aaeea
EXPECTED_CASES_SHA=13df7a1a84c4e822d8b4d5810630bc5f456b894353c82ab2f70b7e1467e871b1
EXPECTED_DIALOGUE_REPORTER_SHA=35e393658785740430eec603459dac5ec3bfc1dc8bbac37f531de16582fe4c5e
EXPECTED_FIXTURE_SOURCE_SHA=0239b569d1d446b33bef010c28d9ee00e6a7a745e1578cfc6706c4465fc88809

PLAN="$OUT/validation-plan.tsv"
DESIGN="$OUT/design.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
RAW="$OUT/validation-raw.tsv"
SCORES="$OUT/validation-scores.tsv"
LIFE="$OUT/validation-life-summary.tsv"
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

seal "$SCREENING" "$EXPECTED_SCREENING_SHA" "A.110 screening"
seal "$SOURCE_VERDICT" "$EXPECTED_SOURCE_VERDICT_SHA" "A.110 reservoir verdict"
seal "$A112_RAW" "$EXPECTED_A112_RAW_SHA" "A.112 raw receipts"
seal "$A112_SCORES" "$EXPECTED_A112_SCORES_SHA" "A.112 discovery scores"
seal "$A112_VERDICT" "$EXPECTED_A112_VERDICT_SHA" "A.112 refusal"
seal "$CASES" "$EXPECTED_CASES_SHA" "A.80 road cases"
seal "$DIALOGUE_REPORTER" "$EXPECTED_DIALOGUE_REPORTER_SHA" "state dialogue reporter"
seal "$FIXTURE_SOURCE" "$EXPECTED_FIXTURE_SOURCE_SHA" "relational fixture source"
grep -q '^result=balanced-reservoir-anatomy-admissible$' "$SOURCE_VERDICT"
grep -q '^result[[:space:]]no-transition-surprise-redistribution-candidate$' \
    "$A112_VERDICT"

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
            if (writer_rows != 48 || NF != 13 || $1 != "life" ||
                $2 != "split" || $3 != "base_seed" ||
                $11 != "settled" || $12 != "enrolled" ||
                $13 != "enrollment_rank") exit 2
            print "life", "split", "base_seed", "candidate_order", \
                "rotation", "session", "order", "source_order", \
                "texture", "run_seed", "prompt"
            next
        }
        $11 == "true" && $12 == "false" {
            life = $1
            split_name = $2
            base_seed = $3
            candidate_order = $4
            selected[split_name]++
            seen_life[life]++
            for (rotation = 0; rotation <= 7; rotation++)
                for (session = 1; session <= 6; session++)
                    for (order = 1; order <= 8; order++) {
                        source_order = ((order - 1 + rotation) % 8) + 1
                        key = session SUBSEP source_order
                        run_seed = base_seed + 40000 + session * 100 + order
                        print life, split_name, base_seed, candidate_order, \
                            rotation, session, order, source_order, \
                            texture[key], run_seed, prompt[key]
                        position_source[life SUBSEP order SUBSEP source_order]++
                        output_rows++
                    }
        }
        END {
            if (writer_rows != 48 || selected["primary"] != 5 ||
                selected["holdout"] != 6 || output_rows != 4224)
                exit 2
            for (life in seen_life) {
                if (seen_life[life] != 1) exit 2
                for (position = 1; position <= 8; position++)
                    for (source_order = 1; source_order <= 8; source_order++)
                        if (position_source[life SUBSEP position SUBSEP source_order] != 6)
                            exit 2
            }
        }
    ' "$CASES" "$SCREENING"
}

write_design() {
    printf 'field\tvalue\n'
    printf 'mechanism\trelational-transition-redistribution\n'
    printf 'nomination_source\tA.112 sealed discovery only\n'
    printf 'nomination_life_wins\t25 (11 primary + 14 holdout)\n'
    printf 'nomination_surprise_gain\t0.002150471\n'
    printf 'nomination_brier_gain\t0.000345148\n'
    printf 'semantic_share\tpositive(gap_relief)/max(positive(gap_relief),positive(distress_relief))\n'
    printf 'plasticity_gain\t0.50\n'
    printf 'candidate_alpha\talpha*(1+0.50*miss*semantic_share)\n'
    printf 'matched_control\tA.112 alpha*(1+0.25*miss)\n'
    printf 'edge_mass\tA.79-exact\n'
    printf 'validation_source\tA.110 settled non-enrolled overflow only\n'
    printf 'validation_lives\t11 (5 primary + 6 holdout)\n'
    printf 'branches_per_life\t8 cyclic rotations\n'
    printf 'branch_turns\t48\n'
    printf 'branch_adaptation_turns\t24\n'
    printf 'branch_evaluation_turns\t24\n'
    printf 'minimum_eligible_turns_per_branch\t16\n'
    printf 'required_life_wins\t8\n'
    printf 'required_primary_wins\t4\n'
    printf 'required_holdout_wins\t4\n'
    printf 'required_surprise_gain\t0.001\n'
    printf 'required_brier_gain\t0.00025\n'
    printf 'required_relational_over_ungated_surprise\tpositive\n'
    printf 'required_texture_sign\tpositive-all-four\n'
    printf 'required_position_sign\tpositive-all-eight\n'
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

run_branch() {
    local life="$1" split="$2" base_seed="$3" candidate_order="$4" rotation="$5"
    local branch_dir="$OUT/replays/$split-$life/r$rotation"
    local raw="$branch_dir/raw.tsv"
    local state="$branch_dir/leo.state"
    local source_body="$SOURCE/candidates/$life/leo.state"
    mkdir -p "$branch_dir"
    cp "$source_body" "$state"
    : > "$raw"
    local rows=0
    while IFS=$'\t' read -r plan_life plan_split plan_seed plan_candidate_order \
        plan_rotation session order source_order texture run_seed prompt; do
        rows=$((rows + 1))
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local log="$branch_dir/$stem.log"
        local receipt="$branch_dir/$stem.receipt.tsv"
        local pre post pre_turn pre_ids source transition transition_total
        local pre_gap pre_distress pre_alignment post_turn post_ids target
        local ignored_transition ignored_total post_gap post_distress post_alignment
        local reply event has_prediction
        pre="$("$FIXTURE" "$state")"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$state" \
            --seed "$run_seed" --respond "$prompt" --debug-field --save "$state" \
            --no-state-transition-plasticity > "$log" 2>&1
        post="$("$FIXTURE" "$state")"
        reply="$(reply_from_log "$log")"
        [ -n "$reply" ] || return 1
        awk -v cell="$life" -v cohort="$split" -v base_seed="$base_seed" \
            -v phase=relational-redistribution -v session="$session" \
            -v order="$order" -v texture="$texture" -v run_seed="$run_seed" \
            -v prompt="$prompt" -v reply="$reply" \
            -f "$DIALOGUE_REPORTER" "$log" > "$receipt"
        event="$(awk -F '\t' '{print $13}' "$receipt")"
        has_prediction="$(awk -F '\t' '{print $20}' "$receipt")"
        IFS=$'\t' read -r pre_turn pre_ids source transition transition_total \
            pre_gap pre_distress pre_alignment <<< "$pre"
        IFS=$'\t' read -r post_turn post_ids target ignored_transition ignored_total \
            post_gap post_distress post_alignment <<< "$post"
        printf 'validation\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$life" "$split" "$candidate_order" "$rotation" "$session" \
            "$order" "$source_order" "$texture" "$event" "$reply" \
            "$pre_turn" "$pre_ids" "$source" "$transition" \
            "$transition_total" "$pre_gap" "$pre_distress" "$pre_alignment" \
            "$post_turn" "$post_ids" "$target" "$post_gap" "$post_distress" \
            "$post_alignment" "$has_prediction" >> "$raw"
    done < <(awk -F '\t' -v life="$life" -v rotation="$rotation" \
        'NR > 1 && $1 == life && $5 == rotation' "$PLAN")
    [ "$rows" -eq 48 ] || return 1
}

replay_plan() {
    local running=0
    local -a pids=()
    printf 'cohort\tlife\tsplit\tcandidate_order\trotation\tsession\torder\tsource_order\ttexture\tevent\treply\tpre_turn\tpre_ids\tsource\ttransition\ttransition_total\tpre_gap\tpre_distress\tpre_alignment\tpost_turn\tpost_ids\ttarget\tpost_gap\tpost_distress\tpost_alignment\thas_prediction\n' > "$RAW"
    while IFS=$'\t' read -r life split base_seed candidate_order rotation; do
        run_branch "$life" "$split" "$base_seed" "$candidate_order" "$rotation" &
        pids+=("$!")
        running=$((running + 1))
        if [ "$running" -ge "$JOBS" ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
            pids=()
            running=0
        fi
    done < <(awk -F '\t' 'NR > 1 && !seen[$1 SUBSEP $5]++ {
        print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5
    }' "$PLAN")
    if [ "$running" -gt 0 ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
    fi
    while IFS=$'\t' read -r life split rotation; do
        cat "$OUT/replays/$split-$life/r$rotation/raw.tsv" >> "$RAW"
    done < <(awk -F '\t' 'NR > 1 && !seen[$1 SUBSEP $5]++ {
        print $1 "\t" $2 "\t" $5
    }' "$PLAN")
}

aggregate() {
    awk -f "$REPORTER" "$RAW" > "$SCORES"
    awk -f "$LIFE_REPORTER" "$SCORES" > "$LIFE"
    awk -f "$VERDICT_REPORTER" "$LIFE" > "$VERDICT"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$PLAN" "$DESIGN" "$SOURCE_RECEIPT" "$RAW"; do
        [ -s "$path" ] || { printf 'incomplete A.113 aggregate source: %s\n' "$path" >&2; exit 2; }
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
        printf 'A.113 sealed validation plan: %s\n' "$OUT"
        exit 0
    fi
    make -C "$ROOT" leo >/dev/null
    "$CC" "$FIXTURE_SOURCE" -O2 -lm -Wall -Wextra -Wno-unused-function \
        -o "$FIXTURE" -lpthread
    replay_plan
fi

aggregate
cat "$VERDICT"
