#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-organ-parser.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/updated.log" <<'EOF'
     [state-swarm: turn=7 states=2 active=2 winner=2 event=updated similarity=0.731 entropy=0.642 members=1:0.300,2:0.700 organs=1:0.100000/0.200000/0.300000/0.400000/0.500000/0.600000/0.700000,2:0.700000/0.600000/0.500000/0.400000/0.300000/0.200000/0.100000 adjacent=1 clocks=0.91/0.95/0.98/1.00]
EOF

awk -v cell=river -v cohort=replication -v base_seed=11801 \
    -v phase=writer -v session=3 -v order=7 -v texture=wonder \
    -v run_seed=12108 -v prompt='What moved?' -v reply='The light moved.' \
    -f "$ROOT/scripts/state_swarm_organ_dialogue_report.awk" \
    "$TMP/updated.log" > "$TMP/updated.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 23 || $9 != 7 || $10 != "updated" || $11 != 2 ||
            $12 != 1 || $13 != "0.300" || $14 != 1 ||
            $15 != "0.100000" || $21 != "0.700000") exit 1
    }
    NR == 2 {
        if (NF != 23 || $12 != 2 || $13 != "0.700" || $14 != 1 ||
            $15 != "0.700000" || $21 != "0.100000") exit 1
    }
    END { if (NR != 2) exit 1 }
' "$TMP/updated.tsv"

cat > "$TMP/born.log" <<'EOF'
     [state-swarm: turn=3 states=2 active=1 winner=2 event=born similarity=0.320 entropy=0.000 members=1:0.000,2:1.000 organs=1:0.100000/0.200000/0.300000/0.400000/0.500000/0.600000/0.700000,2:na adjacent=1 clocks=1.00/1.00/1.00/1.00]
EOF

awk -v cell=river -v cohort=replication -v base_seed=11801 \
    -v phase=writer -v session=1 -v order=3 -v texture=storm \
    -v run_seed=11904 -v prompt='Where?' -v reply='Near the rain.' \
    -f "$ROOT/scripts/state_swarm_organ_dialogue_report.awk" \
    "$TMP/born.log" > "$TMP/born.tsv"

awk -F '\t' '
    NR == 1 { if ($12 != 1 || $14 != 1 || $15 == "na") exit 1 }
    NR == 2 {
        if ($12 != 2 || $14 != 0) exit 1
        for (i = 15; i <= 21; i++) if ($i != "na") exit 1
    }
    END { if (NR != 2) exit 1 }
' "$TMP/born.tsv"

if awk -f "$ROOT/scripts/state_swarm_organ_dialogue_report.awk" \
    "$TMP/updated.log" >/dev/null 2>&1; then
    printf 'organ parser accepted missing metadata\n' >&2
    exit 1
fi

printf 'state-swarm organ receipt parser: ok\n'
