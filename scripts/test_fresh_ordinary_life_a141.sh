#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-fresh-ordinary-life-a141-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/fresh_ordinary_life_a141_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.141") exit 2; phase++ }
    $1 == "source_body" { if ($2 !~ /empty body/) exit 2; source++ }
    $1 == "base_seed" { if ($2 != 853) exit 2; seed++ }
    $1 == "turns" { if ($2 != 24) exit 2; turns++ }
    $1 == "planned_api_turns" { if ($2 != 24) exit 2; api++ }
    $1 == "api_store" { if ($2 != "false") exit 2; store++ }
    $1 == "target_word" { if ($2 != "absent") exit 2; target++ }
    $1 == "desired_wonder" { if ($2 != "absent") exit 2; wonder++ }
    $1 == "answer_instruction" { if ($2 != "absent") exit 2; answer++ }
    $1 == "runtime_change" { if ($2 != "forbidden before observation") exit 2; runtime++ }
    END {
        if (phase != 1 || source != 1 || seed != 1 || turns != 1 ||
            api != 1 || store != 1 || target != 1 || wonder != 1 ||
            answer != 1 || runtime != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/fresh_ordinary_life_a141_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 27 || $1 != "life" || $4 != "plan_sha256" ||
            $27 != "final_pending_turns") exit 2
        next
    }
    NF != 27 || $1 != "ordinary" || $2 != 853 ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 != 24 || $8 != 24 || $9 != 24 ||
        $10 !~ /^[0-9a-f]{64}$/ || $11 !~ /^[0-9a-f]{64}$/ ||
        $12 !~ /^[0-9a-f]{64}$/ || $13 !~ /^[0-9a-f]{64}$/ ||
        $14 !~ /^[0-9a-f]{64}$/ || $15 != 15 || $16 != 18 ||
        $17 != 1 || $18 != 20 || $19 != "simply@5" || $20 != 5 ||
        $21 != "Simply? Light or Now?" || $22 != 6 ||
        $24 != "simply" || $25 != "light" || $26 != "now" ||
        $27 != 19 { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

"$ROOT/scripts/fresh_ordinary_life_a141_replay.sh" \
    "$TMP/replay" > "$TMP/replay.out"
cmp -s "$ROOT/scripts/fresh_ordinary_life_a141_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"
grep -q $'^result\tfresh-ordinary-life-exposes-qualified-both-gap$' \
    "$TMP/replay.out"
printf 'fresh ordinary life A.141 contracts: ok\n'
