#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-transition-plasticity-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

make_raw() {
    local mode="$1" out="$2"
    awk -v mode="$mode" 'BEGIN {
        OFS = "\t"
        print "cohort", "life", "split", "rank", "arm", "session", "order", \
            "texture", "event", "reply", "pre_turn", "pre_ids", "source", \
            "transition", "transition_total", "post_turn", "post_ids", \
            "target", "has_prediction"
        ids = "1/2/3/4/5/6/7/8"
        source = "1.000000000/0.000000000/0.000000000/0.000000000/0.000000000/0.000000000/0.000000000/0.000000000"
        target = source
        off_matrix = "0.500000000/0.500000000/0/0/0/0/0/0"
        on_matrix = mode == "positive" ? "0.750000000/0.250000000/0/0/0/0/0/0" : off_matrix
        zeros = "/0/0/0/0/0/0/0/0"
        for (i = 2; i <= 8; i++) {
            off_matrix = off_matrix zeros
            on_matrix = on_matrix zeros
        }
        for (life = 1; life <= 32; life++) {
            split_name = life <= 16 ? "primary" : "holdout"
            label = (split_name == "primary" ? "p" : "h") sprintf("%02d", split_name == "primary" ? life : life - 16)
            rank = split_name == "primary" ? life : life - 16
            for (arm_index = 1; arm_index <= 2; arm_index++) {
                arm = arm_index == 1 ? "on" : "off"
                matrix = arm == "on" ? on_matrix : off_matrix
                for (session = 1; session <= 6; session++)
                    for (order = 1; order <= 8; order++) {
                        turn = 96 + (session - 1) * 8 + order
                        texture = order <= 4 ? "home" : (order <= 6 ? "storm" : (order == 7 ? "wonder" : "social"))
                        print "discovery", label, split_name, rank, arm, session, order, \
                            texture, "updated", "The same reply.", turn - 1, ids, \
                            source, matrix, 1, turn, ids, target, 1
                    }
            }
        }
    }' > "$out"
}

make_raw positive "$TMP/positive-raw.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_plasticity_report.awk" \
    "$TMP/positive-raw.tsv" > "$TMP/positive-scores.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_plasticity_life.awk" \
    "$TMP/positive-scores.tsv" > "$TMP/positive-life.tsv"
awk -v cohort=discovery \
    -f "$ROOT/scripts/state_swarm_transition_plasticity_verdict.awk" \
    "$TMP/positive-life.tsv" > "$TMP/positive-verdict.txt"
grep -q '^result transition-surprise-plasticity-candidate$' \
    "$TMP/positive-verdict.txt"
grep -q '^life_wins 32$' "$TMP/positive-verdict.txt"

make_raw neutral "$TMP/neutral-raw.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_plasticity_report.awk" \
    "$TMP/neutral-raw.tsv" > "$TMP/neutral-scores.tsv"
awk -f "$ROOT/scripts/state_swarm_transition_plasticity_life.awk" \
    "$TMP/neutral-scores.tsv" > "$TMP/neutral-life.tsv"
awk -v cohort=discovery \
    -f "$ROOT/scripts/state_swarm_transition_plasticity_verdict.awk" \
    "$TMP/neutral-life.tsv" > "$TMP/neutral-verdict.txt"
grep -q '^result no-transition-surprise-plasticity-candidate$' \
    "$TMP/neutral-verdict.txt"
grep -q '^life_wins 0$' "$TMP/neutral-verdict.txt"

awk -F '\t' -v OFS='\t' 'NR == 2 { $15 = 2 } { print }' \
    "$TMP/positive-raw.tsv" > "$TMP/forged-raw.tsv"
if awk -f "$ROOT/scripts/state_swarm_transition_plasticity_report.awk" \
    "$TMP/forged-raw.tsv" > /dev/null 2>&1; then
    printf 'transition-plasticity reporter accepted a forged matrix total\n' >&2
    exit 1
fi

printf 'state-swarm transition plasticity decision: ok\n'
