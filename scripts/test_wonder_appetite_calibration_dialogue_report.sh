#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-calibration: turn=17 pending=0 scored=1 confirmed=1 external=0 lost=0 unscorable=0 brier=0.032 entries=suvin:14/17/17/0.820/0.911/1/3/1/sustained/0.032]
EOF

got="$(
    awk -v scenario=parked-sustained -v seed=83 \
        -f "$ROOT/scripts/wonder_appetite_calibration_dialogue_report.awk" \
        "$TMP"
)"
expected=$'parked-sustained\t83\t17\t0\t1\t1\t0\t0\t0\t0.032\tsuvin:14/17/17/0.820/0.911/1/3/1/sustained/0.032'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite calibration parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite calibration report parser: ok\n'
