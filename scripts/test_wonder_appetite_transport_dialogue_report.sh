#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-transport: min-arm=8 ceiling=0.500 unattested=0 pending=0 refuted=0 incompatible=0 observing=0 shifted=0 provisional=1 cells=u62-70:134/16/16/8/8/7/1/1/7/0/0/0/0.500/0.280/0.720/0.500/0.280/0.720/0.500/0.280/0.720/0.125/0.471/0.125/0.471/1/1/1/provisional]
EOF

got="$(
    awk -v scenario=transport-provisional -v seed=101 \
        -f "$ROOT/scripts/wonder_appetite_transport_dialogue_report.awk" \
        "$TMP"
)"
expected=$'transport-provisional\t101\t8\t0.500\t0\t0\t0\t0\t0\t0\t1\tu62-70:134/16/16/8/8/7/1/1/7/0/0/0/0.500/0.280/0.720/0.500/0.280/0.720/0.500/0.280/0.720/0.125/0.471/0.125/0.471/1/1/1/provisional'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite transport parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite transport report parser: ok\n'
