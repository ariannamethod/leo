#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-third-fresh-ordinary-life-a147-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/third_fresh_ordinary_life_a147_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.147") exit 2; phase++ }
    $1 == "source_merge" { if ($2 != "29674d2a4e8c8b3e1b66c213f18335a1a6aec65e") exit 2; merge++ }
    $1 == "fork" { if ($2 !~ /^none/) exit 2; fork++ }
    $1 == "base_seed" { if ($2 != 618) exit 2; seed++ }
    $1 == "planned_api_turns" { if ($2 != 24) exit 2; api++ }
    $1 == "api_store" { if ($2 != "false") exit 2; store++ }
    $1 == "target_word" { if ($2 != "absent") exit 2; target++ }
    $1 == "desired_wonder" { if ($2 != "absent") exit 2; wonder++ }
    $1 == "answer_instruction" { if ($2 != "absent") exit 2; answer++ }
    $1 == "kettle_as_experimental_demand" { if ($2 != "absent") exit 2; kettle++ }
    $1 == "prior_voice_example" { if ($2 != "absent") exit 2; voice++ }
    $1 == "runtime_change" { if ($2 != "forbidden before observation") exit 2; runtime++ }
    END {
        if (phase != 1 || merge != 1 || fork != 1 || seed != 1 ||
            api != 1 || store != 1 || target != 1 || wonder != 1 ||
            answer != 1 || kettle != 1 || voice != 1 || runtime != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/third_fresh_ordinary_life_a147_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 49 || $1 != "phase" || $4 != "plan_sha256" ||
            $49 != "opening_hidden_prior_terms") exit 2
        next
    }
    NF != 49 || $1 != "A.147" || $2 != 618 ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 !~ /^[0-9a-f]{64}$/ ||
        $8 != 24 || $9 != 24 || $10 != 24 ||
        $11 != "gpt-5.6-luna" ||
        $12 !~ /^[0-9a-f]{64}$/ || $13 !~ /^[0-9a-f]{64}$/ ||
        $14 !~ /^[0-9a-f]{64}$/ || $15 !~ /^[0-9a-f]{64}$/ ||
        $16 !~ /^[0-9a-f]{64}$/ || $17 != 12 || $18 != 21 ||
        $19 != 1 || $20 != 12 || $21 != 7 || $22 != 1 || $23 != 3 ||
        $24 != 12 || $25 != "finished@1,shelter@10,shelter@12" ||
        $26 != 1 || $27 != "Finished?" || $28 != 10 ||
        $29 != "Shelter? Man or Small?" || $30 != 12 ||
        $31 != "Shelter? Man or Small?" || $32 != 13 ||
        $33 !~ /^Small—/ || $34 != "none" || $35 != 2 || $36 != 1 ||
        $37 != 1 || $38 != "finished" || $39 != 1 || $40 != 0 ||
        $41 != 3 || $42 != "small" || $43 != "none" || $44 != 1 ||
        $45 != 0 || $46 != "true" || $47 != 3 || $48 != 3 || $49 != 0 {
            exit 2
        }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

"$ROOT/scripts/third_fresh_ordinary_life_a147_replay.sh" \
    "$TMP/replay" > "$TMP/replay.out"
cmp -s "$ROOT/scripts/third_fresh_ordinary_life_a147_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"
cmp -s "$ROOT/scripts/third_fresh_ordinary_life_a147_anatomy.tsv" \
    "$TMP/replay/anatomy.async.tsv"
grep -q $'^school_questions\tfinished@1,shelter@10,shelter@12$' \
    "$TMP/replay.out"
grep -q $'^final_pending\tnone$' "$TMP/replay.out"
grep -q $'^final_deferred\tfinished$' "$TMP/replay.out"
grep -q $'^generic_openings_with_kettle\t3/3$' "$TMP/replay.out"
grep -q $'^result\tthird-fresh-life-learns-shelter-and-exposes-interlocutor-opening-collapse$' \
    "$TMP/replay.out"
printf 'third fresh ordinary life A.147 contracts: ok\n'
