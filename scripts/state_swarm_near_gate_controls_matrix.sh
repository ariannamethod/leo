#!/usr/bin/env bash
# A.91: dual matched near-gate controls with complete-life replay locks.
set -Eeuo pipefail

trap 'rc=$?; printf "near-gate control runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${LEO_STATE_NEAR_GATE_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
ANATOMY_SOURCE="${LEO_STATE_NEAR_GATE_ANATOMY_SOURCE:-/private/tmp/leo-state-swarm-trigger-gate-anatomy-a90-r1-20260807}"
EXPECTED="${LEO_STATE_NEAR_GATE_EXPECTED:-19}"
EXPECTED_WRITER_ROWS="${LEO_STATE_NEAR_GATE_EXPECTED_WRITER_ROWS:-4096}"
JOBS="${LEO_STATE_NEAR_GATE_JOBS:-4}"
AGGREGATE_ONLY="${LEO_STATE_NEAR_GATE_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-near-gate-controls-$STAMP}"

TRIGGERS="$SOURCE/trigger-events.tsv"
SCREEN_PLAN="$SOURCE/screen-plan.tsv"
WARM_RECEIPTS="$SOURCE/warm-receipts.tsv"
WRITER_PLAN="$SOURCE/writer-plan.tsv"
WRITER_RECEIPTS="$SOURCE/writer-receipts.tsv"
EVENT_LOCKS="$ANATOMY_SOURCE/replay-locks.tsv"

EXPECTED_TRIGGER_SHA="${LEO_STATE_NEAR_GATE_TRIGGER_SHA:-72de2d7bfc3dd873d513457867c440f36709b80c3f7dcd1bb43e728aa9d0c9a3}"
EXPECTED_SCREEN_PLAN_SHA="${LEO_STATE_NEAR_GATE_SCREEN_PLAN_SHA:-017ab2f9239ca20cc51f1691cf9175f4a5ca36e7e337a654654791f86a81ea8f}"
EXPECTED_WARM_RECEIPTS_SHA="${LEO_STATE_NEAR_GATE_WARM_RECEIPTS_SHA:-02a7a18552ed850b3f7844ee75ca9bfedff5f9f6b750db293fbe81e271c51840}"
EXPECTED_WRITER_PLAN_SHA="${LEO_STATE_NEAR_GATE_WRITER_PLAN_SHA:-1cb1301c20e5124bc9e0493a354c6eb83347eea6c14665181c366ef629df43b3}"
EXPECTED_WRITER_RECEIPTS_SHA="${LEO_STATE_NEAR_GATE_WRITER_RECEIPTS_SHA:-10bf4251848f4edaec4a34d66d3d811afff187df9f10aeb71ff761a342c0e833}"
EXPECTED_EVENT_LOCKS_SHA="${LEO_STATE_NEAR_GATE_EVENT_LOCKS_SHA:-2f1a4e341745a2dda5a1c74550a73da574653dbbc08c5717e382ebd4fd4e3bc1}"

case "$EXPECTED:$EXPECTED_WRITER_ROWS:$JOBS" in
    *[!0-9:]*|0:*|*:0:*|*:0) printf 'invalid A.91 dimensions\n' >&2; exit 2 ;;
esac

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

require_sha() {
    local file="$1" expected="$2" label="$3"
    [ -s "$file" ] && [ "$(sha256_file "$file")" = "$expected" ] || {
        printf 'A.91 source mismatch: %s (%s)\n' "$label" "$file" >&2
        exit 2
    }
}

require_sha "$TRIGGERS" "$EXPECTED_TRIGGER_SHA" trigger-events
require_sha "$SCREEN_PLAN" "$EXPECTED_SCREEN_PLAN_SHA" screen-plan
require_sha "$WARM_RECEIPTS" "$EXPECTED_WARM_RECEIPTS_SHA" warm-receipts
require_sha "$WRITER_PLAN" "$EXPECTED_WRITER_PLAN_SHA" writer-plan
require_sha "$WRITER_RECEIPTS" "$EXPECTED_WRITER_RECEIPTS_SHA" writer-receipts
require_sha "$EVENT_LOCKS" "$EXPECTED_EVENT_LOCKS_SHA" event-replay-locks

MATCHES="$OUT/matches.tsv"
CONTROLS="$OUT/controls.tsv"
REPLAY_LIVES="$OUT/replay-lives.tsv"
CONTROL_LOCKS="$OUT/control-replay-locks.tsv"
OBSERVATIONS="$OUT/observations.tsv"
PROJECTIONS="$OUT/projections.tsv"
PAIR_SUMMARY="$OUT/pair-summary.tsv"
VERDICT="$OUT/verdict.txt"

if [ "$AGGREGATE_ONLY" = 1 ]; then
    [ -d "$OUT" ] && [ -s "$CONTROL_LOCKS" ] || {
        printf 'incomplete A.91 run cannot be aggregated: %s\n' "$OUT" >&2
        exit 2
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT/controls" "$OUT/lives"
fi

awk -v expected="$EXPECTED" -v writer_expected="$EXPECTED_WRITER_ROWS" \
    -f "$ROOT/scripts/state_swarm_near_gate_controls_select.awk" \
    "$TRIGGERS" "$EVENT_LOCKS" "$WRITER_RECEIPTS" > "$MATCHES"

printf 'control\tpair\tfamily\tlife\tsplit\tbase_seed\tturn\tsession\torder\ttexture\trun_seed\tsimilarity\tprompt\treply\tsource_log\tsource_log_sha\n' > "$CONTROLS"
awk -F '\t' 'BEGIN { OFS = "\t" }
    NR > 1 {
        print $15, $1, "organism", $3, $4, $5, $16, $17, $18, $19,
              $20, $21, $26, $27
        print $28, $1, "ecology", $29, $4, $30, $31, $32, $33, $34,
              $35, $36, $40, $41
    }
' "$MATCHES" |
while IFS=$'\t' read -r control pair family life split base_seed turn \
    session order texture run_seed similarity prompt reply; do
    printf -v stem 's%d-%02d-%s' "$session" "$order" "$texture"
    source_log="$SOURCE/candidates/$life/writer-logs/$stem.log"
    [ -s "$source_log" ] || {
        printf 'missing control source log: %s\n' "$control" >&2
        exit 2
    }
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$control" "$pair" "$family" "$life" "$split" "$base_seed" \
        "$turn" "$session" "$order" "$texture" "$run_seed" "$similarity" \
        "$prompt" "$reply" "$source_log" "$(sha256_file "$source_log")" \
        >> "$CONTROLS"
done

awk -F '\t' -v expected="$EXPECTED" '
    NR == 1 {
        if (NF != 16 || $1 != "control" || $3 != "family" ||
            $15 != "source_log" || $16 != "source_log_sha") exit 1
        next
    }
    {
        if (NF != 16 || seen[$1]++ || $1 != sprintf("%s-t%03d", $4, $7) ||
            $2 !~ /^[0-9][0-9]$/ || $3 !~ /^(organism|ecology)$/ ||
            $4 !~ /^[ph][0-9][0-9]$/ || $5 !~ /^(primary|holdout)$/ ||
            $10 !~ /^(home|storm|wonder|social)$/ ||
            length($16) != 64 || $16 !~ /^[0-9a-f]+$/) exit 1
        family[$3]++; rows++
    }
    END {
        if (rows != expected * 2 || family["organism"] != expected ||
            family["ecology"] != expected) exit 1
    }
' "$CONTROLS" || {
    printf 'invalid A.91 control plan\n' >&2
    exit 2
}

{
    printf 'life\tsplit\tbase_seed\n'
    awk -F '\t' 'NR > 1 && !seen[$4]++ { print $4, $5, $6 }' OFS=$'\t' \
        "$CONTROLS" | sort
} > "$REPLAY_LIVES"

if [ "${LEO_STATE_NEAR_GATE_PLAN_ONLY:-0}" = 1 ]; then
    cat "$MATCHES"
    printf '\n'
    cat "$CONTROLS"
    exit 0
fi

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

normalize_log() {
    sed -E \
        -e 's|^(\[leo step0\] ingest corpus .*) in [0-9.]+ ms$|\1 in TIME ms|' \
        -e 's|^\[leo\] loaded state from .*$|[leo] loaded state from BODY|' \
        -e 's|^\[leo\] saved state to .* \(step=|[leo] saved state to BODY (step=|' \
        "$1"
}

canonical_receipt() {
    local file="$1" life="$2" phase="$3" session="$4" order="$5"
    awk -F '\t' -v life="$life" -v phase="$phase" -v session="$session" \
        -v order="$order" '
        NR > 1 && $1 == life && $4 == phase && $5 == session && $6 == order {
            print; found++
        }
        END { if (found != 1) exit 2 }
    ' "$file"
}

is_control_turn() {
    local life="$1" turn="$2"
    awk -F '\t' -v life="$life" -v turn="$turn" \
        'NR > 1 && $4 == life && $7 == turn { found++ } END { exit found == 1 ? 0 : 1 }' \
        "$CONTROLS"
}

if [ "$AGGREGATE_ONLY" != 1 ]; then
    make -C "$ROOT" leo >/dev/null

    replay_life() {
        local wanted_life="$1" wanted_split="$2" wanted_seed="$3"
        local life_out="$OUT/lives/$wanted_life"
        local state="$life_out/leo.state"
        local generated="$life_out/generated.log"
        local source_normalized="$life_out/source.normalized"
        local generated_normalized="$life_out/generated.normalized"
        mkdir -p "$life_out"

        awk -F '\t' -v life="$wanted_life" 'NR > 1 && $1 == life' "$SCREEN_PLAN" |
        while IFS=$'\t' read -r life split base_seed phase session order \
            texture run_seed prompt; do
            local stem source_log reply receipt expected_receipt
            printf -v stem 's%d-%02d-%s' "$session" "$order" "$texture"
            source_log="$SOURCE/candidates/$life/warm-logs/$stem.log"
            [ -s "$source_log" ] || exit 1
            local args=("$ROOT/leo" --corpus "$ROOT/leo.txt")
            if [ -f "$state" ]; then args+=(--load "$state"); fi
            args+=(--seed "$run_seed" --respond "$prompt" --debug-field --save "$state")
            "${args[@]}" > "$generated" 2>&1
            reply="$(reply_from_log "$generated")"
            receipt="$(awk -v cell="$life" -v cohort="$split" \
                -v base_seed="$base_seed" -v phase="$phase" \
                -v session="$session" -v order="$order" -v texture="$texture" \
                -v run_seed="$run_seed" -v prompt="$prompt" -v reply="$reply" \
                -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$generated")"
            expected_receipt="$(canonical_receipt "$WARM_RECEIPTS" "$life" warm "$session" "$order")"
            [ "$receipt" = "$expected_receipt" ] || exit 1
            normalize_log "$source_log" > "$source_normalized"
            normalize_log "$generated" > "$generated_normalized"
            cmp -s "$source_normalized" "$generated_normalized" || exit 1
        done

        awk -F '\t' -v life="$wanted_life" 'NR > 1 && $1 == life' "$WRITER_PLAN" |
        while IFS=$'\t' read -r life split base_seed phase session order \
            texture run_seed prompt; do
            local stem source_log reply receipt expected_receipt turn control control_out
            turn=$((32 + (session - 1) * 8 + order))
            printf -v stem 's%d-%02d-%s' "$session" "$order" "$texture"
            source_log="$SOURCE/candidates/$life/writer-logs/$stem.log"
            [ -s "$source_log" ] || exit 1
            if is_control_turn "$life" "$turn"; then
                printf -v control '%s-t%03d' "$life" "$turn"
                control_out="$OUT/controls/$control"
                mkdir -p "$control_out"
                cp "$state" "$control_out/precontrol.state"
            else
                control=""
            fi
            "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$state" \
                --seed "$run_seed" --respond "$prompt" --debug-field \
                --save "$state" > "$generated" 2>&1
            reply="$(reply_from_log "$generated")"
            receipt="$(awk -v cell="$life" -v cohort="$split" \
                -v base_seed="$base_seed" -v phase="$phase" \
                -v session="$session" -v order="$order" -v texture="$texture" \
                -v run_seed="$run_seed" -v prompt="$prompt" -v reply="$reply" \
                -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$generated")"
            expected_receipt="$(canonical_receipt "$WRITER_RECEIPTS" "$life" writer "$session" "$order")"
            [ "$receipt" = "$expected_receipt" ] || exit 1
            normalize_log "$source_log" > "$source_normalized"
            normalize_log "$generated" > "$generated_normalized"
            cmp -s "$source_normalized" "$generated_normalized" || exit 1
            if [ -n "$control" ]; then
                cp "$state" "$control_out/updated.state"
                cp "$source_log" "$control_out/source.log"
            fi
        done
        cmp -s "$state" "$SOURCE/candidates/$wanted_life/leo.state" || exit 1
        printf '%s\ttrue\n' "$wanted_life" > "$life_out/final-lock.tsv"
        rm -f "$generated" "$source_normalized" "$generated_normalized"
    }

    pids=()
    running=0
    while IFS=$'\t' read -r life split base_seed; do
        replay_life "$life" "$split" "$base_seed" &
        pids+=("$!")
        running=$((running + 1))
        if [ "$running" -ge "$JOBS" ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
            pids=()
            running=0
        fi
    done < <(tail -n +2 "$REPLAY_LIVES")
    if [ "$running" -gt 0 ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
    fi

    printf 'control\tpair\tfamily\tlife\tsplit\tbase_seed\tturn\tsession\torder\ttexture\trun_seed\tprecontrol_sha\tupdated_sha\tsource_log_sha\treplay_log_sha\tnormalized_sha\tlife_state_equal\tstate_equal\tlog_equal\tshape_equal\treply_equal\n' > "$CONTROL_LOCKS"
    while IFS=$'\t' read -r control pair family life split base_seed turn \
        session order texture run_seed similarity prompt reply source_log source_log_sha; do
        control_out="$OUT/controls/$control"
        precontrol="$control_out/precontrol.state"
        updated="$control_out/updated.state"
        replay_state="$control_out/replay.state"
        replay_log="$control_out/replay.log"
        source_normalized="$control_out/source.normalized"
        replay_normalized="$control_out/replay.normalized"
        [ -s "$precontrol" ] && [ -s "$updated" ] || exit 1
        cp "$precontrol" "$replay_state"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$replay_state" \
            --seed "$run_seed" --respond "$prompt" --debug-field \
            --save "$replay_state" > "$replay_log" 2>&1
        [ "$(reply_from_log "$source_log")" = "$reply" ] &&
            [ "$(reply_from_log "$replay_log")" = "$reply" ] || exit 1
        source_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$source_log")"
        replay_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$replay_log")"
        [ "$source_shape" = "$replay_shape" ] || exit 1
        normalize_log "$source_log" > "$source_normalized"
        normalize_log "$replay_log" > "$replay_normalized"
        cmp -s "$source_normalized" "$replay_normalized" || exit 1
        cmp -s "$replay_state" "$updated" || exit 1
        [ "$(sha256_file "$source_log")" = "$source_log_sha" ] || exit 1
        [ "$(cat "$OUT/lives/$life/final-lock.tsv")" = "$life"$'\ttrue' ] || exit 1
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\ttrue\n' \
            "$control" "$pair" "$family" "$life" "$split" "$base_seed" \
            "$turn" "$session" "$order" "$texture" "$run_seed" \
            "$(sha256_file "$precontrol")" "$(sha256_file "$updated")" \
            "$source_log_sha" "$(sha256_file "$replay_log")" \
            "$(sha256_file "$source_normalized")" >> "$CONTROL_LOCKS"
        rm -f "$replay_state"
    done < <(tail -n +2 "$CONTROLS")
fi

awk -F '\t' -v expected="$((EXPECTED * 2))" '
    NR == 1 {
        if (NF != 21 || $1 != "control" || $12 != "precontrol_sha" ||
            $17 != "life_state_equal" || $21 != "reply_equal") exit 1
        next
    }
    {
        if (NF != 21 || seen[$1]++ || $3 !~ /^(organism|ecology)$/) exit 1
        for (i = 12; i <= 16; i++)
            if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) exit 1
        for (i = 17; i <= 21; i++) if ($i != "true") exit 1
        rows++
    }
    END { if (rows != expected) exit 1 }
' "$CONTROL_LOCKS" || {
    printf 'invalid A.91 control replay locks\n' >&2
    exit 2
}

printf 'observation\tpair\tfamily\tsource_id\tlife\tsplit\tbase_seed\tturn\tsession\torder\ttexture\trun_seed\tevent\tsimilarity\twinner_id\tdisplaced_id\tnearest_id\tnearest_organs\tremoved_organs\tmembers\torgans\tprompt\treply\tsource_log\tsource_log_sha\treplay_log_sha\tnormalized_sha\tstate_equal\tlog_equal\tshape_equal\treply_equal\n' > "$OBSERVATIONS"

while IFS=$'\t' read -r event life split base_seed enrollment_rank trigger_turn \
    session order texture run_seed displaced_id trigger_new_id similarity nearest_id \
    nearest_organs removed_organs members organs prompt reply; do
    pair="$(awk -F '\t' -v event="$event" 'NR > 1 && $2 == event { print $1 }' "$MATCHES")"
    lock="$(awk -F '\t' -v event="$event" 'NR > 1 && $1 == event { print }' "$EVENT_LOCKS")"
    [ -n "$pair" ] && [ -n "$lock" ] || exit 1
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ event_source_sha \
        event_replay_sha event_normalized_sha event_state_equal event_log_equal \
        event_shape_equal event_reply_equal <<< "$lock"
    source_log="$SOURCE/candidates/$life/events/$event/trigger.log"
    [ "$(sha256_file "$source_log")" = "$event_source_sha" ] || exit 1
    printf 'event-%s\t%s\tevent\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\treplaced\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$pair" "$pair" "$event" "$life" "$split" "$base_seed" \
        "$trigger_turn" "$session" "$order" "$texture" "$run_seed" \
        "$similarity" "$trigger_new_id" "$displaced_id" "$nearest_id" \
        "$nearest_organs" "$removed_organs" "$members" "$organs" "$prompt" \
        "$reply" "$source_log" "$event_source_sha" "$event_replay_sha" \
        "$event_normalized_sha" "$event_state_equal" "$event_log_equal" \
        "$event_shape_equal" "$event_reply_equal" >> "$OBSERVATIONS"
done < <(tail -n +2 "$TRIGGERS")

while IFS=$'\t' read -r control pair family life split base_seed turn session \
    order texture run_seed similarity prompt reply source_log source_log_sha; do
    lock="$(awk -F '\t' -v control="$control" 'NR > 1 && $1 == control { print }' "$CONTROL_LOCKS")"
    [ -n "$lock" ] || exit 1
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ control_replay_sha \
        control_normalized_sha control_life_equal control_state_equal \
        control_log_equal control_shape_equal control_reply_equal <<< "$lock"
    shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$source_log")"
    IFS=$'\t' read -r shape_turn shape_event winner shape_similarity members \
        displaced nearest nearest_organs removed_organs organs <<< "$shape"
    [ "$shape_turn" -eq "$turn" ] && [ "$shape_event" = updated ] &&
        [ "$shape_similarity" = "$similarity" ] || exit 1
    printf '%s-%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tupdated\t%s\t%s\t0\t%s\t%s\tna\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$family" "$pair" "$pair" "$family" "$control" "$life" "$split" \
        "$base_seed" "$turn" "$session" "$order" "$texture" "$run_seed" \
        "$similarity" "$winner" "$nearest" "$nearest_organs" "$members" \
        "$organs" "$prompt" "$reply" "$source_log" "$source_log_sha" \
        "$control_replay_sha" "$control_normalized_sha" "$control_state_equal" \
        "$control_log_equal" "$control_shape_equal" "$control_reply_equal" \
        >> "$OBSERVATIONS"
done < <(tail -n +2 "$CONTROLS")

awk -v expected="$EXPECTED" -f "$ROOT/scripts/state_swarm_near_gate_controls_report.awk" \
    "$OBSERVATIONS" > "$PROJECTIONS"
awk -v expected="$EXPECTED" -v mode=pairs \
    -f "$ROOT/scripts/state_swarm_near_gate_controls_verdict.awk" \
    "$PROJECTIONS" > "$PAIR_SUMMARY"
awk -v expected="$EXPECTED" -v mode=verdict \
    -f "$ROOT/scripts/state_swarm_near_gate_controls_verdict.awk" \
    "$PROJECTIONS" > "$VERDICT"

cat "$MATCHES"
printf '\n'
cat "$PAIR_SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nsource: %s\nanatomy: %s\nrun: %s\n' "$SOURCE" "$ANATOMY_SOURCE" "$OUT"
