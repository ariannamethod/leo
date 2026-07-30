#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_SUSCEPTIBILITY_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_susceptibility_holdout.sh"
)"
expected=$'arm\tlives\tturns\tcases\tvariants\thorizon\tschedule\tcontract\nside-a\t4\t32\t128\t3\t4\tnew-surface\tdual-surface-susceptibility\nside-b\t4\t32\t128\t3\t4\tnew-surface\tdual-surface-susceptibility'

[ "$got" = "$expected" ] || {
    printf 'invalid appetite susceptibility holdout plan:\n%s\n' "$got" >&2
    exit 1
}

printf 'deferred Wonder appetite susceptibility holdout plan: ok\n'
