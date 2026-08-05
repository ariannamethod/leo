#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-incidence-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

HEADER='life\tsplit\tbase_seed\tsettled\twarm_turns\twriter_turns\tfinal_states\twarm_births\twarm_replacements\twarm_session4_changes\twriter_births\twriter_updates\twriter_replacements\tfirst_replacement_turn\tminimum_similarity\tminimum_turn\tbelow_gate\tnear_005\tnear_010\tnear_020\tnear_050\tabove_050'

write_fixture() {
    local path="$1" adequate="$2"
    printf '%b\n' "$HEADER" > "$path"
    for i in $(seq 1 32); do
        if [ "$i" -le 24 ]; then
            printf -v life 'p%02d' "$i"
            split=primary
        else
            printf -v life 'h%02d' "$((i - 24))"
            split=holdout
        fi
        replacement=0
        if [ "$adequate" = 1 ] && { [ "$i" -le 3 ] || [ "$i" -eq 25 ]; }; then
            replacement=1
        fi
        if [ "$replacement" -eq 1 ]; then
            printf '%s\t%s\t%d\ttrue\t32\t64\t8\t8\t0\t0\t0\t63\t1\t51\t0.399000\t51\t1\t0\t0\t1\t10\t52\n' \
                "$life" "$split" "$((22000 + i * 1009))" >> "$path"
        else
            printf '%s\t%s\t%d\ttrue\t32\t64\t8\t8\t0\t0\t0\t64\t0\t0\t0.412000\t77\t0\t0\t0\t2\t10\t52\n' \
                "$life" "$split" "$((22000 + i * 1009))" >> "$path"
        fi
    done
}

write_fixture "$TMP/zero.tsv" 0
awk -f "$ROOT/scripts/state_swarm_displacement_incidence_report.awk" \
    "$TMP/zero.tsv" > "$TMP/zero.txt"
grep -q '^replacement_events=0 replacement_lives=0$' "$TMP/zero.txt"
grep -q '^result=incidence-below-observation-floor$' "$TMP/zero.txt"

write_fixture "$TMP/adequate.tsv" 1
awk -f "$ROOT/scripts/state_swarm_displacement_incidence_report.awk" \
    "$TMP/adequate.tsv" > "$TMP/adequate.txt"
grep -q '^replacement_events=4 replacement_lives=4$' "$TMP/adequate.txt"
grep -q '^primary_events=3 primary_lives=3 holdout_events=1 holdout_lives=1$' \
    "$TMP/adequate.txt"
grep -q '^result=incidence-mapped-anatomy-admissible$' "$TMP/adequate.txt"

printf 'state-swarm displacement incidence report: ok\n'
