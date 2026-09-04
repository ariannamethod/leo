#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-second-fresh-ordinary-life-a144-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/second_fresh_ordinary_life_a144_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.144") exit 2; phase++ }
    $1 == "source_body" { if ($2 !~ /merged A.143.*empty conversational body/) exit 2; source++ }
    $1 == "fork" { if ($2 !~ /^none/) exit 2; fork++ }
    $1 == "base_seed" { if ($2 != 542) exit 2; seed++ }
    $1 == "turns" { if ($2 != 24) exit 2; turns++ }
    $1 == "planned_api_turns" { if ($2 != 24) exit 2; api++ }
    $1 == "target_word" { if ($2 != "absent") exit 2; target++ }
    $1 == "desired_wonder" { if ($2 != "absent") exit 2; wonder++ }
    $1 == "answer_instruction" { if ($2 != "absent") exit 2; answer++ }
    $1 == "runtime_change" { if ($2 != "forbidden before observation") exit 2; runtime++ }
    END {
        if (phase != 1 || source != 1 || fork != 1 || seed != 1 ||
            turns != 1 || api != 1 || target != 1 || wonder != 1 ||
            answer != 1 || runtime != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/second_fresh_ordinary_life_a144_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 41 || $1 != "life" || $4 != "plan_sha256" ||
            $41 != "yeah_resolved") exit 2
        next
    }
    NF != 41 || $1 != "ordinary" || $2 != 542 ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 != 24 || $8 != 24 || $9 != 24 ||
        $10 != "gpt-5.6-luna" || $11 !~ /^[0-9a-f]{64}$/ ||
        $12 !~ /^[0-9a-f]{64}$/ || $13 !~ /^[0-9a-f]{64}$/ ||
        $14 !~ /^[0-9a-f]{64}$/ || $15 !~ /^[0-9a-f]{64}$/ ||
        $16 != 14 || $17 != 22 || $18 != 1 || $19 != 18 ||
        $20 != 1 || $21 != 4 || $22 != 21 ||
        $23 != "finished@4,yeah@6" || $24 != 4 || $25 != "Finished?" ||
        $26 != 5 || $28 != "answer" || $29 != 6 || $30 != "Yeah?" ||
        $31 != "yeah" || $32 != "none" || $33 != "none" ||
        $34 != 18 || $35 != 2 || $36 != 1 || $37 != "none" ||
        $38 != 0 || $39 != 4 || $40 != "none" || $41 != 0 { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

"$ROOT/scripts/second_fresh_ordinary_life_a144_replay.sh" \
    "$TMP/replay" > "$TMP/replay.out"
cmp -s "$ROOT/scripts/second_fresh_ordinary_life_a144_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"
grep -q $'^result\tsecond-fresh-ordinary-life-exposes-discourse-wonder$' \
    "$TMP/replay.out"
printf 'second fresh ordinary life A.144 contracts: ok\n'
