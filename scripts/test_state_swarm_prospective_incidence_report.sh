#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-prospective-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

SCREEN_HEADER='life\tsplit\tbase_seed\tcandidate_order\twarm_turns\twarm_final_states\twarm_births\twarm_updates\twarm_replacements\twarm_session4_changes\tsettled\tenrolled\tenrollment_rank'
LIFE_HEADER='life\tsplit\tbase_seed\tenrollment_rank\twarm_turns\twriter_turns\twarm_final_states\twarm_births\twarm_replacements\twarm_session4_changes\twriter_births\twriter_updates\twriter_replacements\tfirst_replacement_turn\tminimum_similarity\tminimum_turn\tbelow_gate\tnear_005\tnear_010\tnear_020\tnear_050\tabove_050'

write_fixture() {
    local stem="$1" adequate="$2"
    local screen="$TMP/$stem-screening.tsv"
    local lives="$TMP/$stem-lives.tsv"
    local primary_rank=0 holdout_rank=0
    printf '%b\n' "$SCREEN_HEADER" > "$screen"
    printf '%b\n' "$LIFE_HEADER" > "$lives"

    for i in $(seq 1 40); do
        if [ "$i" -le 30 ]; then
            printf -v life 'p%02d' "$i"
            split=primary
            local_rank=$primary_rank
        else
            printf -v life 'h%02d' "$((i - 30))"
            split=holdout
            local_rank=$holdout_rank
        fi
        seed=$((61001 + (i - 1) * 1031))
        settled=true
        births=8
        updates=24
        warm_replacements=0
        session4_changes=0
        if [ "$i" -eq 5 ] || [ "$i" -eq 33 ]; then
            settled=false
            updates=23
            warm_replacements=1
            session4_changes=1
        fi
        enrolled=false
        enrollment_rank=0
        if [ "$settled" = true ]; then
            if [ "$split" = primary ] && [ "$primary_rank" -lt 24 ]; then
                primary_rank=$((primary_rank + 1))
                enrollment_rank=$primary_rank
                enrolled=true
            elif [ "$split" = holdout ] && [ "$holdout_rank" -lt 8 ]; then
                holdout_rank=$((holdout_rank + 1))
                enrollment_rank=$holdout_rank
                enrolled=true
            fi
        fi
        printf '%s\t%s\t%d\t%d\t32\t8\t%d\t%d\t%d\t%d\t%s\t%s\t%d\n' \
            "$life" "$split" "$seed" "$i" "$births" "$updates" \
            "$warm_replacements" "$session4_changes" "$settled" \
            "$enrolled" "$enrollment_rank" >> "$screen"

        [ "$enrolled" = true ] || continue
        replacement=0
        if [ "$adequate" = 1 ] && { [ "$life" = p01 ] ||
            [ "$life" = p02 ] || [ "$life" = p03 ] ||
            [ "$life" = h01 ]; }; then
            replacement=1
        fi
        if [ "$replacement" -eq 1 ]; then
            printf '%s\t%s\t%d\t%d\t32\t64\t8\t8\t0\t0\t0\t63\t1\t51\t0.399000\t51\t1\t0\t0\t1\t10\t52\n' \
                "$life" "$split" "$seed" "$enrollment_rank" >> "$lives"
        else
            printf '%s\t%s\t%d\t%d\t32\t64\t8\t8\t0\t0\t0\t64\t0\t0\t0.412000\t77\t0\t0\t0\t2\t10\t52\n' \
                "$life" "$split" "$seed" "$enrollment_rank" >> "$lives"
        fi
    done
}

write_fixture zero 0
awk -f "$ROOT/scripts/state_swarm_prospective_incidence_report.awk" \
    "$TMP/zero-screening.tsv" "$TMP/zero-lives.tsv" > "$TMP/zero.txt"
grep -q '^screened_candidates=40 primary=30 holdout=10$' "$TMP/zero.txt"
grep -q '^settled_candidates=38/40 primary=29/30 holdout=9/10$' "$TMP/zero.txt"
grep -q '^enrolled_lives=32 primary=24 holdout=8 writer_observations=2048$' "$TMP/zero.txt"
grep -q '^post_writer_exclusions=0$' "$TMP/zero.txt"
grep -q '^result=prospective-incidence-below-observation-floor$' "$TMP/zero.txt"

write_fixture adequate 1
awk -f "$ROOT/scripts/state_swarm_prospective_incidence_report.awk" \
    "$TMP/adequate-screening.tsv" "$TMP/adequate-lives.tsv" \
    > "$TMP/adequate.txt"
grep -q '^replacement_events=4 replacement_lives=4$' "$TMP/adequate.txt"
grep -q '^primary_events=3 primary_lives=3 holdout_events=1 holdout_lives=1$' \
    "$TMP/adequate.txt"
grep -q '^result=prospective-incidence-mapped-anatomy-admissible$' \
    "$TMP/adequate.txt"

awk -F '\t' 'BEGIN { OFS = FS }
    NR == 1 { print; next }
    $1 == "p01" { $12 = "false"; $13 = 0 }
    { print }
' "$TMP/adequate-screening.tsv" > "$TMP/tampered-screening.tsv"
if awk -f "$ROOT/scripts/state_swarm_prospective_incidence_report.awk" \
    "$TMP/tampered-screening.tsv" "$TMP/adequate-lives.tsv" >/dev/null 2>&1; then
    printf 'report accepted outcome-shaped enrollment\n' >&2
    exit 1
fi

sed '$d' "$TMP/adequate-lives.tsv" > "$TMP/missing-life.tsv"
if awk -f "$ROOT/scripts/state_swarm_prospective_incidence_report.awk" \
    "$TMP/adequate-screening.tsv" "$TMP/missing-life.tsv" >/dev/null 2>&1; then
    printf 'report accepted a post-writer exclusion\n' >&2
    exit 1
fi

printf 'state-swarm prospective incidence report: ok\n'
