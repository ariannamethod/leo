#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTUAL="$(
    LEO_WONDER_COMMA_SCOPE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_comma_scope_life.sh"
)"
EXPECTED="$(
    printf 'source\tcases\tcontinued\tresolved\tfollowups\tprocesses\tcontract\n'
    printf 'A.77\t10\t1\t9\t10\t21\tclause-bearing-comma-scope'
)"
[ "$ACTUAL" = "$EXPECTED" ] || {
    printf 'unexpected A.77 comma-scope plan\n%s\n' "$ACTUAL" >&2
    exit 1
}
printf 'deferred Wonder comma-scope life plan: ok\n'
