#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-relational-transition-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

make_raw() {
    local mode="$1" output="$2"
    awk -v OFS='\t' -v mode="$mode" '
        function activation(active_index,    i, value) {
            value = ""
            for (i = 1; i <= 8; i++)
                value = value (i == 1 ? "" : "/") \
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
            print "cohort", "life", "split", "candidate_order", "rotation", \
                "session", "order", "source_order", "texture", "event", \
                "reply", "pre_turn", "pre_ids", "source", "transition", \
                "transition_total", "pre_gap", "pre_distress", \
                "pre_alignment", "post_turn", "post_ids", "target", \
                "post_gap", "post_distress", "post_alignment", \
                "has_prediction"
            texture[1] = "home"; texture[2] = "storm"
            texture[3] = "home"; texture[4] = "wonder"
            texture[5] = "social"; texture[6] = "home"
            texture[7] = "storm"; texture[8] = "home"
            ids = "1/2/3/4/5/6/7/8"
            for (life_number = 1; life_number <= 11; life_number++) {
                split_name = life_number <= 5 ? "primary" : "holdout"
                rank = life_number <= 5 ? 35 + life_number : 69 + life_number
                prefix = split_name == "primary" ? "p" : "h"
                life_rank = split_name == "primary" ? \
                    35 + life_number : 29 + life_number
                life = sprintf("%s%02d", prefix, life_rank)
                for (rotation = 0; rotation <= 7; rotation++) {
                    for (i = 1; i <= 64; i++) matrix[i] = 0.1
                    turn = 0
                    for (session = 1; session <= 6; session++)
                        for (order = 1; order <= 8; order++) {
                            turn++
                            source_index = ((turn - 1) % 8) + 1
                            target_index = (turn % 8) + 1
                            source_order = ((order - 1 + rotation) % 8) + 1
                            transition = matrix_value()
                            pre_gap = mode == "positive" ? 0.8 : 0.2
                            post_gap = mode == "positive" ? 0.4 : 0.4
                            print "validation", life, split_name, rank, rotation, \
                                session, order, source_order, texture[source_order], \
                                "updated", "synthetic", 100 + turn - 1, ids, \
                                activation(source_index), transition, \
                                sprintf("%.9f", matrix_total), pre_gap, 0.8, 0.5, \
                                100 + turn, ids, activation(target_index), post_gap, \
                                0.6, 0.5, 1
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
    ' > "$output"
}

make_raw positive "$TMP/positive-raw.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_report.awk" \
    "$TMP/positive-raw.tsv" > "$TMP/positive-scores.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_life.awk" \
    "$TMP/positive-scores.tsv" > "$TMP/positive-life.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_verdict.awk" \
    "$TMP/positive-life.tsv" > "$TMP/positive-verdict.txt"
grep -q '^result[[:space:]]relational-transition-redistribution-confirmed$' \
    "$TMP/positive-verdict.txt"
grep -q '^life_wins[[:space:]]11$' "$TMP/positive-verdict.txt"
awk -F '\t' 'NR > 1 && $14 != "1.000000000" { exit 1 }' \
    "$TMP/positive-scores.tsv"

make_raw closed "$TMP/closed-raw.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_report.awk" \
    "$TMP/closed-raw.tsv" > "$TMP/closed-scores.tsv"
awk -F '\t' 'NR > 1 && ($14 != "0.000000000" || $18 < -0.000001 || $18 > 0.000001) {
    exit 1
}' "$TMP/closed-scores.tsv"

awk -F '\t' -v OFS='\t' '
    NR == 3 {
        n = split($15, value, "/")
        value[1] += 0.01
        $15 = ""
        for (i = 1; i <= n; i++) $15 = $15 (i == 1 ? "" : "/") value[i]
        $16 += 0.01
    }
    { print }
' "$TMP/positive-raw.tsv" > "$TMP/forged-raw.tsv"
if awk -f "$ROOT/scripts/state_swarm_relational_transition_report.awk" \
    "$TMP/forged-raw.tsv" >/dev/null 2>&1; then
    printf 'relational reporter accepted a forged transition replay\n' >&2
    exit 1
fi

write_population() {
    local social="$1" position5="$2" over_ungated="$3" output="$4"
    printf 'cohort\tlife\tsplit\tcandidate_order\tbranches\tpaired_turns\teligible\tevent_censored\ttopology_censored\tforecast_censored\tsurprise_gain\tbrier_gain\tungated_surprise_gain\tungated_brier_gain\trelational_over_ungated_surprise\trelational_over_ungated_brier\thome_gain\tstorm_gain\twonder_gain\tsocial_gain\tposition_1_gain\tposition_2_gain\tposition_3_gain\tposition_4_gain\tposition_5_gain\tposition_6_gain\tposition_7_gain\tposition_8_gain\tsemantic_share\tresult\n' > "$output"
    local life_number split life candidate_order
    for life_number in $(seq 1 11); do
        if [ "$life_number" -le 5 ]; then
            split=primary
            life="p$((35 + life_number))"
            candidate_order=$((35 + life_number))
        else
            split=holdout
            life="h$((29 + life_number))"
            candidate_order=$((69 + life_number))
        fi
        printf 'validation\t%s\t%s\t%d\t8\t192\t192\t0\t0\t0\t0.002000000\t0.001000000\t0.001000000\t0.000500000\t%s\t0.000500000\t0.002000000\t0.002000000\t0.002000000\t%s\t0.002000000\t0.002000000\t0.002000000\t0.002000000\t%s\t0.002000000\t0.002000000\t0.002000000\t0.500000000\tlife-admissible\n' \
            "$life" "$split" "$candidate_order" "$over_ungated" "$social" \
            "$position5" >> "$output"
    done
}

write_population 0.002000000 0.002000000 0.001000000 "$TMP/population-positive.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_verdict.awk" \
    "$TMP/population-positive.tsv" > "$TMP/population-positive.txt"
grep -q '^result[[:space:]]relational-transition-redistribution-confirmed$' \
    "$TMP/population-positive.txt"

write_population -0.000001000 0.002000000 0.001000000 "$TMP/texture-refusal.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_verdict.awk" \
    "$TMP/texture-refusal.tsv" > "$TMP/texture-refusal.txt"
grep -q '^result[[:space:]]relational-transition-redistribution-not-confirmed$' \
    "$TMP/texture-refusal.txt"

write_population 0.002000000 -0.000001000 0.001000000 "$TMP/position-refusal.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_verdict.awk" \
    "$TMP/position-refusal.tsv" > "$TMP/position-refusal.txt"
grep -q '^result[[:space:]]relational-transition-redistribution-not-confirmed$' \
    "$TMP/position-refusal.txt"

write_population 0.002000000 0.002000000 -0.000001000 "$TMP/matched-refusal.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_verdict.awk" \
    "$TMP/matched-refusal.tsv" > "$TMP/matched-refusal.txt"
grep -q '^result[[:space:]]relational-transition-redistribution-not-confirmed$' \
    "$TMP/matched-refusal.txt"

head -n 7 "$TMP/population-positive.tsv" > "$TMP/forged.tsv"
if awk -f "$ROOT/scripts/state_swarm_relational_transition_verdict.awk" \
    "$TMP/forged.tsv" >/dev/null 2>&1; then
    printf 'relational verdict accepted a forged half-population\n' >&2
    exit 1
fi

printf 'state-swarm relational transition decision: ok\n'
