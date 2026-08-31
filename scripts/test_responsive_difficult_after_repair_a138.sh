#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-responsive-difficult-after-repair-a138-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/responsive_difficult_after_repair_a138_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.138") exit 2; phase++ }
    $1 == "prefix_turns" { if ($2 != 25) exit 2; prefix++ }
    $1 == "continuation_turns" { if ($2 != 10) exit 2; continuation++ }
    $1 == "planned_api_turns" { if ($2 != 10) exit 2; api++ }
    $1 == "api_store" { if ($2 != "false") exit 2; store++ }
    $1 == "prior_a136_continuation_visible" { if ($2 != "false") exit 2; prior++ }
    $1 == "answer_instruction" { if ($2 != "absent") exit 2; answer++ }
    $1 == "runtime_change" { if ($2 != "forbidden before observation") exit 2; runtime++ }
    END {
        if (phase != 1 || prefix != 1 || continuation != 1 ||
            api != 1 || store != 1 || prior != 1 || answer != 1 ||
            runtime != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/responsive_difficult_after_repair_a138_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 25 || $1 != "life" || $4 != "plan_sha256" ||
            $5 != "api_turns_sha256" || $8 != "prompts_sha256" ||
            $25 != "pending") exit 2
        next
    }
    NF != 25 || $1 != "meal" || $2 != 617 || $6 != 25 || $7 != 10 ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^[0-9a-f]{64}$/ ||
        $10 !~ /^[0-9a-f]{64}$/ || $11 !~ /^[0-9a-f]{64}$/ ||
        $12 !~ /^[0-9a-f]{64}$/ || $13 != 19 || $14 != 10 ||
        $15 != 0 || $16 != 22 ||
        $17 != "lentil@2,difficult@15,difficult@25" ||
        $18 != "clarify" || $19 != "true" || $20 != 4 ||
        $21 != "none" || $22 != "none" || $23 != 0 ||
        $24 != 1 || $25 != "difficult" { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

fixture="$(awk -F '\t' 'NR == 2 { print $3 }' "$frozen")"
plan_sha="$(awk -F '\t' 'NR == 2 { print $4 }' "$frozen")"
api_turns_sha="$(awk -F '\t' 'NR == 2 { print $5 }' "$frozen")"
prompts_sha="$(awk -F '\t' 'NR == 2 { print $8 }' "$frozen")"
[ "$(shasum -a 256 "$ROOT/$fixture" | awk '{print $1}')" = "$prompts_sha" ]
[ "$(shasum -a 256 "$plan" | awk '{print $1}')" = "$plan_sha" ]
[ "$(shasum -a 256 "$ROOT/scripts/responsive_difficult_after_repair_a138_api_turns.tsv" | awk '{print $1}')" = "$api_turns_sha" ]

awk -F '\t' '
    NR == 1 {
        if (NF != 5 || $1 != "turn" || $5 != "model") exit 2
        next
    }
    NF != 5 || $1 != NR + 24 ||
        ($3 != "clarify" && $3 != "follow" && $3 != "comfort") ||
        $4 != "true" || $5 != "gpt-5.6-luna" { exit 2 }
    { rows++; answers += ($3 == "answer") }
    END { if (rows != 10 || answers != 0) exit 2 }
' "$ROOT/scripts/responsive_difficult_after_repair_a138_api_turns.tsv"

"$ROOT/scripts/responsive_difficult_after_repair_a138_replay.sh" \
    "$TMP/replay" > "$TMP/replay.out"
grep -q $'^sync_replay_exact\ttrue$' "$TMP/replay.out"
grep -q $'^async_reproducible\ttrue$' "$TMP/replay.out"
grep -q $'^api_answer_stances\t0$' "$TMP/replay.out"
grep -q $'^difficult_resolution_turn\tnone$' "$TMP/replay.out"
grep -q $'^open_wonder_turns\t22$' "$TMP/replay.out"
cmp -s "$ROOT/scripts/responsive_difficult_after_repair_a138_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"

grep -q $'^actual-turn26\t.*\t4\tnone\tnone\t0\t1\tdifficult\tnone\tnone$' \
    "$TMP/replay/anatomy.tsv"
grep -q $'^positive-control\tDifficult is pain\.\t4\tpain\tpain\t1\t1\tnone\tnone\tnone$' \
    "$TMP/replay/anatomy.tsv"
grep -q $'^turn35\tnone\t4\tnone\tnone\t0\t1\tdifficult\tnone\tnone$' \
    "$TMP/replay/anatomy.tsv"

printf 'responsive difficult after repair A.138 contracts: ok\n'
