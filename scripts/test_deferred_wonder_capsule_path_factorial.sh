#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_CAPSULE_PATH_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_capsule_path_factorial.sh"
)"
expected=$'source\tselected_states\tfactorial_arms\tclosure_arms\tvariants\thorizon\tpaired_contexts_per_factor\tcontract\nA.71\t9\t32\t1\t3\t4\t16\texact-state-capsule-factorization'

[ "$got" = "$expected" ] || {
    printf 'invalid capsule path factorial plan:\n%s\n' "$got" >&2
    exit 1
}

[ "$(($(wc -l < "$ROOT/scripts/deferred_wonder_capsule_path_arms.tsv") - 1))" \
    -eq 33 ]
[ "$(($(wc -l < "$ROOT/scripts/deferred_wonder_capsule_path_acceptance.tsv") - 1))" \
    -eq 9 ]
grep -Fq 'g_leo_gamma_pull_on' "$ROOT/leo.c"
grep -Fq 'g_leo_spore_meaning_on' "$ROOT/leo.c"
grep -Fq 'g_leo_gamma_diary_on' "$ROOT/leo.c"
grep -Fq 'f00000 visible replies are byte-identical to no-capsule' \
    "$ROOT/scripts/deferred_wonder_capsule_path_acceptance.tsv"

printf 'deferred Wonder capsule path factorial plan: ok\n'
