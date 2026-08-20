#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-relational-transition-default-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

write_raw() {
    local output="$1"
    awk -v OFS='\t' 'BEGIN {
        print "life", "split", "session", "order", "texture", \
            "default_reference", "legacy_reference", "overlap", \
            "semantic_share", "default_changed", "default_on_exact", \
            "transition_only", "default_off_different", "same_reply"
        for (life_number = 1; life_number <= 11; life_number++) {
            split_name = life_number <= 5 ? "primary" : "holdout"
            life = split_name == "primary" ? \
                sprintf("p%d", 35 + life_number) : \
                sprintf("h%d", 29 + life_number)
            different = 0
            for (session = 1; session <= 6; session++)
                for (order = 1; order <= 8; order++) {
                    texture = order == 2 || order == 7 ? "storm" : \
                        (order == 4 ? "wonder" : (order == 5 ? "social" : "home"))
                    relation = order == 2 ? 1 : 0
                    if (relation) different = 1
                    print life, split_name, session, order, texture, \
                        "exact", "exact", "0.125000000", \
                        sprintf("%.9f", relation), relation, 1, 1, different, 1
                }
        }
    }' > "$output"
}

write_raw "$TMP/positive.tsv"
awk -f "$ROOT/scripts/state_swarm_relational_transition_default_verdict.awk" \
    "$TMP/positive.tsv" > "$TMP/positive-verdict.txt"
grep -q '^result[[:space:]]relational-transition-default-admitted$' \
    "$TMP/positive-verdict.txt"
grep -q '^runtime_turns[[:space:]]528$' "$TMP/positive-verdict.txt"

awk -F '\t' -v OFS='\t' 'NR == 2 { $11 = 0 } { print }' \
    "$TMP/positive.tsv" > "$TMP/default-forgery.tsv"
if awk -f "$ROOT/scripts/state_swarm_relational_transition_default_verdict.awk" \
    "$TMP/default-forgery.tsv" >/dev/null 2>&1; then
    printf 'default verdict accepted an explicit-on mismatch\n' >&2
    exit 1
fi

awk -F '\t' -v OFS='\t' 'NR > 1 { $13 = 0 } { print }' \
    "$TMP/positive.tsv" > "$TMP/no-ablation-effect.tsv"
if awk -f "$ROOT/scripts/state_swarm_relational_transition_default_verdict.awk" \
    "$TMP/no-ablation-effect.tsv" >/dev/null 2>&1; then
    printf 'default verdict accepted a law with no observable ablation\n' >&2
    exit 1
fi

head -n 289 "$TMP/positive.tsv" > "$TMP/half-population.tsv"
if awk -f "$ROOT/scripts/state_swarm_relational_transition_default_verdict.awk" \
    "$TMP/half-population.tsv" >/dev/null 2>&1; then
    printf 'default verdict accepted a half population\n' >&2
    exit 1
fi

printf 'state-swarm relational transition default decision: ok\n'
