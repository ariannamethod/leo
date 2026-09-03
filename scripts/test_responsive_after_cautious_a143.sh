#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-responsive-after-cautious-a143-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/responsive_after_cautious_a143_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.143") exit 2; phase++ }
    $1 == "source_body" { if ($2 !~ /exact A.141.*merged A.142/) exit 2; source++ }
    $1 == "prefix_turns" { if ($2 != 6) exit 2; prefix++ }
    $1 == "continuation_turns" { if ($2 != 18) exit 2; continuation++ }
    $1 == "planned_api_turns" { if ($2 != 18) exit 2; api++ }
    $1 == "api_store" { if ($2 != "false") exit 2; store++ }
    $1 == "target_word" { if ($2 != "absent") exit 2; target++ }
    $1 == "desired_wonder" { if ($2 != "absent") exit 2; wonder++ }
    $1 == "answer_instruction" { if ($2 != "absent") exit 2; answer++ }
    $1 == "difficult_as_experimental_demand" { if ($2 != "absent") exit 2; difficult++ }
    $1 == "runtime_change" { if ($2 != "forbidden before observation") exit 2; runtime++ }
    END {
        if (phase != 1 || source != 1 || prefix != 1 || continuation != 1 ||
            api != 1 || store != 1 || target != 1 || wonder != 1 ||
            answer != 1 || difficult != 1 || runtime != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/responsive_after_cautious_a143_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 34 || $1 != "life" || $4 != "plan_sha256" ||
            $34 != "receive_alternate") exit 2
        next
    }
    NF != 34 || $1 != "ordinary" || $2 != 853 ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 !~ /^[0-9a-f]{64}$/ ||
        $8 != 6 || $9 != 18 || $10 != 18 || $11 != 18 ||
        $12 != "gpt-5.6-luna" || $13 !~ /^[0-9a-f]{64}$/ ||
        $14 !~ /^[0-9a-f]{64}$/ || $15 !~ /^[0-9a-f]{64}$/ ||
        $16 !~ /^[0-9a-f]{64}$/ || $17 !~ /^[0-9a-f]{64}$/ ||
        $18 != 12 || $19 != 15 || $20 != 1 || $21 != 12 ||
        $22 != 5 || $23 != 2 || $24 != "simply@5,receive@19" ||
        $25 != 19 || $26 != "Receive? Water or Home?" || $27 != 20 ||
        $29 != "none" || $30 != 2 || $31 != "light" || $32 != "now" ||
        $33 != "water" || $34 != "home" { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

"$ROOT/scripts/responsive_after_cautious_a143_replay.sh" \
    "$TMP/replay" > "$TMP/replay.out"
cmp -s "$ROOT/scripts/responsive_after_cautious_a143_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"
grep -q $'^result\tresponsive-after-cautious-hears-second-cautious-pair$' \
    "$TMP/replay.out"
printf 'responsive after cautious A.143 contracts: ok\n'
