#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-admission: attested=1 legacy=0 cells=u62-70:73/70/16/8/8/7/1/1/7/0.125/0.471/0.125/0.471/attested]
EOF

got="$(
    awk -v scenario=armed -v seed=101 \
        -f "$ROOT/scripts/wonder_appetite_admission_dialogue_report.awk" \
        "$TMP"
)"
expected=$'armed\t101\t1\t0\tu62-70:73/70/16/8/8/7/1/1/7/0.125/0.471/0.125/0.471/attested'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite admission parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite admission report parser: ok\n'
