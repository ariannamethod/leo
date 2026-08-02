#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-anatomy-log-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/updated.log" <<'EOF'
     [state-swarm: turn=12 states=2 active=1 winner=2 event=updated similarity=0.700 entropy=0.500 members=1:0.100,2:0.900 organs=1:0.100000/0.100000/0.100000/0.100000/0.100000/0.100000/0.100000,2:0.700000/0.700000/0.700000/0.700000/0.700000/0.700000/0.700000 nearest=2 nearest_organs=0.700000/0.700000/0.700000/0.700000/0.700000/0.700000/0.700000 adjacent=1]
EOF
cat > "$TMP/replaced.log" <<'EOF'
     [state-swarm: turn=19 states=2 active=1 winner=3 event=replaced similarity=0.350 entropy=0.000 members=1:0.000,3:1.000 organs=1:0.200000/0.200000/0.200000/0.200000/0.200000/0.200000/0.200000,3:na nearest=2 nearest_organs=0.350000/0.350000/0.350000/0.350000/0.350000/0.350000/0.350000 adjacent=1 replaced=2 removed_organs=0.350000/0.350000/0.350000/0.350000/0.350000/0.350000/0.350000]
EOF

awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" \
    "$TMP/updated.log" > "$TMP/updated.tsv"
awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" \
    "$TMP/replaced.log" > "$TMP/replaced.tsv"

awk -F '\t' 'NF != 10 || $1 != 12 || $2 != "updated" || $3 != 2 ||
    $6 != 0 || $7 != 2 || $9 != "na" { exit 1 }' "$TMP/updated.tsv"
awk -F '\t' 'NF != 10 || $1 != 19 || $2 != "replaced" || $3 != 3 ||
    $6 != 2 || $7 != 2 || $9 == "na" { exit 1 }' "$TMP/replaced.tsv"

sed 's/similarity=0.350/similarity=0.450/' "$TMP/replaced.log" \
    > "$TMP/bad.log"
if awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" \
    "$TMP/bad.log" >/dev/null 2>&1; then
    printf 'anatomy parser accepted a false nearest reconstruction\n' >&2
    exit 1
fi

printf 'state-swarm displacement anatomy log parser: ok\n'
