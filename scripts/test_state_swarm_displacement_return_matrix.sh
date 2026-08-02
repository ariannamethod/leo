#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-displacement-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/plan"
LEO_STATE_DISPLACEMENT_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_displacement_return_matrix.sh" "$OUT" \
    > "$TMP/plan.out"
cmp -s "$OUT/plan.tsv" "$TMP/plan.out"

awk -F '\t' '
    NR == 1 { next }
    {
        rows++; cases[$1]++; kinds[$1 SUBSEP $12]++
        if (seen[$1 SUBSEP $11]++ || $7 != 32 + ($5 - 1) * 8 + $6 ||
            $9 != $4 + $5 * 100 + $6 || $14 == "" || $15 == "") exit 1
        if ($1 == "window51" && ($2 != "window" || $7 != 51 || $10 != 3))
            exit 1
        if ($1 == "lantern68" && ($2 != "lantern" || $7 != 68 || $10 != 4))
            exit 1
        if ($1 == "lantern77" && ($2 != "lantern" || $7 != 77 || $10 != 3))
            exit 1
    }
    END {
        if (rows != 12 || length(cases) != 3) exit 1
        for (case_name in cases)
            if (cases[case_name] != 4 ||
                kinds[case_name SUBSEP "exact-birth"] != 1 ||
                kinds[case_name SUBSEP "birth-paraphrase"] != 1 ||
                kinds[case_name SUBSEP "exact-anchor"] != 1 ||
                kinds[case_name SUBSEP "anchor-paraphrase"] != 1) exit 1
    }
' "$TMP/plan.out"

RAW="$TMP/raw.tsv"
printf 'case\tcell\tcohort\tbase_seed\ttrigger_turn\tdisplaced_id\ttrigger_new_id\tprobe\tkind\treturn_seed\tcontrol_event\tcontrol_winner\tcontrol_similarity\tcontrol_members\tcontrol_replaced\tdisplaced_event\tdisplaced_winner\tdisplaced_similarity\tdisplaced_members\tdisplaced_replaced\tprompt\treply\n' > "$RAW"
for probe in 1 2 3 4; do
    case "$probe" in
        1) displaced_event=updated; displaced_winner=9 ;;
        2) displaced_event=updated; displaced_winner=2 ;;
        3) displaced_event=replaced; displaced_winner=10 ;;
        4) displaced_event=updated; displaced_winner=9 ;;
    esac
    if [ "$probe" -eq 4 ]; then
        control_winner=2
        control_members='1:0.100,2:0.500,3:0.300,4:0.100'
    else
        control_winner=3
        control_members='1:0.100,2:0.100,3:0.700,4:0.100'
    fi
    printf 'fixture\twindow\treplication\t1\t51\t3\t9\t%s\tkind\t%s\tupdated\t%s\t0.800\t%s\t0\t%s\t%s\t0.700\t1:0.200,2:0.300,9:0.500,4:0.000\t0\tprompt\treply\n' \
        "$probe" "$probe" "$control_winner" "$control_members" \
        "$displaced_event" "$displaced_winner" >> "$RAW"
done

awk -f "$ROOT/scripts/state_swarm_displacement_report.awk" "$RAW" \
    > "$TMP/probes.tsv"
awk -F '\t' '
    NR == 1 { next }
    $8 == 1 { if ($19 != "true" || $20 != "trigger-capture") exit 1 }
    $8 == 2 { if ($19 != "true" || $20 != "survivor-return") exit 1 }
    $8 == 3 { if ($19 != "true" || $20 != "rebirth") exit 1 }
    $8 == 4 { if ($19 != "false" || $20 != "unanchored") exit 1 }
    END { if (NR != 5) exit 1 }
' "$TMP/probes.tsv"

cp "$RAW" "$TMP/invalid-members.tsv"
sed -i.bak '$s/1:0.200,2:0.300,9:0.500,4:0.000/1:0.200,2:0.300,9:0.500,3:0.000/' \
    "$TMP/invalid-members.tsv"
if awk -f "$ROOT/scripts/state_swarm_displacement_report.awk" \
    "$TMP/invalid-members.tsv" >/dev/null 2>&1; then
    printf 'scorer accepted a displaced zero-mass old ID\n' >&2
    exit 1
fi

printf 'state-swarm displacement return plan and scorer: ok\n'
