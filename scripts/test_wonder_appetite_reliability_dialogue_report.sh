#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-reliability: scored=5 positives=4 sustained=4 grounded=0 faded=1 pending=0 external=0 lost=0 unscorable=0 brier=0.165 ece=0.111 cells=u62-70:4/3/0.690/0.750/0.301/0.954/0.197/+0.060/aligned|s80-90:1/1/0.820/1.000/0.207/1.000/0.032/+0.180/forming]
EOF

got="$(
    awk -v scenario=old -v seed=83 \
        -f "$ROOT/scripts/wonder_appetite_reliability_dialogue_report.awk" \
        "$TMP"
)"
expected=$'old\t83\t5\t4\t4\t0\t1\t0\t0\t0\t0\t0.165\t0.111\tu62-70:4/3/0.690/0.750/0.301/0.954/0.197/+0.060/aligned|s80-90:1/1/0.820/1.000/0.207/1.000/0.032/+0.180/forming'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite reliability parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite reliability report parser: ok\n'
