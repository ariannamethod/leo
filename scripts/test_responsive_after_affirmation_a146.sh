#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-responsive-after-affirmation-a146-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/responsive_after_affirmation_a146_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.146") exit 2; phase++ }
    $1 == "source_body" { if ($2 !~ /exact A.145 candidate/) exit 2; source++ }
    $1 == "prefix_turns" { if ($2 != 6) exit 2; prefix++ }
    $1 == "planned_api_turns" { if ($2 != 18) exit 2; api++ }
    $1 == "api_store" { if ($2 != "false") exit 2; store++ }
    $1 == "private_diagnostics_visible" { if ($2 != "false") exit 2; private++ }
    $1 == "hidden_target_instruction" { if ($2 != "absent") exit 2; target++ }
    $1 == "repair_instruction" { if ($2 != "absent") exit 2; repair++ }
    $1 == "runtime_change" { if ($2 != "forbidden before observation") exit 2; runtime++ }
    END {
        if (phase != 1 || source != 1 || prefix != 1 || api != 1 ||
            store != 1 || private != 1 || target != 1 || repair != 1 ||
            runtime != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/responsive_after_affirmation_a146_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 40 || $1 != "phase" || $4 != "plan_sha256" ||
            $40 != "first_continuation_leo") exit 2
        next
    }
    NF != 40 || $1 != "A.146" || $2 != 542 ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 !~ /^[0-9a-f]{64}$/ ||
        $8 != 6 || $9 != 18 || $10 != 18 || $11 != 18 ||
        $12 != "gpt-5.6-luna" ||
        $13 !~ /^[0-9a-f]{64}$/ || $14 !~ /^[0-9a-f]{64}$/ ||
        $15 !~ /^[0-9a-f]{64}$/ || $16 !~ /^[0-9a-f]{64}$/ ||
        $17 !~ /^[0-9a-f]{64}$/ || $18 != 13 || $19 != 14 ||
        $20 != 6 || $21 != 1 || $22 != 11 || $23 != 0 ||
        $24 != "finished@4" || $25 != "none" || $26 != 21 ||
        $27 != "finished" || $28 != 20 || $29 != 1 || $30 != 1 ||
        $31 != "somehow" || $32 != 1 || $33 != 2 || $34 != 3 ||
        $35 != 0 || $36 != 0 || $37 != 0 || $38 != "true" ||
        $39 !~ /^Gentle rain/ || $40 !~ /^The quiet without being asked/ {
            exit 2
        }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

"$ROOT/scripts/responsive_after_affirmation_a146_replay.sh" \
    "$TMP/replay" > "$TMP/replay.out"
cmp -s "$ROOT/scripts/responsive_after_affirmation_a146_anatomy.tsv" \
    "$TMP/replay/anatomy.tsv"
cmp -s "$ROOT/scripts/responsive_after_affirmation_a146_anatomy.tsv" \
    "$TMP/replay/anatomy.async.tsv"
grep -q $'^sync_async_school_anatomy_exact\ttrue$' "$TMP/replay.out"
grep -q $'^continuation_questions\tnone$' "$TMP/replay.out"
grep -q $'^final_pending\tfinished$' "$TMP/replay.out"
grep -q $'^final_deferred\tsomehow$' "$TMP/replay.out"
grep -q $'^result\tpost-affirmation-mouth-continues-without-shifted-interruption$' \
    "$TMP/replay.out"
printf 'responsive after affirmation A.146 contracts: ok\n'
