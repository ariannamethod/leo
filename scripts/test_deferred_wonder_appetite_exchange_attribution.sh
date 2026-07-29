#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_EXCHANGE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_exchange_attribution.sh"
)"
expected=$'trace\tturns\tcontract\nexternal-pair\t1\texternal-sufficient\nself-pair\t1\tself-sufficient\nexternal-cross-ab\t1\texternal-cross-required\nexternal-cross-ba\t1\texternal-cross-required-reversed\nreflected-cross\t1\treflected-cross-required\necho-one\t1\tsame-side-echo\nexternal-temporal\t2\texternal-sufficient-adjacent\nself-temporal\t2\tself-sufficient-adjacent\ncross-owner\t1\tdifferent-owner-sides\nliteral-human\t1\thuman-address-confound\nliteral-leo\t1\tleo-self-address-confound\nnatural-83\t64\tA.62-visible-exchanges\nnatural-137\t64\tA.62-visible-exchanges\nnatural-211\t64\tA.62-visible-exchanges'
[ "$got" = "$expected" ] || {
    printf 'invalid appetite exchange plan:\n%s\n' "$got" >&2
    exit 1
}

printf 'deferred Wonder appetite exchange attribution plan: ok\n'
