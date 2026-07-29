#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_SOURCE_CADENCE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_source_cadence_life.sh"
)"
expected=$'case\tacquisition_sources\tdeferred_sources\trounds\tacquisition_turns\tcontinuation_turns\tcue_pattern\tplan_visibility\nsource-cadence\t8\t7\t14\t208\t392\tround-robin-alternating-sustained-faded\tsealed-before-replies'

[ "$got" = "$expected" ] || {
    printf 'invalid appetite source-cadence life plan:\n%s\n' "$got" >&2
    exit 1
}
printf 'deferred Wonder appetite source-cadence life plan: ok\n'
