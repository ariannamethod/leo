#!/usr/bin/env bash
# A.87: map displacement incidence before reopening organ anatomy.
set -Eeuo pipefail

trap 'rc=$?; printf "displacement incidence runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIVES="${LEO_STATE_INCIDENCE_LIVES:-$ROOT/scripts/state_swarm_displacement_incidence_lives.tsv}"
WARM_CASES="${LEO_STATE_INCIDENCE_WARM_CASES:-$ROOT/scripts/state_swarm_settled_warmup_cases.tsv}"
WRITER_CASES="${LEO_STATE_INCIDENCE_WRITER_CASES:-$ROOT/scripts/state_swarm_alphabet_cases.tsv}"
JOBS="${LEO_STATE_INCIDENCE_JOBS:-1}"
AGGREGATE_ONLY="${LEO_STATE_INCIDENCE_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-displacement-incidence-$STAMP}"

if [ "$AGGREGATE_ONLY" = 1 ]; then
    [ -d "$OUT/lives" ] && [ -s "$OUT/plan.tsv" ] || {
        printf 'incomplete incidence run cannot be aggregated: %s\n' "$OUT" >&2
        exit 2
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
fi
case "$JOBS" in
    ''|*[!0-9]*|0) printf 'invalid incidence job count: %s\n' "$JOBS" >&2; exit 2 ;;
esac
for file in "$LIVES" "$WARM_CASES" "$WRITER_CASES"; do
    [ -s "$file" ] || {
        printf 'displacement incidence input missing: %s\n' "$file" >&2
        exit 2
    }
done

awk -F '\t' '
    NR == 1 {
        if (NF != 3 || $1 != "life" || $2 != "split" ||
            $3 != "base_seed") exit 1
        next
    }
    {
        if (NF != 3 || $1 !~ /^[ph][0-9][0-9]$/ ||
            $2 !~ /^(primary|holdout)$/ || $3 !~ /^[0-9]+$/ ||
            (($1 ~ /^p/) != ($2 == "primary")) ||
            (($1 ~ /^h/) != ($2 == "holdout")) ||
            life[$1]++ || seed[$3]++) exit 1
        cohort_count[$2]++
        rows++
    }
    END {
        if (rows != 32 || cohort_count["primary"] != 24 ||
            cohort_count["holdout"] != 8) exit 1
    }
' "$LIVES" || {
    printf 'invalid displacement incidence lives: %s\n' "$LIVES" >&2
    exit 2
}

awk -F '\t' '
    BEGIN {
        name[1] = "home"; name[2] = "storm"
        name[3] = "wonder"; name[4] = "social"
    }
    NR == 1 {
        if (NF != 4 || $1 != "session" || $2 != "order" ||
            $3 != "texture" || $4 != "prompt") exit 1
        next
    }
    {
        if (NF != 4 || $1 < 1 || $1 > 4 || $2 < 1 || $2 > 8 ||
            $3 !~ /^(home|storm|wonder|social)$/ || $4 == "" ||
            slot[$1 SUBSEP $2]++ || prompt[$4]++) exit 1
        texture[$1 SUBSEP $3]++
        crossed[$2 SUBSEP $3]++
        rows++
    }
    END {
        if (rows != 32 || length(slot) != 32) exit 1
        for (session = 1; session <= 4; session++)
            for (i = 1; i <= 4; i++)
                if (texture[session SUBSEP name[i]] != 2) exit 1
        for (position = 1; position <= 8; position++)
            for (i = 1; i <= 4; i++)
                if (crossed[position SUBSEP name[i]] != 1) exit 1
    }
' "$WARM_CASES" || {
    printf 'invalid displacement incidence warm cases: %s\n' "$WARM_CASES" >&2
    exit 2
}

awk -F '\t' '
    NR == 1 {
        if (NF != 5 || $1 != "kind" || $2 != "session" ||
            $3 != "order" || $4 != "texture" || $5 != "prompt") exit 1
        next
    }
    $1 == "writer" {
        if ($2 < 1 || $2 > 8 || $3 < 1 || $3 > 8 ||
            $4 !~ /^(home|storm|wonder|social)$/ || $5 == "" ||
            slot[$2 SUBSEP $3]++ || prompt[$5]++) exit 1
        rows++
    }
    $1 != "writer" && $1 != "probe" { exit 1 }
    END { if (rows != 64 || length(slot) != 64) exit 1 }
' "$WRITER_CASES" || {
    printf 'invalid displacement incidence writer cases: %s\n' "$WRITER_CASES" >&2
    exit 2
}

PLAN="$OUT/plan.tsv"
RECEIPTS="$OUT/receipts.tsv"
LIFE_SUMMARY="$OUT/life-summary.tsv"
EVENTS="$OUT/events.tsv"
STRATA="$OUT/strata.tsv"
VERDICT="$OUT/verdict.txt"

if [ "$AGGREGATE_ONLY" != 1 ]; then
    mkdir -p "$OUT/lives"
    printf 'life\tsplit\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tprompt\n' > "$PLAN"
    while IFS=$'\t' read -r life split base_seed; do
        while IFS=$'\t' read -r session order texture prompt; do
            run_seed=$((base_seed + 3000 + session * 100 + order))
            printf '%s\t%s\t%s\twarm\t%s\t%s\t%s\t%s\t%s\n' \
                "$life" "$split" "$base_seed" "$session" "$order" \
                "$texture" "$run_seed" "$prompt" >> "$PLAN"
        done < <(tail -n +2 "$WARM_CASES")
        while IFS=$'\t' read -r kind session order texture prompt; do
            [ "$kind" = writer ] || continue
            run_seed=$((base_seed + session * 100 + order))
            printf '%s\t%s\t%s\twriter\t%s\t%s\t%s\t%s\t%s\n' \
                "$life" "$split" "$base_seed" "$session" "$order" \
                "$texture" "$run_seed" "$prompt" >> "$PLAN"
        done < <(tail -n +2 "$WRITER_CASES")
    done < <(tail -n +2 "$LIVES")
fi

awk -F '\t' '
    NR == 1 { next }
    {
        rows++; lives[$1]++; phase[$1 SUBSEP $4]++
        if (seed[$1 SUBSEP $8]++) exit 1
    }
    END {
        if (rows != 3072 || length(lives) != 32) exit 1
        for (life in lives)
            if (lives[life] != 96 || phase[life SUBSEP "warm"] != 32 ||
                phase[life SUBSEP "writer"] != 64) exit 1
    }
' "$PLAN" || {
    printf 'invalid displacement incidence plan: %s\n' "$PLAN" >&2
    exit 2
}

if [ "${LEO_STATE_INCIDENCE_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

receipt_header='life\tsplit\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tstates\tactive\twinner\tevent\tsimilarity\tentropy\tmembers\tmember_sum\tadjacent\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply'

if [ "$AGGREGATE_ONLY" != 1 ]; then
make -C "$ROOT" leo >/dev/null

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

run_life() {
    local wanted_life="$1" wanted_split="$2" wanted_seed="$3"
    local life_dir="$OUT/lives/$wanted_life"
    local life_receipts="$life_dir/receipts.tsv"
    local state="$life_dir/leo.state"
    mkdir -p "$life_dir/logs"
    : > "$life_receipts"

    awk -F '\t' -v life="$wanted_life" 'NR > 1 && $1 == life' "$PLAN" |
    while IFS=$'\t' read -r life split base_seed phase session order \
        texture run_seed prompt; do
        local stem="${phase}-s${session}-$(printf '%02d' "$order")-${texture}"
        local log="$life_dir/logs/$stem.log"
        local reply
        local args=("$ROOT/leo" --corpus "$ROOT/leo.txt")
        if [ -f "$state" ]; then args+=(--load "$state"); fi
        args+=(--seed "$run_seed" --respond "$prompt" --debug-field \
               --save "$state")
        "${args[@]}" > "$log" 2>&1
        [ -s "$state" ] || exit 1
        reply="$(reply_from_log "$log")"
        [ -n "$reply" ] || exit 1
        awk -v cell="$life" -v cohort="$split" \
            -v base_seed="$base_seed" -v phase="$phase" \
            -v session="$session" -v order="$order" \
            -v texture="$texture" -v run_seed="$run_seed" \
            -v prompt="$prompt" -v reply="$reply" \
            -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$log" \
            >> "$life_receipts"
    done
}

pids=()
running=0
while IFS=$'\t' read -r life split base_seed; do
    run_life "$life" "$split" "$base_seed" &
    pids+=("$!")
    running=$((running + 1))
    if [ "$running" -ge "$JOBS" ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
        pids=()
        running=0
    fi
done < <(tail -n +2 "$LIVES")
if [ "$running" -gt 0 ]; then
    for pid in "${pids[@]}"; do wait "$pid"; done
fi
fi

printf '%b\n' "$receipt_header" > "$RECEIPTS"
while IFS=$'\t' read -r life split base_seed; do
    [ "$(wc -l < "$OUT/lives/$life/receipts.tsv")" -eq 96 ] || {
        printf 'incomplete life receipt: %s\n' "$life" >&2
        exit 1
    }
    cat "$OUT/lives/$life/receipts.tsv" >> "$RECEIPTS"
done < <(tail -n +2 "$LIVES")

printf 'life\tsplit\tbase_seed\tsettled\twarm_turns\twriter_turns\tfinal_states\twarm_births\twarm_replacements\twarm_session4_changes\twriter_births\twriter_updates\twriter_replacements\tfirst_replacement_turn\tminimum_similarity\tminimum_turn\tbelow_gate\tnear_005\tnear_010\tnear_020\tnear_050\tabove_050\n' > "$LIFE_SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        rows++; turns[$1]++
        if ($9 != turns[$1] || ($9 == 1 && $18 != 0) ||
            ($9 > 1 && $18 != 1)) exit 1
        cohort[$1] = $2; seed[$1] = $3; final_states[$1] = $10
        if ($4 == "warm") {
            warm[$1]++
            if ($13 == "born") warm_birth[$1]++
            else if ($13 == "replaced") warm_replacement[$1]++
            else if ($13 != "updated") exit 1
            if ($5 == 4 && $13 != "updated") session4_change[$1]++
            next
        }
        if ($4 != "writer") exit 1
        writer[$1]++
        if ($13 == "born") writer_birth[$1]++
        else if ($13 == "updated") writer_update[$1]++
        else if ($13 == "replaced") {
            writer_replacement[$1]++
            if (!first_replacement[$1]) first_replacement[$1] = $9
        } else exit 1
        similarity = $14 + 0
        if (!have_min[$1] || similarity < minimum[$1]) {
            minimum[$1] = similarity
            minimum_turn[$1] = $9
            have_min[$1] = 1
        }
        # The debug surface prints three decimals. Event identity preserves
        # the unrounded <0.40 decision when a value renders as 0.400.
        if ($13 == "replaced") below[$1]++
        else if (similarity < 0.405) near005[$1]++
        else if (similarity < 0.410) near010[$1]++
        else if (similarity < 0.420) near020[$1]++
        else if (similarity < 0.450) near050[$1]++
        else above050[$1]++
    }
    END {
        if (rows != 3072 || length(turns) != 32) exit 1
        for (life in turns) {
            settled = warm[life] == 32 && final_states[life] == 8 &&
                      session4_change[life] == 0
            if (turns[life] != 96 || warm[life] != 32 ||
                writer[life] != 64 || !have_min[life]) exit 1
            if (settled && (writer_birth[life] != 0 ||
                below[life] != writer_replacement[life])) exit 1
            printf "%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                   life, cohort[life], seed[life], settled ? "true" : "false",
                   warm[life], writer[life], final_states[life],
                   warm_birth[life] + 0, warm_replacement[life] + 0,
                   session4_change[life] + 0, writer_birth[life] + 0,
                   writer_update[life] + 0, writer_replacement[life] + 0,
                   first_replacement[life] + 0, minimum[life],
                   minimum_turn[life], below[life] + 0, near005[life] + 0,
                   near010[life] + 0, near020[life] + 0,
                   near050[life] + 0, above050[life] + 0
        }
    }
' "$RECEIPTS" | sort >> "$LIFE_SUMMARY"

printf 'life\tsplit\tbase_seed\tturn\tsession\torder\ttexture\tsimilarity\treplaced_id\tnew_id\tprompt\treply\n' > "$EVENTS"
awk -F '\t' '
    FILENAME == ARGV[1] {
        if (FNR > 1 && $4 == "true") settled[$1] = 1
        next
    }
    FNR == 1 { next }
    $4 == "writer" && $13 == "replaced" && settled[$1] {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
               $1, $2, $3, $9, $5, $6, $7, $14, $19, $12, $33, $34
    }
' "$LIFE_SUMMARY" "$RECEIPTS" >> "$EVENTS"

printf 'dimension\tvalue\tobservations\tlives\treplacements\treplacement_lives\tminimum_similarity\tminimum_life\tminimum_turn\tbelow_gate\tnear_005\tnear_010\tnear_020\tnear_050\tabove_050\n' > "$STRATA"
awk -F '\t' '
    function add(kind, value, life, similarity, event,    key) {
        key = kind SUBSEP value
        observations[key]++
        lives[key SUBSEP life] = 1
        if (!(key in minimum) || similarity < minimum[key]) {
            minimum[key] = similarity
            minimum_life[key] = life
            minimum_turn[key] = $9
        }
        if (event == "replaced") {
            replacements[key]++
            replacement_lives[key SUBSEP life] = 1
        }
        if (event == "replaced") below[key]++
        else if (similarity < 0.405) near005[key]++
        else if (similarity < 0.410) near010[key]++
        else if (similarity < 0.420) near020[key]++
        else if (similarity < 0.450) near050[key]++
        else above050[key]++
    }
    function emit(kind, value,    key, composite, n_lives, n_event_lives, part) {
        key = kind SUBSEP value
        n_lives = 0; n_event_lives = 0
        for (composite in lives) {
            split(composite, part, SUBSEP)
            if (part[1] == kind && part[2] == value) n_lives++
        }
        for (composite in replacement_lives) {
            split(composite, part, SUBSEP)
            if (part[1] == kind && part[2] == value) n_event_lives++
        }
        printf "%s\t%s\t%d\t%d\t%d\t%d\t%.6f\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
               kind, value, observations[key] + 0, n_lives,
               replacements[key] + 0, n_event_lives, minimum[key],
               minimum_life[key], minimum_turn[key], below[key] + 0,
               near005[key] + 0, near010[key] + 0, near020[key] + 0,
               near050[key] + 0, above050[key] + 0
    }
    FILENAME == ARGV[1] {
        if (FNR > 1 && $4 == "true") settled[$1] = 1
        next
    }
    FNR == 1 { next }
    $4 == "writer" && settled[$1] {
        similarity = $14 + 0
        add("overall", "all", $1, similarity, $13)
        add("split", $2, $1, similarity, $13)
        add("texture", $7, $1, similarity, $13)
        add("session", $5, $1, similarity, $13)
        add("position", $6, $1, similarity, $13)
    }
    END {
        emit("overall", "all")
        emit("split", "primary"); emit("split", "holdout")
        emit("texture", "home"); emit("texture", "storm")
        emit("texture", "wonder"); emit("texture", "social")
        for (i = 1; i <= 8; i++) emit("session", i)
        for (i = 1; i <= 8; i++) emit("position", i)
    }
' "$LIFE_SUMMARY" "$RECEIPTS" >> "$STRATA"

awk -f "$ROOT/scripts/state_swarm_displacement_incidence_report.awk" \
    "$LIFE_SUMMARY" > "$VERDICT"

cat "$LIFE_SUMMARY"
printf '\n'
cat "$EVENTS"
printf '\n'
cat "$STRATA"
printf '\n'
cat "$VERDICT"
printf '\nprocesses=3072\nrun: %s\n' "$OUT"
