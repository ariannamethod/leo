#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_FATHER_PATH_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_father_path_localization.sh"
)"
expected=$'source\tcases\twitnesses\tarms\tvariants\thorizon\tcontract\nA.70\t64\t9\t12\t3\t4\texact-state-conditional-localization'

[ "$got" = "$expected" ] || {
    printf 'invalid father path localization plan:\n%s\n' "$got" >&2
    exit 1
}

[ "$(($(wc -l < "$ROOT/scripts/deferred_wonder_father_path_arms.tsv") - 1))" \
    -eq 12 ]
[ "$(($(wc -l < "$ROOT/scripts/deferred_wonder_father_path_acceptance.tsv") - 1))" \
    -eq 8 ]

printf 'deferred Wonder father path localization plan: ok\n'
