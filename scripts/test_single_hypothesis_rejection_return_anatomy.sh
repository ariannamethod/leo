#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-single-hypothesis-rejection-return-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

awk -F '\t' '
    NR == 1 { if (NF != 2 || $1 != "field" || $2 != "value") exit 2; next }
    NF != 2 || seen[$1]++ { exit 2 }
    $1 == "phase" { if ($2 != "A.135") exit 2; phase++ }
    $1 == "expected_return" { if ($2 != "Difficult?") exit 2; expected++ }
    $1 == "synthetic_cases" { if ($2 != 5) exit 2; cases++ }
    $1 == "api_turns" { if ($2 != 0) exit 2; api++ }
    $1 == "runtime_change" { if ($2 !~ /^prohibited/) exit 2; runtime++ }
    END { if (phase != 1 || expected != 1 || cases != 1 || api != 1 || runtime != 1) exit 2 }
' "$ROOT/scripts/single_hypothesis_rejection_return_plan.tsv"

"$ROOT/scripts/single_hypothesis_rejection_return_anatomy.sh" \
    "$TMP/anatomy" >/dev/null
[ "$(wc -l < "$TMP/anatomy/synthetic.tsv" | tr -d ' ')" -eq 6 ]
[ "$(wc -l < "$TMP/anatomy/natural.tsv" | tr -d ' ')" -eq 2 ]
grep -q $'^literal-return\twhat is zorble?\tzorble\tnone\tnone\tnone\t0\t1\tZorble?$' \
    "$TMP/anatomy/synthetic.tsv"
grep -q $'^sleep-literal-return\twhat is zorble?\tzorble\tnone\tnone\tnone\t0\t1\tZorble?$' \
    "$TMP/anatomy/synthetic.tsv"
grep -q $'^rejected-anaphora\tis it water?\tzorble\tnone\tnone\tnone\t0\t0\tordinary$' \
    "$TMP/anatomy/synthetic.tsv"
grep -q $'^later-positive\ta zorble is animal\tnone\tnone\tnone\tanimal\t1\t0\tordinary$' \
    "$TMP/anatomy/synthetic.tsv"
grep -q $'^natural-a134\tWhat is difficult?\tdifficult\tnone\tnone\tnone\t0\t1\tDifficult?$' \
    "$TMP/anatomy/natural.tsv"

awk -F '\t' '
    FNR == NR {
        if (FNR == 1) next
        if (NF != 9 || seen[$1]++) exit 2
        expected[$1] = $3 FS $4 FS $5 FS $6 FS $7 FS $8 FS $9
        next
    }
    FNR == 1 { next }
    NF != 9 || !($1 in expected) ||
        ($3 FS $4 FS $5 FS $6 FS $7 FS $8 FS $9) != expected[$1] { exit 2 }
    { observed++ }
    END { if (length(expected) != 5 || observed != 5) exit 2 }
' "$ROOT/scripts/single_hypothesis_rejection_return_cases.tsv" \
    "$TMP/anatomy/synthetic.tsv"

printf 'single-hypothesis rejection return anatomy contracts: ok\n'
