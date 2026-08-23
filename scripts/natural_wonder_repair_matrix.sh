#!/usr/bin/env bash
# A.119: paired historical-control and repaired-boundary natural replays.
set -Eeuo pipefail

trap 'rc=$?; printf "natural Wonder repair matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-natural-wonder-repair-$STAMP}"
CONTROL="$OUT/control"
CANDIDATE="$OUT/candidate"
VERDICT="$OUT/verdict.tsv"

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT"

LEO_NATURAL_WORD_BOUNDARY=0 LEO_NATURAL_EXPECT_A118=1 \
    "$ROOT/scripts/natural_wonder_repair_anatomy.sh" "$CONTROL" \
    > "$OUT/control.out"
LEO_NATURAL_WORD_BOUNDARY=1 \
    "$ROOT/scripts/natural_wonder_repair_anatomy.sh" "$CANDIDATE" \
    > "$OUT/candidate.out"

cmp -s "$CONTROL/anatomy.tsv" "$CANDIDATE/anatomy.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 9 || $1 != "life" || $8 != "a118_transcript_exact" ||
            $9 != "a118_state_exact") exit 2
        next
    }
    NF != 9 || $8 != "true" || $9 != "true" { exit 2 }
    { rows++ }
    END { if (rows != 3) exit 2 }
' "$CONTROL/natural.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 9 { exit 2 }
    $1 == "home" || $1 == "weather" {
        if ($8 != "true" || $9 != "true") exit 2
        unchanged++
    }
    $1 == "memory" {
        if ($6 != 12 || $7 != "outdoors@11,belonged@17,belonged@19" ||
            $8 != "false" || $9 != "false" || $7 ~ /(^|,)don@/) exit 2
        repaired++
    }
    END { if (unchanged != 2 || repaired != 1) exit 2 }
' "$CANDIDATE/natural.tsv"

{
    printf 'metric\tcontrol\tcandidate\n'
    printf 'a118_exact_lives\t3\t2\n'
    printf 'memory_open_wonder_turns\t18\t12\n'
    printf 'memory_curly_shard_questions\t3\t0\n'
    printf 'memory_remaining_questions\tdon,belonged\toutdoors,belonged\n'
    printf 'result\thistorical-boundary-reproduced\tcurly-apostrophe-boundary-repaired\n'
} > "$VERDICT"

cat "$VERDICT"
printf 'A.119 natural Wonder repair matrix: %s\n' "$OUT"
