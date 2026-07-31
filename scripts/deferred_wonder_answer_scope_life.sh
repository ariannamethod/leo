#!/usr/bin/env bash
# A.76: one referenced statement cannot conscript the rest of a human turn.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/scripts/deferred_wonder_answer_scope_cases.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-answer-scope-$STAMP}"

if [ "${LEO_WONDER_SCOPE_PLAN_ONLY:-0}" = 1 ]; then
    cases="$(($(wc -l < "$CASES") - 1))"
    continued="$(
        awk -F '\t' 'NR > 1 && $3 == "continued" {n++} END {print n + 0}' \
            "$CASES"
    )"
    resolved="$(
        awk -F '\t' 'NR > 1 && $3 == "resolved" {n++} END {print n + 0}' \
            "$CASES"
    )"
    [ "$cases" -eq 10 ] &&
        [ "$continued" -eq 4 ] &&
        [ "$resolved" -eq 6 ] || {
        printf 'answer-scope life cases do not satisfy the sealed plan\n' >&2
        exit 1
    }
    printf 'source\tcases\tcontinued\tresolved\tfollowups\tprocesses\tcontract\n'
    printf 'A.76\t%d\t%d\t%d\t%d\t%d\tstatement-scope-before-evidence\n' \
        "$cases" "$continued" "$resolved" "$cases" \
        "$((1 + cases + cases))"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/cases"
cp "$CASES" "$OUT/cases.tsv"
LEO_WONDER_SCOPE_PLAN_ONLY=1 "$0" > "$OUT/sealed-plan.tsv"
shasum -a 256 "$ROOT/leo.c" "$ROOT/leo.txt" \
    > "$OUT/source.sha256"
(
    cd "$OUT"
    shasum -a 256 cases.tsv sealed-plan.tsv > sealed-inputs.sha256
)

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

receipt_field() {
    local marker="$1"
    local key="$2"
    local file="$3"
    awk -v marker="$marker" -v key="$key" '
        index($0, marker) {
            for (i = 1; i <= NF; i++)
                if (index($i, key "=") == 1) {
                    sub("^" key "=", "", $i)
                    sub(/\]$/, "", $i)
                    print $i
                    exit
                }
        }
    ' "$file"
}

OPEN="$OUT/open.state"
"$ROOT/leo" --seed 83 \
    --respond "is a zorble water or cat" \
    --save "$OPEN" --debug-field \
    > "$OUT/open.log" 2>&1
[ "$(reply_from_log "$OUT/open.log")" = "Zorble? Water or Animal?" ]
[ "$(receipt_field '[curiosity:' outcome "$OUT/open.log")" = asked ]
[ "$(receipt_field '[pre-wonder:' pending "$OUT/open.log")" = zorble ]
[ "$(receipt_field '[pre-wonder:' resolved "$OUT/open.log")" = 0 ]
shasum -a 256 "$OPEN" > "$OUT/open.sha256"

RESULTS="$OUT/results.tsv"
printf 'case\toutcome\tpending\tresolved\tfollowup\tperceived\tlearned\n' \
    > "$RESULTS"
tail -n +2 "$OUT/cases.tsv" |
while IFS=$'\t' read -r case_id answer expected_outcome \
        expected_pending expected_resolved followup_prompt \
        expected_followup expected_perceived expected_learned; do
    case_dir="$OUT/cases/$case_id"
    mkdir -p "$case_dir"
    printf '%s\n' "$answer" > "$case_dir/answer.txt"
    "$ROOT/leo" --load "$OPEN" --seed 84 \
        --respond "$answer" \
        --save "$case_dir/after.state" --debug-field \
        > "$case_dir/answer.log" 2>&1

    outcome="$(
        receipt_field '[curiosity:' outcome "$case_dir/answer.log"
    )"
    pending="$(
        receipt_field '[pre-wonder:' pending "$case_dir/answer.log"
    )"
    resolved="$(
        receipt_field '[pre-wonder:' resolved "$case_dir/answer.log"
    )"
    [ "$outcome" = "$expected_outcome" ]
    [ "$pending" = "$expected_pending" ]
    [ "$resolved" = "$expected_resolved" ]
    grep -Eq "\\[flow: .* in=${expected_perceived}\\(" \
        "$case_dir/answer.log"

    "$ROOT/leo" --load "$case_dir/after.state" --seed 85 \
        --respond "$followup_prompt" \
        --save "$case_dir/followup.state" --debug-field \
        > "$case_dir/followup.log" 2>&1
    followup="$(reply_from_log "$case_dir/followup.log")"
    [ "$followup" = "$expected_followup" ]
    if [ "$expected_outcome" = resolved ]; then
        [ "$expected_learned" != none ]
        [ "$(
            receipt_field '[curiosity:' outcome \
                "$case_dir/followup.log"
        )" = asked ]
        [ "$(
            receipt_field '[curiosity:' candidate \
                "$case_dir/followup.log"
        )" = flom ]
    else
        [ "$expected_learned" = none ]
        [ "$(
            receipt_field '[curiosity:' outcome \
                "$case_dir/followup.log"
        )" = reasked ]
        [ "$(
            receipt_field '[pre-wonder:' resolved \
                "$case_dir/followup.log"
        )" = 0 ]
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_id" "$outcome" "$pending" "$resolved" \
        "$followup" "$expected_perceived" "$expected_learned" \
        >> "$RESULTS"
done

[ "$(($(wc -l < "$RESULTS") - 1))" -eq 10 ]
(
    cd "$OUT"
    shasum -a 256 -c sealed-inputs.sha256 > /dev/null
    shasum -a 256 open.state results.tsv > receipt.sha256
    printf '%s\n' \
        '17d65d5af898d0d5213fba0e157cde9791f91ec16169e7b912c852e084f85bda  open.state' \
        'b9b4f65613097427ee22636422d623397d0f90e812cfe513d484e915eb45ccef  results.tsv' \
        > expected-results.sha256
    shasum -a 256 -c expected-results.sha256 > /dev/null
)

cat "$RESULTS"
printf '\nopen state: %s\nreceipt: %s\n' \
    "$OPEN" "$OUT/receipt.sha256"
