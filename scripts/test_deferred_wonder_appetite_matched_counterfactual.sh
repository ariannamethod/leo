#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_MATCHED_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_matched_counterfactual.sh"
)"
expected=$'case\ttrace\tcause\tobserve\tvariants\tcontract\nblind-307-nareth\tblind-307\t21\t24\t4\texact-state-semantic-factorial\nblind-401-nareth\tblind-401\t13\t13\t4\texact-state-semantic-factorial\nside-a-307-nareth\tside-a-307\t3\t6\t4\texact-state-semantic-factorial\nside-a-401-flom\tside-a-401\t26\t27\t4\texact-state-semantic-factorial'
[ "$got" = "$expected" ] || {
    printf 'invalid appetite matched counterfactual plan:\n%s\n' "$got" >&2
    exit 1
}

printf 'deferred Wonder appetite matched counterfactual plan: ok\n'
