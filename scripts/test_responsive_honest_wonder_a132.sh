#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-responsive-honest-wonder-a132-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/responsive_honest_wonder_a132_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.132") exit 2; phase++ }
    $1 == "prefix_turns" { if ($2 != 2) exit 2; prefix++ }
    $1 == "continuation_turns" { if ($2 != 22) exit 2; continuation++ }
    $1 == "planned_api_turns" { if ($2 != 22) exit 2; api++ }
    $1 == "api_store" { if ($2 != "false") exit 2; store++ }
    END { if (phase != 1 || prefix != 1 || continuation != 1 || api != 1 || store != 1) exit 2 }
' "$plan"

frozen="$ROOT/scripts/responsive_honest_wonder_a132_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 11 || $1 != "life" || $3 != "fixture" ||
            $6 != "prompts_sha256" || $11 != "sync_async_reply_mismatches") exit 2
        next
    }
    NF != 11 || $1 != "meal" || $2 != 617 || $4 != 2 || $5 != 22 ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 !~ /^[0-9a-f]{64}$/ ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^[0-9a-f]{64}$/ ||
        $10 !~ /^[0-9a-f]{64}$/ || $11 != 9 { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

fixture="$(awk -F '\t' 'NR == 2 { print $3 }' "$frozen")"
expected_sha="$(awk -F '\t' 'NR == 2 { print $6 }' "$frozen")"
[ "$(shasum -a 256 "$ROOT/$fixture" | awk '{print $1}')" = "$expected_sha" ]

"$ROOT/scripts/responsive_honest_wonder_a132_replay.sh" "$TMP/replay" \
    > "$TMP/replay.out"
grep -q $'^sync_replay_exact\ttrue$' "$TMP/replay.out"
grep -q $'^async_reproducible\ttrue$' "$TMP/replay.out"
grep -q $'^lentil_resolved_turn\t3$' "$TMP/replay.out"
grep -q $'^meaningful_opened_turn\t14$' "$TMP/replay.out"
cmp -s "$ROOT/scripts/responsive_honest_wonder_a132_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"

printf 'responsive honest Wonder A.132 contracts: ok\n'
