#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_FLOM_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_flom_third_life.sh"
)"
expected=$'hypothesis\tlives\tturns\tcases\tvariants\thorizon\tschedule\tcontract\nside-a/flom\t8\t32\t64\t3\t4\tthird-surface\tdual-surface-breadth'

[ "$got" = "$expected" ] || {
    printf 'invalid appetite Flom third-life plan:\n%s\n' "$got" >&2
    exit 1
}

printf 'deferred Wonder appetite Flom third-life plan: ok\n'
