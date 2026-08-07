#!/usr/bin/env bash
# A.90: exact-replay every A.89 trigger before reading its frozen gate anatomy.
set -Eeuo pipefail

trap 'rc=$?; printf "trigger gate anatomy runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${LEO_STATE_TRIGGER_ANATOMY_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
TRIGGERS="$SOURCE/trigger-events.tsv"
EXPECTED_EVENTS="${LEO_STATE_TRIGGER_ANATOMY_EXPECTED_EVENTS:-19}"
EXPECTED_TRIGGER_SHA="${LEO_STATE_TRIGGER_ANATOMY_EXPECTED_TRIGGER_SHA:-72de2d7bfc3dd873d513457867c440f36709b80c3f7dcd1bb43e728aa9d0c9a3}"
AGGREGATE_ONLY="${LEO_STATE_TRIGGER_ANATOMY_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-trigger-gate-anatomy-$STAMP}"

case "$EXPECTED_EVENTS" in
    ''|*[!0-9]*|0) printf 'invalid trigger event count: %s\n' "$EXPECTED_EVENTS" >&2; exit 2 ;;
esac
case "$EXPECTED_TRIGGER_SHA" in
    *[!0-9a-f]*|'') printf 'invalid trigger ledger SHA-256\n' >&2; exit 2 ;;
esac
[ "${#EXPECTED_TRIGGER_SHA}" -eq 64 ] || {
    printf 'invalid trigger ledger SHA-256 length\n' >&2
    exit 2
}
[ -s "$TRIGGERS" ] || {
    printf 'missing A.89 trigger ledger: %s\n' "$TRIGGERS" >&2
    exit 2
}

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

[ "$(sha256_file "$TRIGGERS")" = "$EXPECTED_TRIGGER_SHA" ] || {
    printf 'A.89 trigger ledger is not the sealed source: %s\n' "$TRIGGERS" >&2
    exit 2
}

awk -F '\t' -v expected="$EXPECTED_EVENTS" '
    NR == 1 {
        if (NF != 20 || $1 != "event" || $2 != "life" ||
            $6 != "trigger_turn" || $10 != "run_seed" ||
            $11 != "displaced_id" || $12 != "trigger_new_id" ||
            $20 != "reply") exit 1
        next
    }
    {
        if (NF != 20 || $1 != sprintf("%s-t%03d", $2, $6) ||
            $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
            $4 !~ /^[0-9]+$/ || $5 !~ /^[0-9]+$/ ||
            $6 !~ /^[0-9]+$/ || $7 !~ /^[0-9]+$/ ||
            $8 !~ /^[0-9]+$/ || $9 !~ /^(home|storm|wonder|social)$/ ||
            $10 !~ /^[0-9]+$/ || $11 !~ /^[0-9]+$/ ||
            $12 !~ /^[0-9]+$/ || $19 == "" || $20 == "" || seen[$1]++)
            exit 1
        rows++
    }
    END { if (rows != expected) exit 1 }
' "$TRIGGERS" || {
    printf 'invalid A.89 trigger ledger: %s\n' "$TRIGGERS" >&2
    exit 2
}

PLAN="$OUT/plan.tsv"
LOCKS="$OUT/replay-locks.tsv"
PROJECTIONS="$OUT/projections.tsv"
EVENT_SUMMARY="$OUT/event-summary.tsv"
VERDICT="$OUT/verdict.txt"

if [ "$AGGREGATE_ONLY" = 1 ]; then
    [ -s "$PLAN" ] && [ -s "$LOCKS" ] || {
        printf 'incomplete trigger replay cannot be aggregated: %s\n' "$OUT" >&2
        exit 2
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT/events"
    printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tdisplaced_id\ttrigger_new_id\tprompt\treply\tpretrigger_state\tdisplaced_state\tsource_log\tpretrigger_sha\tdisplaced_sha\tsource_log_sha\n' > "$PLAN"
    while IFS=$'\t' read -r event life split base_seed enrollment_rank \
        trigger_turn session order texture run_seed displaced_id \
        trigger_new_id similarity nearest_id nearest_organs removed_organs \
        members organs prompt reply; do
        event_dir="$SOURCE/candidates/$life/events/$event"
        pretrigger="$event_dir/pretrigger.state"
        displaced="$event_dir/displaced.state"
        source_log="$event_dir/trigger.log"
        [ -s "$pretrigger" ] && [ -s "$displaced" ] && [ -s "$source_log" ] || {
            printf 'incomplete A.89 trigger package: %s\n' "$event" >&2
            exit 2
        }
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$event" "$life" "$split" "$base_seed" "$enrollment_rank" \
            "$trigger_turn" "$session" "$order" "$texture" "$run_seed" \
            "$displaced_id" "$trigger_new_id" "$prompt" "$reply" \
            "$pretrigger" "$displaced" "$source_log" \
            "$(sha256_file "$pretrigger")" "$(sha256_file "$displaced")" \
            "$(sha256_file "$source_log")" >> "$PLAN"
    done < <(tail -n +2 "$TRIGGERS")
fi

awk -F '\t' -v expected="$EXPECTED_EVENTS" '
    NR == 1 {
        if (NF != 20 || $1 != "event" || $6 != "trigger_turn" ||
            $15 != "pretrigger_state" || $20 != "source_log_sha") exit 1
        next
    }
    {
        if (NF != 20 || seen[$1]++ || $1 != sprintf("%s-t%03d", $2, $6) ||
            $3 !~ /^(primary|holdout)$/ || $13 == "" || $14 == "") exit 1
        for (i = 18; i <= 20; i++)
            if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) exit 1
        rows++
    }
    END { if (rows != expected) exit 1 }
' "$PLAN" || {
    printf 'invalid trigger replay plan: %s\n' "$PLAN" >&2
    exit 2
}

while IFS=$'\t' read -r event life split base_seed enrollment_rank \
    trigger_turn session order texture run_seed displaced_id trigger_new_id \
    prompt reply pretrigger displaced source_log pre_sha displaced_sha log_sha; do
    [ -s "$pretrigger" ] && [ -s "$displaced" ] && [ -s "$source_log" ] &&
        [ "$(sha256_file "$pretrigger")" = "$pre_sha" ] &&
        [ "$(sha256_file "$displaced")" = "$displaced_sha" ] &&
        [ "$(sha256_file "$source_log")" = "$log_sha" ] || {
            printf 'trigger package changed after sealing: %s\n' "$event" >&2
            exit 2
        }
done < <(tail -n +2 "$PLAN")

if [ "${LEO_STATE_TRIGGER_ANATOMY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

normalize_log() {
    sed -E \
        -e 's|^\[leo\] loaded state from .*$|[leo] loaded state from BODY|' \
        -e 's|^\[leo\] saved state to .* \(step=|[leo] saved state to BODY (step=|' \
        "$1"
}

if [ "$AGGREGATE_ONLY" != 1 ]; then
    make -C "$ROOT" leo >/dev/null
    printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tpretrigger_sha\tdisplaced_sha\tsource_log_sha\treplay_log_sha\tnormalized_sha\tstate_equal\tlog_equal\tshape_equal\treply_equal\n' > "$LOCKS"
    while IFS=$'\t' read -r event life split base_seed enrollment_rank \
        trigger_turn session order texture run_seed displaced_id trigger_new_id \
        prompt reply pretrigger displaced source_log pre_sha displaced_sha log_sha; do
        event_out="$OUT/events/$event"
        mkdir -p "$event_out"
        replay_state="$event_out/replay.state"
        replay_log="$event_out/replay.log"
        source_normalized="$event_out/source.normalized"
        replay_normalized="$event_out/replay.normalized"
        cp "$pretrigger" "$replay_state"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$replay_state" \
            --seed "$run_seed" --respond "$prompt" --debug-field \
            --save "$replay_state" > "$replay_log" 2>&1

        source_reply="$(reply_from_log "$source_log")"
        replay_reply="$(reply_from_log "$replay_log")"
        [ -n "$source_reply" ] && [ "$source_reply" = "$reply" ] &&
            [ "$replay_reply" = "$reply" ] || {
                printf 'trigger reply replay mismatch: %s\n' "$event" >&2
                exit 1
            }
        source_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$source_log")"
        replay_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$replay_log")"
        [ "$source_shape" = "$replay_shape" ] || {
            printf 'trigger geometry replay mismatch: %s\n' "$event" >&2
            exit 1
        }
        IFS=$'\t' read -r shape_turn shape_event shape_new shape_similarity \
            shape_members shape_displaced shape_nearest shape_nearest_organs \
            shape_removed_organs shape_organs <<< "$source_shape"
        [ "$shape_turn" -eq "$trigger_turn" ] && [ "$shape_event" = replaced ] &&
            [ "$shape_new" -eq "$trigger_new_id" ] &&
            [ "$shape_displaced" -eq "$displaced_id" ] || {
                printf 'trigger source row disagrees with package: %s\n' "$event" >&2
                exit 1
            }
        normalize_log "$source_log" > "$source_normalized"
        normalize_log "$replay_log" > "$replay_normalized"
        cmp -s "$source_normalized" "$replay_normalized" || {
            printf 'trigger full-log replay mismatch: %s\n' "$event" >&2
            exit 1
        }
        cmp -s "$replay_state" "$displaced" || {
            printf 'trigger state replay mismatch: %s\n' "$event" >&2
            exit 1
        }
        normalized_sha="$(sha256_file "$source_normalized")"
        replay_log_sha="$(sha256_file "$replay_log")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' \
            "$event" "$life" "$split" "$base_seed" "$enrollment_rank" \
            "$trigger_turn" "$session" "$order" "$texture" "$run_seed" \
            "$pre_sha" "$displaced_sha" "$log_sha" "$replay_log_sha" \
            "$normalized_sha" >> "$LOCKS"
        rm -f "$replay_state"
    done < <(tail -n +2 "$PLAN")
fi

awk -f "$ROOT/scripts/state_swarm_trigger_gate_anatomy_report.awk" \
    "$LOCKS" "$TRIGGERS" > "$PROJECTIONS"
awk -v mode=events -f "$ROOT/scripts/state_swarm_trigger_gate_anatomy_verdict.awk" \
    "$PROJECTIONS" > "$EVENT_SUMMARY"
awk -v mode=verdict -f "$ROOT/scripts/state_swarm_trigger_gate_anatomy_verdict.awk" \
    "$PROJECTIONS" > "$VERDICT"

cat "$LOCKS"
printf '\n'
cat "$EVENT_SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nprocesses=%d\nsource: %s\nrun: %s\n' "$EXPECTED_EVENTS" "$SOURCE" "$OUT"
