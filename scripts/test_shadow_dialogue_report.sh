#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-shadow-report-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf 'What is a glim?\nDo you remember glim?\n/quit\n' > "$TMP/prompts.txt"
printf '%s\n' \
    'you> leo> Glim?' \
    'A second line.' \
    '     [shadow: observed=1 next=2 action=space target=abc confidence=0.95 reasons=open,asked]' \
    'you> leo> Glim?' \
    '     [shadow: observed=2 next=3 action=space target=abc confidence=0.90 reasons=open,asked]' \
    '     [shadow-calibration: proposal=1 observed=2 verdict=unscorable scored=0 confirmed=0 brier=0.000]' \
    'you> [leo step0] PASS' > "$TMP/raw.log"

awk -v scenario=fixture -v seed=83 -v prompt_file="$TMP/prompts.txt" \
    -f "$ROOT/scripts/shadow_dialogue_report.awk" "$TMP/raw.log" > "$TMP/rows.tsv"

awk -F '\t' '
    NR == 1 {
        ok = NF == 13 && $1 == "fixture" && $2 == "83" && $3 == "1" &&
             $5 == "Glim?\\nA second line." && $6 == "space" &&
             $10 == "2" && $11 == "Do you remember glim?" &&
             $12 == "Glim?" && $13 == "unscorable"
    }
    NR == 2 {
        ok = ok && NF == 13 && $3 == "2" && $10 == "" && $13 == ""
    }
    END { exit !(ok && NR == 2) }
' "$TMP/rows.tsv"

printf 'scenario\tseed\tproposal_turn\tprompt\treply\taction\ttarget\tconfidence\treasons\tobserved_turn\tnext_prompt\tnext_reply\tverdict\n' > "$TMP/receipts.tsv"
cat "$TMP/rows.tsv" >> "$TMP/receipts.tsv"
printf '%s\n' \
    $'scenario\tseed\tturn\tsession\tsession_seed\tprompt' \
    $'fixture\t83\t1\t1\t83\tWhat is a glim?' \
    $'fixture\t83\t2\t2\t84\tDo you remember glim?' > "$TMP/sessions.tsv"

awk -f "$ROOT/scripts/shadow_sleep_edges.awk" \
    "$TMP/sessions.tsv" "$TMP/receipts.tsv" > "$TMP/edges.tsv"
awk -F '\t' '
    NR == 2 {
        ok = NF == 9 && $1 == "fixture" && $3 == "1" && $4 == "1" &&
             $5 == "space" && $7 == "2" && $8 == "2" &&
             $9 == "unscorable"
    }
    END { exit !(ok && NR == 2) }
' "$TMP/edges.tsv"

awk -f "$ROOT/scripts/shadow_receipt_summary.awk" \
    "$TMP/receipts.tsv" > "$TMP/summary.txt"
grep -Fq 'proposals=2 scored=0 unscorable=1 pending=1' "$TMP/summary.txt"

printf '%s\n' \
    'you> leo> Glim?' \
    'A second line.' \
    '     [shadow: observed=1 next=2 action=space target=abc confidence=0.95 reasons=open,asked]' \
    'you> [leo step0] PASS' > "$TMP/visible-raw.log"
awk -f "$ROOT/scripts/leo_visible_reply.awk" "$TMP/visible-raw.log" > "$TMP/reply.txt"
printf 'Glim?\nA second line.\n' > "$TMP/expected-reply.txt"
cmp -s "$TMP/expected-reply.txt" "$TMP/reply.txt"

: > "$TMP/policy-history.jsonl"
"$ROOT/scripts/visible_branch_policy.sh" "$TMP/policy-history.jsonl" \
    1 flom 'warm light' 'cool rain' > "$TMP/policy-1.json"
jq -e '.branch == "introduce-target" and (.utterance | contains("flom"))' \
    "$TMP/policy-1.json" >/dev/null
printf '%s\n' '{"turn":1,"reply":"He keeps the light."}' > "$TMP/policy-history.jsonl"
"$ROOT/scripts/visible_branch_policy.sh" "$TMP/policy-history.jsonl" \
    2 flom 'warm light' 'cool rain' > "$TMP/policy-2.json"
jq -e '.branch == "repeat-unmet-target" and (.utterance | contains("flom"))' \
    "$TMP/policy-2.json" >/dev/null
printf '%s\n' '{"turn":2,"reply":"Flom?"}' >> "$TMP/policy-history.jsonl"
"$ROOT/scripts/visible_branch_policy.sh" "$TMP/policy-history.jsonl" \
    3 flom 'warm light' 'cool rain' > "$TMP/policy-3.json"
jq -e '.branch == "protect-new-question" and .utterance == "I do not know yet."' \
    "$TMP/policy-3.json" >/dev/null
printf '%s\n' '{"turn":7,"reply":"Flom?"}' >> "$TMP/policy-history.jsonl"
"$ROOT/scripts/visible_branch_policy.sh" "$TMP/policy-history.jsonl" \
    8 flom 'warm light' 'cool rain' > "$TMP/policy-8.json"
jq -e '.branch == "cooldown-exact-repeat" and .visible_evidence.exact_repeat' \
    "$TMP/policy-8.json" >/dev/null

printf 'shadow dialogue report parser: ok\n'
