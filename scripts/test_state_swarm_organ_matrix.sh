#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-organ-matrix.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEO_STATE_ALPHABET_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_alphabet_matrix.sh" "$TMP/plan" \
    > "$TMP/plan.tsv"

mkdir -p "$TMP/incomplete-holistic"
cp "$TMP/plan.tsv" "$TMP/incomplete-holistic/plan.tsv"
printf 'receipt\n' > "$TMP/incomplete-holistic/receipts.tsv"
if LEO_STATE_ORGAN_HOLISTIC="$TMP/incomplete-holistic" \
    "$ROOT/scripts/state_swarm_organ_matrix.sh" "$TMP/incomplete-output" \
    > "$TMP/incomplete.out" 2> "$TMP/incomplete.err"; then
    printf 'external holistic evidence without raw logs unexpectedly passed\n' >&2
    exit 1
fi
grep -Fx "holistic evidence log missing: $TMP/incomplete-holistic/lives/river/logs/s1-01-writer-home.on.log" \
    "$TMP/incomplete.err" >/dev/null
[ ! -e "$TMP/incomplete-output" ]

printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tevent\tstates\tmember_id\tholistic_activation\torgan_valid\tperception\texpression\town_field\tbody\trhythm\tform\tdarkmatter\tprompt\treply\n' \
    > "$TMP/organs.tsv"

awk -F '\t' '
    BEGIN { OFS = "\t"; texture["home"] = 1; texture["storm"] = 2;
            texture["wonder"] = 3; texture["social"] = 4 }
    NR == 1 || $4 != "writer" { next }
    {
        turn++
        for (id = 1; id <= 8; id++) {
            perception = id == texture[$7] ? 0.9 : 0.1
            expression = id == $6 ? 0.9 : 0.1
            print $1, $2, $3, $4, $5, $6, $7, $8, turn, "updated", 8,
                  id, "0.125", 1, perception, expression,
                  "0.5", "0.5", "0.5", "0.5", "0.5", $10, "reply"
        }
    }
' "$TMP/plan.tsv" >> "$TMP/organs.tsv"

awk -f "$ROOT/scripts/state_swarm_organ_report.awk" "$TMP/organs.tsv" \
    | sort -t $'\t' -k4,4 > "$TMP/factors.tsv"

awk -F '\t' '
    {
        rows++
        if (NF != 19 || $5 != 32 || $6 != 0 || $7 != 8 || $8 != 4 ||
            $9 != 32 || $10 != 0) exit 1
        if ($4 == "perception") {
            perception++
            if ($11 != 32 || $12 != "1.000000" || $13 < 0.02 ||
                $15 != 0 || $19 != "texture-bearing") exit 1
        } else if ($4 == "expression") {
            expression++
            if ($11 != 0 || $15 != 32 || $16 != "1.000000" ||
                $17 < 0.01 || $19 != "position-bearing") exit 1
        } else {
            neutral++
            if ($11 != 0 || $15 != 0 || $19 != "unformed") exit 1
        }
    }
    END {
        if (rows != 21 || perception != 3 || expression != 3 || neutral != 15)
            exit 1
    }
' "$TMP/factors.tsv"

printf 'state-swarm organ factorization scorer: ok\n'
