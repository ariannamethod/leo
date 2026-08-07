#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-near-gate-select.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

hash='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tdisplaced_id\ttrigger_new_id\tsimilarity\tnearest_id\tnearest_organs\tremoved_organs\tmembers\torgans\tprompt\treply\n' > "$TMP/triggers.tsv"
printf 'p01-t033\tp01\tprimary\t100\t1\t33\t1\t1\thome\t201\t1\t9\t0.390\t1\t0/0/0/0.6/0.8/0.5/0.7\t0/0/0/0.6/0.8/0.5/0.7\t9:1,2:0,3:0,4:0,5:0,6:0,7:0,8:0\t9:na,2:0/0/0/0.1/0.1/0.1/0.1,3:0/0/0/0.1/0.1/0.1/0.1,4:0/0/0/0.1/0.1/0.1/0.1,5:0/0/0/0.1/0.1/0.1/0.1,6:0/0/0/0.1/0.1/0.1/0.1,7:0/0/0/0.1/0.1/0.1/0.1,8:0/0/0/0.1/0.1/0.1/0.1\tevent primary\treply primary\n' >> "$TMP/triggers.tsv"
printf 'h01-t033\th01\tholdout\t300\t1\t33\t1\t1\thome\t401\t1\t9\t0.380\t1\t0/0/0/0.6/0.8/0.5/0.7\t0/0/0/0.6/0.8/0.5/0.7\t9:1,2:0,3:0,4:0,5:0,6:0,7:0,8:0\t9:na,2:0/0/0/0.1/0.1/0.1/0.1,3:0/0/0/0.1/0.1/0.1/0.1,4:0/0/0/0.1/0.1/0.1/0.1,5:0/0/0/0.1/0.1/0.1/0.1,6:0/0/0/0.1/0.1/0.1/0.1,7:0/0/0/0.1/0.1/0.1/0.1,8:0/0/0/0.1/0.1/0.1/0.1\tevent holdout\treply holdout\n' >> "$TMP/triggers.tsv"

printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tpretrigger_sha\tdisplaced_sha\tsource_log_sha\treplay_log_sha\tnormalized_sha\tstate_equal\tlog_equal\tshape_equal\treply_equal\n' > "$TMP/locks.tsv"
printf 'p01-t033\tp01\tprimary\t100\t1\t33\t1\t1\thome\t201\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' "$hash" "$hash" "$hash" "$hash" "$hash" >> "$TMP/locks.tsv"
printf 'h01-t033\th01\tholdout\t300\t1\t33\t1\t1\thome\t401\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' "$hash" "$hash" "$hash" "$hash" "$hash" >> "$TMP/locks.tsv"

printf 'life\tsplit\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tstates\tactive\twinner\tevent\tsimilarity\tentropy\tmembers\tmember_sum\tadjacent\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply\n' > "$TMP/writer.tsv"
writer_row() {
    printf '%s\t%s\t%s\twriter\t%s\t%s\t%s\t%s\t%s\t8\t1\t1\tupdated\t%s\t0.5\t1:1,2:0,3:0,4:0,5:0,6:0,7:0,8:0\t1.000\t1\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t%s\t%s\n' "$@"
}
writer_row p01 primary 100 1 2 storm 202 34 0.410 'organism primary' 'reply op' >> "$TMP/writer.tsv"
writer_row p02 primary 200 1 1 home 301 33 0.410 'ecology primary' 'reply ep' >> "$TMP/writer.tsv"
writer_row h01 holdout 300 1 2 storm 402 34 0.420 'organism holdout' 'reply oh' >> "$TMP/writer.tsv"
writer_row h02 holdout 400 1 1 home 501 33 0.420 'ecology holdout' 'reply eh' >> "$TMP/writer.tsv"

awk -v expected=2 -v writer_expected=4 \
    -f "$ROOT/scripts/state_swarm_near_gate_controls_select.awk" \
    "$TMP/triggers.tsv" "$TMP/locks.tsv" "$TMP/writer.tsv" > "$TMP/matches.tsv"

awk -F '\t' '
    NR == 1 { if (NF != 41 || $1 != "pair" || $41 != "ecology_reply") exit 1; next }
    NR == 2 { if ($15 != "p01-t034" || $28 != "p02-t033") exit 1 }
    NR == 3 { if ($15 != "h01-t034" || $28 != "h02-t033") exit 1 }
    END { if (NR != 3) exit 1 }
' "$TMP/matches.tsv"

sed '2s/true$/false/' "$TMP/locks.tsv" > "$TMP/bad-locks.tsv"
if awk -v expected=2 -v writer_expected=4 \
    -f "$ROOT/scripts/state_swarm_near_gate_controls_select.awk" \
    "$TMP/triggers.tsv" "$TMP/bad-locks.tsv" "$TMP/writer.tsv" >/dev/null 2>&1; then
    printf 'near-gate selector accepted an unlocked event\n' >&2
    exit 1
fi

printf 'state-swarm dual near-gate control selector: ok\n'
