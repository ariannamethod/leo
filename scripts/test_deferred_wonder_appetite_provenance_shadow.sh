#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_PROVENANCE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_provenance_shadow.sh"
)"
expected=$'trace\tturns\tcontract\nsame-turn-ab\t1\texternal-opens-self-completes\nsame-turn-ba\t1\texternal-opens-self-completes-reversed\ntemporal-ab\t2\texternal-precedes-self\nretroactive\t2\tpast-self-cannot-complete\nreflected-origin\t1\treflection-cannot-open\nreflected-completion\t2\treflection-blocks-self-completion\nreflected-passage\t3\treflection-does-not-rewrite-invitation\nexternal-current\t1\texternal-pair-is-sufficient\nexternal-temporal\t2\texternal-complement-closes-invitation\nexternal-reorientation\t2\texternal-closure-precedes-self\nself-sufficient\t1\tself-pair-cannot-certify\nsame-side\t1\tsame-side-cannot-complete\nexpired\t9\tlate-self-cannot-complete\ncross-owner\t1\twonder-ownership-is-closed\nliteral-human\t1\thuman-address-is-confounded\nliteral-self\t1\tself-address-is-confounded\nblind\t2x32\tA.65-sealed-external-life\nside-a\t2x32\tA.65-sealed-side-a-life\nside-b\t2x32\tA.65-sealed-side-b-life'
[ "$got" = "$expected" ] || {
    printf 'invalid appetite provenance shadow plan:\n%s\n' "$got" >&2
    exit 1
}

printf 'deferred Wonder appetite provenance shadow plan: ok\n'
