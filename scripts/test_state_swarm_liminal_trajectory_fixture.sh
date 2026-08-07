#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-liminal-fixture.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

"${CC:-cc}" "$ROOT/tests/state_swarm_liminal_trajectory_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/liminal-trajectory-fixture" -lpthread

set +e
"$TMP/liminal-trajectory-fixture" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || {
    printf 'liminal fixture accepted a missing mode: rc=%s\n' "$rc" >&2
    exit 1
}

printf 'state-swarm liminal trajectory fixture: ok\n'
