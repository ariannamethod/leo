#!/usr/bin/env bash
# A.84: settle state geometry before the sealed organ crossover begins.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="${LEO_STATE_SETTLED_WARMUP_CASES:-$ROOT/scripts/state_swarm_settled_warmup_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-settled-organs-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
[ -f "$CASES" ] || {
    printf 'settled warm-up cases not found: %s\n' "$CASES" >&2
    exit 2
}

awk -F '\t' '
    BEGIN {
        label[1] = "home"; label[2] = "storm"
        label[3] = "wonder"; label[4] = "social"
    }
    NR == 1 {
        if (NF != 4 || $1 != "session" || $2 != "order" ||
            $3 != "texture" || $4 != "prompt") exit 1
        next
    }
    {
        if ($1 !~ /^[0-9]+$/ || $1 < 1 || $1 > 4 ||
            $2 !~ /^[0-9]+$/ || $2 < 1 || $2 > 8 ||
            $3 !~ /^(home|storm|wonder|social)$/ || $4 == "" ||
            slot[$1 SUBSEP $2]++ || prompt[$4]++) exit 1
        session_texture[$1 SUBSEP $3]++
        crossed[$2 SUBSEP $3]++
        rows++
    }
    END {
        if (rows != 32 || length(slot) != 32) exit 1
        for (session = 1; session <= 4; session++)
            for (i = 1; i <= 4; i++)
                if (session_texture[session SUBSEP label[i]] != 2) exit 1
        for (position = 1; position <= 8; position++)
            for (i = 1; i <= 4; i++)
                if (crossed[position SUBSEP label[i]] != 1) exit 1
    }
' "$CASES" || {
    printf 'invalid settled warm-up crossover: %s\n' "$CASES" >&2
    exit 2
}

mkdir -p "$OUT/warmup/lives"
LIVES="$OUT/warmup/lives.tsv"
PLAN="$OUT/warmup/plan.tsv"
RECEIPTS="$OUT/warmup/receipts.tsv"
SUMMARY="$OUT/warmup/summary.tsv"
HOLISTIC="$OUT/holistic"
ANALYSIS="$OUT/organ-analysis"
VERDICT="$OUT/verdict.txt"

printf 'cell\tcohort\tbase_seed\n' > "$LIVES"
printf 'river\treplication\t11801\n' >> "$LIVES"
printf 'window\treplication\t12721\n' >> "$LIVES"
printf 'lantern\tconfirmatory\t13633\n' >> "$LIVES"

printf 'cell\tcohort\tbase_seed\tsession\torder\ttexture\trun_seed\tprompt\n' > "$PLAN"
tail -n +2 "$LIVES" |
while IFS=$'\t' read -r cell cohort base_seed; do
    tail -n +2 "$CASES" |
    while IFS=$'\t' read -r session order texture prompt; do
        run_seed=$((base_seed + 3000 + session * 100 + order))
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$cohort" "$base_seed" "$session" "$order" \
            "$texture" "$run_seed" "$prompt" >> "$PLAN"
    done
done

if [ "${LEO_STATE_SETTLED_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null

printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tstates\tactive\twinner\tevent\tsimilarity\tentropy\tmembers\tmember_sum\tadjacent\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply\n' \
    > "$RECEIPTS"

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

tail -n +2 "$LIVES" |
while IFS=$'\t' read -r wanted_cell wanted_cohort wanted_seed; do
    life="$OUT/warmup/lives/$wanted_cell"
    mkdir -p "$life/logs"
    state="$life/leo.state"
    awk -F '\t' -v cell="$wanted_cell" 'NR > 1 && $1 == cell' "$PLAN" |
    while IFS=$'\t' read -r cell cohort base_seed session order texture \
        run_seed prompt; do
        stem="w${session}-$(printf '%02d' "$order")-${texture}"
        log="$life/logs/$stem.log"
        args=("$ROOT/leo")
        if [ -f "$state" ]; then args+=(--load "$state"); fi
        args+=(--seed "$run_seed" --respond "$prompt" --debug-field \
               --save "$state")
        "${args[@]}" > "$log" 2>&1
        [ -s "$state" ] || exit 1
        reply="$(reply_from_log "$log")"
        [ -n "$reply" ] || exit 1
        awk -v cell="$cell" -v cohort="$cohort" \
            -v base_seed="$base_seed" -v phase=warmup \
            -v session="$session" -v order="$order" \
            -v texture="$texture" -v run_seed="$run_seed" \
            -v prompt="$prompt" -v reply="$reply" \
            -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$log" \
            >> "$RECEIPTS"
    done
done

printf 'cell\tcohort\tbase_seed\tturns\tfinal_states\tbirths\treplacements\tsettled_session_changes\n' \
    > "$SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        rows++
        turns[$1]++
        if ($9 != turns[$1] || ($9 == 1 && $18 != 0) ||
            ($9 > 1 && $18 != 1)) exit 1
        final_states[$1] = $10
        cohort[$1] = $2
        seed[$1] = $3
        if ($13 == "born") births[$1]++
        else if ($13 == "replaced") replacements[$1]++
        else if ($13 != "updated") exit 1
        if ($5 == 4 && $13 != "updated") settled_changes[$1]++
    }
    END {
        if (rows != 96 || length(turns) != 3) exit 1
        for (cell in turns) {
            if (turns[cell] != 32 || final_states[cell] != 8 ||
                settled_changes[cell] != 0) exit 1
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\n",
                   cell, cohort[cell], seed[cell], turns[cell],
                   final_states[cell], births[cell] + 0,
                   replacements[cell] + 0, settled_changes[cell] + 0
        }
    }
' "$RECEIPTS" | sort >> "$SUMMARY" || {
    printf 'state swarm did not settle before scored acquisition\n' >&2
    exit 1
}

if [ "${LEO_STATE_SETTLED_WARMUP_ONLY:-0}" = 1 ]; then
    cat "$SUMMARY"
    printf '\nwarm-up: %s\n' "$OUT/warmup"
    exit 0
fi

LEO_STATE_ALPHABET_INITIAL_ROOT="$OUT/warmup/lives" \
LEO_STATE_ALPHABET_TURN_OFFSET=32 \
    "$ROOT/scripts/state_swarm_alphabet_matrix.sh" "$HOLISTIC" \
    > "$OUT/holistic.stdout"

LEO_STATE_ORGAN_HOLISTIC="$HOLISTIC" \
    "$ROOT/scripts/state_swarm_organ_matrix.sh" "$ANALYSIS" \
    > "$OUT/organ-analysis.stdout"

awk -F '\t' '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        holistic++
        acquisition_changes = $18 + $20
        holdout_changes = $19 + $21
        if (acquisition_changes == 0) clean_acquisition++
        if (holdout_changes == 0) clean_holdout++
        if (acquisition_changes == 0 && holdout_changes == 0)
            clean_transfer++
        changes[$1] = acquisition_changes + holdout_changes
        next
    }
    FNR == 1 { next }
    {
        rows++
        organs[$4]++
        complete = $5 == 32 && $6 == 0 && $7 == 8 && $8 == 4 &&
                   $9 == 32 && $10 == 0
        if (complete) {
            complete_lives[$4]++
            if ($12 >= 0.50 && $13 >= 0.02) texture[$4]++
            if ($16 >= 0.25 && $17 >= 0.01) position[$4]++
        }
    }
    END {
        print "state-swarm settled organ factorization A.84"
        printf "warmup_turns=96 scored_writer_turns=192 counterfactual_probes=96 total_processes=384\n"
        printf "holistic_lives=%d factor_rows=%d\n", holistic, rows
        printf "local_warmup_settlement=3/3 clean_acquisition=%d/3 clean_holdout=%d/3 clean_transfer=%d/3\n",
               clean_acquisition + 0, clean_holdout + 0,
               clean_transfer + 0
        printf "transfer_changes lantern=%d river=%d window=%d\n",
               changes["lantern"] + 0, changes["river"] + 0,
               changes["window"] + 0
        admitted = clean_transfer == 3
        name[1] = "perception"; name[2] = "expression"
        name[3] = "own-field"; name[4] = "body"
        name[5] = "rhythm"; name[6] = "form"
        name[7] = "darkmatter"
        for (i = 1; i <= 7; i++) {
            organ = name[i]
            if (!admitted) verdict = "not-admitted"
            else if (texture[organ] >= 2 && position[organ] >= 2)
                verdict = "factorized"
            else if (texture[organ] >= 2) verdict = "texture-bearing"
            else if (position[organ] >= 2) verdict = "position-bearing"
            else verdict = "unformed"
            printf "%s complete_lives=%d/3 texture_support=%d/3 position_support=%d/3 verdict=%s\n",
                   organ, complete_lives[organ] + 0, texture[organ] + 0,
                   position[organ] + 0, verdict
        }
        print "warm-up is excluded from every prototype; complete scored coverage is required for admission"
        print "all labels remain laboratory-only; no update, persistence, or speech reader changed"
        print admitted ? "result=admitted" : "result=warmup-settlement-did-not-transfer"
        if (holistic != 3 || rows != 21 || length(organs) != 7) exit 1
        for (organ in organs) if (organs[organ] != 3) exit 1
    }
' "$HOLISTIC/alphabet.tsv" "$ANALYSIS/factors.tsv" > "$VERDICT"

cat "$SUMMARY"
printf '\n'
cat "$HOLISTIC/alphabet.tsv"
printf '\n'
cat "$ANALYSIS/factors.tsv"
printf '\n'
cat "$VERDICT"
printf '\nwarm-up: %s\nholistic: %s\norgan analysis: %s\n' \
    "$OUT/warmup" "$HOLISTIC" "$ANALYSIS"
