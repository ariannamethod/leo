#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_WONDER_REFERENCE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_answer_reference_life.sh"
)"
expected=$'source\tcases\tcontinued\tresolved\treasks\tprocesses\tcontract\nA.75\t9\t4\t5\t4\t14\treference-before-lesson'

[ "$got" = "$expected" ] || {
    printf 'invalid deferred Wonder answer-reference life plan:\n%s\n' \
        "$got" >&2
    exit 1
}
[ "$(($(wc -l < \
    "$ROOT/scripts/deferred_wonder_answer_reference_cases.tsv") - 1))" \
    -eq 9 ]
grep -Fq $'unrelated-water\tthe river and sea have water\tcontinued' \
    "$ROOT/scripts/deferred_wonder_answer_reference_cases.tsv"
grep -Fq $'ellipse-option\tanimal\tresolved' \
    "$ROOT/scripts/deferred_wonder_answer_reference_cases.tsv"
grep -Fq $'affirmative-correction\tyes, it is music\tresolved' \
    "$ROOT/scripts/deferred_wonder_answer_reference_cases.tsv"

printf 'deferred Wonder answer-reference life plan: ok\n'
