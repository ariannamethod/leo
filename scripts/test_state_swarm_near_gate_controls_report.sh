#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-near-gate-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

hash='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
event_vector='0/0/0/0.6/0.8/0.5/0.7'
flat_vector='0.42/0.42/0.42/0.42/0.42/0.42/0.42'
low_vector='0.1/0.1/0.1/0.1/0.1/0.1/0.1'
event_members='9:1,2:0,3:0,4:0,5:0,6:0,7:0,8:0'
event_organs="9:na,2:$low_vector,3:$low_vector,4:$low_vector,5:$low_vector,6:$low_vector,7:$low_vector,8:$low_vector"
control_members='1:1,2:0,3:0,4:0,5:0,6:0,7:0,8:0'
control_organs="1:$flat_vector,2:$low_vector,3:$low_vector,4:$low_vector,5:$low_vector,6:$low_vector,7:$low_vector,8:$low_vector"

printf 'observation\tpair\tfamily\tsource_id\tlife\tsplit\tbase_seed\tturn\tsession\torder\ttexture\trun_seed\tevent\tsimilarity\twinner_id\tdisplaced_id\tnearest_id\tnearest_organs\tremoved_organs\tmembers\torgans\tprompt\treply\tsource_log\tsource_log_sha\treplay_log_sha\tnormalized_sha\tstate_equal\tlog_equal\tshape_equal\treply_equal\n' > "$TMP/observations.tsv"

emit_event() {
    local pair="$1" life="$2" source="$3"
    printf 'event-%s\t%s\tevent\t%s\t%s\tprimary\t100\t33\t1\t1\thome\t201\treplaced\t0.348\t9\t1\t1\t%s\t%s\t%s\t%s\tevent prompt\tevent reply\t/source/event.log\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' \
        "$pair" "$pair" "$source" "$life" "$event_vector" "$event_vector" \
        "$event_members" "$event_organs" "$hash" "$hash" "$hash"
}

emit_control() {
    local pair="$1" family="$2" life="$3" source="$4"
    printf '%s-%s\t%s\t%s\t%s\t%s\tprimary\t100\t34\t1\t2\tstorm\t202\tupdated\t0.420\t1\t0\t1\t%s\tna\t%s\t%s\tcontrol prompt\tcontrol reply\t/source/control.log\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' \
        "$family" "$pair" "$pair" "$family" "$source" "$life" \
        "$flat_vector" "$control_members" "$control_organs" \
        "$hash" "$hash" "$hash"
}

emit_event 01 p01 p01-t033 >> "$TMP/observations.tsv"
emit_control 01 organism p01 p01-t034 >> "$TMP/observations.tsv"
emit_control 01 ecology p02 p02-t033 >> "$TMP/observations.tsv"
emit_event 02 p03 p03-t033 >> "$TMP/observations.tsv"
emit_control 02 organism p03 p03-t034 >> "$TMP/observations.tsv"
emit_control 02 ecology p04 p04-t033 >> "$TMP/observations.tsv"

awk -v expected=2 -f "$ROOT/scripts/state_swarm_near_gate_controls_report.awk" \
    "$TMP/observations.tsv" > "$TMP/projections.tsv"
[ "$(wc -l < "$TMP/projections.tsv")" -eq 43 ]

awk -v expected=2 -v sign_required=2 -v mean_required=0.01 -v mode=pairs \
    -f "$ROOT/scripts/state_swarm_near_gate_controls_verdict.awk" \
    "$TMP/projections.tsv" > "$TMP/pairs.tsv"
awk -v expected=2 -v sign_required=2 -v mean_required=0.01 -v mode=verdict \
    -f "$ROOT/scripts/state_swarm_near_gate_controls_verdict.awk" \
    "$TMP/projections.tsv" > "$TMP/verdict.txt"

grep -q '^result=crossing-specific-organ-polarity$' "$TMP/verdict.txt"
grep -q '^polarity organism positive=2 negative=0 tie=0 .* strong=true$' "$TMP/verdict.txt"
grep -q '^polarity ecology positive=2 negative=0 tie=0 .* strong=true$' "$TMP/verdict.txt"

sed '2s/true$/false/' "$TMP/observations.tsv" > "$TMP/bad-observations.tsv"
if awk -v expected=2 -f "$ROOT/scripts/state_swarm_near_gate_controls_report.awk" \
    "$TMP/bad-observations.tsv" >/dev/null 2>&1; then
    printf 'near-gate reporter accepted a false replay lock\n' >&2
    exit 1
fi

printf 'state-swarm dual near-gate control reporters: ok\n'
