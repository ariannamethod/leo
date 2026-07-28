#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-checkpoint: budget=32 epochs=2 history=2 active=0 terminal=2 blocked=0 cells=u62-70:390/0/0/0/0/empty/2/134/262/provisional/16/8/8/1/1/16/8/8/1/1/262/390/provisional/16/8/8/1/1/16/8/8/1/1]
     [wonder-appetite-checkpoint-sequence: one=0 stable-provisional=1 emerging-shift=0 persistent-shift=0 recovered=0 insufficient=0 incompatible=0 cells=u62-70:2/provisional/provisional/1/stable-provisional]
EOF

got="$(
    awk -v scenario=checkpoint-stable -v seed=5501 \
        -f "$ROOT/scripts/wonder_appetite_checkpoint_dialogue_report.awk" \
        "$TMP"
)"
expected=$'checkpoint-stable\t5501\t32\t2\t2\t0\t2\t0\tu62-70:390/0/0/0/0/empty/2/134/262/provisional/16/8/8/1/1/16/8/8/1/1/262/390/provisional/16/8/8/1/1/16/8/8/1/1\t0\t1\t0\t0\t0\t0\t0\tu62-70:2/provisional/provisional/1/stable-provisional'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite checkpoint parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite checkpoint report parser: ok\n'
