#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-relational-transition-runtime-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

write_raw() {
    local output="$1"
    awk -v OFS='\t' 'BEGIN {
        print "kind", "life", "split", "session", "order", "texture", \
            "reference", "overlap", "semantic_share", \
            "candidate_changed", "transition_only", "same_reply"
        for (life_number = 1; life_number <= 11; life_number++) {
            split_name = life_number <= 5 ? "primary" : "holdout"
            life = split_name == "primary" ? \
                sprintf("p%d", 35 + life_number) : \
                sprintf("h%d", 29 + life_number)
            for (session = 1; session <= 6; session++)
                for (order = 1; order <= 8; order++) {
                    texture = order == 2 || order == 7 ? "storm" : \
                        (order == 4 ? "wonder" : (order == 5 ? "social" : "home"))
                    relation = order == 2 ? 1 : 0
                    print "runtime", life, split_name, session, order, texture, \
                        "exact", "0.125000000", sprintf("%.9f", relation), \
                        relation, 1, 1
                }
        }
        for (session = 1; session <= 6; session++)
            for (order = 1; order <= 8; order++) {
                texture = order == 2 || order == 7 ? "storm" : \
                    (order == 4 ? "wonder" : (order == 5 ? "social" : "home"))
                print "default", "p36", "primary", session, order, texture, \
                    "default-exact", 0, 0, 0, 1, 1
            }
    }' > "$output"
}

write_raw "$TMP/positive.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_runtime_verdict.awk" \
    "$TMP/positive.tsv" > "$TMP/positive-verdict.txt"
grep -q '^result[[:space:]]relational-transition-runtime-exact$' \
    "$TMP/positive-verdict.txt"
grep -q '^exact_reference_turns[[:space:]]528$' "$TMP/positive-verdict.txt"
grep -q '^default_ablation_turns[[:space:]]48$' "$TMP/positive-verdict.txt"

awk -F '\t' -v OFS='\t' 'NR == 2 { $12 = 0 } { print }' \
    "$TMP/positive.tsv" > "$TMP/voice-forgery.tsv"
if awk -f "$ROOT/scripts/state_swarm_relational_transition_runtime_verdict.awk" \
    "$TMP/voice-forgery.tsv" >/dev/null 2>&1; then
    printf 'runtime verdict accepted a voice-boundary forgery\n' >&2
    exit 1
fi

head -n 289 "$TMP/positive.tsv" > "$TMP/half-population.tsv"
if awk -f "$ROOT/scripts/state_swarm_relational_transition_runtime_verdict.awk" \
    "$TMP/half-population.tsv" >/dev/null 2>&1; then
    printf 'runtime verdict accepted a half population\n' >&2
    exit 1
fi

awk -F '\t' -v OFS='\t' 'NR > 1 && $1 == "runtime" { $10 = 0 } { print }' \
    "$TMP/positive.tsv" > "$TMP/no-effect.tsv"
if awk -f "$ROOT/scripts/state_swarm_relational_transition_runtime_verdict.awk" \
    "$TMP/no-effect.tsv" >/dev/null 2>&1; then
    printf 'runtime verdict accepted a candidate that never changed a transition\n' >&2
    exit 1
fi

printf 'state-swarm relational transition runtime decision: ok\n'
