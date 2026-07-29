#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_POPULATION_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_population_causal_lift.sh"
)"
expected=$'arm\tlives\tturns\tcases\tvariants\thorizon\tcontract\nside-a\t2\t32\t64\t4\t4\texact-state-all-invitations\nside-b\t2\t32\t64\t4\t4\texact-state-all-invitations'

[ "$got" = "$expected" ] || {
    printf 'invalid appetite population causal lift plan:\n%s\n' "$got" >&2
    exit 1
}

printf 'deferred Wonder appetite population causal lift plan: ok\n'
