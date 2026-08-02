#!/usr/bin/env bash
# A.86: measure whether displacement fate belongs to one organ or their geometry.
set -Eeuo pipefail

trap 'rc=$?; printf "displacement anatomy runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIVES="${LEO_STATE_ANATOMY_LIVES:-$ROOT/scripts/state_swarm_displacement_anatomy_lives.tsv}"
WARM_CASES="${LEO_STATE_ANATOMY_WARM_CASES:-$ROOT/scripts/state_swarm_settled_warmup_cases.tsv}"
ALPHABET_CASES="${LEO_STATE_ANATOMY_ALPHABET_CASES:-$ROOT/scripts/state_swarm_alphabet_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-displacement-anatomy-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
for file in "$LIVES" "$WARM_CASES" "$ALPHABET_CASES"; do
    [ -s "$file" ] || {
        printf 'displacement anatomy input missing: %s\n' "$file" >&2
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
        if (NF != 3 || $1 !~ /^h[0-9][0-9]$/ || $2 != "holdout" ||
            $3 !~ /^[0-9]+$/ || life[$1]++ || seed[$3]++) exit 1
        rows++
    }
    END { if (rows != 8) exit 1 }
' "$LIVES" || {
    printf 'invalid displacement anatomy lives: %s\n' "$LIVES" >&2
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
        rows++
    }
    END {
        if (rows != 32 || length(slot) != 32) exit 1
        for (session = 1; session <= 4; session++)
            for (i = 1; i <= 4; i++)
                if (texture[session SUBSEP name[i]] != 2) exit 1
    }
' "$WARM_CASES" || {
    printf 'invalid displacement anatomy warm cases: %s\n' "$WARM_CASES" >&2
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
' "$ALPHABET_CASES" || {
    printf 'invalid displacement anatomy writer cases: %s\n' "$ALPHABET_CASES" >&2
    exit 2
}

mkdir -p "$OUT/lives"
PLAN="$OUT/plan.tsv"
RECEIPTS="$OUT/receipts.tsv"
EVENTS="$OUT/events.tsv"
RAW="$OUT/returns.raw.tsv"
ANATOMY="$OUT/anatomy.tsv"
LIFE_SUMMARY="$OUT/life-summary.tsv"
EVENT_SUMMARY="$OUT/event-summary.tsv"
VERDICT="$OUT/verdict.txt"

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
    done < <(tail -n +2 "$ALPHABET_CASES")
done < <(tail -n +2 "$LIVES")

awk -F '\t' '
    NR == 1 { next }
    {
        rows++; lives[$1]++; phase[$1 SUBSEP $4]++
        if (seed[$1 SUBSEP $8]++) exit 1
    }
    END {
        if (rows != 768 || length(lives) != 8) exit 1
        for (life in lives)
            if (lives[life] != 96 || phase[life SUBSEP "warm"] != 32 ||
                phase[life SUBSEP "writer"] != 64) exit 1
    }
' "$PLAN" || {
    printf 'invalid displacement anatomy plan: %s\n' "$PLAN" >&2
    exit 2
}

if [ "${LEO_STATE_ANATOMY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null

printf 'life\tsplit\tbase_seed\tphase\tsession\torder\ttexture\trun_seed\tturn\tstates\tactive\twinner\tevent\tsimilarity\tentropy\tmembers\tmember_sum\tadjacent\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply\n' > "$RECEIPTS"
printf 'event\tlife\tsplit\tsettled\tbase_seed\ttrigger_turn\tdisplaced_id\ttrigger_new_id\tbirth_turn\tbirth_seed\tanchor_available\tanchor_turn\tanchor_seed\tanchor_mass\ttrigger_voice_equal\ttrigger_non_swarm_equal\ttrigger_state_different\ttrigger_prompt\treply\n' > "$EVENTS"
printf 'event\tlife\tsplit\tsettled\tbase_seed\ttrigger_turn\tdisplaced_id\ttrigger_new_id\tprobe\tkind\treturn_seed\tcontrol_turn\tcontrol_event\tcontrol_winner\tcontrol_similarity\tcontrol_members\tcontrol_replaced\tcontrol_nearest\tcontrol_nearest_organs\tcontrol_removed_organs\tcontrol_organs\tdisplaced_turn\tdisplaced_event\tdisplaced_winner\tdisplaced_similarity\tdisplaced_members\tdisplaced_replaced\tdisplaced_nearest\tdisplaced_nearest_organs\tdisplaced_removed_organs\tdisplaced_organs\tprompt\treply\n' > "$RAW"

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

receipt_from_log() {
    local log="$1" life="$2" split="$3" base_seed="$4"
    local phase="$5" session="$6" order="$7" texture="$8"
    local run_seed="$9" prompt="${10}" reply="${11}"
    awk -v cell="$life" -v cohort="$split" -v base_seed="$base_seed" \
        -v phase="$phase" -v session="$session" -v order="$order" \
        -v texture="$texture" -v run_seed="$run_seed" \
        -v prompt="$prompt" -v reply="$reply" \
        -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$log"
}

normalize_log() {
    local log="$1" event_dir="$2" main_state="${3:-}"
    local args=(-e '/\[state-swarm:/d'
                -e "s|$event_dir/control.state|BODY|g"
                -e "s|$event_dir/displaced.state|BODY|g")
    if [ -n "$main_state" ]; then args+=(-e "s|$main_state|BODY|g"); fi
    sed "${args[@]}" "$log"
}

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

processes=0
event_count=0
while IFS=$'\t' read -r wanted_life wanted_split wanted_seed; do
    life_dir="$OUT/lives/$wanted_life"
    mkdir -p "$life_dir/logs" "$life_dir/events"
    state="$life_dir/leo.state"
    settled=""
    expected_turn=0

    while IFS=$'\t' read -r life split base_seed phase session order \
        texture run_seed prompt; do
        if [ "$phase" = writer ] && [ -z "$settled" ]; then
            settled="$(awk -F '\t' -v life="$life" '
                NR > 1 && $1 == life && $4 == "warm" {
                    rows++; states = $10
                    if ($5 == 4 && $13 != "updated") changes++
                }
                END { print (rows == 32 && states == 8 && changes == 0) ? "true" : "false" }
            ' "$RECEIPTS")"
        fi

        expected_turn=$((expected_turn + 1))
        stem="${phase}-s${session}-$(printf '%02d' "$order")-${texture}"
        log="$life_dir/logs/$stem.log"
        pre_state="$life_dir/pre-${expected_turn}.state"
        if [ "$phase" = writer ]; then cp "$state" "$pre_state"; fi

        args=("$ROOT/leo")
        if [ -f "$state" ]; then args+=(--load "$state"); fi
        args+=(--seed "$run_seed" --respond "$prompt" --debug-field \
               --save "$state")
        "${args[@]}" > "$log" 2>&1
        processes=$((processes + 1))
        [ -s "$state" ] || exit 1
        reply="$(reply_from_log "$log")"
        [ -n "$reply" ] || exit 1
        receipt="$(receipt_from_log "$log" "$life" "$split" \
            "$base_seed" "$phase" "$session" "$order" "$texture" \
            "$run_seed" "$prompt" "$reply")"
        printf '%s\n' "$receipt" >> "$RECEIPTS"
        actual_turn="$(printf '%s\n' "$receipt" | awk -F '\t' '{print $9}')"
        [ "$actual_turn" -eq "$expected_turn" ] || exit 1

        event="$(printf '%s\n' "$receipt" | awk -F '\t' '{print $13}')"
        if [ "$phase" != writer ] || [ "$event" != replaced ]; then
            if [ "$phase" = writer ]; then rm -f "$pre_state"; fi
            continue
        fi

        event_count=$((event_count + 1))
        printf -v event_id '%s-t%03d' "$life" "$actual_turn"
        event_dir="$life_dir/events/$event_id"
        mkdir -p "$event_dir/returns"
        mv "$pre_state" "$event_dir/pretrigger.state"
        cp "$state" "$event_dir/displaced.state"

        trigger_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$log")"
        IFS=$'\t' read -r trigger_turn trigger_event trigger_new_id \
            trigger_similarity trigger_members displaced_id trigger_nearest \
            trigger_nearest_organs trigger_removed_organs trigger_organs \
            <<< "$trigger_shape"
        [ "$trigger_turn" -eq "$actual_turn" ] &&
            [ "$trigger_event" = replaced ] && [ "$displaced_id" -gt 0 ] || exit 1

        cp "$event_dir/pretrigger.state" "$event_dir/control.state"
        control_trigger_log="$event_dir/trigger.control.log"
        "$ROOT/leo" --load "$event_dir/control.state" --seed "$run_seed" \
            --respond "$prompt" --debug-field --no-state-swarm \
            --save "$event_dir/control.state" > "$control_trigger_log" 2>&1
        processes=$((processes + 1))
        control_trigger_reply="$(reply_from_log "$control_trigger_log")"
        [ -n "$control_trigger_reply" ] && [ "$control_trigger_reply" = "$reply" ] || exit 1
        ! grep -q '\[state-swarm:' "$control_trigger_log" || exit 1
        normalize_log "$log" "$event_dir" "$state" > "$event_dir/trigger.displaced.normalized"
        normalize_log "$control_trigger_log" "$event_dir" "$state" > "$event_dir/trigger.control.normalized"
        cmp -s "$event_dir/trigger.displaced.normalized" \
            "$event_dir/trigger.control.normalized" || exit 1
        ! cmp -s "$event_dir/displaced.state" "$event_dir/control.state" || exit 1

        birth_info="$(awk -F '\t' -v life="$life" -v old="$displaced_id" \
            -v trigger="$trigger_turn" '
            NR > 1 && $1 == life && $9 < trigger && $12 == old &&
                ($13 == "born" || $13 == "replaced") {
                matches++; value = $9 "\t" $8 "\t" $33
            }
            END { if (matches != 1) exit 1; print value }
        ' "$RECEIPTS")"
        IFS=$'\t' read -r birth_turn birth_seed birth_prompt <<< "$birth_info"

        anchor_info="$(awk -F '\t' -v life="$life" -v old="$displaced_id" \
            -v trigger="$trigger_turn" '
            function abs(value) { return value < 0 ? -value : value }
            function mass(value, wanted,    item, pair, n, i) {
                n = split(value, item, ",")
                for (i = 1; i <= n; i++) {
                    split(item[i], pair, ":")
                    if (pair[1] + 0 == wanted) return pair[2] + 0
                }
                return 0
            }
            NR > 1 && $1 == life && $9 < trigger && $12 == old &&
                $13 == "updated" {
                value = mass($16, old)
                if (!found || value > best + 0.0000001 ||
                    (abs(value - best) <= 0.0000001 && $9 < turn)) {
                    found = 1; best = value; turn = $9
                    seed = $8; prompt = $33
                }
            }
            END {
                if (found) printf "%s\t%s\t%.6f\t%s\n", turn, seed, best, prompt
            }
        ' "$RECEIPTS")"
        anchor_available=false
        anchor_turn=0
        anchor_seed=0
        anchor_mass=0
        anchor_prompt=""
        if [ -n "$anchor_info" ]; then
            anchor_available=true
            IFS=$'\t' read -r anchor_turn anchor_seed anchor_mass anchor_prompt \
                <<< "$anchor_info"
        fi

        return_plan="$event_dir/returns.plan.tsv"
        printf '1\texact-birth\t%s\t%s\n' "$birth_seed" "$birth_prompt" > "$return_plan"
        if [ "$anchor_available" = true ]; then
            printf '2\texact-anchor\t%s\t%s\n' "$anchor_seed" "$anchor_prompt" >> "$return_plan"
        fi

        displaced_sha="$(sha256_file "$event_dir/displaced.state")"
        control_sha="$(sha256_file "$event_dir/control.state")"
        while IFS=$'\t' read -r probe kind return_seed return_prompt; do
            control_log="$event_dir/returns/p${probe}.control.log"
            displaced_log="$event_dir/returns/p${probe}.displaced.log"
            "$ROOT/leo" --load "$event_dir/control.state" --seed "$return_seed" \
                --respond "$return_prompt" --debug-field > "$control_log" 2>&1
            processes=$((processes + 1))
            "$ROOT/leo" --load "$event_dir/displaced.state" --seed "$return_seed" \
                --respond "$return_prompt" --debug-field > "$displaced_log" 2>&1
            processes=$((processes + 1))
            control_reply="$(reply_from_log "$control_log")"
            displaced_reply="$(reply_from_log "$displaced_log")"
            [ -n "$control_reply" ] && [ "$control_reply" = "$displaced_reply" ] || exit 1
            normalize_log "$control_log" "$event_dir" > "$event_dir/returns/p${probe}.control.normalized"
            normalize_log "$displaced_log" "$event_dir" > "$event_dir/returns/p${probe}.displaced.normalized"
            cmp -s "$event_dir/returns/p${probe}.control.normalized" \
                "$event_dir/returns/p${probe}.displaced.normalized" || exit 1

            control_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$control_log")"
            displaced_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$displaced_log")"
            control_turn="$(printf '%s\n' "$control_shape" | awk -F '\t' '{print $1}')"
            displaced_turn="$(printf '%s\n' "$displaced_shape" | awk -F '\t' '{print $1}')"
            [ "$control_turn" -eq $((trigger_turn + 1)) ] &&
                [ "$displaced_turn" -eq "$control_turn" ] || exit 1
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$event_id" "$life" "$split" "$settled" "$base_seed" \
                "$trigger_turn" "$displaced_id" "$trigger_new_id" \
                "$probe" "$kind" "$return_seed" "$control_shape" \
                "$displaced_shape" "$return_prompt" "$control_reply" >> "$RAW"
        done < "$return_plan"
        [ "$(sha256_file "$event_dir/displaced.state")" = "$displaced_sha" ] &&
            [ "$(sha256_file "$event_dir/control.state")" = "$control_sha" ] || exit 1

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\t%s\t%s\n' \
            "$event_id" "$life" "$split" "$settled" "$base_seed" \
            "$trigger_turn" "$displaced_id" "$trigger_new_id" \
            "$birth_turn" "$birth_seed" "$anchor_available" \
            "$anchor_turn" "$anchor_seed" "$anchor_mass" "$prompt" "$reply" \
            >> "$EVENTS"
    done < <(awk -F '\t' -v life="$wanted_life" 'NR > 1 && $1 == life' "$PLAN")
    [ -n "$settled" ] || exit 1
done < <(tail -n +2 "$LIVES")

awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_report.awk" "$RAW" > "$ANATOMY"

printf 'life\tsplit\tbase_seed\tturns\tfinal_states\twarm_changes\twriter_births\twriter_replacements\tsettled\n' > "$LIFE_SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        rows++; turns[$1]++; cohort[$1] = $2; seed[$1] = $3
        states[$1] = $10
        if ($4 == "warm" && $5 == 4 && $13 != "updated") warm_changes[$1]++
        if ($4 == "writer" && $13 == "born") births[$1]++
        if ($4 == "writer" && $13 == "replaced") replacements[$1]++
    }
    END {
        if (rows != 768 || length(turns) != 8) exit 1
        for (life in turns) {
            if (turns[life] != 96 || states[life] != 8) exit 1
            settled = warm_changes[life] == 0 ? "true" : "false"
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%s\n",
                   life, cohort[life], seed[life], turns[life], states[life],
                   warm_changes[life] + 0, births[life] + 0,
                   replacements[life] + 0, settled
        }
    }
' "$RECEIPTS" | sort >> "$LIFE_SUMMARY"

printf 'event\tlife\tsettled\treturns\tqualified\trobust\tsurvivor_return\ttrigger_capture\trebirth\tboundary_projections\n' > "$EVENT_SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        returns[$1]++; life[$1] = $2; settled[$1] = $4
        if ($13 == "true") {
            qualified[$1]++
            fate[$1 SUBSEP $14]++
            if ($25 == "true") robust[$1]++
            for (i = 17; i <= 23; i++) if ($i == "boundary") boundary[$1]++
        }
    }
    END {
        for (event in returns) {
            if (returns[event] < 1 || returns[event] > 2) exit 1
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                   event, life[event], settled[event], returns[event],
                   qualified[event] + 0, robust[event] + 0,
                   fate[event SUBSEP "survivor-return"] + 0,
                   fate[event SUBSEP "trigger-capture"] + 0,
                   fate[event SUBSEP "rebirth"] + 0, boundary[event] + 0
        }
    }
' "$ANATOMY" | sort >> "$EVENT_SUMMARY"

awk -F '\t' -v processes="$processes" -v event_count="$event_count" '
    NR == 1 { next }
    {
        returns++
        all_event[$1]++
        if ($4 != "true" || $13 != "true") next
        qualified++
        event[$1] = 1
        life[$2] = 1
        fate[$14]++
        if ($25 == "true") robust++
        for (i = 17; i <= 23; i++) {
            if ($i == "boundary") boundary++
            if ($i != $14) sensitive[i - 16]++
        }
    }
    END {
        adequate = qualified >= 8 && length(event) >= 4 && length(life) >= 4
        if (!adequate) result = "insufficient"
        else if (3 * robust >= 2 * qualified) result = "distributed"
        else if (3 * robust <= qualified) result = "organ-sensitive"
        else result = "mixed"
        print "state-swarm displacement anatomy A.86"
        printf "processes=%d main_life_turns=768 displacement_events=%d return_processes=%d\n",
               processes, event_count, processes - 768 - event_count
        printf "returns=%d qualified=%d events=%d lives=%d robust=%d\n",
               returns, qualified, length(event), length(life), robust
        printf "qualified_fates survivor-return=%d trigger-capture=%d rebirth=%d\n",
               fate["survivor-return"] + 0, fate["trigger-capture"] + 0,
               fate["rebirth"] + 0
        printf "loo_changes perception=%d expression=%d own-field=%d body=%d rhythm=%d form=%d darkmatter=%d boundary=%d\n",
               sensitive[1] + 0, sensitive[2] + 0, sensitive[3] + 0,
               sensitive[4] + 0, sensitive[5] + 0, sensitive[6] + 0,
               sensitive[7] + 0, boundary + 0
        print "adequacy requires >=8 qualified returns across >=4 events and >=4 lives"
        print "within 0.002 of replacement gate 0.40 is boundary; >=6/7 matching projections is robust"
        print "all post-settlement replacements and automatic exact birth/strongest prior updated anchors are retained"
        print "receipts are observational; no projection enters update, persistence, generation, or speech"
        print "result=" result
        if (length(all_event) != event_count) exit 1
    }
' "$ANATOMY" > "$VERDICT"

cat "$LIFE_SUMMARY"
printf '\n'
cat "$EVENT_SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nplan: %s\nevents: %s\nraw returns: %s\nanatomy: %s\n' \
    "$PLAN" "$EVENTS" "$RAW" "$ANATOMY"
