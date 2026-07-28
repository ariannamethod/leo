#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_CHECKPOINT_LIFE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_checkpoint_life.sh"
)"
expected=$'case\ttarget\tturns\texpected_status\texpected_sources\texpected_max_source\none-wonder-cycle\tsuvin\t145\tsource-starved\t1\t32'

[ "$got" = "$expected" ] || {
    printf 'invalid natural checkpoint life plan:\n%s\n' "$got" >&2
    exit 1
}
printf 'deferred Wonder appetite natural checkpoint life plan: ok\n'
