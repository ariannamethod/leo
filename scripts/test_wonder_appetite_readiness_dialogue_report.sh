#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-readiness: ceiling=0.500 min-arm=8 forming=0 unpaired=0 observing=0 motion-unbounded=0 restraint-unbounded=0 both-unbounded=0 candidate=1 cells=u62-70:16/8/8/0.500/0.125/0.471/0.125/0.471/0.029/0.029/candidate]
EOF

got="$(
    awk -v scenario=candidate -v seed=97 \
        -f "$ROOT/scripts/wonder_appetite_readiness_dialogue_report.awk" \
        "$TMP"
)"
expected=$'candidate\t97\t0.500\t8\t0\t0\t0\t0\t0\t0\t1\tu62-70:16/8/8/0.500/0.125/0.471/0.125/0.471/0.029/0.029/candidate'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite readiness parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite readiness report parser: ok\n'
