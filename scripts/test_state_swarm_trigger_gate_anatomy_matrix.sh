#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-trigger-gate-plan.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SOURCE="$TMP/source"
TRIGGERS="$SOURCE/trigger-events.tsv"
VECTOR='0.300000/0.300000/0.300000/0.300000/0.300000/0.300000/0.300000'

mkdir -p "$SOURCE/candidates/p01/events/p01-t051"
mkdir -p "$SOURCE/candidates/h01/events/h01-t051"
printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tdisplaced_id\ttrigger_new_id\tsimilarity\tnearest_id\tnearest_organs\tremoved_organs\tmembers\torgans\tprompt\treply\n' > "$TRIGGERS"
printf 'p01-t051\tp01\tprimary\t200001\t1\t51\t3\t3\thome\t200304\t8\t9\t0.300\t1\t%s\t%s\t1:0.1\t9:na\tprompt p01\treply p01\n' \
    "$VECTOR" "$VECTOR" >> "$TRIGGERS"
printf 'h01-t051\th01\tholdout\t201001\t1\t51\t3\t3\thome\t201304\t8\t9\t0.300\t1\t%s\t%s\t1:0.1\t9:na\tprompt h01\treply h01\n' \
    "$VECTOR" "$VECTOR" >> "$TRIGGERS"

for event in p01/p01-t051 h01/h01-t051; do
    event_dir="$SOURCE/candidates/${event%/*}/events/${event#*/}"
    printf 'pretrigger %s\n' "$event" > "$event_dir/pretrigger.state"
    printf 'displaced %s\n' "$event" > "$event_dir/displaced.state"
    printf 'trigger %s\n' "$event" > "$event_dir/trigger.log"
done

trigger_sha="$(shasum -a 256 "$TRIGGERS" | awk '{ print $1 }')"
LEO_STATE_TRIGGER_ANATOMY_SOURCE="$SOURCE" \
LEO_STATE_TRIGGER_ANATOMY_EXPECTED_EVENTS=2 \
LEO_STATE_TRIGGER_ANATOMY_EXPECTED_TRIGGER_SHA="$trigger_sha" \
LEO_STATE_TRIGGER_ANATOMY_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_trigger_gate_anatomy_matrix.sh" "$TMP/run" \
    > "$TMP/plan.stdout"

cmp -s "$TMP/run/plan.tsv" "$TMP/plan.stdout"
awk -F '\t' '
    NR == 1 {
        if (NF != 20 || $1 != "event" || $15 != "pretrigger_state" ||
            $20 != "source_log_sha") exit 1
        next
    }
    {
        if (NF != 20 || $1 != sprintf("%s-t%03d", $2, $6) ||
            $3 !~ /^(primary|holdout)$/ || seen[$1]++) exit 1
        for (i = 18; i <= 20; i++)
            if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) exit 1
        rows++
    }
    END { if (rows != 2) exit 1 }
' "$TMP/run/plan.tsv"

printf 'tamper\n' >> "$TRIGGERS"
if LEO_STATE_TRIGGER_ANATOMY_SOURCE="$SOURCE" \
    LEO_STATE_TRIGGER_ANATOMY_EXPECTED_EVENTS=2 \
    LEO_STATE_TRIGGER_ANATOMY_EXPECTED_TRIGGER_SHA="$trigger_sha" \
    LEO_STATE_TRIGGER_ANATOMY_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_trigger_gate_anatomy_matrix.sh" \
    "$TMP/tampered-run" >/dev/null 2>&1; then
    printf 'trigger gate anatomy accepted a changed source ledger\n' >&2
    exit 1
fi

printf 'state-swarm trigger gate anatomy plan: ok\n'
