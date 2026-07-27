#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-drift: measured=1 forming=1 stable=0 rising=1 falling=0 cells=u62-70:8/0/4/0.690/0.690/0.000/1.000/0.000/0.490/0.510/1.000/0.476/0.096/+1.000/+0.000/+1.000/-0.380/rising|s80-90:1/0/0/0.000/0.000/0.000/0.000/0.000/0.000/0.000/0.000/0.000/0.000/+0.000/+0.000/+0.000/+0.000/forming]
EOF

got="$(
    awk -v scenario=old -v seed=83 \
        -f "$ROOT/scripts/wonder_appetite_drift_dialogue_report.awk" \
        "$TMP"
)"
expected=$'old\t83\t1\t1\t0\t1\t0\tu62-70:8/0/4/0.690/0.690/0.000/1.000/0.000/0.490/0.510/1.000/0.476/0.096/+1.000/+0.000/+1.000/-0.380/rising|s80-90:1/0/0/0.000/0.000/0.000/0.000/0.000/0.000/0.000/0.000/0.000/0.000/+0.000/+0.000/+0.000/+0.000/forming'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite drift parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite drift report parser: ok\n'
