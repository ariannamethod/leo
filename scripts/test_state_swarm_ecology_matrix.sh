#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-ecology-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/receipt.log" <<'EOF'
     [state-swarm: turn=7 states=3 active=2 winner=2 event=updated similarity=0.731 entropy=0.642 members=1:0.200,2:0.700,4:0.100 adjacent=1 observed=1.000/-0.250/0.125/0.000 expected=1(0.600) overlap=0.320 surprise=1.139 forecast=0.250/-0.100/0.050/0.020 clocks=0.91/0.95/0.98/1.00]
EOF

got="$(
    awk -v cell=fixture -v cohort=replication -v base_seed=83 \
        -v phase=writer -v session=2 -v order=3 -v texture=home \
        -v run_seed=286 -v prompt='The room is quiet.' \
        -v reply='The night. Wind.' \
        -f "$ROOT/scripts/state_swarm_dialogue_report.awk" \
        "$TMP/receipt.log"
)"
printf '%s\n' "$got" > "$TMP/receipt.tsv"
awk -F '\t' '
    NR == 1 {
        ok = NF == 34 && $1 == "fixture" && $4 == "writer" &&
             $5 == "2" && $7 == "home" && $9 == "7" &&
             $10 == "3" && $11 == "2" && $12 == "2" &&
             $13 == "updated" && $16 == "1:0.200,2:0.700,4:0.100" &&
             $17 == "1.000" && $18 == "1" && $19 == "0" &&
             $20 == "1" && $21 == "1" && $22 == "0.600" &&
             $23 == "0.320" && $24 == "1.139" &&
             $25 == "1.000" && $26 == "-0.250" &&
             $29 == "0.250" && $32 == "0.020" &&
             $33 == "The room is quiet." && $34 == "The night. Wind."
    }
    END { exit !(ok && NR == 1) }
' "$TMP/receipt.tsv"

cat > "$TMP/first.log" <<'EOF'
     [state-swarm: turn=1 states=1 active=1 winner=1 event=born similarity=0.000 entropy=0.000 members=1:1.000 adjacent=0 clocks=1.00/1.00/1.00/1.00]
EOF
first="$(
    awk -v cell=first -v cohort=replication -v base_seed=83 \
        -v phase=writer -v session=1 -v order=1 -v texture=home \
        -v run_seed=184 -v prompt=quiet -v reply=small \
        -f "$ROOT/scripts/state_swarm_dialogue_report.awk" \
        "$TMP/first.log"
)"
printf '%s\n' "$first" | awk -F '\t' '
    NR == 1 {
        ok = NF == 34 && $18 == 0 && $20 == 0 && $21 == 0 &&
             $25 == "na" && $29 == "na"
    }
    END { exit !ok }
'

cat > "$TMP/bad.log" <<'EOF'
     [state-swarm: turn=7 states=2 active=1 winner=1 event=updated similarity=0.700 entropy=0.500 members=1:0.400,2:0.400 adjacent=1 observed=0.000/0.000/0.000/0.000 clocks=1.00/1.00/1.00/1.00]
EOF
if awk -v cell=bad -v cohort=bad -v base_seed=1 -v phase=writer \
       -v session=1 -v order=1 -v texture=home -v run_seed=1 \
       -v prompt=bad -v reply=bad \
       -f "$ROOT/scripts/state_swarm_dialogue_report.awk" \
       "$TMP/bad.log" >/dev/null 2>&1; then
    printf 'state-swarm parser accepted an activation mass below one\n' >&2
    exit 1
fi

OUT="$TMP/plan"
LEO_STATE_ECOLOGY_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_ecology_matrix.sh" "$OUT" \
    > "$TMP/plan.out"
cmp -s "$OUT/plan.tsv" "$TMP/plan.out"

awk -F '\t' '
    NR == 1 {
        if (NF != 10 || $1 != "cell" || $2 != "cohort" ||
            $3 != "base_seed" || $4 != "phase" || $5 != "session" ||
            $6 != "order" || $7 != "texture" || $8 != "run_seed" ||
            $9 != "persisted" || $10 != "prompt")
            exit 1
        next
    }
    {
        rows++
        lives[$1]++
        cohorts[$2]++
        sessions[$1 SUBSEP $5]++
        textures[$7]++
        slot = $1 SUBSEP $4 SUBSEP $5 SUBSEP $6
        if (seen_slot[slot]++) exit 1
        if ($4 == "writer") {
            writers[$1]++
            if ($9 != 1 || writer_seed[$1 SUBSEP $8]++) exit 1
            if (writer_prompt[$1 SUBSEP $10]++) exit 1
        } else if ($4 == "probe") {
            probes[$1]++
            if ($9 != 0) exit 1
            key = $1 SUBSEP $7
            if (!(key in probe_seed)) probe_seed[key] = $8
            else if (probe_seed[key] != $8) exit 1
            probe_texture[$1 SUBSEP $5 SUBSEP $7]++
        } else {
            exit 1
        }
    }
    END {
        if (rows != 108 || length(lives) != 3 ||
            cohorts["replication"] != 72 || cohorts["confirmatory"] != 36 ||
            length(sessions) != 9 || length(probe_texture) != 36)
            exit 1
        for (cell in lives)
            if (lives[cell] != 36 || writers[cell] != 24 || probes[cell] != 12)
                exit 1
        for (key in sessions) if (sessions[key] != 12) exit 1
        for (key in probe_texture) if (probe_texture[key] != 1) exit 1
    }
' "$TMP/plan.out"

printf 'state-swarm ecology parser and sealed plan: ok\n'
