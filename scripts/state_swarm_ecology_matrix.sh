#!/usr/bin/env bash
# A.80: readerless ecology for Leo's tiny lived-state/sequence weights.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="${LEO_STATE_ECOLOGY_CASES:-$ROOT/scripts/state_swarm_ecology_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-ecology-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
[ -f "$CASES" ] || {
    printf 'state ecology cases not found: %s\n' "$CASES" >&2
    exit 2
}

awk -F '\t' '
    NR == 1 {
        if (NF != 5 || $1 != "kind" || $2 != "session" ||
            $3 != "order" || $4 != "texture" || $5 != "prompt")
            exit 1
        next
    }
    {
        if (($1 != "writer" && $1 != "probe") ||
            $2 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+$/ ||
            $4 !~ /^(home|storm|wonder|social)$/ || $5 == "" ||
            prompt[$5]++)
            exit 1
        if ($1 == "writer") {
            if ($2 < 1 || $2 > 3 || $3 < 1 || $3 > 8 ||
                writer[$2 SUBSEP $3]++)
                exit 1
            sequence[$2] = sequence[$2] (sequence[$2] ? "," : "") $4
            writers++
        } else {
            if ($2 != 0 || $3 < 1 || $3 > 4 || probe[$3]++ ||
                probe_texture[$4]++)
                exit 1
            probes++
        }
    }
    END {
        expected = "home,storm,home,wonder,social,home,storm,home"
        if (writers != 24 || probes != 4 || length(writer) != 24 ||
            length(probe) != 4 || length(probe_texture) != 4)
            exit 1
        for (s = 1; s <= 3; s++)
            if (sequence[s] != expected) exit 1
    }
' "$CASES" || {
    printf 'invalid state ecology design: %s\n' "$CASES" >&2
    exit 2
}

mkdir -p "$OUT/lives"
LIVES="$OUT/lives.tsv"
PLAN="$OUT/plan.tsv"
RECEIPTS="$OUT/receipts.tsv"
EPOCHS="$OUT/epochs.tsv"
SUMMARY="$OUT/summary.tsv"
VERDICT="$OUT/verdict.txt"

printf 'cell\tcohort\tbase_seed\n' > "$LIVES"
printf 'river\treplication\t8301\n' >> "$LIVES"
printf 'window\treplication\t9011\n' >> "$LIVES"
printf 'lantern\tconfirmatory\t10007\n' >> "$LIVES"

printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tpersisted\tprompt\n' \
    > "$PLAN"
tail -n +2 "$LIVES" |
while IFS=$'\t' read -r cell cohort base_seed; do
    for session in 1 2 3; do
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

        awk -F '\t' '
            NR > 1 && $1 == "probe" { print $3 "\t" $4 "\t" $5 }
        ' "$CASES" | sort -t $'\t' -k1,1n |
        while IFS=$'\t' read -r order texture prompt; do
            run_seed=$((base_seed + 900 + order))
            printf '%s\t%s\t%s\tprobe\t%s\t%s\t%s\t%s\t0\t%s\n' \
                "$cell" "$cohort" "$base_seed" "$session" "$order" \
                "$texture" "$run_seed" "$prompt" >> "$PLAN"
        done
    done
done

if [ "${LEO_STATE_ECOLOGY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null

printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tstates\tactive\twinner\tevent\tsimilarity\tentropy\tmembers\tmember_sum\tadjacent\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply\tvoice_equal\tstate_equal\n' \
    > "$RECEIPTS"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
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
        if [ -f "$state" ]; then
            args+=(--load "$state")
        fi
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
            [ -s "$state" ] || {
                printf '%s session %s probe has no lived state\n' \
                    "$cell" "$session" >&2
                exit 1
            }
            before_sha="$(sha256_file "$state")"
            "${args[@]}" > "$on_log" 2>&1
            off_log="$life/logs/$stem.off.log"
            off_args=("$ROOT/leo" --load "$state" --seed "$run_seed"
                      --respond "$prompt" --debug-field --no-state-swarm)
            "${off_args[@]}" > "$off_log" 2>&1
            after_sha="$(sha256_file "$state")"
            on_reply="$(reply_from_log "$on_log")"
            off_reply="$(reply_from_log "$off_log")"
            [ "$on_reply" = "$off_reply" ] && voice_equal=true || voice_equal=false
            [ "$before_sha" = "$after_sha" ] && state_equal=true || state_equal=false
            [ "$voice_equal" = true ] && [ "$state_equal" = true ] || {
                printf '%s session %s probe %s violated shadow boundary: voice=%s state=%s\n' \
                    "$cell" "$session" "$texture" "$voice_equal" \
                    "$state_equal" >&2
                exit 1
            }
        fi

        reply="$(reply_from_log "$on_log")"
        [ -n "$reply" ] || {
            printf '%s session %s %s %s emitted no visible reply\n' \
                "$cell" "$session" "$phase" "$order" >&2
            exit 1
        }
        receipt="$(
            awk -v cell="$cell" -v cohort="$cohort" \
                -v base_seed="$base_seed" -v phase="$phase" \
                -v session="$session" -v order="$order" \
                -v texture="$texture" -v run_seed="$run_seed" \
                -v prompt="$prompt" -v reply="$reply" \
                -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$on_log"
        )"
        [ "$(printf '%s\n' "$receipt" | wc -l | tr -d ' ')" -eq 1 ] || {
            printf '%s session %s %s %s emitted an invalid state receipt\n' \
                "$cell" "$session" "$phase" "$order" >&2
            exit 1
        }
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
            if ($9 != writers[$1]) exit 1
            if (($9 == 1 && $18 != 0) || ($9 > 1 && $18 != 1)) exit 1
        } else if ($4 == "probe") {
            probes[$1]++
            if ($9 != $5 * 8 + 1 || $18 != 1 ||
                $35 != "true" || $36 != "true")
                exit 1
        } else {
            exit 1
        }
    }
    END {
        if (rows != 108 || length(life) != 3) exit 1
        for (cell in life)
            if (life[cell] != 36 || writers[cell] != 24 || probes[cell] != 12)
                exit 1
    }
' "$RECEIPTS" || {
    printf 'state ecology receipt chronology failed\n' >&2
    exit 1
}

printf 'cell\tcohort\tbase_seed\tsession\twriter_turns\tfinal_states\tbirths\tupdates\treplacements\tmulti_active\tmean_similarity\tmean_entropy\tpredictions\ttop1_hits\ttop1_rate\tmean_expected_probability\tmean_surprise\tmean_uniform_surprise\texcess_surprise\tforecast_mae\n' \
    > "$EPOCHS"

awk -F '\t' '
    function abs(x) { return x < 0 ? -x : x }
    NR == 1 || $4 != "writer" { next }
    {
        key = $1 SUBSEP $5
        cell[key] = $1
        cohort[key] = $2
        seed[key] = $3
        session[key] = $5
        turns[key]++
        final_states[key] = $10
        if ($13 == "born") births[key]++
        else if ($13 == "updated") updates[key]++
        else if ($13 == "replaced") replacements[key]++
        if ($11 > 1) multi[key]++
        similarity[key] += $14
        entropy[key] += $15
        if ($20 == 1) {
            predictions[key]++
            if ($21 == $12) hits[key]++
            expected_probability[key] += $22
            surprise[key] += $24
            uniform[key] += log($10)
            forecast_mae[key] += (abs($25 - $29) + abs($26 - $30) + abs($27 - $31) + abs($28 - $32)) / 4.0
        }
    }
    END {
        for (key in turns) {
            mean_surprise = predictions[key] ? surprise[key] / predictions[key] : 0
            mean_uniform = predictions[key] ? uniform[key] / predictions[key] : 0
            printf "%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%.3f\t%.3f\t%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\n",
                   cell[key], cohort[key], seed[key], session[key], turns[key],
                   final_states[key], births[key] + 0, updates[key] + 0,
                   replacements[key] + 0, multi[key] + 0,
                   similarity[key] / turns[key], entropy[key] / turns[key],
                   predictions[key] + 0, hits[key] + 0,
                   predictions[key] ? hits[key] / predictions[key] : 0,
                   predictions[key] ? expected_probability[key] / predictions[key] : 0,
                   mean_surprise, mean_uniform, mean_surprise - mean_uniform,
                   predictions[key] ? forecast_mae[key] / predictions[key] : 0
        }
    }
' "$RECEIPTS" | sort >> "$EPOCHS"

printf 'cell\tcohort\tbase_seed\twriter_turns\tfinal_states\tdistinct_winners\tbirths\tupdates\treplacements\tholdout_replacements\tmulti_active\tmean_similarity\tmean_entropy\tpredictions\ttop1_hits\ttop1_rate\tmean_expected_probability\tmean_surprise\tmean_uniform_surprise\texcess_surprise\tforecast_mae\tanchor_comparisons\tanchor_returns\tanchor_return_rate\tholdout_anchor_returns\tholdout_anchor_rate\tholdout_anchor_novel\tdominant_share\tverdict\n' \
    > "$SUMMARY"

awk -F '\t' '
    function abs(x) { return x < 0 ? -x : x }
    NR == 1 { next }
    {
        cell = $1
        cohort[cell] = $2
        seed[cell] = $3
        cells[cell] = 1
        if ($4 == "writer") {
            writers[cell]++
            final_states[cell] = $10
            winner_key = cell SUBSEP $12
            if (!winner_seen[winner_key]++) distinct[cell]++
            if ($13 == "born") births[cell]++
            else if ($13 == "updated") updates[cell]++
            else if ($13 == "replaced") replacements[cell]++
            if ($5 == 3 && $13 == "replaced") holdout_replacements[cell]++
            if ($11 > 1) multi[cell]++
            similarity[cell] += $14
            entropy[cell] += $15
            if ($20 == 1) {
                predictions[cell]++
                if ($21 == $12) hits[cell]++
                expected_probability[cell] += $22
                surprise[cell] += $24
                uniform_surprise[cell] += log($10)
                forecast_mae[cell] += (abs($25 - $29) + abs($26 - $30) + abs($27 - $31) + abs($28 - $32)) / 4.0
            }
            if ($5 >= 2) {
                late[cell]++
                late_winner[cell SUBSEP $12]++
            }
        } else {
            probes[cell]++
            anchor[cell SUBSEP $7 SUBSEP $5] = $12
            textures[$7] = 1
            if ($5 == 3 && $13 != "updated") anchor_novel[cell]++
        }
    }
    END {
        for (key in late_winner) {
            split(key, part, SUBSEP)
            cell = part[1]
            if (late_winner[key] > dominant[cell])
                dominant[cell] = late_winner[key]
        }
        for (cell in cells) {
            comparisons = 0
            returns = 0
            holdout_returns = 0
            for (texture in textures) {
                a1 = anchor[cell SUBSEP texture SUBSEP 1]
                a2 = anchor[cell SUBSEP texture SUBSEP 2]
                a3 = anchor[cell SUBSEP texture SUBSEP 3]
                if (a1 && a2) { comparisons++; if (a1 == a2) returns++ }
                if (a2 && a3) {
                    comparisons++
                    if (a2 == a3) { returns++; holdout_returns++ }
                }
            }
            dominant_share = late[cell] ? dominant[cell] / late[cell] : 0
            holdout_rate = holdout_returns / 4.0
            return_rate = comparisons ? returns / comparisons : 0
            if (distinct[cell] <= 1 || dominant_share >= 0.85)
                verdict = "collapsed"
            else if (holdout_replacements[cell] > 2 || anchor_novel[cell] > 2)
                verdict = "thrashing"
            else if (holdout_returns >= 3) {
                if (holdout_replacements[cell] == 0 && dominant_share < 0.75)
                    verdict = "stable"
                else
                    verdict = "provisional"
            } else
                verdict = "provisional"
            top1_rate = predictions[cell] ? hits[cell] / predictions[cell] : 0
            mean_expected = predictions[cell] ? expected_probability[cell] / predictions[cell] : 0
            mean_surprise = predictions[cell] ? surprise[cell] / predictions[cell] : 0
            mean_uniform = predictions[cell] ? uniform_surprise[cell] / predictions[cell] : 0
            mean_forecast_mae = predictions[cell] ? forecast_mae[cell] / predictions[cell] : 0
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.3f\t%.3f\t%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%d\t%d\t%.3f\t%d\t%.3f\t%d\t%.3f\t%s\n",
                   cell, cohort[cell], seed[cell], writers[cell],
                   final_states[cell], distinct[cell], births[cell] + 0,
                   updates[cell] + 0, replacements[cell] + 0,
                   holdout_replacements[cell] + 0, multi[cell] + 0,
                   similarity[cell] / writers[cell],
                   entropy[cell] / writers[cell], predictions[cell] + 0,
                   hits[cell] + 0, top1_rate, mean_expected, mean_surprise,
                   mean_uniform, mean_surprise - mean_uniform, mean_forecast_mae,
                   comparisons, returns, return_rate, holdout_returns,
                   holdout_rate, anchor_novel[cell] + 0, dominant_share, verdict
        }
    }
' "$RECEIPTS" | sort >> "$SUMMARY"

awk -F '\t' '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        lives++
        verdict[$29]++
        next
    }
    FNR == 1 { next }
    $4 == "probe" {
        probes++
        if ($35 == "true") voice_equal++
        if ($36 == "true") state_equal++
    }
    END {
        print "state-swarm ecology A.80"
        printf "lives=%d stable=%d provisional=%d thrashing=%d collapsed=%d\n",
               lives, verdict["stable"] + 0, verdict["provisional"] + 0,
               verdict["thrashing"] + 0, verdict["collapsed"] + 0
        printf "counterfactual_probes=%d voice_equal=%d state_equal=%d\n",
               probes, voice_equal, state_equal
        print "classification=stable requires >=3/4 holdout anchor returns, zero holdout replacements, and <0.75 dominant share"
        print "classification=thrashing requires >2 holdout replacements or >2 novel holdout anchors"
        print "classification=collapsed requires <=1 winner or >=0.85 dominant share after acquisition"
        print "ecological verdicts are observations; only receipt, chronology, voice, and file invariants can fail the run"
    }
' "$SUMMARY" "$RECEIPTS" > "$VERDICT"

cat "$SUMMARY"
printf '\nepochs:\n'
cat "$EPOCHS"
printf '\n'
cat "$VERDICT"
printf '\nplan: %s\nreceipts: %s\n' "$PLAN" "$RECEIPTS"
