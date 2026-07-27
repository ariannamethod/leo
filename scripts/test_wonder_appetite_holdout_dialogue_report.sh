#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-holdout: budget=16 min-arm=4 ceiling=0.500 pending=0 confirmed=1 motion-failed=0 restraint-failed=0 both-failed=0 coverage-starved=0 invalidated=0 cells=u62-70:73/70/16/16/8/8/7/1/1/7/0/0/0.125/0.471/0.125/0.471/confirmed/74,78]
EOF

got="$(
    awk -v scenario=confirmed -v seed=101 \
        -f "$ROOT/scripts/wonder_appetite_holdout_dialogue_report.awk" \
        "$TMP"
)"
expected=$'confirmed\t101\t16\t4\t0.500\t0\t1\t0\t0\t0\t0\t0\tu62-70:73/70/16/16/8/8/7/1/1/7/0/0/0.125/0.471/0.125/0.471/confirmed/74,78'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite holdout parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite holdout report parser: ok\n'
