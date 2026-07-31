#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTUAL="$(
    LEO_WONDER_SCOPE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_answer_scope_life.sh"
)"
EXPECTED="$(
    printf 'source\tcases\tcontinued\tresolved\tfollowups\tprocesses\tcontract\n'
    printf 'A.76\t10\t4\t6\t10\t21\tstatement-scope-before-evidence'
)"
[ "$ACTUAL" = "$EXPECTED" ] || {
    printf 'unexpected A.76 answer-scope plan\n%s\n' "$ACTUAL" >&2
    exit 1
}
printf 'deferred Wonder answer-scope life plan: ok\n'
