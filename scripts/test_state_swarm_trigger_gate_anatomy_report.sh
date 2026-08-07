#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-trigger-gate-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LOCKS="$TMP/locks.tsv"
TRIGGERS="$TMP/triggers.tsv"
HASH='0000000000000000000000000000000000000000000000000000000000000000'
LOW='0.100000/0.100000/0.100000/0.100000/0.100000/0.100000/0.100000'
DISTRIBUTED='0.350000/0.350000/0.350000/0.350000/0.350000/0.350000/0.350000'
SENSITIVE='0.000000/0.000000/0.630000/0.630000/0.630000/0.630000/0.630000'
MEMBERS='1:0.000,2:0.000,3:0.000,4:0.000,5:0.000,6:0.000,7:0.000,9:1.000'

printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tpretrigger_sha\tdisplaced_sha\tsource_log_sha\treplay_log_sha\tnormalized_sha\tstate_equal\tlog_equal\tshape_equal\treply_equal\n' > "$LOCKS"
printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tdisplaced_id\ttrigger_new_id\tsimilarity\tnearest_id\tnearest_organs\tremoved_organs\tmembers\torgans\tprompt\treply\n' > "$TRIGGERS"

append_event() {
    local life="$1" split="$2" base="$3" vector="$4" similarity="$5"
    local event="${life}-t051" run_seed=$((base + 303))
    local organs="1:${vector},2:${LOW},3:${LOW},4:${LOW},5:${LOW},6:${LOW},7:${LOW},9:na"
    printf '%s\t%s\t%s\t%d\t1\t51\t3\t3\thome\t%d\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' \
        "$event" "$life" "$split" "$base" "$run_seed" \
        "$HASH" "$HASH" "$HASH" "$HASH" "$HASH" >> "$LOCKS"
    printf '%s\t%s\t%s\t%d\t1\t51\t3\t3\thome\t%d\t8\t9\t%s\t1\t%s\t%s\t%s\t%s\tprompt %s\treply %s\n' \
        "$event" "$life" "$split" "$base" "$run_seed" "$similarity" \
        "$vector" "$LOW" "$MEMBERS" "$organs" "$life" "$life" \
        >> "$TRIGGERS"
}

append_event p01 primary 200001 "$DISTRIBUTED" 0.350000
append_event p02 primary 201001 "$SENSITIVE" 0.390600
append_event h01 holdout 202001 "$DISTRIBUTED" 0.350000
append_event h02 holdout 203001 "$SENSITIVE" 0.390600

awk -f "$ROOT/scripts/state_swarm_trigger_gate_anatomy_report.awk" \
    "$LOCKS" "$TRIGGERS" > "$TMP/projections.tsv"
awk -v mode=events \
    -f "$ROOT/scripts/state_swarm_trigger_gate_anatomy_verdict.awk" \
    "$TMP/projections.tsv" > "$TMP/events.tsv"
awk -v mode=verdict \
    -f "$ROOT/scripts/state_swarm_trigger_gate_anatomy_verdict.awk" \
    "$TMP/projections.tsv" > "$TMP/verdict.txt"

awk -F '\t' '
    NR == 1 { next }
    $1 == "p01-t051" || $1 == "h01-t051" {
        if ($7 != 7 || $8 != 0 || $9 != 0 || $11 != "true") exit 1
        distributed++
    }
    $1 == "p02-t051" || $1 == "h02-t051" {
        if ($7 != 5 || $8 != 2 || $9 != 0 || $11 != "false") exit 1
        sensitive++
    }
    END { if (NR != 5 || distributed != 2 || sensitive != 2) exit 1 }
' "$TMP/events.tsv"
grep -q '^events=4 lives=4 primary=2 holdout=2 projections=28 replay_locked=4$' \
    "$TMP/verdict.txt"
grep -q '^event_stability robust=2 nonrobust=2$' "$TMP/verdict.txt"
grep -q '^result=mixed$' "$TMP/verdict.txt"

awk -F '\t' 'BEGIN { OFS = FS } NR == 2 { $19 = "false" } { print }' \
    "$LOCKS" > "$TMP/unlocked.tsv"
if awk -f "$ROOT/scripts/state_swarm_trigger_gate_anatomy_report.awk" \
    "$TMP/unlocked.tsv" "$TRIGGERS" >/dev/null 2>&1; then
    printf 'trigger gate anatomy accepted a failed replay lock\n' >&2
    exit 1
fi

awk -F '\t' 'BEGIN { OFS = FS } NR == 2 { $14 = 2 } { print }' \
    "$TRIGGERS" > "$TMP/bad-nearest.tsv"
if awk -f "$ROOT/scripts/state_swarm_trigger_gate_anatomy_report.awk" \
    "$LOCKS" "$TMP/bad-nearest.tsv" >/dev/null 2>&1; then
    printf 'trigger gate anatomy accepted a false nearest state\n' >&2
    exit 1
fi

printf 'state-swarm trigger gate anatomy reporters: ok\n'
