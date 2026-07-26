#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [pre-wonder-shadow: turn=12 status=confident winner=suvin margin=0.906 pending=none entries=suvin:1.000/0.528/0.906/0|nareth:0.000/0.000/0.000/0]
EOF

got="$(
    awk -v scenario=semantic-1 -v seed=83 \
        -f "$ROOT/scripts/prewonder_shadow_dialogue_report.awk" "$TMP"
)"
expected=$'semantic-1\t83\t12\tconfident\tsuvin\t0.906\tnone\tsuvin:1.000/0.528/0.906/0|nareth:0.000/0.000/0.000/0'

if [ "$got" != "$expected" ]; then
    printf 'unexpected pre-Wonder shadow parser output:\n%s\n' "$got" >&2
    exit 1
fi

printf 'pre-Wonder shadow report parser: ok\n'
