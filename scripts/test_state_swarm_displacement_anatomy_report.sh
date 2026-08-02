#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-anatomy-report-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
RAW="$TMP/raw.tsv"

printf 'event\tlife\tsplit\tsettled\tbase_seed\ttrigger_turn\tdisplaced_id\ttrigger_new_id\tprobe\tkind\treturn_seed\tcontrol_turn\tcontrol_event\tcontrol_winner\tcontrol_similarity\tcontrol_members\tcontrol_replaced\tcontrol_nearest\tcontrol_nearest_organs\tcontrol_removed_organs\tcontrol_organs\tdisplaced_turn\tdisplaced_event\tdisplaced_winner\tdisplaced_similarity\tdisplaced_members\tdisplaced_replaced\tdisplaced_nearest\tdisplaced_nearest_organs\tdisplaced_removed_organs\tdisplaced_organs\tprompt\treply\n' > "$RAW"

small='0.100000/0.100000/0.100000/0.100000/0.100000/0.100000/0.100000'
control_high='0.700000/0.700000/0.700000/0.700000/0.700000/0.700000/0.700000'
capture_high='0.800000/0.800000/0.800000/0.800000/0.800000/0.800000/0.800000'
control_members='1:0.050,2:0.050,3:0.650,4:0.050,5:0.050,6:0.050,7:0.050,8:0.050'
control_organs="1:${small},2:${small},3:${control_high},4:${small},5:${small},6:${small},7:${small},8:${small}"
control_shape="52\tupdated\t3\t0.700\t${control_members}\t0\t3\t${control_high}\tna\t${control_organs}"

capture_members='1:0.050,2:0.050,9:0.650,4:0.050,5:0.050,6:0.050,7:0.050,8:0.050'
capture_organs="1:${small},2:${small},9:${capture_high},4:${small},5:${small},6:${small},7:${small},8:${small}"
capture_shape="52\tupdated\t9\t0.800\t${capture_members}\t0\t9\t${capture_high}\tna\t${capture_organs}"
printf 'e1\th01\tholdout\ttrue\t14939\t51\t3\t9\t1\texact-birth\t15824\t%b\t%b\tprompt one\treply one\n' \
    "$control_shape" "$capture_shape" >> "$RAW"

rebirth_members='1:0.125,2:0.125,9:0.125,4:0.125,5:0.125,6:0.125,7:0.125,10:0.125'
low='0.350000/0.350000/0.350000/0.350000/0.350000/0.350000/0.350000'
lower='0.200000/0.200000/0.200000/0.200000/0.200000/0.200000/0.200000'
rebirth_organs="1:${low},2:${lower},9:${lower},4:${lower},5:${lower},6:${lower},7:${lower},10:na"
rebirth_shape="52\treplaced\t10\t0.350\t${rebirth_members}\t8\t1\t${low}\t${lower}\t${rebirth_organs}"
printf 'e2\th02\tholdout\ttrue\t15331\t51\t3\t9\t1\texact-birth\t15824\t%b\t%b\tprompt two\treply two\n' \
    "$control_shape" "$rebirth_shape" >> "$RAW"

awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_report.awk" "$RAW" \
    > "$TMP/anatomy.tsv"
awk -F '\t' '
    NR == 1 { next }
    $1 == "e1" {
        if ($13 != "true" || $14 != "trigger-capture" ||
            $24 != 7 || $25 != "true" || $26 != "none") exit 1
    }
    $1 == "e2" {
        if ($13 != "true" || $14 != "rebirth" ||
            $24 != 7 || $25 != "true" || $26 != "none") exit 1
    }
    END { if (NR != 3) exit 1 }
' "$TMP/anatomy.tsv"

sed '2s/9:0.650/3:0.650/' "$RAW" > "$TMP/bad.tsv"
if awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_report.awk" \
    "$TMP/bad.tsv" >/dev/null 2>&1; then
    printf 'anatomy scorer accepted the displaced old ID\n' >&2
    exit 1
fi

printf 'state-swarm displacement anatomy scorer: ok\n'
