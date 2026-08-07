#!/usr/bin/env bash
# A.88: enroll settled lives before any writer outcome is observable.
set -Eeuo pipefail

trap 'rc=$?; printf "prospective incidence runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CANDIDATES="${LEO_STATE_PROSPECTIVE_CANDIDATES:-$ROOT/scripts/state_swarm_prospective_incidence_candidates.tsv}"
WARM_CASES="${LEO_STATE_PROSPECTIVE_WARM_CASES:-$ROOT/scripts/state_swarm_settled_warmup_cases.tsv}"
WRITER_CASES="${LEO_STATE_PROSPECTIVE_WRITER_CASES:-$ROOT/scripts/state_swarm_alphabet_cases.tsv}"
JOBS="${LEO_STATE_PROSPECTIVE_JOBS:-1}"
AGGREGATE_ONLY="${LEO_STATE_PROSPECTIVE_AGGREGATE_ONLY:-0}"
EXPECTED_CANDIDATES="${LEO_STATE_PROSPECTIVE_EXPECTED_CANDIDATES:-40}"
PRIMARY_CANDIDATES="${LEO_STATE_PROSPECTIVE_PRIMARY_CANDIDATES:-30}"
HOLDOUT_CANDIDATES="${LEO_STATE_PROSPECTIVE_HOLDOUT_CANDIDATES:-10}"
PRIMARY_TARGET="${LEO_STATE_PROSPECTIVE_PRIMARY_TARGET:-24}"
HOLDOUT_TARGET="${LEO_STATE_PROSPECTIVE_HOLDOUT_TARGET:-8}"
SEED_START="${LEO_STATE_PROSPECTIVE_SEED_START:-61001}"
SEED_STEP="${LEO_STATE_PROSPECTIVE_SEED_STEP:-1031}"
CAPTURE_EVENTS="${LEO_STATE_PROSPECTIVE_CAPTURE_EVENTS:-0}"
REPORTER="${LEO_STATE_PROSPECTIVE_REPORTER:-$ROOT/scripts/state_swarm_prospective_incidence_report.awk}"
PROFILE_NAME="${LEO_STATE_PROSPECTIVE_PROFILE_NAME:-A.88}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-prospective-incidence-$STAMP}"

if [ "$AGGREGATE_ONLY" = 1 ]; then
    [ -d "$OUT/candidates" ] && [ -s "$OUT/screen-plan.tsv" ] || {
        printf 'incomplete prospective run cannot be aggregated: %s\n' "$OUT" >&2
        exit 2
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
fi
case "$JOBS" in
    ''|*[!0-9]*|0) printf 'invalid prospective job count: %s\n' "$JOBS" >&2; exit 2 ;;
esac
for value in "$EXPECTED_CANDIDATES" "$PRIMARY_CANDIDATES" \
    "$HOLDOUT_CANDIDATES" "$PRIMARY_TARGET" "$HOLDOUT_TARGET" \
    "$SEED_START" "$SEED_STEP"; do
    case "$value" in
        ''|*[!0-9]*|0) printf 'invalid prospective population value: %s\n' "$value" >&2; exit 2 ;;
    esac
done
[ "$EXPECTED_CANDIDATES" -eq $((PRIMARY_CANDIDATES + HOLDOUT_CANDIDATES)) ] &&
    [ "$PRIMARY_TARGET" -le "$PRIMARY_CANDIDATES" ] &&
    [ "$HOLDOUT_TARGET" -le "$HOLDOUT_CANDIDATES" ] || {
        printf 'inconsistent prospective population dimensions\n' >&2
        exit 2
    }
case "$CAPTURE_EVENTS" in
    0|1) ;;
    *) printf 'invalid prospective capture mode: %s\n' "$CAPTURE_EVENTS" >&2; exit 2 ;;
esac
for file in "$CANDIDATES" "$WARM_CASES" "$WRITER_CASES" "$REPORTER"; do
    [ -s "$file" ] || {
        printf 'prospective incidence input missing: %s\n' "$file" >&2
        exit 2
    }
done

awk -F '\t' -v total="$EXPECTED_CANDIDATES" \
    -v primary="$PRIMARY_CANDIDATES" -v holdout="$HOLDOUT_CANDIDATES" \
    -v seed_start="$SEED_START" -v seed_step="$SEED_STEP" '
    NR == 1 {
        if (NF != 3 || $1 != "life" || $2 != "split" ||
            $3 != "base_seed") exit 1
        next
    }
    {
        rows++
        expected_life = rows <= primary ? sprintf("p%02d", rows) : sprintf("h%02d", rows - primary)
        expected_split = rows <= primary ? "primary" : "holdout"
        expected_seed = seed_start + (rows - 1) * seed_step
        if (NF != 3 || $1 != expected_life || $2 != expected_split ||
            $3 !~ /^[0-9]+$/ || $3 != expected_seed ||
            life[$1]++ || seed[$3]++) exit 1
        cohort_count[$2]++
    }
    END {
        if (rows != total || cohort_count["primary"] != primary ||
            cohort_count["holdout"] != holdout) exit 1
    }
' "$CANDIDATES" || {
    printf 'invalid prospective incidence candidates: %s\n' "$CANDIDATES" >&2
    exit 2
}

awk -F '\t' '
    BEGIN {
        name[1] = "home"; name[2] = "storm"
        name[3] = "wonder"; name[4] = "social"
    }
    NR == 1 {
        if (NF != 4 || $1 != "session" || $2 != "order" ||
            $3 != "texture" || $4 != "prompt") exit 1
        next
    }
    {
        if (NF != 4 || $1 < 1 || $1 > 4 || $2 < 1 || $2 > 8 ||
            $3 !~ /^(home|storm|wonder|social)$/ || $4 == "" ||
            slot[$1 SUBSEP $2]++ || prompt[$4]++) exit 1
        texture[$1 SUBSEP $3]++
        crossed[$2 SUBSEP $3]++
        rows++
    }
    END {
        if (rows != 32 || length(slot) != 32) exit 1
        for (session = 1; session <= 4; session++)
            for (i = 1; i <= 4; i++)
                if (texture[session SUBSEP name[i]] != 2) exit 1
        for (position = 1; position <= 8; position++)
            for (i = 1; i <= 4; i++)
                if (crossed[position SUBSEP name[i]] != 1) exit 1
    }
' "$WARM_CASES" || {
    printf 'invalid prospective incidence warm cases: %s\n' "$WARM_CASES" >&2
    exit 2
}

awk -F '\t' '
    NR == 1 {
        if (NF != 5 || $1 != "kind" || $2 != "session" ||
            $3 != "order" || $4 != "texture" || $5 != "prompt") exit 1
        next
    }
    $1 == "writer" {
        if ($2 < 1 || $2 > 8 || $3 < 1 || $3 > 8 ||
            $4 !~ /^(home|storm|wonder|social)$/ || $5 == "" ||
            slot[$2 SUBSEP $3]++ || prompt[$5]++) exit 1
        rows++
    }
    $1 != "writer" && $1 != "probe" { exit 1 }
    END { if (rows != 64 || length(slot) != 64) exit 1 }
' "$WRITER_CASES" || {
    printf 'invalid prospective incidence writer cases: %s\n' "$WRITER_CASES" >&2
    exit 2
}

SCREEN_PLAN="$OUT/screen-plan.tsv"
WARM_RECEIPTS="$OUT/warm-receipts.tsv"
SCREENING="$OUT/screening.tsv"
ENROLLMENT="$OUT/enrollment.tsv"
WRITER_PLAN="$OUT/writer-plan.tsv"
WRITER_RECEIPTS="$OUT/writer-receipts.tsv"
LIFE_SUMMARY="$OUT/life-summary.tsv"
EVENTS="$OUT/events.tsv"
TRIGGER_EVENTS="$OUT/trigger-events.tsv"
STRATA="$OUT/strata.tsv"
VERDICT="$OUT/verdict.txt"

if [ "$AGGREGATE_ONLY" != 1 ]; then
    mkdir -p "$OUT/candidates"
    printf 'life\tsplit\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tprompt\n' > "$SCREEN_PLAN"
    while IFS=$'\t' read -r life split base_seed; do
        while IFS=$'\t' read -r session order texture prompt; do
            run_seed=$((base_seed + 3000 + session * 100 + order))
            printf '%s\t%s\t%s\twarm\t%s\t%s\t%s\t%s\t%s\n' \
                "$life" "$split" "$base_seed" "$session" "$order" \
                "$texture" "$run_seed" "$prompt" >> "$SCREEN_PLAN"
        done < <(tail -n +2 "$WARM_CASES")
    done < <(tail -n +2 "$CANDIDATES")
fi

awk -F '\t' -v expected_lives="$EXPECTED_CANDIDATES" \
    -v expected_rows="$((EXPECTED_CANDIDATES * 32))" '
    NR == 1 { next }
    {
        rows++; lives[$1]++
        if ($4 != "warm" || seed[$1 SUBSEP $8]++) exit 1
    }
    END {
        if (rows != expected_rows || length(lives) != expected_lives) exit 1
        for (life in lives)
            if (lives[life] != 32) exit 1
    }
' "$SCREEN_PLAN" || {
    printf 'invalid prospective incidence screen plan: %s\n' "$SCREEN_PLAN" >&2
    exit 2
}

if [ "${LEO_STATE_PROSPECTIVE_PLAN_ONLY:-0}" = 1 ]; then
    cat "$SCREEN_PLAN"
    exit 0
fi

receipt_header='life\tsplit\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tstates\tactive\twinner\tevent\tsimilarity\tentropy\tmembers\tmember_sum\tadjacent\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply'

if [ "$AGGREGATE_ONLY" != 1 ]; then
make -C "$ROOT" leo >/dev/null

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

run_warm_life() {
    local wanted_life="$1" wanted_split="$2" wanted_seed="$3"
    local life_dir="$OUT/candidates/$wanted_life"
    local life_receipts="$life_dir/warm-receipts.tsv"
    local state="$life_dir/leo.state"
    mkdir -p "$life_dir/warm-logs"
    : > "$life_receipts"

    awk -F '\t' -v life="$wanted_life" 'NR > 1 && $1 == life' "$SCREEN_PLAN" |
    while IFS=$'\t' read -r life split base_seed phase session order \
        texture run_seed prompt; do
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local log="$life_dir/warm-logs/$stem.log"
        local reply
        local args=("$ROOT/leo" --corpus "$ROOT/leo.txt")
        if [ -f "$state" ]; then args+=(--load "$state"); fi
        args+=(--seed "$run_seed" --respond "$prompt" --debug-field \
               --save "$state")
        "${args[@]}" > "$log" 2>&1
        [ -s "$state" ] || exit 1
        reply="$(reply_from_log "$log")"
        [ -n "$reply" ] || exit 1
        awk -v cell="$life" -v cohort="$split" \
            -v base_seed="$base_seed" -v phase="$phase" \
            -v session="$session" -v order="$order" \
            -v texture="$texture" -v run_seed="$run_seed" \
            -v prompt="$prompt" -v reply="$reply" \
            -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$log" \
            >> "$life_receipts"
    done
}

pids=()
running=0
while IFS=$'\t' read -r life split base_seed; do
    run_warm_life "$life" "$split" "$base_seed" &
    pids+=("$!")
    running=$((running + 1))
    if [ "$running" -ge "$JOBS" ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
        pids=()
        running=0
    fi
done < <(tail -n +2 "$CANDIDATES")
if [ "$running" -gt 0 ]; then
    for pid in "${pids[@]}"; do wait "$pid"; done
fi
fi

printf '%b\n' "$receipt_header" > "$WARM_RECEIPTS"
while IFS=$'\t' read -r life split base_seed; do
    [ "$(wc -l < "$OUT/candidates/$life/warm-receipts.tsv")" -eq 32 ] || {
        printf 'incomplete warm receipt: %s\n' "$life" >&2
        exit 1
    }
    cat "$OUT/candidates/$life/warm-receipts.tsv" >> "$WARM_RECEIPTS"
done < <(tail -n +2 "$CANDIDATES")

printf 'life\tsplit\tbase_seed\tcandidate_order\twarm_turns\twarm_final_states\twarm_births\twarm_updates\twarm_replacements\twarm_session4_changes\tsettled\tenrolled\tenrollment_rank\n' > "$SCREENING"
awk -F '\t' -v primary_target="$PRIMARY_TARGET" \
    -v holdout_target="$HOLDOUT_TARGET" \
    -v expected_candidates="$EXPECTED_CANDIDATES" '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        order[++candidates] = $1
        split_name[$1] = $2
        seed[$1] = $3
        next
    }
    FNR == 1 { next }
    {
        life = $1
        if (!split_name[life] || $2 != split_name[life] || $3 != seed[life] ||
            $4 != "warm") exit 1
        turns[life]++
        if ($9 != turns[life] || ($9 == 1 && $18 != 0) ||
            ($9 > 1 && $18 != 1)) exit 1
        final_states[life] = $10
        if ($13 == "born") births[life]++
        else if ($13 == "updated") updates[life]++
        else if ($13 == "replaced") replacements[life]++
        else exit 1
        if ($5 == 4 && $13 != "updated") session4_changes[life]++
        rows++
    }
    END {
        if (rows != expected_candidates * 32 ||
            candidates != expected_candidates) exit 1
        target["primary"] = primary_target
        target["holdout"] = holdout_target
        for (i = 1; i <= candidates; i++) {
            life = order[i]
            if (turns[life] != 32 ||
                births[life] + updates[life] + replacements[life] != 32) exit 1
            settled = final_states[life] == 8 && session4_changes[life] == 0
            enrolled = settled && rank[split_name[life]] < target[split_name[life]]
            if (enrolled) rank[split_name[life]]++
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%d\n",
                   life, split_name[life], seed[life], i, turns[life],
                   final_states[life], births[life] + 0, updates[life] + 0,
                   replacements[life] + 0, session4_changes[life] + 0,
                   settled ? "true" : "false", enrolled ? "true" : "false",
                   enrolled ? rank[split_name[life]] : 0
        }
    }
' "$CANDIDATES" "$WARM_RECEIPTS" >> "$SCREENING" || {
    printf 'invalid prospective warm receipts\n' >&2
    exit 2
}

printf 'life\tsplit\tbase_seed\tcandidate_order\tenrollment_rank\n' > "$ENROLLMENT"
awk -F '\t' 'NR > 1 && $12 == "true" { print $1, $2, $3, $4, $13 }' \
    OFS=$'\t' "$SCREENING" >> "$ENROLLMENT"

if ! awk -F '\t' -v primary_target="$PRIMARY_TARGET" \
    -v holdout_target="$HOLDOUT_TARGET" '
    NR == 1 { next }
    {
        rows++; split_count[$2]++
        if ($5 != split_count[$2]) exit 1
    }
    END {
        if (rows != primary_target + holdout_target ||
            split_count["primary"] != primary_target ||
            split_count["holdout"] != holdout_target) exit 1
    }
' "$ENROLLMENT"; then
    {
        printf 'state-swarm prospective displacement incidence %s\n' "$PROFILE_NAME"
        awk -F '\t' -v expected="$EXPECTED_CANDIDATES" \
            -v primary_candidates="$PRIMARY_CANDIDATES" \
            -v holdout_candidates="$HOLDOUT_CANDIDATES" \
            'NR > 1 { candidates[$2]++; if ($11 == "true") settled[$2]++; if ($12 == "true") enrolled[$2]++ }
            END { printf "screened_candidates=%d primary=%d holdout=%d\n", expected, primary_candidates, holdout_candidates;
                  printf "settled_candidates=%d/%d primary=%d/%d holdout=%d/%d\n", settled["primary"] + settled["holdout"], expected, settled["primary"] + 0, primary_candidates, settled["holdout"] + 0, holdout_candidates;
                  printf "enrolled_lives=%d primary=%d holdout=%d\n", enrolled["primary"] + enrolled["holdout"], enrolled["primary"] + 0, enrolled["holdout"] + 0 }' "$SCREENING"
        printf 'result=prospective-enrollment-incomplete\n'
    } > "$VERDICT"
    cat "$SCREENING"
    printf '\n'
    cat "$VERDICT"
    exit 3
fi

printf 'life\tsplit\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tprompt\n' > "$WRITER_PLAN"
while IFS=$'\t' read -r life split base_seed candidate_order enrollment_rank; do
    while IFS=$'\t' read -r kind session order texture prompt; do
        [ "$kind" = writer ] || continue
        run_seed=$((base_seed + session * 100 + order))
        printf '%s\t%s\t%s\twriter\t%s\t%s\t%s\t%s\t%s\n' \
            "$life" "$split" "$base_seed" "$session" "$order" \
            "$texture" "$run_seed" "$prompt" >> "$WRITER_PLAN"
    done < <(tail -n +2 "$WRITER_CASES")
done < <(tail -n +2 "$ENROLLMENT")

awk -F '\t' -v expected_lives="$((PRIMARY_TARGET + HOLDOUT_TARGET))" \
    -v expected_rows="$(((PRIMARY_TARGET + HOLDOUT_TARGET) * 64))" '
    NR == 1 { next }
    {
        rows++; lives[$1]++
        if ($4 != "writer" || seed[$1 SUBSEP $8]++) exit 1
    }
    END {
        if (rows != expected_rows || length(lives) != expected_lives) exit 1
        for (life in lives)
            if (lives[life] != 64) exit 1
    }
' "$WRITER_PLAN" || {
    printf 'invalid prospective incidence writer plan: %s\n' "$WRITER_PLAN" >&2
    exit 2
}

if [ "$AGGREGATE_ONLY" != 1 ]; then
run_writer_life() {
    local wanted_life="$1" wanted_split="$2" wanted_seed="$3"
    local enrollment_rank="$4"
    local life_dir="$OUT/candidates/$wanted_life"
    local life_receipts="$life_dir/writer-receipts.tsv"
    local life_events="$life_dir/trigger-events.tsv"
    local state="$life_dir/leo.state"
    [ -s "$state" ] || return 1
    mkdir -p "$life_dir/writer-logs"
    : > "$life_receipts"
    if [ "$CAPTURE_EVENTS" = 1 ]; then
        mkdir -p "$life_dir/events"
        : > "$life_events"
    fi

    awk -F '\t' -v life="$wanted_life" 'NR > 1 && $1 == life' "$WRITER_PLAN" |
    while IFS=$'\t' read -r life split base_seed phase session order \
        texture run_seed prompt; do
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local log="$life_dir/writer-logs/$stem.log"
        local reply receipt actual_turn event expected_turn pre_state
        local args=("$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$state" \
                    --seed "$run_seed" --respond "$prompt" --debug-field \
                    --save "$state")
        expected_turn=$((32 + (session - 1) * 8 + order))
        pre_state="$life_dir/pre-${expected_turn}.state"
        if [ "$CAPTURE_EVENTS" = 1 ]; then cp "$state" "$pre_state"; fi
        "${args[@]}" > "$log" 2>&1
        reply="$(reply_from_log "$log")"
        [ -n "$reply" ] || exit 1
        receipt="$(awk -v cell="$life" -v cohort="$split" \
            -v base_seed="$base_seed" -v phase="$phase" \
            -v session="$session" -v order="$order" \
            -v texture="$texture" -v run_seed="$run_seed" \
            -v prompt="$prompt" -v reply="$reply" \
            -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$log")"
        printf '%s\n' "$receipt" >> "$life_receipts"
        actual_turn="$(printf '%s\n' "$receipt" | awk -F '\t' '{ print $9 }')"
        event="$(printf '%s\n' "$receipt" | awk -F '\t' '{ print $13 }')"
        [ "$actual_turn" -eq "$expected_turn" ] || exit 1
        if [ "$CAPTURE_EVENTS" != 1 ]; then continue; fi
        if [ "$event" != replaced ]; then
            rm -f "$pre_state"
            continue
        fi

        local event_id event_dir trigger_shape trigger_turn trigger_event
        local trigger_new_id trigger_similarity trigger_members displaced_id
        local trigger_nearest trigger_nearest_organs trigger_removed_organs
        local trigger_organs
        printf -v event_id '%s-t%03d' "$life" "$actual_turn"
        event_dir="$life_dir/events/$event_id"
        [ ! -e "$event_dir" ] || exit 1
        mkdir -p "$event_dir"
        mv "$pre_state" "$event_dir/pretrigger.state"
        cp "$state" "$event_dir/displaced.state"
        cp "$log" "$event_dir/trigger.log"
        trigger_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$log")"
        IFS=$'\t' read -r trigger_turn trigger_event trigger_new_id \
            trigger_similarity trigger_members displaced_id trigger_nearest \
            trigger_nearest_organs trigger_removed_organs trigger_organs \
            <<< "$trigger_shape"
        [ "$trigger_turn" -eq "$actual_turn" ] &&
            [ "$trigger_event" = replaced ] && [ "$displaced_id" -gt 0 ] || exit 1
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$event_id" "$life" "$split" "$base_seed" "$enrollment_rank" \
            "$trigger_turn" "$session" "$order" "$texture" "$run_seed" \
            "$displaced_id" "$trigger_new_id" "$trigger_similarity" \
            "$trigger_nearest" "$trigger_nearest_organs" \
            "$trigger_removed_organs" "$trigger_members" "$trigger_organs" \
            "$prompt" "$reply" >> "$life_events"
    done
}

pids=()
running=0
while IFS=$'\t' read -r life split base_seed candidate_order enrollment_rank; do
    run_writer_life "$life" "$split" "$base_seed" "$enrollment_rank" &
    pids+=("$!")
    running=$((running + 1))
    if [ "$running" -ge "$JOBS" ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
        pids=()
        running=0
    fi
done < <(tail -n +2 "$ENROLLMENT")
if [ "$running" -gt 0 ]; then
    for pid in "${pids[@]}"; do wait "$pid"; done
fi
fi

printf '%b\n' "$receipt_header" > "$WRITER_RECEIPTS"
while IFS=$'\t' read -r life split base_seed candidate_order enrollment_rank; do
    [ "$(wc -l < "$OUT/candidates/$life/writer-receipts.tsv")" -eq 64 ] || {
        printf 'incomplete writer receipt: %s\n' "$life" >&2
        exit 1
    }
    cat "$OUT/candidates/$life/writer-receipts.tsv" >> "$WRITER_RECEIPTS"
done < <(tail -n +2 "$ENROLLMENT")

if [ "$CAPTURE_EVENTS" = 1 ]; then
    printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tdisplaced_id\ttrigger_new_id\tsimilarity\tnearest_id\tnearest_organs\tremoved_organs\tmembers\torgans\tprompt\treply\n' > "$TRIGGER_EVENTS"
    while IFS=$'\t' read -r life split base_seed candidate_order enrollment_rank; do
        life_events="$OUT/candidates/$life/trigger-events.tsv"
        [ -f "$life_events" ] || {
            printf 'missing trigger event ledger: %s\n' "$life" >&2
            exit 1
        }
        cat "$life_events" >> "$TRIGGER_EVENTS"
    done < <(tail -n +2 "$ENROLLMENT")
    while IFS=$'\t' read -r event life split base_seed enrollment_rank \
        trigger_turn session order texture run_seed displaced_id \
        trigger_new_id similarity nearest_id nearest_organs removed_organs \
        members organs prompt reply; do
        event_dir="$OUT/candidates/$life/events/$event"
        [ -s "$event_dir/pretrigger.state" ] &&
            [ -s "$event_dir/displaced.state" ] &&
            [ -s "$event_dir/trigger.log" ] || {
                printf 'incomplete trigger event package: %s\n' "$event" >&2
                exit 1
            }
    done < <(tail -n +2 "$TRIGGER_EVENTS")
fi

printf 'life\tsplit\tbase_seed\tenrollment_rank\twarm_turns\twriter_turns\twarm_final_states\twarm_births\twarm_replacements\twarm_session4_changes\twriter_births\twriter_updates\twriter_replacements\tfirst_replacement_turn\tminimum_similarity\tminimum_turn\tbelow_gate\tnear_005\tnear_010\tnear_020\tnear_050\tabove_050\n' > "$LIFE_SUMMARY"
awk -F '\t' -v expected_lives="$((PRIMARY_TARGET + HOLDOUT_TARGET))" \
    -v expected_rows="$(((PRIMARY_TARGET + HOLDOUT_TARGET) * 64))" '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        if ($12 == "true") {
            order[++enrolled_count] = $1
            split_name[$1] = $2; seed[$1] = $3; rank[$1] = $13
            warm_turns[$1] = $5; warm_final[$1] = $6
            warm_births[$1] = $7; warm_replacements[$1] = $9
            warm_session4[$1] = $10
        }
        next
    }
    FNR == 1 { next }
    {
        life = $1
        if (!split_name[life] || $2 != split_name[life] || $3 != seed[life] ||
            $4 != "writer") exit 1
        writer_turns[life]++
        if ($9 != 32 + writer_turns[life] || $18 != 1) exit 1
        if ($13 == "born") writer_births[life]++
        else if ($13 == "updated") writer_updates[life]++
        else if ($13 == "replaced") {
            writer_replacements[life]++
            if (!first_replacement[life]) first_replacement[life] = $9
        } else exit 1
        similarity = $14 + 0
        if (!have_min[life] || similarity < minimum[life]) {
            minimum[life] = similarity
            minimum_turn[life] = $9
            have_min[life] = 1
        }
        if ($13 == "replaced") below[life]++
        else if (similarity < 0.405) near005[life]++
        else if (similarity < 0.410) near010[life]++
        else if (similarity < 0.420) near020[life]++
        else if (similarity < 0.450) near050[life]++
        else above050[life]++
        rows++
    }
    END {
        if (rows != expected_rows || enrolled_count != expected_lives) exit 1
        for (i = 1; i <= enrolled_count; i++) {
            life = order[i]
            if (writer_turns[life] != 64 || !have_min[life] ||
                writer_births[life] != 0 ||
                below[life] != writer_replacements[life]) exit 1
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                   life, split_name[life], seed[life], rank[life],
                   warm_turns[life], writer_turns[life], warm_final[life],
                   warm_births[life], warm_replacements[life],
                   warm_session4[life], writer_births[life] + 0,
                   writer_updates[life] + 0, writer_replacements[life] + 0,
                   first_replacement[life] + 0, minimum[life],
                   minimum_turn[life], below[life] + 0, near005[life] + 0,
                   near010[life] + 0, near020[life] + 0,
                   near050[life] + 0, above050[life] + 0
        }
    }
' "$SCREENING" "$WRITER_RECEIPTS" >> "$LIFE_SUMMARY" || {
    printf 'invalid prospective writer receipts\n' >&2
    exit 2
}

printf 'life\tsplit\tbase_seed\tturn\tsession\torder\ttexture\tsimilarity\treplaced_id\tnew_id\tprompt\treply\n' > "$EVENTS"
awk -F '\t' '
    NR == 1 { next }
    $13 == "replaced" {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
               $1, $2, $3, $9, $5, $6, $7, $14, $19, $12, $33, $34
    }
' "$WRITER_RECEIPTS" >> "$EVENTS"

printf 'dimension\tvalue\tobservations\tlives\treplacements\treplacement_lives\tminimum_similarity\tminimum_life\tminimum_turn\tbelow_gate\tnear_005\tnear_010\tnear_020\tnear_050\tabove_050\n' > "$STRATA"
awk -F '\t' '
    function add(kind, value, life, similarity, event,    key) {
        key = kind SUBSEP value
        observations[key]++
        lives[key SUBSEP life] = 1
        if (!(key in minimum) || similarity < minimum[key]) {
            minimum[key] = similarity
            minimum_life[key] = life
            minimum_turn[key] = $9
        }
        if (event == "replaced") {
            replacements[key]++
            replacement_lives[key SUBSEP life] = 1
        }
        if (event == "replaced") below[key]++
        else if (similarity < 0.405) near005[key]++
        else if (similarity < 0.410) near010[key]++
        else if (similarity < 0.420) near020[key]++
        else if (similarity < 0.450) near050[key]++
        else above050[key]++
    }
    function emit(kind, value,    key, composite, n_lives, n_event_lives, part) {
        key = kind SUBSEP value
        n_lives = 0; n_event_lives = 0
        for (composite in lives) {
            split(composite, part, SUBSEP)
            if (part[1] == kind && part[2] == value) n_lives++
        }
        for (composite in replacement_lives) {
            split(composite, part, SUBSEP)
            if (part[1] == kind && part[2] == value) n_event_lives++
        }
        printf "%s\t%s\t%d\t%d\t%d\t%d\t%.6f\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
               kind, value, observations[key] + 0, n_lives,
               replacements[key] + 0, n_event_lives, minimum[key],
               minimum_life[key], minimum_turn[key], below[key] + 0,
               near005[key] + 0, near010[key] + 0, near020[key] + 0,
               near050[key] + 0, above050[key] + 0
    }
    NR == 1 { next }
    {
        similarity = $14 + 0
        add("overall", "all", $1, similarity, $13)
        add("split", $2, $1, similarity, $13)
        add("texture", $7, $1, similarity, $13)
        add("session", $5, $1, similarity, $13)
        add("position", $6, $1, similarity, $13)
    }
    END {
        emit("overall", "all")
        emit("split", "primary"); emit("split", "holdout")
        emit("texture", "home"); emit("texture", "storm")
        emit("texture", "wonder"); emit("texture", "social")
        for (i = 1; i <= 8; i++) emit("session", i)
        for (i = 1; i <= 8; i++) emit("position", i)
    }
' "$WRITER_RECEIPTS" >> "$STRATA"

if [ "$CAPTURE_EVENTS" = 1 ]; then
    awk -f "$REPORTER" "$SCREENING" "$LIFE_SUMMARY" \
        "$OUT/trigger-events.tsv" > "$VERDICT"
else
    awk -f "$REPORTER" "$SCREENING" "$LIFE_SUMMARY" > "$VERDICT"
fi

cat "$SCREENING"
printf '\n'
cat "$LIFE_SUMMARY"
printf '\n'
cat "$EVENTS"
printf '\n'
cat "$STRATA"
printf '\n'
cat "$VERDICT"
printf '\nprocesses=%d\nrun: %s\n' \
    "$((EXPECTED_CANDIDATES * 32 + (PRIMARY_TARGET + HOLDOUT_TARGET) * 64))" \
    "$OUT"
