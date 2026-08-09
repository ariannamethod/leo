#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-transition-consequence-fixture.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

"${CC:-cc}" "$ROOT/tests/state_swarm_transition_consequence_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/transition-consequence-fixture" -lpthread
set +e
"$TMP/transition-consequence-fixture" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || {
    printf 'transition consequence fixture accepted a missing mode: rc=%s\n' \
        "$rc" >&2
    exit 1
}

printf 'state-swarm transition consequence fixture: ok\n'
