#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-road-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/plan"
LEO_STATE_ROAD_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_road_calibration.sh" "$OUT" > "$TMP/plan.out"
cmp -s "$OUT/plan.tsv" "$TMP/plan.out"

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "cell" || $4 != "phase" ||
            $5 != "session" || $8 != "run_seed" || $9 != "persisted")
            exit 1
        next
    }
    {
        rows++
        lives[$1]++
        sessions[$1 SUBSEP $5]++
        slot = $1 SUBSEP $4 SUBSEP $5 SUBSEP $6
        if (seen[slot]++) exit 1
        if ($4 == "writer") {
            writers[$1]++
            if ($9 != 1 || writer_seed[$1 SUBSEP $8]++) exit 1
        } else if ($4 == "probe") {
            probes[$1]++
            if ($9 != 0) exit 1
            key = $1 SUBSEP $7
            if (!(key in probe_seed)) probe_seed[key] = $8
            else if (probe_seed[key] != $8) exit 1
        } else exit 1
    }
    END {
        if (rows != 216 || length(lives) != 3 || length(sessions) != 18)
            exit 1
        for (cell in lives)
            if (lives[cell] != 72 || writers[cell] != 48 || probes[cell] != 24)
                exit 1
        for (key in sessions) if (sessions[key] != 12) exit 1
    }
' "$TMP/plan.out"

RECEIPTS="$TMP/receipts.tsv"
printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tstates\tactive\twinner\tevent\tsimilarity\tentropy\tmembers\tmember_sum\tadjacent\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply\tvoice_equal\tstate_equal\n' > "$RECEIPTS"
for cell in river window lantern; do
    case "$cell" in
        lantern) cohort=confirmatory; seed=10007 ;;
        river) cohort=replication; seed=8301 ;;
        window) cohort=replication; seed=9011 ;;
    esac
    turn=0
    for session in 1 2 3 4 5 6; do
        for order in 1 2 3 4 5 6 7 8; do
            turn=$((turn + 1))
            event=updated
            prediction=1
            expected='1'
            expected_probability='1.000'
            overlap='1.000'
            surprise='0.200'
            if [ "$turn" -eq 1 ]; then
                event=born
                prediction=0
                expected=0
                expected_probability=0
                overlap=0
                surprise=0
            fi
            printf '%s\t%s\t%s\twriter\t%s\t%s\thome\t%s\t%s\t1\t1\t1\t%s\t1.000\t0.000\t1:1.000\t1.000\t%s\t0\t%s\t%s\t%s\t%s\t%s\t0\t0\t0\t0\t0\t0\t0\t0\tprompt\treply\tna\tna\n' \
                "$cell" "$cohort" "$seed" "$session" "$order" \
                "$((seed + session * 100 + order))" "$turn" "$event" \
                "$((turn > 1 ? 1 : 0))" "$prediction" "$expected" \
                "$expected_probability" "$overlap" "$surprise" >> "$RECEIPTS"
        done
    done
done

awk -f "$ROOT/scripts/state_swarm_road_report.awk" "$RECEIPTS" \
    > "$TMP/epochs.tsv"
awk -F '\t' '
    {
        rows++
        if (NF != 20 || $5 != 8 || $6 != 1 || $9 != 0 ||
            $11 != "0.200000" || $12 != "0.000000" ||
            $14 != "0.000000" || $15 != "0.000000" ||
            $20 != "0.000000") exit 1
        if ($4 == 1) {
            if ($10 != 7 || $17 != 0 || $19 != 6) exit 1
        } else if ($10 != 8 || $17 != 8 || $19 != 8) exit 1
    }
    END { if (rows != 18) exit 1 }
' "$TMP/epochs.tsv"

printf 'state-swarm road calibration plan and baselines: ok\n'
