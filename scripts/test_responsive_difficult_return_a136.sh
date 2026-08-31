#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-responsive-difficult-return-a136-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/responsive_difficult_return_a136_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.136") exit 2; phase++ }
    $1 == "prefix_turns" { if ($2 != 25) exit 2; prefix++ }
    $1 == "continuation_turns" { if ($2 != 10) exit 2; continuation++ }
    $1 == "planned_api_turns" { if ($2 != 10) exit 2; api++ }
    $1 == "api_store" { if ($2 != "false") exit 2; store++ }
    $1 == "answer_instruction" { if ($2 != "absent") exit 2; answer++ }
    END {
        if (phase != 1 || prefix != 1 || continuation != 1 ||
            api != 1 || store != 1 || answer != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/responsive_difficult_return_a136_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 17 || $1 != "life" || $3 != "fixture" ||
            $4 != "api_turns_sha256" || $7 != "prompts_sha256" ||
            $17 != "first_api_reply_reference") exit 2
        next
    }
    NF != 17 || $1 != "meal" || $2 != 617 || $5 != 25 || $6 != 10 ||
        $4 !~ /^[0-9a-f]{64}$/ || $7 !~ /^[0-9a-f]{64}$/ ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^[0-9a-f]{64}$/ ||
        $10 !~ /^[0-9a-f]{64}$/ || $11 !~ /^[0-9a-f]{64}$/ ||
        $12 != 18 || $13 != 9 || $14 != 12 ||
        $15 != "lentil@2,difficult@15,difficult@25" ||
        $16 != "clarify" || $17 != "true" { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

fixture="$(awk -F '\t' 'NR == 2 { print $3 }' "$frozen")"
api_turns_sha="$(awk -F '\t' 'NR == 2 { print $4 }' "$frozen")"
prompts_sha="$(awk -F '\t' 'NR == 2 { print $7 }' "$frozen")"
[ "$(shasum -a 256 "$ROOT/$fixture" | awk '{print $1}')" = "$prompts_sha" ]
[ "$(shasum -a 256 "$ROOT/scripts/responsive_difficult_return_a136_api_turns.tsv" | awk '{print $1}')" = "$api_turns_sha" ]

awk -F '\t' '
    NR == 1 {
        if (NF != 5 || $1 != "turn" || $5 != "model") exit 2
        next
    }
    NF != 5 || $1 != NR + 24 ||
        ($3 != "clarify" && $3 != "follow") ||
        ($4 != "true" && $4 != "false") ||
        $5 != "gpt-5.6-luna" { exit 2 }
    { rows++; references += ($4 == "true") }
    END { if (rows != 10 || references != 9) exit 2 }
' "$ROOT/scripts/responsive_difficult_return_a136_api_turns.tsv"

"$ROOT/scripts/responsive_difficult_return_a136_replay.sh" \
    "$TMP/replay" > "$TMP/replay.out"
grep -q $'^sync_replay_exact\ttrue$' "$TMP/replay.out"
grep -q $'^async_reproducible\ttrue$' "$TMP/replay.out"
grep -q $'^difficult_return_turn\t25$' "$TMP/replay.out"
grep -q $'^difficult_false_resolution_turn\t26$' "$TMP/replay.out"
grep -q $'^first_api_stance\tclarify$' "$TMP/replay.out"
cmp -s "$ROOT/scripts/responsive_difficult_return_a136_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"

grep -q $'^actual-turn26\t.*\t5\tman\tnone\tman\t1\t1\tnone$' \
    "$TMP/replay/anatomy.tsv"
grep -q $'^no-answer-followup\t.*\t5\tnone\tnone\tnone\t0\t1\tdifficult$' \
    "$TMP/replay/anatomy.tsv"
grep -q $'^she-after\t.*\t4\twoman\tnone\twoman\t1\t1\tnone$' \
    "$TMP/replay/anatomy.tsv"
grep -q $'^child-after\t.*\t4\tchild\tnone\tchild\t1\t1\tnone$' \
    "$TMP/replay/anatomy.tsv"

printf 'responsive difficult return A.136 contracts: ok\n'
