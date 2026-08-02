#!/usr/bin/env bash
# A.83: decompose the exact A.82 crossover by existing similarity organ.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-organs-$STAMP}"
HOLISTIC_SOURCE="${LEO_STATE_ORGAN_HOLISTIC:-}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}

HOLISTIC="${HOLISTIC_SOURCE:-$OUT/holistic}"
ORGANS="$OUT/organs.tsv"
FACTORS="$OUT/factors.tsv"
VERDICT="$OUT/verdict.txt"

validate_holistic_logs() {
    tail -n +2 "$HOLISTIC/plan.tsv" |
    while IFS=$'\t' read -r cell cohort base_seed phase session order \
        texture run_seed persisted prompt; do
        [ "$phase" = writer ] || continue
        stem="s${session}-$(printf '%02d' "$order")-${phase}-${texture}"
        log="$HOLISTIC/lives/$cell/logs/$stem.on.log"
        [ -s "$log" ] || {
            printf 'holistic evidence log missing: %s\n' "$log" >&2
            exit 2
        }
    done
}

# The child runner owns the sealed cases, chronology, save/load boundary, and
# default/--no-state-swarm counterfactual. A.83 only reads its new receipts.
if [ -z "$HOLISTIC_SOURCE" ]; then
    mkdir -p "$OUT"
    "$ROOT/scripts/state_swarm_alphabet_matrix.sh" "$HOLISTIC" \
        > "$OUT/holistic.stdout"
else
    [ -s "$HOLISTIC/plan.tsv" ] && [ -s "$HOLISTIC/receipts.tsv" ] || {
        printf 'holistic evidence is incomplete: %s\n' "$HOLISTIC" >&2
        exit 2
    }
    validate_holistic_logs
    mkdir -p "$OUT"
fi

printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tevent\tstates\tmember_id\tholistic_activation\torgan_valid\tperception\texpression\town_field\tbody\trhythm\tform\tdarkmatter\tprompt\treply\n' \
    > "$ORGANS"

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

tail -n +2 "$HOLISTIC/plan.tsv" |
while IFS=$'\t' read -r cell cohort base_seed phase session order \
    texture run_seed persisted prompt; do
    [ "$phase" = writer ] || continue
    stem="s${session}-$(printf '%02d' "$order")-${phase}-${texture}"
    log="$HOLISTIC/lives/$cell/logs/$stem.on.log"
    [ -s "$log" ] || exit 1
    reply="$(reply_from_log "$log")"
    [ -n "$reply" ] || exit 1
    awk -v cell="$cell" -v cohort="$cohort" -v base_seed="$base_seed" \
        -v phase="$phase" -v session="$session" -v order="$order" \
        -v texture="$texture" -v run_seed="$run_seed" \
        -v prompt="$prompt" -v reply="$reply" \
        -f "$ROOT/scripts/state_swarm_organ_dialogue_report.awk" "$log" \
        >> "$ORGANS"
done

printf 'cell\tcohort\tbase_seed\torgan\tacquisition_turns\tacquisition_excluded\tmin_texture_acquisition\tmin_position_acquisition\tholdout_turns\tholdout_excluded\ttexture_hits\ttexture_accuracy\ttexture_margin\ttexture_similarity\tposition_hits\tposition_accuracy\tposition_margin\tposition_similarity\tverdict\n' \
    > "$FACTORS"
awk -f "$ROOT/scripts/state_swarm_organ_report.awk" "$ORGANS" |
    sort -t $'\t' -k1,1 -k4,4 >> "$FACTORS"

awk -F '\t' '
    NR == 1 { next }
    {
        rows++
        lives[$1]++
        organs[$4]++
        verdict[$4 SUBSEP $19]++
        texture_ok = $9 == 32 && $10 == 0 && $7 >= 4
        position_ok = $9 == 32 && $10 == 0 && $8 >= 2
        if (texture_ok) {
            texture_adequate[$4]++
            if ($12 >= 0.50 && $13 >= 0.02) texture[$4]++
        }
        if (position_ok) {
            position_adequate[$4]++
            if ($16 >= 0.25 && $17 >= 0.01) position[$4]++
        }
        if (!texture_ok || !position_ok) partial++
    }
    END {
        print "state-swarm organ factorization A.83"
        printf "rows=%d lives=%d organs=%d partial_coverage=%d\n",
               rows, length(lives), length(organs), partial + 0
        for (organ in organs) {
            if (texture[organ] >= 2 && position[organ] >= 2)
                status = "factorized"
            else if (texture[organ] >= 2) status = "texture-bearing"
            else if (position[organ] >= 2) status = "position-bearing"
            else status = "unformed"
            printf "%s texture_support=%d/%d position_support=%d/%d verdict=%s\n",
                   organ, texture[organ] + 0, texture_adequate[organ] + 0,
                   position[organ] + 0, position_adequate[organ] + 0, status
        }
        print "chance: texture=0.250 position=0.125"
        print "birth/replacement turns are excluded: their new slot has no pre-update prototype"
        print "all organ names and classifiers remain laboratory-only; no update or speech reader changed"
        if (rows != 21 || length(lives) != 3 || length(organs) != 7) exit 1
        for (organ in organs)
            if (organs[organ] != 3 || texture_adequate[organ] < 2 ||
                position_adequate[organ] < 2) exit 1
    }
' "$FACTORS" | sort > "$VERDICT"

cat "$FACTORS"
printf '\n'
cat "$VERDICT"
printf '\nholistic evidence: %s\norgan receipts: %s\n' \
    "$HOLISTIC" "$ORGANS"
