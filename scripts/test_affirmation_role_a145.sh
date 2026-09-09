#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-affirmation-role-a145-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

plan="$ROOT/scripts/affirmation_role_a145_plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.145") exit 2; phase++ }
    $1 == "source_body" { if ($2 !~ /exact A.144.*turn 5/) exit 2; source++ }
    $1 == "turns" { if ($2 != 6) exit 2; turns++ }
    $1 == "api_turns" { if ($2 != 0) exit 2; api++ }
    $1 == "role_source" { if ($2 != "leo_school_word_is_affirmation") exit 2; role++ }
    $1 == "newly_bounded_surfaces" { if ($2 != "yeah,yep,okay") exit 2; bounded++ }
    $1 == "no_new_stoplist" { if ($2 != "true") exit 2; stoplist++ }
    $1 == "named_ablation" { if ($2 != "--no-school-affirmation-role") exit 2; ablation++ }
    $1 == "state_format_change" { if ($2 != "forbidden") exit 2; state++ }
    END {
        if (phase != 1 || source != 1 || turns != 1 || api != 1 ||
            role != 1 || bounded != 1 || stoplist != 1 ||
            ablation != 1 || state != 1) exit 2
    }
' "$plan"

frozen="$ROOT/scripts/affirmation_role_a145_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 31 || $1 != "phase" || $4 != "plan_sha256" ||
            $31 != "api_turns") exit 2
        next
    }
    NF != 31 || $1 != "A.145" || $2 != 542 ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 !~ /^[0-9a-f]{64}$/ ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^[0-9a-f]{64}$/ ||
        $10 !~ /^[0-9a-f]{64}$/ || $11 != 6 || $12 != 1 ||
        $13 != 0 || $14 != "finished@4,yeah@6" ||
        $15 != "finished@4" || $16 != "yeah" ||
        $17 != "finished" || $18 != 2 || $19 != 1 ||
        $20 != 1 || $21 != 1 || $22 != "somehow" ||
        $23 != 1 || $24 != 3 || $25 != 1 || $26 != 0 ||
        $27 != 0 || $28 != 0 || $29 != "true" ||
        $30 != "true" || $31 != 0 { exit 2 }
    { rows++ }
    END { if (rows != 1) exit 2 }
' "$frozen"

"$ROOT/scripts/affirmation_role_a145_anatomy.sh" \
    "$TMP/anatomy" > "$TMP/anatomy.out"
cmp -s "$ROOT/scripts/affirmation_role_a145_expected.tsv" \
    "$TMP/anatomy/anatomy.tsv"
grep -q $'^control_a144_exact\ttrue$' "$TMP/anatomy.out"
grep -q $'^result\taffirmation-role-prevents-discourse-redirect-without-erasing-wonder$' \
    "$TMP/anatomy.out"
printf 'affirmation role A.145 contracts: ok\n'
