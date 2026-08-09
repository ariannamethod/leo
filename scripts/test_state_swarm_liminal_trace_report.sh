#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-liminal-trace-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

HASH='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
ORGANS='0.1/0.2/0.3/0.4/0.5/0.6/0.7'
printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turns\tbuild_turns\tscore_turns\tpre_sha\tpost_sha\tfinal_sha\treproduced_sha\tlog_equal\tstate_equal\tgeometry_equal\n' > "$TMP/locks.tsv"
lock() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t3\t5\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$((96 - $6))" \
        "$HASH" "$HASH" "$HASH" "$HASH"
}
lock 01 event p01-t050 p01 primary 50 >> "$TMP/locks.tsv"
lock 01 ecology p11-t050 p11 primary 50 >> "$TMP/locks.tsv"
lock 02 event h01-t060 h01 holdout 60 >> "$TMP/locks.tsv"
lock 02 ecology h11-t060 h11 holdout 60 >> "$TMP/locks.tsv"

printf 'pair\tarm\tanchor\tanchor_turn\tfuture_turn\trelative\ttexture\tforward_similarity\treverse_similarity\tstable_similarity\tstable_nearest_id\tforward_stable_margin\treverse_stable_margin\torder_margin\tdirectional_nearest\tsupport\tstrong\tforward_organs\treverse_organs\tstable_organs\tprompt\treply\n' > "$TMP/scores.tsv"
score() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t1\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tprompt %s\treply %s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" \
        "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" \
        "$ORGANS" "$ORGANS" "$ORGANS" "$1" "$2"
}
emit_arm() {
    local pair="$1" arm="$2" anchor="$3" turn="$4" confirm="$5"
    if [ "$confirm" = true ]; then
        score "$pair" "$arm" "$anchor" "$turn" "$((turn + 4))" 4 home 0.560000 0.500000 0.450000 0.110000 0.050000 0.060000 true true true
        score "$pair" "$arm" "$anchor" "$turn" "$((turn + 5))" 5 storm 0.500000 0.450000 0.440000 0.060000 0.010000 0.050000 true true false
    else
        score "$pair" "$arm" "$anchor" "$turn" "$((turn + 4))" 4 home 0.460000 0.470000 0.450000 0.010000 0.020000 -0.010000 false false false
        score "$pair" "$arm" "$anchor" "$turn" "$((turn + 5))" 5 storm 0.420000 0.410000 0.440000 -0.020000 -0.030000 0.010000 false false false
    fi
    score "$pair" "$arm" "$anchor" "$turn" "$((turn + 6))" 6 wonder 0.390000 0.380000 0.430000 -0.040000 -0.050000 0.010000 false false false
    score "$pair" "$arm" "$anchor" "$turn" "$((turn + 7))" 7 social 0.400000 0.410000 0.450000 -0.050000 -0.040000 -0.010000 false false false
    score "$pair" "$arm" "$anchor" "$turn" "$((turn + 8))" 8 home 0.410000 0.400000 0.430000 -0.020000 -0.030000 0.010000 false false false
}
emit_arm 01 event p01-t050 50 true >> "$TMP/scores.tsv"
emit_arm 01 ecology p11-t050 50 false >> "$TMP/scores.tsv"
emit_arm 02 event h01-t060 60 false >> "$TMP/scores.tsv"
emit_arm 02 ecology h11-t060 60 true >> "$TMP/scores.tsv"

awk -v expected=2 -f "$ROOT/scripts/state_swarm_liminal_trace_report.awk" \
    "$TMP/locks.tsv" "$TMP/scores.tsv" > "$TMP/summary.tsv"
awk -v expected=2 -f "$ROOT/scripts/state_swarm_liminal_trace_verdict.awk" \
    "$TMP/summary.tsv" > "$TMP/verdict.txt"
awk -F '\t' '
    NR == 1 { if (NF != 21 || $10 != "event_confirmation" || $17 != "ecology_confirmation") exit 1; next }
    $1 == "01" { if ($10 != "true" || $17 != "false") exit 1; first++ }
    $1 == "02" { if ($10 != "false" || $17 != "true") exit 1; second++ }
    END { if (NR != 3 || first != 1 || second != 1) exit 1 }
' "$TMP/summary.tsv"
grep -q '^event_confirmation 1$' "$TMP/verdict.txt"
grep -q '^ecology_confirmation 1$' "$TMP/verdict.txt"
grep -q '^event_only_confirmation 1$' "$TMP/verdict.txt"
grep -q '^ecology_only_confirmation 1$' "$TMP/verdict.txt"
grep -q '^result directional-trace-underpowered$' "$TMP/verdict.txt"

sed '$d' "$TMP/scores.tsv" > "$TMP/truncated.tsv"
if awk -v expected=2 -f "$ROOT/scripts/state_swarm_liminal_trace_report.awk" \
    "$TMP/locks.tsv" "$TMP/truncated.tsv" >/dev/null 2>&1; then
    printf 'liminal trace reporter accepted a truncated score tail\n' >&2
    exit 1
fi

awk -F '\t' 'BEGIN { OFS=FS } NR == 2 { $14 = "0.070000" } { print }' \
    "$TMP/scores.tsv" > "$TMP/false-margin.tsv"
if awk -v expected=2 -f "$ROOT/scripts/state_swarm_liminal_trace_report.awk" \
    "$TMP/locks.tsv" "$TMP/false-margin.tsv" >/dev/null 2>&1; then
    printf 'liminal trace reporter accepted a false order margin\n' >&2
    exit 1
fi

printf 'state-swarm liminal trace reporters: ok\n'
