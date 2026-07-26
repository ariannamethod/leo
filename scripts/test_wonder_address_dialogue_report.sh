#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-address: turn=13 status=sibling-conflict winner=nareth active=suvin margin=1.000 guarded=1 entries=suvin:0.000/0/1|nareth:1.000/0/0]
EOF

got="$(
    awk -v scenario=sibling-semantic -v seed=771 \
        -f "$ROOT/scripts/wonder_address_dialogue_report.awk" "$TMP"
)"
expected=$'sibling-semantic\t771\t13\tsibling-conflict\tnareth\tsuvin\t1.000\t1\tsuvin:0.000/0/1|nareth:1.000/0/0'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder address parser output:\n%s\n' "$got" >&2
    exit 1
fi

printf 'Wonder address report parser: ok\n'
