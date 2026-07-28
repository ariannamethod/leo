#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_SOURCE_ECOLOGY_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_source_ecology_life.sh"
)"
expected=$'case\tsources\tturns_per_source\tturns\tplan_visibility\texpected_status\neight-wonder-blocks\t8\t26\t208\tsealed-before-replies\tobserved-not-prescribed'

[ "$got" = "$expected" ] || {
    printf 'invalid source ecology life plan:\n%s\n' "$got" >&2
    exit 1
}
printf 'deferred Wonder appetite source ecology life plan: ok\n'
