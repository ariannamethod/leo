#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
got="$(
    LEO_APPETITE_VISIBLE_SIGNAL_PLAN_ONLY=1 \
        "$ROOT/scripts/deferred_wonder_appetite_visible_signal.sh"
)"
expected=$'case\tlife_turns\tforecasts\thigh_sources\tlow_sources\tproposal_signal\toutcome_schedule\tplan_visibility\nvisible-history\t351\t32\t2\t2\tspoken-open-vs-unspoken-deferred\t7/8-vs-5/8\tsealed-before-replies'

[ "$got" = "$expected" ] || {
    printf 'invalid appetite visible signal plan:\n%s\n' "$got" >&2
    exit 1
}
printf 'deferred Wonder appetite visible signal plan: ok\n'
