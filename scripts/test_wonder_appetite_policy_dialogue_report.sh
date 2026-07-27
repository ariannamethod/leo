#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-policy: eligible=1 forming=2 uncalibrated=3 drifting=4 legacy=5 none=6 supported=7 overreach=8 missed=9 restraint=10 confounded=11 pending=12 entries=policy:42/0.650/0/8/aligned/stable/eligible/supported]
EOF

got="$(
    awk -v scenario=stable-return -v seed=83 \
        -f "$ROOT/scripts/wonder_appetite_policy_dialogue_report.awk" \
        "$TMP"
)"
expected=$'stable-return\t83\t1\t2\t3\t4\t5\t6\t7\t8\t9\t10\t11\t12\tpolicy:42/0.650/0/8/aligned/stable/eligible/supported'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite policy parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite policy report parser: ok\n'
