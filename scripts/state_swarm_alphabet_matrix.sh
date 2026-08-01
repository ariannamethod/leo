#!/usr/bin/env bash
# A.82: factor state texture from temporal position without adding a reader.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="${LEO_STATE_ALPHABET_CASES:-$ROOT/scripts/state_swarm_alphabet_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-alphabet-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
[ -f "$CASES" ] || {
    printf 'state alphabet cases not found: %s\n' "$CASES" >&2
    exit 2
}

awk -F '\t' '
    BEGIN {
        label[1] = "home"
        label[2] = "storm"
        label[3] = "wonder"
        label[4] = "social"
    }
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
            if ($2 < 1 || $2 > 8 || $3 < 1 || $3 > 8 ||
                writer[$2 SUBSEP $3]++)
                exit 1
            half = $2 <= 4 ? 1 : 2
            session_texture[$2 SUBSEP $4]++
            crossed[half SUBSEP $3 SUBSEP $4]++
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
        if (writers != 64 || probes != 4 || length(writer) != 64 ||
            length(probe) != 4 || length(probe_texture) != 4)
            exit 1
        for (s = 1; s <= 8; s++) {
            for (i = 1; i <= 4; i++) {
                if (session_texture[s SUBSEP label[i]] != 2) exit 1
            }
            if (s <= 4 && sequence[s] == sequence[s + 4]) exit 1
        }
        for (half = 1; half <= 2; half++)
            for (position = 1; position <= 8; position++)
                for (i = 1; i <= 4; i++) {
                    if (crossed[half SUBSEP position SUBSEP label[i]] != 1)
                        exit 1
                }
    }
' "$CASES" || {
    printf 'invalid state alphabet crossover: %s\n' "$CASES" >&2
    exit 2
}

mkdir -p "$OUT/lives"
LIVES="$OUT/lives.tsv"
PLAN="$OUT/plan.tsv"
RECEIPTS="$OUT/receipts.tsv"
ALPHABET="$OUT/alphabet.tsv"
VERDICT="$OUT/verdict.txt"

printf 'cell\tcohort\tbase_seed\n' > "$LIVES"
printf 'river\treplication\t11801\n' >> "$LIVES"
printf 'window\treplication\t12721\n' >> "$LIVES"
printf 'lantern\tconfirmatory\t13633\n' >> "$LIVES"

printf 'cell\tcohort\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tpersisted\tprompt\n' > "$PLAN"
tail -n +2 "$LIVES" |
while IFS=$'\t' read -r cell cohort base_seed; do
    for session in 1 2 3 4 5 6 7 8; do
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
            run_seed=$((base_seed + 1900 + order))
            printf '%s\t%s\t%s\tprobe\t%s\t%s\t%s\t%s\t0\t%s\n' \
                "$cell" "$cohort" "$base_seed" "$session" "$order" \
                "$texture" "$run_seed" "$prompt" >> "$PLAN"
        done
    done
done

if [ "${LEO_STATE_ALPHABET_PLAN_ONLY:-0}" = 1 ]; then
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
            [ -s "$state" ] || exit 1
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
        if (rows != 288 || length(life) != 3) exit 1
        for (cell in life)
            if (life[cell] != 96 || writers[cell] != 64 || probes[cell] != 32)
                exit 1
    }
' "$RECEIPTS" || {
    printf 'state alphabet receipt chronology failed\n' >&2
    exit 1
}

printf 'cell\tcohort\tbase_seed\tholdout_turns\ttexture_hits\ttexture_accuracy\ttexture_margin\ttexture_similarity\tposition_hits\tposition_accuracy\tposition_margin\tposition_similarity\tjoint_hits\tjoint_accuracy\tjoint_margin\tjoint_similarity\tfinal_states\tacquisition_births\tholdout_births\tacquisition_replacements\tholdout_replacements\tverdict\n' > "$ALPHABET"
awk -f "$ROOT/scripts/state_swarm_alphabet_report.awk" "$RECEIPTS" | sort \
    >> "$ALPHABET"

awk -F '\t' '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        lives++
        verdict[$22]++
        next
    }
    FNR == 1 { next }
    $4 == "probe" {
        probes++
        if ($35 == "true") voice_equal++
        if ($36 == "true") state_equal++
    }
    END {
        print "state-swarm alphabet factorization A.82"
        printf "lives=%d factorized=%d texture-alphabet=%d order-alphabet=%d entangled=%d unformed=%d unstable-geometry=%d\n",
               lives, verdict["factorized"] + 0,
               verdict["texture-alphabet"] + 0,
               verdict["order-alphabet"] + 0,
               verdict["entangled"] + 0, verdict["unformed"] + 0,
               verdict["unstable-geometry"] + 0
        printf "counterfactual_probes=%d voice_equal=%d state_equal=%d\n",
               probes, voice_equal, state_equal
        print "chance: texture=0.250 position=0.125 joint=0.03125"
        print "all labels and classifiers remain in the laboratory; Leo receives no authored state names"
    }
' "$ALPHABET" "$RECEIPTS" > "$VERDICT"

cat "$ALPHABET"
printf '\n'
cat "$VERDICT"
printf '\nplan: %s\nreceipts: %s\n' "$PLAN" "$RECEIPTS"
