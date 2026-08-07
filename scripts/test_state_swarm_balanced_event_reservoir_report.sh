#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-state-balanced-reservoir-report.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

SCREEN_HEADER='life\tsplit\tbase_seed\tcandidate_order\twarm_turns\twarm_final_states\twarm_births\twarm_updates\twarm_replacements\twarm_session4_changes\tsettled\tenrolled\tenrollment_rank'
LIFE_HEADER='life\tsplit\tbase_seed\tenrollment_rank\twarm_turns\twriter_turns\twarm_final_states\twarm_births\twarm_replacements\twarm_session4_changes\twriter_births\twriter_updates\twriter_replacements\tfirst_replacement_turn\tminimum_similarity\tminimum_turn\tbelow_gate\tnear_005\tnear_010\tnear_020\tnear_050\tabove_050'
EVENT_HEADER='event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tdisplaced_id\ttrigger_new_id\tsimilarity\tnearest_id\tnearest_organs\tremoved_organs\tmembers\torgans\tprompt\treply'
VECTOR='0.399000/0.399000/0.399000/0.399000/0.399000/0.399000/0.399000'
MEMBERS='1:0.1,2:0.2,4:0.4,5:0.5,6:0.6,7:0.7,8:0.8,9:0.9'
ORGANS="1:$VECTOR,2:$VECTOR,4:$VECTOR,5:$VECTOR,6:$VECTOR,7:$VECTOR,8:$VECTOR,9:na"

write_fixture() {
    local stem="$1" adequate="$2"
    local screen="$TMP/$stem-screening.tsv"
    local lives="$TMP/$stem-lives.tsv"
    local events="$TMP/$stem-events.tsv"
    local primary_rank=0 holdout_rank=0
    printf '%b\n' "$SCREEN_HEADER" > "$screen"
    printf '%b\n' "$LIFE_HEADER" > "$lives"
    printf '%b\n' "$EVENT_HEADER" > "$events"

    for i in $(seq 1 80); do
        if [ "$i" -le 40 ]; then
            printf -v life 'p%02d' "$i"
            split=primary
        else
            printf -v life 'h%02d' "$((i - 40))"
            split=holdout
        fi
        seed=$((110003 + (i - 1) * 1033))
        settled=true
        births=8
        updates=24
        warm_replacements=0
        session4_changes=0
        if [ "$i" -eq 5 ] || [ "$i" -eq 43 ]; then
            settled=false
            updates=23
            warm_replacements=1
            session4_changes=1
        fi
        enrolled=false
        enrollment_rank=0
        if [ "$settled" = true ]; then
            if [ "$split" = primary ] && [ "$primary_rank" -lt 32 ]; then
                primary_rank=$((primary_rank + 1))
                enrollment_rank=$primary_rank
                enrolled=true
            elif [ "$split" = holdout ] && [ "$holdout_rank" -lt 32 ]; then
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
            [ "$life" = p02 ] || [ "$life" = h01 ] ||
            [ "$life" = h02 ]; }; then
            replacement=1
        fi
        if [ "$replacement" -eq 1 ]; then
            printf '%s\t%s\t%d\t%d\t32\t64\t8\t8\t0\t0\t0\t63\t1\t51\t0.399000\t51\t1\t0\t0\t1\t10\t52\n' \
                "$life" "$split" "$seed" "$enrollment_rank" >> "$lives"
            printf '%s-t051\t%s\t%s\t%d\t%d\t51\t3\t3\thome\t%d\t3\t9\t0.399\t3\t%s\t%s\t%s\t%s\tprompt %s\treply %s\n' \
                "$life" "$life" "$split" "$seed" "$enrollment_rank" \
                "$((seed + 303))" "$VECTOR" "$VECTOR" "$MEMBERS" "$ORGANS" \
                "$life" "$life" >> "$events"
        else
            printf '%s\t%s\t%d\t%d\t32\t64\t8\t8\t0\t0\t0\t64\t0\t0\t0.412000\t77\t0\t0\t0\t2\t10\t52\n' \
                "$life" "$split" "$seed" "$enrollment_rank" >> "$lives"
        fi
    done
}

write_fixture zero 0
awk -f "$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk" \
    "$TMP/zero-screening.tsv" "$TMP/zero-lives.tsv" "$TMP/zero-events.tsv" \
    > "$TMP/zero.txt"
grep -q '^screened_candidates=80 primary=40 holdout=40$' "$TMP/zero.txt"
grep -q '^enrolled_lives=64 primary=32 holdout=32 writer_observations=4096$' \
    "$TMP/zero.txt"
grep -q '^replacement_events=0 replacement_lives=0 trigger_packages=0$' \
    "$TMP/zero.txt"
grep -q '^anatomy_gate=closed anatomy_analysis=not-run$' "$TMP/zero.txt"
grep -q '^result=balanced-reservoir-below-observation-floor$' "$TMP/zero.txt"

write_fixture adequate 1
awk -f "$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk" \
    "$TMP/adequate-screening.tsv" "$TMP/adequate-lives.tsv" \
    "$TMP/adequate-events.tsv" > "$TMP/adequate.txt"
grep -q '^replacement_events=4 replacement_lives=4 trigger_packages=4$' \
    "$TMP/adequate.txt"
grep -q '^primary_events=2 primary_lives=2 holdout_events=2 holdout_lives=2$' \
    "$TMP/adequate.txt"
grep -q '^anatomy_gate=open anatomy_analysis=not-run$' "$TMP/adequate.txt"
grep -q '^result=balanced-reservoir-anatomy-admissible$' "$TMP/adequate.txt"

sed '$d' "$TMP/adequate-events.tsv" > "$TMP/missing-event.tsv"
if awk -f "$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk" \
    "$TMP/adequate-screening.tsv" "$TMP/adequate-lives.tsv" \
    "$TMP/missing-event.tsv" >/dev/null 2>&1; then
    printf 'balanced reservoir accepted a missing trigger package\n' >&2
    exit 1
fi

awk -F '\t' 'BEGIN { OFS = FS }
    NR == 1 { print; next }
    NR == 2 { sub(/9:na/, "9:0.399000\/0.399000\/0.399000\/0.399000\/0.399000\/0.399000\/0.399000", $18) }
    { print }
' "$TMP/adequate-events.tsv" > "$TMP/tampered-witness.tsv"
if awk -f "$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk" \
    "$TMP/adequate-screening.tsv" "$TMP/adequate-lives.tsv" \
    "$TMP/tampered-witness.tsv" >/dev/null 2>&1; then
    printf 'balanced reservoir accepted a witness without the newborn gap\n' >&2
    exit 1
fi

awk -F '\t' 'BEGIN { OFS = FS }
    NR == 1 { print; next }
    $1 == "p01" { $12 = "false"; $13 = 0 }
    { print }
' "$TMP/adequate-screening.tsv" > "$TMP/tampered-screening.tsv"
if awk -f "$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk" \
    "$TMP/tampered-screening.tsv" "$TMP/adequate-lives.tsv" \
    "$TMP/adequate-events.tsv" >/dev/null 2>&1; then
    printf 'balanced reservoir accepted outcome-shaped enrollment\n' >&2
    exit 1
fi

printf 'state-swarm balanced event reservoir report: ok\n'
