#!/usr/bin/env bash
# A.75: conversational proximity does not assign every human clause to a Wonder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/scripts/deferred_wonder_answer_reference_cases.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-answer-reference-$STAMP}"

if [ "${LEO_WONDER_REFERENCE_PLAN_ONLY:-0}" = 1 ]; then
    cases="$(($(wc -l < "$CASES") - 1))"
    continued="$(
        awk -F '\t' 'NR > 1 && $3 == "continued" {n++} END {print n + 0}' \
            "$CASES"
    )"
    resolved="$(
        awk -F '\t' 'NR > 1 && $3 == "resolved" {n++} END {print n + 0}' \
            "$CASES"
    )"
    reasks="$(
        awk -F '\t' 'NR > 1 && $6 != "-" {n++} END {print n + 0}' \
            "$CASES"
    )"
    [ "$cases" -eq 9 ] &&
        [ "$continued" -eq 4 ] &&
        [ "$resolved" -eq 5 ] &&
        [ "$reasks" -eq 4 ] || {
        printf 'answer-reference life cases do not satisfy the sealed plan\n' >&2
        exit 1
    }
    printf 'source\tcases\tcontinued\tresolved\treasks\tprocesses\tcontract\n'
    printf 'A.75\t%d\t%d\t%d\t%d\t%d\treference-before-lesson\n' \
        "$cases" "$continued" "$resolved" "$reasks" \
        "$((1 + cases + reasks))"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/cases"
cp "$CASES" "$OUT/cases.tsv"
LEO_WONDER_REFERENCE_PLAN_ONLY=1 "$0" > "$OUT/sealed-plan.tsv"
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
printf 'case\toutcome\tpending\tresolved\treask\tperceived\n' \
    > "$RESULTS"
tail -n +2 "$OUT/cases.tsv" |
while IFS=$'\t' read -r case_id answer expected_outcome \
        expected_pending expected_resolved expected_reask expected_perceived; do
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

    perceived=none
    if [ "$expected_perceived" != "-" ]; then
        grep -Eq "\\[flow: .* in=${expected_perceived}\\(" \
            "$case_dir/answer.log"
        perceived="$expected_perceived"
    fi

    reask=none
    if [ "$expected_reask" != "-" ]; then
        "$ROOT/leo" --load "$case_dir/after.state" --seed 85 \
            --respond "what is zorble?" \
            --save "$case_dir/reask.state" --debug-field \
            > "$case_dir/reask.log" 2>&1
        reask="$(reply_from_log "$case_dir/reask.log")"
        [ "$reask" = "$expected_reask" ]
        [ "$(receipt_field '[curiosity:' outcome "$case_dir/reask.log")" = reasked ]
        [ "$(receipt_field '[pre-wonder:' resolved "$case_dir/reask.log")" = 0 ]
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_id" "$outcome" "$pending" "$resolved" \
        "$reask" "$perceived" >> "$RESULTS"
done

[ "$(($(wc -l < "$RESULTS") - 1))" -eq 9 ]
(
    cd "$OUT"
    shasum -a 256 -c sealed-inputs.sha256 > /dev/null
    shasum -a 256 open.state results.tsv > receipt.sha256
    printf '%s\n' \
        '17d65d5af898d0d5213fba0e157cde9791f91ec16169e7b912c852e084f85bda  open.state' \
        'e6e57d480d556e899f4efc79e58a6de081965e382a23c96866d9f11e47afaa54  results.tsv' \
        > expected-results.sha256
    shasum -a 256 -c expected-results.sha256 > /dev/null
)

cat "$RESULTS"
printf '\nopen state: %s\nreceipt: %s\n' \
    "$OPEN" "$OUT/receipt.sha256"
