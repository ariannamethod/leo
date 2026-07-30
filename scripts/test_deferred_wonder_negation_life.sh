#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_WONDER_NEGATION_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_negation_life.sh"
)"
expected=$'source\tcases\tcontinued\tresolved\treasks\tprocesses\tcontract\nA.74\t7\t4\t3\t4\t12\tassertion-is-not-perception'

[ "$got" = "$expected" ] || {
    printf 'invalid deferred Wonder negation life plan:\n%s\n' "$got" >&2
    exit 1
}
[ "$(($(wc -l < "$ROOT/scripts/deferred_wonder_negation_cases.tsv") - 1))" \
    -eq 7 ]
grep -Fq $'negative-one\ta zorble is not water\tcontinued' \
    "$ROOT/scripts/deferred_wonder_negation_cases.tsv"
grep -Fq $'contrast\ta zorble is not water but animal\tresolved' \
    "$ROOT/scripts/deferred_wonder_negation_cases.tsv"
grep -Fq $'discourse-no\tno a zorble is water in the river and the sea\tresolved' \
    "$ROOT/scripts/deferred_wonder_negation_cases.tsv"

printf 'deferred Wonder negation life plan: ok\n'
