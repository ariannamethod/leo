#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-relational-reader-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

write_scores() {
    local mode="$1" output="$2"
    awk -v OFS='\t' -v mode="$mode" '
        BEGIN {
            print "cohort", "life", "split", "candidate_order", "rotation", \
                "session", "order", "source_order", "texture", "eligible", \
                "reason", "gap_relief", "distress_relief", "semantic_share", \
                "raw_surprise", "ungated_surprise", "candidate_surprise", \
                "surprise_gain", "candidate_over_ungated_surprise", \
                "raw_brier", "ungated_brier", "candidate_brier", "brier_gain", \
                "candidate_over_ungated_brier", "candidate_ce", \
                "candidate_prior_ce", "candidate_prior_ce_gain", \
                "candidate_prior_brier_gain", "raw_ce", "raw_prior_ce", \
                "raw_prior_ce_gain", "raw_prior_brier_gain", \
                "candidate_over_raw_ce", "candidate_over_raw_brier"
            texture[1] = "home"; texture[2] = "storm"
            texture[3] = "wonder"; texture[4] = "social"
            for (life_number = 1; life_number <= 2; life_number++) {
                life = life_number == 1 ? "p36" : "h35"
                split_name = life_number == 1 ? "primary" : "holdout"
                candidate_order = life_number == 1 ? 36 : 75
                for (order = 1; order <= 8; order++) {
                    prior_ce = mode == "positive" ? 1.1 : 0.9
                    prior_gain = mode == "positive" ? 0.1 : -0.1
                    prior_brier_gain = mode == "positive" ? 0.05 : -0.05
                    print "validation", life, split_name, candidate_order, 0, \
                        4, order, order, texture[((order - 1) % 4) + 1], 1, \
                        "none", 0, 0, 0, 0, 0, 0, 0, 0, 0.4, 0, 0.3, \
                        0, 0, 1.0, prior_ce, prior_gain, prior_brier_gain, \
                        1.2, 1.3, 0.1, 0.05, 0.2, 0.1
                }
            }
        }
    ' > "$output"
}

life_args=(
    -v expected_lives=2
    -v expected_primary=1
    -v expected_holdout=1
    -v expected_rows_per_life=8
    -v expected_branches_per_life=1
    -v expected_rows_per_branch=8
    -v minimum_eligible_per_branch=8
)
verdict_args=(
    -v expected_lives=2
    -v expected_primary=1
    -v expected_holdout=1
    -v expected_rows=16
    -v expected_eligible=16
    -v expected_branches_per_life=1
    -v expected_rows_per_life=8
    -v expected_rows_per_branch=8
    -v expected_event_censored=0
    -v expected_topology_censored=0
    -v expected_forecast_censored=0
    -v required_life_wins=2
    -v required_primary_wins=1
    -v required_holdout_wins=1
)

write_scores positive "$TMP/positive-scores.tsv"
awk "${life_args[@]}" \
    -f "$ROOT/scripts/state_swarm_relational_transition_reader_life.awk" \
    "$TMP/positive-scores.tsv" > "$TMP/positive-life.tsv"
awk "${verdict_args[@]}" \
    -f "$ROOT/scripts/state_swarm_relational_transition_reader_verdict.awk" \
    "$TMP/positive-scores.tsv" "$TMP/positive-life.tsv" > "$TMP/positive.txt"
grep -q '^result[[:space:]]relational-road-reader-reentry-nominated$' \
    "$TMP/positive.txt"

write_scores refused "$TMP/refused-scores.tsv"
awk "${life_args[@]}" \
    -f "$ROOT/scripts/state_swarm_relational_transition_reader_life.awk" \
    "$TMP/refused-scores.tsv" > "$TMP/refused-life.tsv"
awk "${verdict_args[@]}" \
    -f "$ROOT/scripts/state_swarm_relational_transition_reader_verdict.awk" \
    "$TMP/refused-scores.tsv" "$TMP/refused-life.tsv" > "$TMP/refused.txt"
grep -q '^result[[:space:]]relational-road-reader-reentry-refused$' \
    "$TMP/refused.txt"

cp "$TMP/positive-life.tsv" "$TMP/forged-life.tsv"
awk -F '\t' -v OFS='\t' 'NR == 2 { $11 += 0.01 } { print }' \
    "$TMP/forged-life.tsv" > "$TMP/forged-life-new.tsv"
if awk "${verdict_args[@]}" \
    -f "$ROOT/scripts/state_swarm_relational_transition_reader_verdict.awk" \
    "$TMP/positive-scores.tsv" "$TMP/forged-life-new.tsv" >/dev/null 2>&1; then
    printf 'relational reader verdict accepted a forged life mean\n' >&2
    exit 1
fi

{ cat "$TMP/positive-scores.tsv"; sed -n '2p' "$TMP/positive-scores.tsv"; } \
    > "$TMP/duplicate-scores.tsv"
if awk "${life_args[@]}" \
    -f "$ROOT/scripts/state_swarm_relational_transition_reader_life.awk" \
    "$TMP/duplicate-scores.tsv" >/dev/null 2>&1; then
    printf 'relational reader life court accepted a duplicate turn\n' >&2
    exit 1
fi

printf 'state-swarm relational transition reader decision: ok\n'
