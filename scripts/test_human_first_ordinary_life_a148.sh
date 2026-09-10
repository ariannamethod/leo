#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-human-first-ordinary-life-a148-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/human_first_ordinary_life_a148_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.148") exit 2; phase++ }
    $1 == "source_merge" {
        if ($2 != "e4a300c7b2b2410f5b9cd43066d7e48ee92bd764") exit 2
        merge++
    }
    $1 == "fork" { if ($2 !~ /^none/) exit 2; fork++ }
    $1 == "base_seed" { if ($2 != 615) exit 2; seed++ }
    $1 == "human_turns" { if ($2 != 1) exit 2; human++ }
    $1 == "planned_api_turns" { if ($2 != 23) exit 2; api++ }
    $1 == "api_start_turn" { if ($2 != 2) exit 2; start++ }
    $1 == "api_store" { if ($2 != "false") exit 2; store++ }
    $1 == "target_word" { if ($2 != "absent") exit 2; target++ }
    $1 == "desired_wonder" { if ($2 != "absent") exit 2; wonder++ }
    $1 == "answer_instruction" { if ($2 != "absent") exit 2; answer++ }
    $1 == "desired_personality" { if ($2 != "absent") exit 2; personality++ }
    $1 == "opening_cue_to_api" { if ($2 !~ /^absent/) exit 2; opening++ }
    $1 == "runtime_change" {
        if ($2 !~ /^forbidden before observation/) exit 2
        runtime++
    }
    END {
        if (NR != 36 || phase != 1 || merge != 1 || fork != 1 ||
            seed != 1 || human != 1 || api != 1 || start != 1 ||
            store != 1 || target != 1 || wonder != 1 || answer != 1 ||
            personality != 1 || opening != 1 || runtime != 1) exit 2
    }
' "$plan"

human="$ROOT/scripts/fixtures/human_first_ordinary_life_a148_turn1.txt"
[ "$(wc -l < "$human" | tr -d ' ')" -eq 1 ]
[ "$(sed -n '1p' "$human")" = 'i hope you are alive and happy :D' ]
case "$(sed -n '1p' "$human")" in *$'\t'*|*$'\r'*) exit 2;; esac

prompts="$ROOT/scripts/fixtures/human_first_ordinary_life_a148_ordinary.txt"
[ "$(wc -l < "$prompts" | tr -d ' ')" -eq 24 ]
cmp -s "$human" <(sed -n '1p' "$prompts")

api_turns="$ROOT/scripts/human_first_ordinary_life_a148_api_turns.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 5 || $1 != "turn" || $2 != "utterance" ||
            $3 != "stance" || $4 != "reply_reference" || $5 != "model") exit 2
        next
    }
    NF != 5 || $1 != NR || $1 < 2 || $1 > 24 || $2 == "" ||
        $3 !~ /^(open|follow|clarify|answer|comfort|challenge|shift|close)$/ ||
        $4 !~ /^(true|false)$/ || $5 != "gpt-5.6-luna" { exit 2 }
    { rows++; stance[$3]++; if ($4 == "true") references++ }
    END {
        if (rows != 23 || references != 22 || stance["open"] != 1 ||
            stance["follow"] != 14 || stance["clarify"] != 4 ||
            stance["answer"] != 0 || stance["comfort"] != 4 ||
            stance["challenge"] != 0 || stance["shift"] != 0 ||
            stance["close"] != 0) exit 2
    }
' "$api_turns"

frozen="$ROOT/scripts/human_first_ordinary_life_a148_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 56 || $1 != "phase" || $5 != "plan_sha256" ||
            $56 != "turn1_reply") exit 2
        next
    }
    NF != 56 || $1 != "A.148" || $2 != 615 ||
        $5 !~ /^[0-9a-f]{64}$/ || $6 !~ /^[0-9a-f]{64}$/ ||
        $7 !~ /^[0-9a-f]{64}$/ || $8 !~ /^[0-9a-f]{64}$/ ||
        $9 !~ /^[0-9a-f]{64}$/ || $10 != 1 || $11 != 23 ||
        $12 != 23 || $13 != 23 || $14 != "gpt-5.6-luna" ||
        $15 !~ /^[0-9a-f]{64}$/ || $16 !~ /^[0-9a-f]{64}$/ ||
        $17 !~ /^[0-9a-f]{64}$/ || $18 !~ /^[0-9a-f]{64}$/ ||
        $19 !~ /^[0-9a-f]{64}$/ || $20 != 16 || $21 != 22 ||
        $22 != 1 || $23 != 14 || $24 != 4 || $25 != 0 ||
        $26 != 4 || $27 != 0 || $28 != 0 || $29 != 0 ||
        $30 != 12 || $31 != 2 || $32 != "mysterious@13" ||
        $33 != 13 || $34 != "Mysterious?" || $35 != "mysterious" ||
        $36 != 1 || $37 != 0 || $38 != 1 || $39 != "smooth" ||
        $40 != 1 || $41 != 0 || $42 != 0 || $43 != 11 ||
        $44 != 2 || $45 != 0 || $46 != 1 || $47 != 1 ||
        $48 != 23 || $49 != 23 || $50 != "true" || $51 != "true" ||
        $52 != "false" || $53 != 8 || $54 != 16 || $55 != 0 ||
        $56 !~ /He wakes up new[.]$/ { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

"$ROOT/scripts/human_first_ordinary_life_a148_replay.sh" \
    "$TMP/replay" > "$TMP/replay.out"
cmp -s "$ROOT/scripts/human_first_ordinary_life_a148_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"
cmp -s "$ROOT/scripts/human_first_ordinary_life_a148_anatomy.tsv" \
    "$TMP/replay/anatomy.async.tsv"
grep -q $'^human_opening_exact\ttrue$' "$TMP/replay.out"
grep -q $'^api_first_turn\t2$' "$TMP/replay.out"
grep -q $'^school_questions\tmysterious@13$' "$TMP/replay.out"
grep -q $'^visible_question_turns\t2$' "$TMP/replay.out"
grep -q $'^final_pending\tmysterious$' "$TMP/replay.out"
grep -q $'^final_deferred\tsmooth$' "$TMP/replay.out"
grep -q $'^result\thuman-opening-removes-synthetic-room-but-api-care-still-shapes-the-life$' \
    "$TMP/replay.out"
printf 'human-first ordinary life A.148 contracts: ok\n'
