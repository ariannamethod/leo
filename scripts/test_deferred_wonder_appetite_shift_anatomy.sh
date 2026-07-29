#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_SHIFT_ANATOMY_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_shift_anatomy.sh"
)"
expected=$'case\tlife_turns\tcontinuation_forecasts\toutcome_assignment\tcomparison\tplan_visibility\nhidden-future\t600\t98\tround-source-parity\texact-proposal-feature-multiset\tsealed-before-replies'

[ "$got" = "$expected" ] || {
    printf 'invalid appetite shift anatomy plan:\n%s\n' "$got" >&2
    exit 1
}
printf 'deferred Wonder appetite shift anatomy plan: ok\n'
