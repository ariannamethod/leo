#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-information-fixture.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

"${CC:-cc}" "$ROOT/tests/state_swarm_road_information_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$TMP/road-information-fixture" -lpthread
set +e
"$TMP/road-information-fixture" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || {
    printf 'road information fixture accepted missing arguments: rc=%s\n' \
        "$rc" >&2
    exit 1
}

printf 'state-swarm road information fixture: ok\n'
