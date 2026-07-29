#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_CADENCE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_cadence_life.sh"
)"
expected=$'case\tsources\ttrials_per_source\tturns\tcue_pattern\tplan_visibility\nlate\t8\t6\t224\tall-after-window\tsealed-before-replies\nmixed\t8\t6\t224\ttwo-within-one-after-pattern\tsealed-before-replies'

[ "$got" = "$expected" ] || {
    printf 'invalid appetite cadence life plan:\n%s\n' "$got" >&2
    exit 1
}
printf 'deferred Wonder appetite cadence life plan: ok\n'
