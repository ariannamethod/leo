#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-delayed-answer-second-return-a140-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/delayed_answer_after_second_return_a140_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.140") exit 2; phase++ }
    $1 == "unknown" { if ($2 != "zorble synthetic only") exit 2; unknown++ }
    $1 == "natural_difficult_mutation" { if ($2 != "forbidden") exit 2; natural++ }
    $1 == "expected_second_return" { if ($2 != "Zorble?") exit 2; second++ }
    $1 == "expected_meaning" { if ($2 != "animal") exit 2; meaning++ }
    $1 == "synthetic_cases" { if ($2 != 7) exit 2; cases++ }
    $1 == "api_turns" { if ($2 != 0) exit 2; api++ }
    $1 == "state_format_change" { if ($2 != "forbidden") exit 2; state++ }
    END {
        if (phase != 1 || unknown != 1 || natural != 1 ||
            second != 1 || meaning != 1 || cases != 1 ||
            api != 1 || state != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/delayed_answer_after_second_return_a140_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 16 || $1 != "phase" || $2 != "plan_sha256" ||
            $3 != "expected_sha256" || $16 != "natural_difficult_mutation")
            exit 2
        next
    }
    NF != 16 || $1 != "A.140" ||
        $2 !~ /^[0-9a-f]{64}$/ || $3 !~ /^[0-9a-f]{64}$/ ||
        $4 != 7 || $5 != "Zorble?" || $6 != 2 ||
        $7 != "animal" || $8 != "animal" || $9 != 1 || $10 != "none" ||
        $11 != "true" || $12 != "true" || $13 != "true" ||
        $14 != "true" || $15 != "true" || $16 != "none" { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

plan_sha="$(awk -F '\t' 'NR == 2 { print $2 }' "$frozen")"
expected_sha="$(awk -F '\t' 'NR == 2 { print $3 }' "$frozen")"
[ "$(shasum -a 256 "$plan" | awk '{print $1}')" = "$plan_sha" ]
[ "$(shasum -a 256 "$ROOT/scripts/delayed_answer_after_second_return_a140_expected.tsv" | awk '{print $1}')" = "$expected_sha" ]

"$ROOT/scripts/delayed_answer_after_second_return_a140_anatomy.sh" \
    "$TMP/anatomy" > "$TMP/anatomy.out"
cmp -s "$ROOT/scripts/delayed_answer_after_second_return_a140_expected.tsv" \
    "$TMP/anatomy/anatomy.tsv"

awk -F '\t' '
    NR == 1 { if (NF != 13 || $1 != "kind" || $13 != "reply") exit 2; next }
    NF != 13 { exit 2 }
    $1 == "after-second-return" && $5 == "none" && $6 == "none" &&
        $7 == 0 && $8 == 2 && $9 == "zorble" && $12 == 1 &&
        $13 == "Zorble?" { second++ }
    ($1 == "late-explicit-answer" || $1 == "sleep-before-answer" ||
     $1 == "sleep-after-answer" || $1 == "following-question") &&
        $5 == "animal" && $6 == "animal" && $7 == 1 && $8 == 2 &&
        $9 == "none" && $10 == "none" && $11 == "none" { closed++ }
    ($1 == "question-shaped" || $1 == "reference-only") &&
        $5 == "none" && $6 == "none" && $7 == 0 && $8 == 2 &&
        $9 == "zorble" { refused++ }
    END { if (second != 1 || closed != 4 || refused != 2) exit 2 }
' "$TMP/anatomy/anatomy.tsv"

grep -q $'^result\tdelayed-answer-after-second-return-observed$' \
    "$TMP/anatomy.out"
printf 'delayed answer after second return A.140 contracts: ok\n'
