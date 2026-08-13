#!/usr/bin/env bash
# A.103: test bounded past-state episodes beyond the frozen A.101 snapshot.
set -Eeuo pipefail

trap 'rc=$?; printf "road episode-memory runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
RENEWAL="${LEO_STATE_EPISODE_RENEWAL_SOURCE:-/private/tmp/leo-state-swarm-renewal-event-reservoir-a103-r1-20260813}"
A101="${LEO_STATE_EPISODE_A101_SOURCE:-/private/tmp/leo-state-swarm-road-error-memory-a101-r1-20260810}"
JOBS="${LEO_STATE_EPISODE_JOBS:-4}"
AGGREGATE_ONLY="${LEO_STATE_EPISODE_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-episode-memory-$STAMP}"

CANDIDATES="$ROOT/scripts/state_swarm_renewal_event_reservoir_candidates.tsv"
WARM_CASES="$ROOT/scripts/state_swarm_settled_warmup_cases.tsv"
WRITER_CASES="$ROOT/scripts/state_swarm_alphabet_cases.tsv"
REPORTER="$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk"
EXPECTED_CANDIDATES_SHA="${LEO_STATE_EPISODE_CANDIDATES_SHA:-b32d476bf6fc990cb310b4ad9afed698c111cd5970ae8f9569cfa06230c7abf0}"
EXPECTED_WARM_CASES_SHA="${LEO_STATE_EPISODE_WARM_CASES_SHA:-1f6e57f2ab55660b8a4cf2cc3e0a2769fa96ffd00ad0d8623e699b318acb4c0b}"
EXPECTED_WRITER_CASES_SHA="${LEO_STATE_EPISODE_WRITER_CASES_SHA:-cfa13bb521d91a6a9f3db7fc278927f9120cd699fe72ce1a149307c170ea45e2}"
EXPECTED_REPORTER_SHA="${LEO_STATE_EPISODE_REPORTER_SHA:-4667e61986b9fd43c62098786ddc28c9d79ecf5dfd1f74ecd1128b587005af80}"

A101_POLICIES="$A101/policies.tsv"
A101_DISCOVERY_PLAN="$A101/discovery-plan.tsv"
A101_VALIDATION_PLAN="$A101/validation-plan.tsv"
A101_DISCOVERY_SUMMARY="$A101/discovery-summary.tsv"
A101_SELECTION="$A101/selection.tsv"
A101_VERDICT="$A101/verdict.txt"
EXPECTED_A101_POLICIES_SHA="${LEO_STATE_EPISODE_A101_POLICIES_SHA:-89736f8e4681db85b8c516f8095c16786d2e13ed1edbd4d3203244baff5529ab}"
EXPECTED_A101_DISCOVERY_PLAN_SHA="${LEO_STATE_EPISODE_A101_DISCOVERY_PLAN_SHA:-ebe356a8b3055c6467a163a38e3893c115bfd39ca13ab6cff56ac802f013b860}"
EXPECTED_A101_VALIDATION_PLAN_SHA="${LEO_STATE_EPISODE_A101_VALIDATION_PLAN_SHA:-259be3140c58c7706f985283734cc0c57b99d2d46f6221c17ee0adad6c026a82}"
EXPECTED_A101_DISCOVERY_SUMMARY_SHA="${LEO_STATE_EPISODE_A101_DISCOVERY_SUMMARY_SHA:-05daa176f90ece7e6eb94016a9bb8e1122f7df0f1c6b2528e8d68643bb8fbb7a}"
EXPECTED_A101_SELECTION_SHA="${LEO_STATE_EPISODE_A101_SELECTION_SHA:-0933c24077634e0e993a4019c628eecb5331138ebd6a26bde4eed99741c3364b}"
EXPECTED_A101_VERDICT_SHA="${LEO_STATE_EPISODE_A101_VERDICT_SHA:-24053340a58e648b569de83255970334ad4fbb87e2f3d694bb1187203c0ffb29}"

case "$JOBS" in
    ''|*[!0-9]*|0) printf 'invalid road episode-memory jobs: %s\n' "$JOBS" >&2; exit 2 ;;
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

seal "$CANDIDATES" "$EXPECTED_CANDIDATES_SHA" "A.103 renewal candidates"
seal "$WARM_CASES" "$EXPECTED_WARM_CASES_SHA" "A.103 warm cases"
seal "$WRITER_CASES" "$EXPECTED_WRITER_CASES_SHA" "A.103 writer cases"
seal "$REPORTER" "$EXPECTED_REPORTER_SHA" "A.103 reservoir reporter"
seal "$A101_POLICIES" "$EXPECTED_A101_POLICIES_SHA" "A.101 policies"
seal "$A101_DISCOVERY_PLAN" "$EXPECTED_A101_DISCOVERY_PLAN_SHA" "A.101 discovery plan"
seal "$A101_VALIDATION_PLAN" "$EXPECTED_A101_VALIDATION_PLAN_SHA" "A.101 validation plan"
seal "$A101_DISCOVERY_SUMMARY" "$EXPECTED_A101_DISCOVERY_SUMMARY_SHA" "A.101 discovery summary"
seal "$A101_SELECTION" "$EXPECTED_A101_SELECTION_SHA" "A.101 selection"
seal "$A101_VERDICT" "$EXPECTED_A101_VERDICT_SHA" "A.101 verdict"
for forbidden in validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A101/$forbidden" ] || {
        printf 'A.101 validation was already opened: %s\n' "$A101/$forbidden" >&2
        exit 2
    }
done

awk -F '\t' '
    $1 == "err-cumulative-gentle" {
        rows++
        if ($2 != 1 || $3 != 0.25 || $4 != 1 || $5 != "discovery" ||
            $6 != 6 || $8 != 5 || $9 != 6 || $10 != 0.002035234 ||
            $12 != 0.002201537) exit 2
    }
    END { if (rows != 1) exit 2 }
' "$A101_DISCOVERY_SUMMARY" || {
    printf 'A.101 snapshot law is not the sealed rank-one discovery law\n' >&2
    exit 2
}

if [ ! -d "$RENEWAL" ]; then
    [ "$AGGREGATE_ONLY" = 0 ] || {
        printf 'renewal source missing during aggregate-only replay: %s\n' "$RENEWAL" >&2
        exit 2
    }
    LEO_STATE_PROSPECTIVE_JOBS="$JOBS" \
        "$ROOT/scripts/state_swarm_renewal_event_reservoir_matrix.sh" \
        "$RENEWAL" > "$RENEWAL.stdout"
fi

SCREEN_PLAN="$RENEWAL/screen-plan.tsv"
WARM_RECEIPTS="$RENEWAL/warm-receipts.tsv"
ENROLLMENT="$RENEWAL/enrollment.tsv"
WRITER_PLAN="$RENEWAL/writer-plan.tsv"
WRITER_RECEIPTS="$RENEWAL/writer-receipts.tsv"
RENEWAL_VERDICT="$RENEWAL/verdict.txt"
for path in "$SCREEN_PLAN" "$WARM_RECEIPTS" "$ENROLLMENT" \
    "$WRITER_PLAN" "$WRITER_RECEIPTS" "$RENEWAL_VERDICT"; do
    [ -s "$path" ] || { printf 'incomplete renewal source: %s\n' "$path" >&2; exit 2; }
done
grep -q '^result=balanced-reservoir-anatomy-admissible$' "$RENEWAL_VERDICT" || {
    printf 'renewal reservoir failed its own admission\n' >&2
    exit 2
}
awk -F '\t' '
    NR == 1 { if (NF != 5 || $1 != "life" || $5 != "enrollment_rank") exit 2; next }
    { rows++; split_count[$2]++; if ($2 !~ /^(primary|holdout)$/) exit 2 }
    END { if (rows != 64 || split_count["primary"] != 32 || split_count["holdout"] != 32) exit 2 }
' "$ENROLLMENT"

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
FIXTURE="$OUT/road-episode-memory-fixture"

write_discovery_plan() {
    awk -F '\t' -v OFS='\t' '
        NR == 1 { print "cohort", $0; next }
        $5 >= 1 && $5 <= 6 { print "discovery", $0; rows++; split_count[$2]++ }
        END {
            if (rows != 12 || split_count["primary"] != 6 ||
                split_count["holdout"] != 6) exit 2
        }
    ' "$ENROLLMENT"
}

write_validation_plan() {
    awk -F '\t' -v OFS='\t' '
        NR == 1 { print "cohort", $0; next }
        $5 >= 7 && $5 <= 11 { print "validation", $0; rows++; split_count[$2]++ }
        END {
            if (rows != 10 || split_count["primary"] != 5 ||
                split_count["holdout"] != 5) exit 2
        }
    ' "$ENROLLMENT"
}

write_policies() {
    printf 'candidate\tepisode_decay\tepisode_strength\tsnapshot_decay\tsnapshot_strength\tprior_alpha\tvariance_ridge\trank\n'
    printf 'episode-last-light\t0.00\t0.10\t1.00\t0.25\t1\t1\t1\n'
    printf 'episode-last-gentle\t0.00\t0.25\t1.00\t0.25\t1\t1\t2\n'
    printf 'episode-short-light\t0.50\t0.10\t1.00\t0.25\t1\t1\t3\n'
    printf 'episode-short-gentle\t0.50\t0.25\t1.00\t0.25\t1\t1\t4\n'
    printf 'episode-long-light\t0.85\t0.10\t1.00\t0.25\t1\t1\t5\n'
    printf 'episode-long-gentle\t0.85\t0.25\t1.00\t0.25\t1\t1\t6\n'
}

write_source_receipt() {
    printf 'source\tsha256\n'
    printf 'renewal-candidates\t%s\n' "$EXPECTED_CANDIDATES_SHA"
    printf 'renewal-warm-cases\t%s\n' "$EXPECTED_WARM_CASES_SHA"
    printf 'renewal-writer-cases\t%s\n' "$EXPECTED_WRITER_CASES_SHA"
    printf 'renewal-reporter\t%s\n' "$EXPECTED_REPORTER_SHA"
    printf 'renewal-screen-plan\t%s\n' "$(sha256_file "$SCREEN_PLAN")"
    printf 'renewal-warm-receipts\t%s\n' "$(sha256_file "$WARM_RECEIPTS")"
    printf 'renewal-enrollment\t%s\n' "$(sha256_file "$ENROLLMENT")"
    printf 'renewal-writer-plan\t%s\n' "$(sha256_file "$WRITER_PLAN")"
    printf 'renewal-writer-receipts\t%s\n' "$(sha256_file "$WRITER_RECEIPTS")"
    printf 'renewal-verdict\t%s\n' "$(sha256_file "$RENEWAL_VERDICT")"
    printf 'a101-policies\t%s\n' "$EXPECTED_A101_POLICIES_SHA"
    printf 'a101-discovery-plan\t%s\n' "$EXPECTED_A101_DISCOVERY_PLAN_SHA"
    printf 'a101-validation-plan\t%s\n' "$EXPECTED_A101_VALIDATION_PLAN_SHA"
    printf 'a101-discovery-summary\t%s\n' "$EXPECTED_A101_DISCOVERY_SUMMARY_SHA"
    printf 'a101-selection\t%s\n' "$EXPECTED_A101_SELECTION_SHA"
    printf 'a101-verdict\t%s\n' "$EXPECTED_A101_VERDICT_SHA"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$DISCOVERY_PLAN" "$VALIDATION_PLAN" "$POLICIES" \
        "$SOURCE_RECEIPT" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES"; do
        [ -s "$path" ] || { printf 'incomplete episode-memory run: %s\n' "$path" >&2; exit 2; }
    done
    write_discovery_plan | cmp -s - "$DISCOVERY_PLAN" || { printf 'A.103 discovery plan diverged\n' >&2; exit 2; }
    write_validation_plan | cmp -s - "$VALIDATION_PLAN" || { printf 'A.103 validation plan diverged\n' >&2; exit 2; }
    write_policies | cmp -s - "$POLICIES" || { printf 'A.103 policy ledger diverged\n' >&2; exit 2; }
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT" || { printf 'A.103 source receipt diverged\n' >&2; exit 2; }
else
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
    mkdir -p "$OUT/replays"
    write_discovery_plan > "$DISCOVERY_PLAN"
    write_validation_plan > "$VALIDATION_PLAN"
    write_policies > "$POLICIES"
    write_source_receipt > "$SOURCE_RECEIPT"
fi

if [ "${LEO_STATE_EPISODE_PLAN_ONLY:-0}" = 1 ]; then
    cat "$DISCOVERY_PLAN"; printf '\n'; cat "$VALIDATION_PLAN"; printf '\n'; cat "$POLICIES"
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

run_life() {
    local cohort="$1" wanted_life="$2" wanted_split="$3" base_seed="$4"
    local life_dir="$OUT/replays/$wanted_split-$wanted_life"
    local state="$life_dir/leo.state"
    local source_body="$RENEWAL/candidates/$wanted_life/leo.state"
    local generated_all="$life_dir/generated.normalized"
    local source_all="$life_dir/source.normalized"
    local life_witnesses="$life_dir/witnesses.tsv"
    local life_lock="$life_dir/lock.tsv"
    local rows=0
    mkdir -p "$life_dir"
    : > "$generated_all"; : > "$source_all"; : > "$life_witnesses"

    while IFS=$'\t' read -r life split warm_base phase session order texture run_seed prompt; do
        [ "$life" = "$wanted_life" ] && [ "$split" = "$wanted_split" ] || continue
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local generated="$life_dir/current.log"
        local canonical="$RENEWAL/candidates/$life/warm-logs/$stem.log"
        local args=("$ROOT/leo" --corpus "$ROOT/leo.txt")
        [ -s "$state" ] && args+=(--load "$state")
        args+=(--seed "$run_seed" --respond "$prompt" --debug-field --save "$state")
        "${args[@]}" > "$generated" 2>&1
        normalize_log "$generated" >> "$generated_all"
        normalize_log "$canonical" >> "$source_all"
        rows=$((rows + 1))
    done < "$SCREEN_PLAN"
    [ "$rows" -eq 32 ] || return 1

    rows=0
    while IFS=$'\t' read -r life split writer_base phase session order texture run_seed prompt; do
        [ "$life" = "$wanted_life" ] && [ "$split" = "$wanted_split" ] || continue
        local turn=$((32 + (session - 1) * 8 + order))
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local generated="$life_dir/current.log"
        local canonical="$RENEWAL/candidates/$life/writer-logs/$stem.log"
        local geometry="$life_dir/geometry.tsv"
        local generated_receipt="$life_dir/generated-receipt.tsv"
        local source_receipt="$life_dir/source-receipt.tsv"
        local reply
        "$FIXTURE" "$state" > "$geometry"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$state" \
            --seed "$run_seed" --respond "$prompt" --debug-field --save "$state" \
            > "$generated" 2>&1
        normalize_log "$generated" >> "$generated_all"
        normalize_log "$canonical" >> "$source_all"
        reply="$(reply_from_log "$generated")"
        [ -n "$reply" ] || return 1
        awk -v cell="$life" -v cohort="$split" -v base_seed="$base_seed" \
            -v phase=writer -v session="$session" -v order="$order" \
            -v texture="$texture" -v run_seed="$run_seed" -v prompt="$prompt" \
            -v reply="$reply" -f "$ROOT/scripts/state_swarm_dialogue_report.awk" \
            "$generated" > "$generated_receipt"
        awk -F '\t' -v life="$life" -v wanted_split="$split" -v turn="$turn" \
            'NR == 1 { next } $1 == life && $2 == wanted_split && $9 == turn { print; rows++ }
             END { if (rows != 1) exit 2 }' "$WRITER_RECEIPTS" > "$source_receipt"
        cmp -s "$generated_receipt" "$source_receipt" || return 1
        IFS=$'\t' read -r pre_turn pre_ids source transition transition_total < "$geometry"
        awk -F '\t' -v OFS='\t' -v cohort="$cohort" -v pre_turn="$pre_turn" \
            -v pre_ids="$pre_ids" -v transition="$transition" -v source="$source" \
            -v transition_total="$transition_total" '
            { print cohort, $1, $2, $9, $5, $6, $7, $13, pre_turn, pre_ids,
                    $16, transition, source, transition_total, $12, $19, $20,
                    $21, $22, $23, $24, $33, $34 }
        ' "$generated_receipt" >> "$life_witnesses"
        rows=$((rows + 1))
    done < "$WRITER_PLAN"
    [ "$rows" -eq 64 ] || return 1
    cmp -s "$generated_all" "$source_all" || return 1
    cmp -s "$state" "$source_body" || return 1
    printf '%s\t%s\t%s\t64\ttrue\ttrue\t%s\t%s\n' \
        "$cohort" "$wanted_life" "$wanted_split" \
        "$(sha256_file "$generated_all")" "$(sha256_file "$state")" > "$life_lock"
    rm -f "$life_dir/current.log" "$life_dir/geometry.tsv" \
        "$life_dir/generated-receipt.tsv" "$life_dir/source-receipt.tsv"
}

replay_plan() {
    local plan="$1" locks="$2" witnesses="$3"
    local pids=() running=0
    while IFS=$'\t' read -r cohort life split base_seed candidate_order enrollment_rank; do
        run_life "$cohort" "$life" "$split" "$base_seed" &
        pids+=("$!"); running=$((running + 1))
        if [ "$running" -ge "$JOBS" ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
            pids=(); running=0
        fi
    done < <(tail -n +2 "$plan")
    if [ "$running" -gt 0 ]; then for pid in "${pids[@]}"; do wait "$pid"; done; fi

    printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$locks"
    printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$witnesses"
    while IFS=$'\t' read -r cohort life split base_seed candidate_order enrollment_rank; do
        cat "$OUT/replays/$split-$life/lock.tsv" >> "$locks"
        cat "$OUT/replays/$split-$life/witnesses.tsv" >> "$witnesses"
    done < <(tail -n +2 "$plan")
}

if [ "$AGGREGATE_ONLY" != 1 ]; then
    make -C "$ROOT" leo >/dev/null
    "$CC" "$ROOT/tests/state_swarm_road_prequential_fixture.c" \
        -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread
    replay_plan "$DISCOVERY_PLAN" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES"
fi

awk -v policy_expected=6 -v life_expected=12 -v writer_expected=64 \
    -v evaluation_start=49 -v score_min=32 \
    -f "$ROOT/scripts/state_swarm_road_episode_memory_report.awk" \
    "$POLICIES" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES" > "$DISCOVERY_SCORES"
awk -v policy_expected=6 -v life_expected=12 -v min_turns=32 \
    -f "$ROOT/scripts/state_swarm_road_episode_memory_life.awk" \
    "$DISCOVERY_SCORES" > "$DISCOVERY_LIFE"
awk -v policy_expected=6 -v discovery_expected=12 -v validation_expected=10 \
    -f "$ROOT/scripts/state_swarm_road_episode_memory_summary.awk" \
    "$DISCOVERY_LIFE" > "$DISCOVERY_SUMMARY"
awk -v policy_expected=6 -f "$ROOT/scripts/state_swarm_road_episode_memory_select.awk" \
    "$DISCOVERY_SUMMARY" > "$SELECTION"

selected="$(awk -F '\t' 'NR == 2 { print $1 }' "$SELECTION")"
[ -n "$selected" ] || { printf 'A.103 selection is empty\n' >&2; exit 2; }

if [ "$selected" != none ]; then
    { sed -n '1p' "$POLICIES"; awk -F '\t' -v selected="$selected" '$1 == selected' "$POLICIES"; } \
        > "$SELECTED_POLICY"
    [ "$(wc -l < "$SELECTED_POLICY" | tr -d ' ')" -eq 2 ] || {
        printf 'selected episode-memory policy is not unique\n' >&2; exit 2;
    }
    if [ "$AGGREGATE_ONLY" != 1 ]; then
        replay_plan "$VALIDATION_PLAN" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES"
    else
        for path in "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES"; do
            [ -s "$path" ] || { printf 'selected candidate lacks validation evidence: %s\n' "$path" >&2; exit 2; }
        done
    fi
    awk -v policy_expected=1 -v life_expected=10 -v writer_expected=64 \
        -v evaluation_start=49 -v score_min=32 \
        -f "$ROOT/scripts/state_swarm_road_episode_memory_report.awk" \
        "$SELECTED_POLICY" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES" > "$VALIDATION_SCORES"
    awk -v policy_expected=1 -v life_expected=10 -v min_turns=32 \
        -f "$ROOT/scripts/state_swarm_road_episode_memory_life.awk" \
        "$VALIDATION_SCORES" > "$VALIDATION_LIFE"
    { sed -n '1p' "$DISCOVERY_LIFE"; tail -n +2 "$DISCOVERY_LIFE"; tail -n +2 "$VALIDATION_LIFE"; } \
        > "$LIFE_SUMMARY"
else
    for path in "$SELECTED_POLICY" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES" \
        "$VALIDATION_SCORES" "$VALIDATION_LIFE"; do
        [ ! -e "$path" ] || { printf 'no-candidate run exposed validation artifact: %s\n' "$path" >&2; exit 2; }
    done
    cp "$DISCOVERY_LIFE" "$LIFE_SUMMARY"
fi

rm -f "$FIXTURE"
awk -v policy_expected=6 -v discovery_expected=12 -v validation_expected=10 \
    -f "$ROOT/scripts/state_swarm_road_episode_memory_summary.awk" \
    "$LIFE_SUMMARY" > "$CANDIDATE_SUMMARY"
awk -f "$ROOT/scripts/state_swarm_road_episode_memory_verdict.awk" \
    "$SELECTION" "$CANDIDATE_SUMMARY" > "$VERDICT"

cat "$CANDIDATE_SUMMARY"; printf '\n'; cat "$SELECTION"; printf '\n'; cat "$VERDICT"
printf '\nrenewal-source: %s\nrun: %s\n' "$RENEWAL" "$OUT"
