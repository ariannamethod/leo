#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-liminal-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

HASH='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
ORGANS='0.1/0.2/0.3/0.4/0.5/0.6/0.7'

printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turns\tpre_sha\tpost_sha\tfinal_sha\treproduced_sha\treply_equal\tstate_equal\n' > "$TMP/locks.tsv"
lock() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t2\t%s\t%s\t%s\t%s\ttrue\ttrue\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" \
        "$HASH" "$HASH" "$HASH" "$HASH"
}
lock 01 event p01-t050 p01 primary 50 >> "$TMP/locks.tsv"
lock 01 ecology p11-t050 p11 primary 50 >> "$TMP/locks.tsv"
lock 02 event h01-t060 h01 holdout 60 >> "$TMP/locks.tsv"
lock 02 ecology h11-t060 h11 holdout 60 >> "$TMP/locks.tsv"

printf 'pair\tarm\tanchor\tanchor_turn\tfuture_turn\trelative\ttexture\tcandidate_similarity\tstable_similarity\tmargin\tstable_nearest_id\tcandidate_nearest\tsupport\tconfirmation\tcandidate_organs\tstable_organs\tprompt\treply\n' > "$TMP/observations.tsv"
observation() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\thome\t%s\t%s\t%s\t1\t%s\t%s\t%s\t%s\t%s\tprompt %s\treply %s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" \
        "${10}" "${11}" "${12}" "$ORGANS" "$ORGANS" "$1" "$2"
}
observation 01 event p01-t050 50 51 1 0.500000 0.400000 0.100000 true true false >> "$TMP/observations.tsv"
observation 01 event p01-t050 50 52 2 0.560000 0.460000 0.100000 true true true >> "$TMP/observations.tsv"
observation 01 ecology p11-t050 50 51 1 0.380000 0.400000 -0.020000 false false false >> "$TMP/observations.tsv"
observation 01 ecology p11-t050 50 52 2 0.370000 0.420000 -0.050000 false false false >> "$TMP/observations.tsv"
observation 02 event h01-t060 60 61 1 0.430000 0.400000 0.030000 true true false >> "$TMP/observations.tsv"
observation 02 event h01-t060 60 62 2 0.380000 0.400000 -0.020000 false false false >> "$TMP/observations.tsv"
observation 02 ecology h11-t060 60 61 1 0.400000 0.450000 -0.050000 false false false >> "$TMP/observations.tsv"
observation 02 ecology h11-t060 60 62 2 0.560000 0.460000 0.100000 true true true >> "$TMP/observations.tsv"

awk -v expected=2 \
    -f "$ROOT/scripts/state_swarm_liminal_confirmation_report.awk" \
    "$TMP/locks.tsv" "$TMP/observations.tsv" > "$TMP/summary.tsv"
awk -v expected=2 \
    -f "$ROOT/scripts/state_swarm_liminal_confirmation_verdict.awk" \
    "$TMP/summary.tsv" > "$TMP/verdict.txt"

awk -F '\t' '
    NR == 1 { if (NF != 20 || $1 != "pair" || $20 != "paired_max_margin_delta") exit 1; next }
    $1 == "01" {
        if ($8 != "true" || $9 != "true" || $10 != 1 || $11 != 2 ||
            $13 != "0.100000" || $14 != "false" || $15 != "false" ||
            $19 != "-0.020000" || $20 != "0.120000") exit 1
        first++
    }
    $1 == "02" {
        if ($8 != "true" || $9 != "false" || $10 != 1 || $11 != "na" ||
            $13 != "0.030000" || $14 != "true" || $15 != "true" ||
            $17 != 2 || $19 != "0.100000" || $20 != "-0.070000") exit 1
        second++
    }
    END { if (NR != 3 || first != 1 || second != 1) exit 1 }
' "$TMP/summary.tsv"
grep -q '^eligible_pairs 2$' "$TMP/verdict.txt"
grep -q '^event_support 2$' "$TMP/verdict.txt"
grep -q '^ecology_support 1$' "$TMP/verdict.txt"
grep -q '^event_only_confirmation 1$' "$TMP/verdict.txt"
grep -q '^ecology_only_confirmation 1$' "$TMP/verdict.txt"
grep -q '^mean_paired_max_margin_delta 0.025000$' "$TMP/verdict.txt"
grep -q '^result temporal-confirmation-underpowered$' "$TMP/verdict.txt"

sed '$d' "$TMP/observations.tsv" > "$TMP/truncated.tsv"
if awk -v expected=2 \
    -f "$ROOT/scripts/state_swarm_liminal_confirmation_report.awk" \
    "$TMP/locks.tsv" "$TMP/truncated.tsv" >/dev/null 2>&1; then
    printf 'liminal reporter accepted a truncated trajectory\n' >&2
    exit 1
fi

sed '2s/true$/false/' "$TMP/locks.tsv" > "$TMP/unlocked.tsv"
if awk -v expected=2 \
    -f "$ROOT/scripts/state_swarm_liminal_confirmation_report.awk" \
    "$TMP/unlocked.tsv" "$TMP/observations.tsv" >/dev/null 2>&1; then
    printf 'liminal reporter accepted a false trajectory lock\n' >&2
    exit 1
fi

printf 'state-swarm liminal confirmation reporters: ok\n'
