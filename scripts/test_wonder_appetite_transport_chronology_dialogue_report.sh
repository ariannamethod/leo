#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-transport-chronology: epochs=2 attempts=16 min-arm=4 ceiling=0.500 unattested=0 pending=0 refuted=0 incompatible=0 observing=0 coverage-starved=0 aggregate-shifted=0 early-shifted=0 recent-shifted=0 both-shifted=0 ecology-shifted=0 provisional=1 cells=u62-70:134/32/1/1/138/198/16]
EOF

got="$(
    awk -v scenario=chronology-provisional -v seed=101 \
        -f "$ROOT/scripts/wonder_appetite_transport_chronology_dialogue_report.awk" \
        "$TMP"
)"
expected=$'chronology-provisional\t101\t2\t16\t4\t0.500\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t1\tu62-70:134/32/1/1/138/198/16'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite transport chronology parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite transport chronology report parser: ok\n'
