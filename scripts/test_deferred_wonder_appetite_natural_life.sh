#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_NATURAL_LIFE_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_natural_life.sh"
)"
expected=$'case\tbirth_turns\tembodiment_turns\tsettle_turns\tlives\tturns_per_life\tinterlocutor\tfuture_at_proposal\toutcome_assignment\nnatural-visible\t8\t7\t8\t3\t64\tlocal-visible-followup-v1\tnot-born\tnone'
[ "$got" = "$expected" ] || {
    printf 'invalid appetite natural life plan:\n%s\n' "$got" >&2
    exit 1
}

[ "$("$ROOT/scripts/leo_visible_followup.sh" \
    2 "He holds a candle near the window.")" = \
  "What is candle like?" ]
[ "$("$ROOT/scripts/leo_visible_followup.sh" 3 "A. A.")" = \
  "What do you remember?" ]
[ "$("$ROOT/scripts/leo_visible_followup.sh" \
    --word 4 "His grandmother waits.")" = grandmother ]
[ "$("$ROOT/scripts/leo_visible_followup.sh" \
    4 "His grandmother waits.")" = \
  "What happens beside grandmother?" ]

printf 'deferred Wonder appetite natural life plan: ok\n'
