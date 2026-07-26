#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite: turn=14 status=salient winner=suvin margin=0.619 pending=nareth entries=suvin:1.000/0.125/1.000/1.000/0.869/1/0|flom:0.000/1.000/0.500/0.000/0.250/0/0]
EOF

got="$(
    awk -v scenario=parked-return -v seed=83 \
        -f "$ROOT/scripts/wonder_appetite_dialogue_report.awk" "$TMP"
)"
expected=$'parked-return\t83\t14\tsalient\tsuvin\t0.619\tnareth\tsuvin:1.000/0.125/1.000/1.000/0.869/1/0|flom:0.000/1.000/0.500/0.000/0.250/0/0'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite parser output:\n%s\n' "$got" >&2
    exit 1
fi

printf 'Wonder appetite report parser: ok\n'
