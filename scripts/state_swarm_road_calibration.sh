#!/usr/bin/env bash
# A.81: six-session prospective calibration of Leo's readerless road model.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="${LEO_STATE_ROAD_CASES:-$ROOT/scripts/state_swarm_road_cases.tsv}"
A80_CASES="$ROOT/scripts/state_swarm_ecology_cases.tsv"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
[ -f "$CASES" ] && [ -f "$A80_CASES" ] || {
    printf 'state road cases are unavailable\n' >&2
    exit 2
}

awk -F '\t' '
    FILENAME == ARGV[1] {
        if (FNR == 1) {
            if (NF != 5 || $1 != "kind" || $2 != "session" ||
                $3 != "order" || $4 != "texture" || $5 != "prompt")
                exit 1
            next
        }
        if (($1 != "writer" && $1 != "probe") ||
            $2 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+$/ ||
            $4 !~ /^(home|storm|wonder|social)$/ || $5 == "" ||
            prompt[$5]++)
            exit 1
        if ($1 == "writer") {
            if ($2 < 1 || $2 > 6 || $3 < 1 || $3 > 8 ||
                writer[$2 SUBSEP $3]++)
                exit 1
            sequence[$2] = sequence[$2] (sequence[$2] ? "," : "") $4
            road[$1 SUBSEP $2 SUBSEP $3] = $0
            writers++
        } else {
            if ($2 != 0 || $3 < 1 || $3 > 4 || probe[$3]++ ||
                probe_texture[$4]++)
                exit 1
            road[$1 SUBSEP $2 SUBSEP $3] = $0
            probes++
        }
        next
    }
    FNR == 1 { next }
    {
        key = $1 SUBSEP $2 SUBSEP $3
        if (!(key in road) || road[key] != $0) exit 1
        baseline++
    }
    END {
        expected = "home,storm,home,wonder,social,home,storm,home"
        if (writers != 48 || probes != 4 || length(writer) != 48 ||
            length(probe) != 4 || length(probe_texture) != 4 || baseline != 28)
            exit 1
        for (s = 1; s <= 6; s++)
            if (sequence[s] != expected) exit 1
    }
' "$CASES" "$A80_CASES" || {
    printf 'invalid or unsealed state road design: %s\n' "$CASES" >&2
    exit 2
}

mkdir -p "$OUT/lives"
LIVES="$OUT/lives.tsv"
PLAN="$OUT/plan.tsv"
RECEIPTS="$OUT/receipts.tsv"
EPOCHS="$OUT/epochs.tsv"
HOLDOUT="$OUT/holdout.tsv"
VERDICT="$OUT/verdict.txt"

printf 'cell\tcohort\tbase_seed\n' > "$LIVES"
printf 'river\treplication\t8301\n' >> "$LIVES"
printf 'window\treplication\t9011\n' >> "$LIVES"
printf 'lantern\tconfirmatory\t10007\n' >> "$LIVES"

printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tpersisted\tprompt\n' > "$PLAN"
tail -n +2 "$LIVES" |
while IFS=$'\t' read -r cell cohort base_seed; do
    for session in 1 2 3 4 5 6; do
        awk -F '\t' -v session="$session" '
            NR > 1 && $1 == "writer" && $2 == session {
                print $3 "\t" $4 "\t" $5
            }
        ' "$CASES" | sort -t $'\t' -k1,1n |
        while IFS=$'\t' read -r order texture prompt; do
            run_seed=$((base_seed + session * 100 + order))
            printf '%s\t%s\t%s\twriter\t%s\t%s\t%s\t%s\t1\t%s\n' \
                "$cell" "$cohort" "$base_seed" "$session" "$order" \
                "$texture" "$run_seed" "$prompt" >> "$PLAN"
        done

        awk -F '\t' 'NR > 1 && $1 == "probe" { print $3 "\t" $4 "\t" $5 }' \
            "$CASES" | sort -t $'\t' -k1,1n |
        while IFS=$'\t' read -r order texture prompt; do
            run_seed=$((base_seed + 900 + order))
            printf '%s\t%s\t%s\tprobe\t%s\t%s\t%s\t%s\t0\t%s\n' \
                "$cell" "$cohort" "$base_seed" "$session" "$order" \
                "$texture" "$run_seed" "$prompt" >> "$PLAN"
        done
    done
done

if [ "${LEO_STATE_ROAD_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null

printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tstates\tactive\twinner\tevent\tsimilarity\tentropy\tmembers\tmember_sum\tadjacent\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply\tvoice_equal\tstate_equal\n' > "$RECEIPTS"

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

tail -n +2 "$LIVES" |
while IFS=$'\t' read -r wanted_cell wanted_cohort wanted_seed; do
    life="$OUT/lives/$wanted_cell"
    mkdir -p "$life/logs"
    state="$life/leo.state"

    awk -F '\t' -v cell="$wanted_cell" 'NR > 1 && $1 == cell' "$PLAN" |
    while IFS=$'\t' read -r cell cohort base_seed phase session order \
        texture run_seed persisted prompt; do
        stem="s${session}-$(printf '%02d' "$order")-${phase}-${texture}"
        on_log="$life/logs/$stem.on.log"
        voice_equal=na
        state_equal=na
        args=("$ROOT/leo")
        if [ -f "$state" ]; then args+=(--load "$state"); fi
        args+=(--seed "$run_seed" --respond "$prompt" --debug-field)

        if [ "$phase" = writer ]; then
            args+=(--save "$state")
            "${args[@]}" > "$on_log" 2>&1
            [ -s "$state" ] || {
                printf '%s session %s writer %s did not save state\n' \
                    "$cell" "$session" "$order" >&2
                exit 1
            }
        else
            [ -s "$state" ] || exit 1
            before_sha="$(sha256_file "$state")"
            "${args[@]}" > "$on_log" 2>&1
            off_log="$life/logs/$stem.off.log"
            "$ROOT/leo" --load "$state" --seed "$run_seed" \
                --respond "$prompt" --debug-field --no-state-swarm \
                > "$off_log" 2>&1
            after_sha="$(sha256_file "$state")"
            on_reply="$(reply_from_log "$on_log")"
            off_reply="$(reply_from_log "$off_log")"
            [ "$on_reply" = "$off_reply" ] && voice_equal=true || voice_equal=false
            [ "$before_sha" = "$after_sha" ] && state_equal=true || state_equal=false
            [ "$voice_equal" = true ] && [ "$state_equal" = true ] || {
                printf '%s session %s probe %s violated shadow boundary\n' \
                    "$cell" "$session" "$texture" >&2
                exit 1
            }
        fi

        reply="$(reply_from_log "$on_log")"
        [ -n "$reply" ] || exit 1
        receipt="$(
            awk -v cell="$cell" -v cohort="$cohort" \
                -v base_seed="$base_seed" -v phase="$phase" \
                -v session="$session" -v order="$order" \
                -v texture="$texture" -v run_seed="$run_seed" \
                -v prompt="$prompt" -v reply="$reply" \
                -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$on_log"
        )"
        [ "$(printf '%s\n' "$receipt" | wc -l | tr -d ' ')" -eq 1 ] || exit 1
        printf '%s\t%s\t%s\n' "$receipt" "$voice_equal" "$state_equal" \
            >> "$RECEIPTS"
    done
done

awk -F '\t' '
    NR == 1 { next }
    {
        rows++
        life[$1]++
        if ($4 == "writer") {
            writers[$1]++
            if ($9 != writers[$1] || ($9 == 1 && $18 != 0) ||
                ($9 > 1 && $18 != 1)) exit 1
        } else if ($4 == "probe") {
            probes[$1]++
            if ($9 != $5 * 8 + 1 || $18 != 1 ||
                $35 != "true" || $36 != "true") exit 1
        } else exit 1
    }
    END {
        if (rows != 216 || length(life) != 3) exit 1
        for (cell in life)
            if (life[cell] != 72 || writers[cell] != 48 || probes[cell] != 24)
                exit 1
    }
' "$RECEIPTS" || {
    printf 'state road receipt chronology failed\n' >&2
    exit 1
}

printf 'cell\tcohort\tbase_seed\tsession\twriter_turns\tfinal_states\tbirths\tupdates\treplacements\tpredictions\traw_surprise\tuniform_surprise\traw_excess\tpersistence_surprise\tmarginal_surprise\tposition_surprise\tposition_coverage\tkernel_surprise\tkernel_coverage\tforecast_mae\n' > "$EPOCHS"
awk -f "$ROOT/scripts/state_swarm_road_report.awk" "$RECEIPTS" |
    sort -t $'\t' -k1,1 -k4,4n >> "$EPOCHS"

printf 'cell\tcohort\tbase_seed\tearly_predictions\tearly_raw\tearly_uniform\tlate_predictions\tlate_raw\tlate_uniform\tlate_excess\tlate_persistence\tlate_marginal\tlate_position\tposition_coverage\tlate_kernel\tkernel_coverage\timprovement\tposition_advantage\tkernel_advantage\tlate_mae\tfinal_states\tbirths\tupdates\treplacements\troad_verdict\tkernel_verdict\n' > "$HOLDOUT"
awk -F '\t' '
    NR == 1 { next }
    {
        cell = $1
        cells[cell] = 1
        cohort[cell] = $2
        seed[cell] = $3
        births[cell] += $7
        updates[cell] += $8
        replacements[cell] += $9
        if ($4 <= 3) {
            early_n[cell] += $10
            early_raw[cell] += $11 * $10
            early_uniform[cell] += $12 * $10
        } else {
            late_n[cell] += $10
            late_raw[cell] += $11 * $10
            late_uniform[cell] += $12 * $10
            late_persistence[cell] += $14 * $10
            late_marginal[cell] += $15 * $10
            late_position[cell] += $16 * $17
            position_n[cell] += $17
            late_kernel[cell] += $18 * $19
            kernel_n[cell] += $19
            late_mae[cell] += $20 * $10
            final_states[cell] = $6
        }
    }
    END {
        for (cell in cells) {
            eraw = early_raw[cell] / early_n[cell]
            euni = early_uniform[cell] / early_n[cell]
            lraw = late_raw[cell] / late_n[cell]
            luni = late_uniform[cell] / late_n[cell]
            lpersist = late_persistence[cell] / late_n[cell]
            lmarg = late_marginal[cell] / late_n[cell]
            lpos = position_n[cell] ? late_position[cell] / position_n[cell] : 0
            lkernel = kernel_n[cell] ? late_kernel[cell] / kernel_n[cell] : 0
            improvement = eraw - lraw
            pos_advantage = lraw - lpos
            kernel_advantage = lraw - lkernel

            if (late_n[cell] >= 23 && lraw <= luni - 0.10 &&
                lraw <= lmarg - 0.05)
                road = "learned-road"
            else if (late_n[cell] >= 23 && position_n[cell] >= 23 &&
                     lraw >= luni + 0.10 && lpos <= lraw - 0.50)
                road = "transition-defect"
            else if (late_n[cell] >= 23 && improvement >= 0.50 &&
                     lraw > luni - 0.10)
                road = "exposure-limited"
            else
                road = "provisional"

            if (kernel_n[cell] < 20)
                kernel = "insufficient"
            else if (lkernel <= lraw - 0.10)
                kernel = "supported"
            else if (lkernel >= lraw + 0.10)
                kernel = "harmful"
            else
                kernel = "neutral"

            printf "%s\t%s\t%s\t%d\t%.6f\t%.6f\t%d\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%d\t%.6f\t%d\t%.6f\t%.6f\t%.6f\t%.6f\t%d\t%d\t%d\t%d\t%s\t%s\n",
                   cell, cohort[cell], seed[cell], early_n[cell], eraw, euni,
                   late_n[cell], lraw, luni, lraw - luni, lpersist, lmarg,
                   lpos, position_n[cell], lkernel, kernel_n[cell], improvement,
                   pos_advantage, kernel_advantage,
                   late_mae[cell] / late_n[cell], final_states[cell],
                   births[cell], updates[cell], replacements[cell], road, kernel
        }
    }
' "$EPOCHS" | sort >> "$HOLDOUT"

awk -F '\t' '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        lives++
        road[$25]++
        kernel[$26]++
        next
    }
    FNR == 1 { next }
    $4 == "probe" {
        probes++
        if ($35 == "true") voice_equal++
        if ($36 == "true") state_equal++
    }
    END {
        print "state-swarm road calibration A.81"
        printf "lives=%d learned-road=%d transition-defect=%d exposure-limited=%d provisional=%d\n",
               lives, road["learned-road"] + 0, road["transition-defect"] + 0,
               road["exposure-limited"] + 0, road["provisional"] + 0
        printf "kernel_supported=%d kernel_neutral=%d kernel_harmful=%d kernel_insufficient=%d\n",
               kernel["supported"] + 0, kernel["neutral"] + 0,
               kernel["harmful"] + 0, kernel["insufficient"] + 0
        printf "counterfactual_probes=%d voice_equal=%d state_equal=%d\n",
               probes, voice_equal, state_equal
        print "road and kernel verdicts are readerless observations, never permission to steer speech"
    }
' "$HOLDOUT" "$RECEIPTS" > "$VERDICT"

cat "$HOLDOUT"
printf '\nepochs:\n'
cat "$EPOCHS"
printf '\n'
cat "$VERDICT"
printf '\nplan: %s\nreceipts: %s\n' "$PLAN" "$RECEIPTS"
