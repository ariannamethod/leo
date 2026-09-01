#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-cautious-paired-answer-a142-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/cautious_paired_answer_a142_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.142") exit 2; phase++ }
    $1 == "source_body" { if ($2 !~ /exact A.141/) exit 2; source++ }
    $1 == "cautious_modifiers" { if ($2 != "maybe,perhaps") exit 2; modifiers++ }
    $1 == "named_ablation" { if ($2 != "--no-school-cautious-pair") exit 2; ablation++ }
    $1 == "direct_cases" { if ($2 != 21) exit 2; cases++ }
    $1 == "candidate_resolved_cases" { if ($2 != 12) exit 2; candidate++ }
    $1 == "ablation_resolved_cases" { if ($2 != 4) exit 2; control++ }
    $1 == "api_turns" { if ($2 != 0) exit 2; api++ }
    $1 == "state_format_change" { if ($2 != "forbidden") exit 2; state++ }
    END {
        if (phase != 1 || source != 1 || modifiers != 1 || ablation != 1 ||
            cases != 1 || candidate != 1 || control != 1 || api != 1 ||
            state != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/cautious_paired_answer_a142_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 26 || $1 != "phase" || $4 != "plan_sha256" ||
            $26 != "api_turns") exit 2
        next
    }
    NF != 26 || $1 != "A.142" || $2 != 853 ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 != 24 ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^[0-9a-f]{64}$/ ||
        $10 !~ /^[0-9a-f]{64}$/ || $11 !~ /^[0-9a-f]{64}$/ ||
        $12 !~ /^[0-9a-f]{64}$/ || $13 != 12 ||
        $14 != "simply@5" || $15 != "simply@5,difficult@13" ||
        $16 != 20 || $17 != 13 || $18 != "difficult" ||
        $19 != "make" || $20 != "home" || $21 != 11 || $22 != 2 ||
        $23 != 21 || $24 != 12 || $25 != 4 || $26 != 0 { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

"$ROOT/scripts/cautious_paired_answer_a142_anatomy.sh" \
    "$TMP/anatomy" > "$TMP/anatomy.out"
cmp -s "$ROOT/scripts/cautious_paired_answer_a142_expected.tsv" \
    "$TMP/anatomy/direct.tsv"
cmp -s "$ROOT/scripts/cautious_paired_answer_a142_life_anatomy.tsv" \
    "$TMP/anatomy/life-anatomy.tsv"
grep -q $'^control_a141_exact\ttrue$' "$TMP/anatomy.out"
grep -q $'^result\tcautious-paired-answer-heard-without-erasing-hesitation$' \
    "$TMP/anatomy.out"
printf 'cautious paired answer A.142 contracts: ok\n'
