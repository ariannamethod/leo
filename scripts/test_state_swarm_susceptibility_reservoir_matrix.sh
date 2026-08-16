#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-susceptibility-reservoir-plan.XXXXXX")"
trap 'rc=$?; rm -rf "$TMP"; exit "$rc"' EXIT

CANDIDATES="$ROOT/scripts/state_swarm_susceptibility_reservoir_candidates.tsv"
CASES="$ROOT/scripts/state_swarm_alphabet_cases.tsv"

awk -F '\t' '
    NR == 1 {
        if (NF != 3 || $1 != "life" || $2 != "split" || $3 != "base_seed") exit 1
        next
    }
    {
        rows++
        expected_life = rows <= 40 ? sprintf("p%02d", rows) : sprintf("h%02d", rows - 40)
        expected_split = rows <= 40 ? "primary" : "holdout"
        expected_seed = 771123 + (rows - 1) * 1033
        if ($1 != expected_life || $2 != expected_split || $3 != expected_seed || seed[$3]++) exit 1
    }
    END { if (rows != 80) exit 1 }
' "$CANDIDATES"

new_first="$(sed -n '2p' "$CANDIDATES" | awk -F '\t' '{ print $3 }')"
[ "$new_first" -eq $((770090 + 1033)) ]

printf 'life\tsplit\tbase_seed\tcandidate_order\tenrollment_rank\n' > "$TMP/enrollment.tsv"
for cohort in primary holdout; do
    prefix=p; base=300001
    [ "$cohort" = holdout ] && prefix=h && base=400001
    for rank in {1..16}; do
        printf '%s%02d\t%s\t%s\t%s\t%s\n' \
            "$prefix" "$rank" "$cohort" "$((base + rank * 1000))" "$rank" "$rank" \
            >> "$TMP/enrollment.tsv"
    done
done

awk -v primary_expected=16 -v holdout_expected=16 \
    -f "$ROOT/scripts/state_swarm_williams8_writer_plan.awk" \
    "$CASES" "$TMP/enrollment.tsv" > "$TMP/writer-plan.tsv"

awk -F '\t' '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        if ($1 == "writer") source[$5] = $2
        next
    }
    FNR == 1 {
        if (NF != 9 || $1 != "life" || $5 != "session" || $9 != "prompt") exit 1
        next
    }
    {
        rows++; life_rows[$1]++
        source_session = source[$9]
        if (!source_session || $7 !~ /^(home|storm|wonder|social)$/ ||
            $8 != $3 + $5 * 100 + $6) exit 1
        key = $1 SUBSEP $5
        if (!(key in life_source)) life_source[key] = source_session
        else if (life_source[key] != source_session) exit 1
        if ($6 == 1) {
            position[$2 SUBSEP $5 SUBSEP source_session]++
            if ($5 > 1) carry[$2 SUBSEP previous[$1] SUBSEP source_session]++
            if ($5 >= 5) {
                score_block = int(((substr($1, 2) + 0) - 1) / 16) + 1
                score_position[$2 SUBSEP score_block SUBSEP $5 SUBSEP source_session]++
                score_carry[$2 SUBSEP score_block SUBSEP previous[$1] SUBSEP source_session]++
            }
            previous[$1] = source_session
        }
    }
    END {
        if (rows != 32 * 64 || length(life_rows) != 32) exit 1
        for (life in life_rows) if (life_rows[life] != 64) exit 1
        for (c = 1; c <= 2; c++) {
            cohort = c == 1 ? "primary" : "holdout"
            for (position_index = 1; position_index <= 8; position_index++)
                for (source_session = 1; source_session <= 8; source_session++)
                    if (position[cohort SUBSEP position_index SUBSEP source_session] != 2) exit 1
            for (source_session = 1; source_session <= 8; source_session++)
                for (destination = 1; destination <= 8; destination++) {
                    observed = carry[cohort SUBSEP source_session SUBSEP destination] + 0
                    if ((source_session == destination && observed != 0) ||
                        (source_session != destination && observed != 2)) exit 1
                }
            for (source_session = 1; source_session <= 8; source_session++)
                for (destination = 1; destination <= 8; destination++) {
                    observed = score_carry[cohort SUBSEP 1 SUBSEP source_session SUBSEP destination] + 0
                    expected = source_session == destination ? 0 : \
                        (destination == ((source_session - 1 + 4) % 8) + 1 ? 2 : 1)
                    if (observed != expected) exit 1
                }
        }
    }
' "$CASES" "$TMP/writer-plan.tsv"

LEO_STATE_PROSPECTIVE_PLAN_ONLY=1 \
    "$ROOT/scripts/state_swarm_susceptibility_reservoir_matrix.sh" "$TMP/run" \
    > "$TMP/plan.stdout"
cmp -s "$TMP/run/screen-plan.tsv" "$TMP/plan.stdout"
[ ! -e "$TMP/run/writer-plan.tsv" ]
awk -F '\t' '
    NR == 1 { next }
    { rows++; lives[$1]++; if ($4 != "warm" || seed[$1 SUBSEP $8]++) exit 1 }
    END {
        if (rows != 2560 || length(lives) != 80) exit 1
        for (life in lives) if (lives[life] != 32) exit 1
    }
' "$TMP/run/screen-plan.tsv"

printf 'state-swarm susceptibility reservoir plan: ok\n'
