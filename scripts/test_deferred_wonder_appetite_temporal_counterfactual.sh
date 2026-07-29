#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_TEMPORAL_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_temporal_counterfactual.sh"
)"
expected=$'trace\tturns\tcontract\nsimultaneous\t1\tboth-sides-same-turn\nsplit-adjacent\t2\tcomplementary-sides-adjacent\nsplit-reverse\t2\tcomplementary-sides-reversed\nrepeat-one\t2\tsame-side-repeated\nsplit-distant\t10\tcomplementary-sides-outside-window\ncross-owner\t2\tdifferent-owner-sides\nliteral-bridge\t2\thuman-address-cannot-carry-support\nnatural-83\t64\tA.62-visible-prompts\nnatural-137\t64\tA.62-visible-prompts\nnatural-211\t64\tA.62-visible-prompts'
[ "$got" = "$expected" ] || {
    printf 'invalid appetite temporal plan:\n%s\n' "$got" >&2
    exit 1
}

printf 'deferred Wonder appetite temporal counterfactual plan: ok\n'
