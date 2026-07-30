#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_CAPSULE_INTERACTION_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_capsule_interaction_population.sh"
)"
expected=$'source\tlives\tturns\tcases\tfactorial_arms\tclosure_arms\tvariants\thorizon\tschedule\tcontract\nA.72\t4\t32\t32\t8\t1\t3\t4\tblock-rotated\tfresh-population-interaction'

[ "$got" = "$expected" ] || {
    printf 'invalid capsule interaction population plan:\n%s\n' "$got" >&2
    exit 1
}

[ "$(($(wc -l < "$ROOT/scripts/deferred_wonder_capsule_interaction_arms.tsv") - 1))" \
    -eq 9 ]
[ "$(($(wc -l < "$ROOT/scripts/deferred_wonder_capsule_interaction_acceptance.tsv") - 1))" \
    -eq 9 ]
[ "$(wc -l < "$ROOT/scripts/deferred_wonder_capsule_interaction_fresh.txt" | tr -d ' ')" \
    -eq 32 ]
if cmp -s \
    "$ROOT/scripts/deferred_wonder_capsule_interaction_fresh.txt" \
    "$ROOT/scripts/deferred_wonder_flom_third_life.txt"; then
    printf 'fresh interaction schedule is not rotated\n' >&2
    exit 1
fi
if ! diff -u \
    <(LC_ALL=C sort "$ROOT/scripts/deferred_wonder_capsule_interaction_fresh.txt") \
    <(LC_ALL=C sort "$ROOT/scripts/deferred_wonder_flom_third_life.txt") \
    > /dev/null; then
    printf 'fresh interaction schedule changes the source prompt multiset\n' >&2
    exit 1
fi
if grep -Eq '1709|1811|1907|2011' \
    "$ROOT/scripts/deferred_wonder_appetite_flom_third_life.sh" \
    "$ROOT/scripts/deferred_wonder_capsule_path_factorial.sh"; then
    printf 'fresh interaction seeds overlap a source experiment\n' >&2
    exit 1
fi
grep -Fq 'ASKxmeaning' \
    "$ROOT/scripts/deferred_wonder_capsule_interaction_acceptance.tsv"
grep -Fq 'positive_seeds>=3/4' \
    "$ROOT/scripts/deferred_wonder_capsule_interaction_acceptance.tsv"
if grep -Eiq '(^|[^[:alpha:]])flom([^[:alpha:]]|$)' \
    "$ROOT/scripts/deferred_wonder_capsule_interaction_fresh.txt"; then
    printf 'fresh interaction population names Flom\n' >&2
    exit 1
fi

printf 'deferred Wonder capsule interaction population plan: ok\n'
