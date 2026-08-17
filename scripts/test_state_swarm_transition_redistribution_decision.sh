#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-transition-redistribution-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

awk -v OFS='\t' '
    function activation(active_index,    i, value) {
        value = ""
        for (i = 1; i <= 8; i++) value = value (i == 1 ? "" : "/") \
            sprintf("%.9f", i == active_index ? 1 : 0)
        return value
    }
    function matrix_value(    i, value, total) {
        value = ""
        total = 0
        for (i = 1; i <= 64; i++) {
            value = value (i == 1 ? "" : "/") sprintf("%.9f", matrix[i])
            total += matrix[i]
        }
        matrix_total = total
        return value
    }
    BEGIN {
        print "cohort", "life", "split", "rank", "rotation", "session", \
            "order", "source_order", "texture", "event", "reply", \
            "pre_turn", "pre_ids", "source", "transition", \
            "transition_total", "post_turn", "post_ids", "target", \
            "has_prediction"
        texture[1] = "home"; texture[2] = "storm"
        texture[3] = "home"; texture[4] = "wonder"
        texture[5] = "social"; texture[6] = "home"
        texture[7] = "storm"; texture[8] = "home"
        ids = "1/2/3/4/5/6/7/8"
        for (split_number = 1; split_number <= 2; split_number++) {
            split_name = split_number == 1 ? "primary" : "holdout"
            prefix = split_number == 1 ? "p" : "h"
            for (rank = 17; rank <= 32; rank++) {
                life = sprintf("%s%02d", prefix, rank)
                rotation = (rank - 17) % 8
                for (i = 1; i <= 64; i++) matrix[i] = 0.1
                turn = 0
                for (session = 1; session <= 6; session++)
                    for (order = 1; order <= 8; order++) {
                        turn++
                        source_index = ((turn - 1) % 8) + 1
                        target_index = (turn % 8) + 1
                        source_order = ((order - 1 + rotation) % 8) + 1
                        transition = matrix_value()
                        print "discovery", life, split_name, rank, rotation, \
                            session, order, source_order, texture[source_order], \
                            "updated", "synthetic", 100 + turn - 1, ids, \
                            activation(source_index), transition, \
                            sprintf("%.9f", matrix_total), 100 + turn, ids, \
                            activation(target_index), 1
                        for (i = 1; i <= 8; i++)
                            for (j = 1; j <= 8; j++) {
                                k = (i - 1) * 8 + j
                                pair = i == source_index && j == target_index ? 1 : 0
                                matrix[k] = 0.997 * matrix[k] + 0.20 * pair
                            }
                    }
            }
        }
    }
' > "$TMP/raw.tsv"

awk -f "$ROOT/scripts/state_swarm_transition_redistribution_report.awk" \
    "$TMP/raw.tsv" > "$TMP/scores.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_redistribution_life.awk" \
    "$TMP/scores.tsv" > "$TMP/replayed-life.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_redistribution_verdict.awk" \
    "$TMP/replayed-life.tsv" > "$TMP/replayed-verdict.txt"
grep -q '^result[[:space:]]transition-surprise-redistribution-candidate$' \
    "$TMP/replayed-verdict.txt"

awk -F '\t' -v OFS='\t' '
    NR == 3 {
        n = split($15, value, "/")
        value[1] += 0.01
        $15 = ""
        for (i = 1; i <= n; i++) $15 = $15 (i == 1 ? "" : "/") value[i]
        $16 += 0.01
    }
    { print }
' "$TMP/raw.tsv" > "$TMP/forged-raw.tsv"
if awk -f "$ROOT/scripts/state_swarm_transition_redistribution_report.awk" \
    "$TMP/forged-raw.tsv" >/dev/null 2>&1; then
    printf 'forged transition replay was accepted\n' >&2
    exit 1
fi

write_population() {
    local social="$1" position5="$2" output="$3"
    printf 'cohort\tlife\tsplit\trank\trotation\tpaired_turns\teligible\tevent_censored\ttopology_censored\tforecast_censored\tsurprise_gain\tbrier_gain\thome_gain\tstorm_gain\twonder_gain\tsocial_gain\tposition_1_gain\tposition_2_gain\tposition_3_gain\tposition_4_gain\tposition_5_gain\tposition_6_gain\tposition_7_gain\tposition_8_gain\tresult\n' > "$output"
    local split prefix rank rotation life
    for split in primary holdout; do
        [ "$split" = primary ] && prefix=p || prefix=h
        for rank in $(seq 17 32); do
            rotation=$(( (rank - 17) % 8 ))
            life="${prefix}$(printf '%02d' "$rank")"
            printf 'discovery\t%s\t%s\t%d\t%d\t24\t24\t0\t0\t0\t0.002000000\t0.001000000\t0.002000000\t0.002000000\t0.002000000\t%s\t0.002000000\t0.002000000\t0.002000000\t0.002000000\t%s\t0.002000000\t0.002000000\t0.002000000\tlife-admissible\n' \
                "$life" "$split" "$rank" "$rotation" "$social" \
                "$position5" >> "$output"
        done
    done
}

write_population 0.002000000 0.002000000 "$TMP/positive.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_redistribution_verdict.awk" \
    "$TMP/positive.tsv" > "$TMP/positive.txt"
grep -q '^result[[:space:]]transition-surprise-redistribution-candidate$' \
    "$TMP/positive.txt"

write_population -0.000001000 0.002000000 "$TMP/texture-refusal.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_redistribution_verdict.awk" \
    "$TMP/texture-refusal.tsv" > "$TMP/texture-refusal.txt"
grep -q '^result[[:space:]]no-transition-surprise-redistribution-candidate$' \
    "$TMP/texture-refusal.txt"

write_population 0.002000000 -0.000001000 "$TMP/position-refusal.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_redistribution_verdict.awk" \
    "$TMP/position-refusal.tsv" > "$TMP/position-refusal.txt"
grep -q '^result[[:space:]]no-transition-surprise-redistribution-candidate$' \
    "$TMP/position-refusal.txt"

head -n 32 "$TMP/positive.tsv" > "$TMP/forged.tsv"
if awk -f "$ROOT/scripts/state_swarm_transition_redistribution_verdict.awk" \
    "$TMP/forged.tsv" >/dev/null 2>&1; then
    printf 'forged half-population was accepted\n' >&2
    exit 1
fi

printf 'state-swarm transition redistribution decision: ok\n'
