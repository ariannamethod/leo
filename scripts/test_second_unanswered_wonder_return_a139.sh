#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-second-unanswered-return-a139-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/second_unanswered_wonder_return_a139_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.139") exit 2; phase++ }
    $1 == "expected_second_return" { if ($2 != "Difficult?") exit 2; expected++ }
    $1 == "expected_return_count" { if ($2 != 2) exit 2; count++ }
    $1 == "natural_cases" { if ($2 != 4) exit 2; natural++ }
    $1 == "synthetic_cases" { if ($2 != 3) exit 2; synthetic++ }
    $1 == "api_turns" { if ($2 != 0) exit 2; api++ }
    $1 == "state_format_change" { if ($2 != "forbidden") exit 2; state++ }
    END {
        if (phase != 1 || expected != 1 || count != 1 ||
            natural != 1 || synthetic != 1 || api != 1 || state != 1)
            exit 2
    }
' "$plan"

frozen="$ROOT/scripts/second_unanswered_wonder_return_a139_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 14 || $1 != "phase" || $2 != "plan_sha256" ||
            $4 != "source_state_sha256" || $14 != "pending") exit 2
        next
    }
    NF != 14 || $1 != "A.139" ||
        $2 !~ /^[0-9a-f]{64}$/ || $4 !~ /^[0-9a-f]{64}$/ ||
        $5 !~ /^[0-9a-f]{64}$/ || $6 !~ /^[0-9a-f]{64}$/ ||
        $7 != 4 || $8 != 3 || $9 != "Difficult?" || $10 != 2 ||
        $11 != "true" || $12 != "none" || $13 != "none" ||
        $14 != "difficult" { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

plan_sha="$(awk -F '\t' 'NR == 2 { print $2 }' "$frozen")"
source_fixture="$(awk -F '\t' 'NR == 2 { print $3 }' "$frozen")"
source_state_sha="$(awk -F '\t' 'NR == 2 { print $4 }' "$frozen")"
natural_sha="$(awk -F '\t' 'NR == 2 { print $5 }' "$frozen")"
synthetic_sha="$(awk -F '\t' 'NR == 2 { print $6 }' "$frozen")"
[ "$(shasum -a 256 "$plan" | awk '{print $1}')" = "$plan_sha" ]
[ "$(awk -F '\t' 'NR == 2 { print $3 }' "$ROOT/scripts/responsive_difficult_after_repair_a138_frozen.tsv")" = "$source_fixture" ]
[ "$(awk -F '\t' 'NR == 2 { print $10 }' "$ROOT/scripts/responsive_difficult_after_repair_a138_frozen.tsv")" = "$source_state_sha" ]
[ "$(shasum -a 256 "$ROOT/scripts/second_unanswered_wonder_return_a139_natural.tsv" | awk '{print $1}')" = "$natural_sha" ]
[ "$(shasum -a 256 "$ROOT/scripts/second_unanswered_wonder_return_a139_synthetic.tsv" | awk '{print $1}')" = "$synthetic_sha" ]

"$ROOT/scripts/second_unanswered_wonder_return_a139_anatomy.sh" \
    "$TMP/anatomy" > "$TMP/anatomy.out"
cmp -s "$ROOT/scripts/second_unanswered_wonder_return_a139_natural.tsv" \
    "$TMP/anatomy/natural.tsv"
cmp -s "$ROOT/scripts/second_unanswered_wonder_return_a139_synthetic.tsv" \
    "$TMP/anatomy/synthetic.tsv"

awk -F '\t' '
    NR == 1 { if (NF != 13 || $1 != "kind" || $13 != "reply") exit 2; next }
    NF != 13 { exit 2 }
    $1 == "turn35" && $4 == 10 && $5 == "none" && $7 == 0 &&
        $8 == 1 && $9 == "difficult" { body++ }
    ($1 == "second-return" || $1 == "sleep-second-return") &&
        $5 == "none" && $6 == "none" && $7 == 0 && $8 == 2 &&
        $9 == "difficult" && $10 == "none" && $11 == "none" &&
        $12 == 1 && $13 == "Difficult?" { second++ }
    $1 == "immediate-third" && $7 == 0 && $8 == 2 &&
        $9 == "difficult" && $12 == 0 && $13 != "Difficult?" { cooldown++ }
    END { if (body != 1 || second != 2 || cooldown != 1) exit 2 }
' "$TMP/anatomy/natural.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 13 { exit 2 }
    ($1 == "synthetic-second" || $1 == "synthetic-sleep-second") &&
        $7 == 0 && $8 == 2 && $9 == "zorble" &&
        $10 == "none" && $11 == "none" && $12 == 1 &&
        $13 == "Zorble?" { second++ }
    $1 == "synthetic-immediate-third" && $7 == 0 && $8 == 2 &&
        $9 == "zorble" && $12 == 0 && $13 != "Zorble?" { cooldown++ }
    END { if (second != 2 || cooldown != 1) exit 2 }
' "$TMP/anatomy/synthetic.tsv"

grep -q $'^result\tsecond-unanswered-Wonder-return-observed$' \
    "$TMP/anatomy.out"
printf 'second unanswered Wonder return A.139 contracts: ok\n'
