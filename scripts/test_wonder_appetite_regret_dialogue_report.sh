#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<'EOF'
     [wonder-appetite-regret: scored=16 eligible=8 abstained=8 supported=5 overreach=3 missed=3 restraint=5 policy-forming=4 policy-uncalibrated=0 policy-drifting=4 pending=0 confounded=0 legacy=0 none=0 coverage=0.500 overreach-axis=0.375/0.137/0.694 missed-axis=0.375/0.137/0.694 forming-cells=0 eligible-cells=1 abstention-cells=1 paired-cells=1 cells=u62-70:8/4/4/1/3/1/3/4/0/0/0.500/0.750/0.301/0.954/0.250/0.046/0.699/paired]
EOF

got="$(
    awk -v scenario=motion-heavy -v seed=83 \
        -f "$ROOT/scripts/wonder_appetite_regret_dialogue_report.awk" \
        "$TMP"
)"
expected=$'motion-heavy\t83\t16\t8\t8\t5\t3\t3\t5\t4\t0\t4\t0\t0\t0\t0\t0.500\t0.375/0.137/0.694\t0.375/0.137/0.694\t0\t1\t1\t1\tu62-70:8/4/4/1/3/1/3/4/0/0/0.500/0.750/0.301/0.954/0.250/0.046/0.699/paired'

if [ "$got" != "$expected" ]; then
    printf 'unexpected Wonder appetite regret parser output:\n%s\n' \
        "$got" >&2
    exit 1
fi

printf 'Wonder appetite regret report parser: ok\n'
