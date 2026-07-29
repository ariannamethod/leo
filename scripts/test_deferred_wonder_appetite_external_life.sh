#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_EXTERNAL_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_external_life.sh"
)"
expected=$'arm\tlives\tturns\tprovenance\toutcomes\nblind\t2\t32\tsealed-external\tnone\nside-a\t2\t32\tsealed-external\tnone\nside-b\t2\t32\tsealed-external\tnone'
[ "$got" = "$expected" ] || {
    printf 'invalid appetite external life plan:\n%s\n' "$got" >&2
    exit 1
}

printf 'deferred Wonder appetite external life plan: ok\n'
