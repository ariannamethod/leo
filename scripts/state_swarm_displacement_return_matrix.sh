#!/usr/bin/env bash
# A.85: ask what becomes of an experience after its coordinate is displaced.
set -Eeuo pipefail

trap 'rc=$?; printf "displacement runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGETS="${LEO_STATE_DISPLACEMENT_TARGETS:-$ROOT/scripts/state_swarm_displacement_targets.tsv}"
RETURNS="${LEO_STATE_DISPLACEMENT_RETURNS:-$ROOT/scripts/state_swarm_displacement_returns.tsv}"
ALPHABET_CASES="${LEO_STATE_ALPHABET_CASES:-$ROOT/scripts/state_swarm_alphabet_cases.tsv}"
WARM_ROOT="${LEO_STATE_DISPLACEMENT_WARM_ROOT:-}"
WARM_RECEIPTS="${LEO_STATE_DISPLACEMENT_WARM_RECEIPTS:-}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-displacement-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
for file in "$TARGETS" "$RETURNS" "$ALPHABET_CASES"; do
    [ -s "$file" ] || {
        printf 'displacement input missing: %s\n' "$file" >&2
        exit 2
    }
done

awk -F '\t' '
    NR == 1 {
        if (NF != 7 || $1 != "case" || $2 != "cell" ||
            $3 != "cohort" || $4 != "base_seed" ||
            $5 != "trigger_session" || $6 != "trigger_order" ||
            $7 != "displaced_id") exit 1
        next
    }
    {
        if (NF != 7 || $1 !~ /^[a-z0-9-]+$/ ||
            $2 !~ /^(window|lantern)$/ ||
            $3 !~ /^(replication|confirmatory)$/ ||
            $4 !~ /^[0-9]+$/ || $5 < 1 || $5 > 8 ||
            $6 < 1 || $6 > 8 || $7 < 1 || seen[$1]++) exit 1
        rows++
    }
    END { if (rows != 3) exit 1 }
' "$TARGETS" || {
    printf 'invalid displacement targets: %s\n' "$TARGETS" >&2
    exit 2
}

awk -F '\t' '
    NR == 1 {
        if (NF != 5 || $1 != "case" || $2 != "probe" ||
            $3 != "kind" || $4 != "run_seed" || $5 != "prompt") exit 1
        next
    }
    {
        if (NF != 5 || $1 !~ /^[a-z0-9-]+$/ || $2 < 1 || $2 > 4 ||
            $3 !~ /^(exact-birth|birth-paraphrase|exact-anchor|anchor-paraphrase)$/ ||
            $4 !~ /^[0-9]+$/ || $5 == "" || seen[$1 SUBSEP $2]++) exit 1
        rows++; cases[$1]++; kinds[$1 SUBSEP $3]++
    }
    END {
        if (rows != 12 || length(cases) != 3) exit 1
        for (case_name in cases)
            if (cases[case_name] != 4 ||
                kinds[case_name SUBSEP "exact-birth"] != 1 ||
                kinds[case_name SUBSEP "birth-paraphrase"] != 1 ||
                kinds[case_name SUBSEP "exact-anchor"] != 1 ||
                kinds[case_name SUBSEP "anchor-paraphrase"] != 1) exit 1
    }
' "$RETURNS" || {
    printf 'invalid displacement returns: %s\n' "$RETURNS" >&2
    exit 2
}

mkdir -p "$OUT/cases"
PLAN="$OUT/plan.tsv"
TRIGGERS="$OUT/triggers.tsv"
RAW="$OUT/returns.raw.tsv"
PROBES="$OUT/probes.tsv"
SUMMARY="$OUT/summary.tsv"
VERDICT="$OUT/verdict.txt"

printf 'case\tcell\tcohort\tbase_seed\ttrigger_session\ttrigger_order\ttrigger_turn\ttrigger_texture\ttrigger_seed\tdisplaced_id\tprobe\tkind\treturn_seed\ttrigger_prompt\treturn_prompt\n' > "$PLAN"
tail -n +2 "$TARGETS" |
while IFS=$'\t' read -r case_name cell cohort base_seed trigger_session \
    trigger_order displaced_id; do
    trigger="$(awk -F '\t' -v session="$trigger_session" -v order="$trigger_order" '
        NR > 1 && $1 == "writer" && $2 == session && $3 == order {
            print $4 "\t" $5
        }
    ' "$ALPHABET_CASES")"
    [ "$(printf '%s\n' "$trigger" | wc -l | tr -d ' ')" -eq 1 ] || exit 1
    IFS=$'\t' read -r trigger_texture trigger_prompt <<< "$trigger"
    [ -n "$trigger_texture" ] && [ -n "$trigger_prompt" ] || exit 1
    trigger_turn=$((32 + (trigger_session - 1) * 8 + trigger_order))
    trigger_seed=$((base_seed + trigger_session * 100 + trigger_order))
    awk -F '\t' -v case_name="$case_name" 'NR > 1 && $1 == case_name' \
        "$RETURNS" |
    while IFS=$'\t' read -r return_case probe kind return_seed return_prompt; do
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$case_name" "$cell" "$cohort" "$base_seed" \
            "$trigger_session" "$trigger_order" "$trigger_turn" \
            "$trigger_texture" "$trigger_seed" "$displaced_id" \
            "$probe" "$kind" "$return_seed" "$trigger_prompt" \
            "$return_prompt" >> "$PLAN"
    done
done

if [ "${LEO_STATE_DISPLACEMENT_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null
warmup_processes=0
if [ -z "$WARM_ROOT" ]; then
    LEO_STATE_SETTLED_WARMUP_ONLY=1 \
        "$ROOT/scripts/state_swarm_settled_organ_matrix.sh" \
        "$OUT/settlement" > "$OUT/settlement.stdout"
    WARM_ROOT="$OUT/settlement/warmup/lives"
    WARM_RECEIPTS="$OUT/settlement/warmup/receipts.tsv"
    warmup_processes=96
fi

if [ -z "$WARM_RECEIPTS" ]; then
    WARM_RECEIPTS="$(dirname "$WARM_ROOT")/receipts.tsv"
fi
[ -s "$WARM_RECEIPTS" ] || {
    printf 'displacement warm receipts missing: %s\n' "$WARM_RECEIPTS" >&2
    exit 2
}

for cell in window lantern; do
    [ -s "$WARM_ROOT/$cell/leo.state" ] || {
        printf 'displacement warm state missing: %s\n' \
            "$WARM_ROOT/$cell/leo.state" >&2
        exit 2
    }
done

printf 'case\tcell\tcohort\tbase_seed\ttrigger_turn\tdisplaced_id\ttrigger_new_id\ttrigger_similarity\tvoice_equal\tnon_swarm_equal\tstate_different\ttrigger_prompt\treply\n' > "$TRIGGERS"
printf 'case\tcell\tcohort\tbase_seed\ttrigger_turn\tdisplaced_id\ttrigger_new_id\tprobe\tkind\treturn_seed\tcontrol_event\tcontrol_winner\tcontrol_similarity\tcontrol_members\tcontrol_replaced\tdisplaced_event\tdisplaced_winner\tdisplaced_similarity\tdisplaced_members\tdisplaced_replaced\tprompt\treply\n' > "$RAW"

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

receipt_from_log() {
    local log="$1" cell="$2" cohort="$3" base_seed="$4"
    local phase="$5" session="$6" order="$7" texture="$8"
    local run_seed="$9" prompt="${10}" reply="${11}"
    awk -v cell="$cell" -v cohort="$cohort" -v base_seed="$base_seed" \
        -v phase="$phase" -v session="$session" -v order="$order" \
        -v texture="$texture" -v run_seed="$run_seed" \
        -v prompt="$prompt" -v reply="$reply" \
        -f "$ROOT/scripts/state_swarm_dialogue_report.awk" "$log"
}

normalize_log() {
    local log="$1" case_dir="$2"
    sed -e '/\[state-swarm:/d' \
        -e "s|$case_dir/displaced.state|BODY|g" \
        -e "s|$case_dir/control.state|BODY|g" "$log"
}

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

tail -n +2 "$TARGETS" |
while IFS=$'\t' read -r case_name cell cohort base_seed trigger_session \
    trigger_order displaced_id; do
    case_dir="$OUT/cases/$case_name"
    mkdir -p "$case_dir/replay" "$case_dir/returns"
    work_state="$case_dir/pretrigger.state"
    cp "$WARM_ROOT/$cell/leo.state" "$work_state"

    birth_prompt="$(awk -F '\t' -v case_name="$case_name" '
        NR > 1 && $1 == case_name && $3 == "exact-birth" { print $5 }
    ' "$RETURNS")"
    [ -n "$birth_prompt" ] || exit 1
    awk -F '\t' -v cell="$cell" -v displaced_id="$displaced_id" \
        -v birth_prompt="$birth_prompt" '
        NR > 1 && $1 == cell && $12 == displaced_id && $13 == "born" &&
            $33 == birth_prompt { matches++ }
        END { if (matches != 1) exit 1 }
    ' "$WARM_RECEIPTS"

    replay_receipts="$case_dir/replay.receipts.tsv"
    : > "$replay_receipts"

    awk -F '\t' -v stop_session="$trigger_session" \
        -v stop_order="$trigger_order" '
        NR > 1 && $1 == "writer" &&
        ($2 < stop_session || ($2 == stop_session && $3 < stop_order)) {
            print $2 "\t" $3 "\t" $4 "\t" $5
        }
    ' "$ALPHABET_CASES" |
    while IFS=$'\t' read -r session order texture prompt; do
        run_seed=$((base_seed + session * 100 + order))
        log="$case_dir/replay/s${session}-$(printf '%02d' "$order")-${texture}.log"
        "$ROOT/leo" --load "$work_state" --seed "$run_seed" \
            --respond "$prompt" --debug-field --save "$work_state" \
            > "$log" 2>&1
        reply="$(reply_from_log "$log")"
        [ -n "$reply" ] || exit 1
        receipt="$(receipt_from_log "$log" "$cell" "$cohort" \
            "$base_seed" replay "$session" "$order" "$texture" \
            "$run_seed" "$prompt" "$reply")"
        printf '%s\n' "$receipt" >> "$replay_receipts"
        actual_turn="$(printf '%s\n' "$receipt" | awk -F '\t' '{print $9}')"
        expected_turn=$((32 + (session - 1) * 8 + order))
        [ "$actual_turn" -eq "$expected_turn" ] || exit 1
    done

    anchor_prompt="$(awk -F '\t' -v case_name="$case_name" '
        NR > 1 && $1 == case_name && $3 == "exact-anchor" { print $5 }
    ' "$RETURNS")"
    [ -n "$anchor_prompt" ] || exit 1
    awk -F '\t' -v displaced_id="$displaced_id" \
        -v anchor_prompt="$anchor_prompt" '
        function member_mass(value, wanted,    item, pair, n, i) {
            n = split(value, item, ",")
            for (i = 1; i <= n; i++) {
                split(item[i], pair, ":")
                if (pair[1] + 0 == wanted) return pair[2] + 0
            }
            return 0
        }
        {
            mass = member_mass($16, displaced_id)
            if (mass > maximum) maximum = mass
            if ($33 == anchor_prompt) {
                anchor_matches++
                anchor_mass = mass
            }
        }
        END {
            if (NR < 1 || anchor_matches != 1 ||
                anchor_mass + 0.000001 < maximum) exit 1
        }
    ' "$replay_receipts"

    trigger="$(awk -F '\t' -v session="$trigger_session" -v order="$trigger_order" '
        NR > 1 && $1 == "writer" && $2 == session && $3 == order {
            print $4 "\t" $5
        }
    ' "$ALPHABET_CASES")"
    IFS=$'\t' read -r trigger_texture trigger_prompt <<< "$trigger"
    trigger_seed=$((base_seed + trigger_session * 100 + trigger_order))
    expected_turn=$((32 + (trigger_session - 1) * 8 + trigger_order))
    displaced_state="$case_dir/displaced.state"
    control_state="$case_dir/control.state"
    cp "$work_state" "$displaced_state"
    cp "$work_state" "$control_state"

    displaced_log="$case_dir/trigger.displaced.log"
    control_log="$case_dir/trigger.control.log"
    "$ROOT/leo" --load "$displaced_state" --seed "$trigger_seed" \
        --respond "$trigger_prompt" --debug-field --save "$displaced_state" \
        > "$displaced_log" 2>&1
    "$ROOT/leo" --load "$control_state" --seed "$trigger_seed" \
        --respond "$trigger_prompt" --debug-field --no-state-swarm \
        --save "$control_state" > "$control_log" 2>&1

    displaced_reply="$(reply_from_log "$displaced_log")"
    control_reply="$(reply_from_log "$control_log")"
    [ -n "$displaced_reply" ] && [ "$displaced_reply" = "$control_reply" ] || exit 1
    ! grep -q '\[state-swarm:' "$control_log" || exit 1
    normalize_log "$displaced_log" "$case_dir" > "$case_dir/trigger.displaced.normalized"
    normalize_log "$control_log" "$case_dir" > "$case_dir/trigger.control.normalized"
    cmp -s "$case_dir/trigger.displaced.normalized" \
        "$case_dir/trigger.control.normalized" || exit 1
    ! cmp -s "$displaced_state" "$control_state" || exit 1

    trigger_receipt="$(receipt_from_log "$displaced_log" "$cell" "$cohort" \
        "$base_seed" trigger "$trigger_session" "$trigger_order" \
        "$trigger_texture" "$trigger_seed" "$trigger_prompt" \
        "$displaced_reply")"
    IFS=$'\t' read -r actual_turn trigger_new_id trigger_event \
        trigger_similarity trigger_replaced <<< "$(printf '%s\n' "$trigger_receipt" |
            awk -F '\t' '{print $9 "\t" $12 "\t" $13 "\t" $14 "\t" $19}')"
    [ "$actual_turn" -eq "$expected_turn" ] &&
        [ "$trigger_event" = replaced ] &&
        [ "$trigger_replaced" -eq "$displaced_id" ] || exit 1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\t%s\t%s\n' \
        "$case_name" "$cell" "$cohort" "$base_seed" "$actual_turn" \
        "$displaced_id" "$trigger_new_id" "$trigger_similarity" \
        "$trigger_prompt" "$displaced_reply" >> "$TRIGGERS"

    displaced_sha="$(sha256_file "$displaced_state")"
    control_sha="$(sha256_file "$control_state")"
    awk -F '\t' -v case_name="$case_name" 'NR > 1 && $1 == case_name' \
        "$RETURNS" |
    while IFS=$'\t' read -r return_case probe kind return_seed prompt; do
        control_return_log="$case_dir/returns/p${probe}.control.log"
        displaced_return_log="$case_dir/returns/p${probe}.displaced.log"
        "$ROOT/leo" --load "$control_state" --seed "$return_seed" \
            --respond "$prompt" --debug-field > "$control_return_log" 2>&1
        "$ROOT/leo" --load "$displaced_state" --seed "$return_seed" \
            --respond "$prompt" --debug-field > "$displaced_return_log" 2>&1
        control_return_reply="$(reply_from_log "$control_return_log")"
        displaced_return_reply="$(reply_from_log "$displaced_return_log")"
        [ -n "$control_return_reply" ] &&
            [ "$control_return_reply" = "$displaced_return_reply" ] || exit 1
        normalize_log "$control_return_log" "$case_dir" \
            > "$case_dir/returns/p${probe}.control.normalized"
        normalize_log "$displaced_return_log" "$case_dir" \
            > "$case_dir/returns/p${probe}.displaced.normalized"
        cmp -s "$case_dir/returns/p${probe}.control.normalized" \
            "$case_dir/returns/p${probe}.displaced.normalized" || exit 1

        control_receipt="$(receipt_from_log "$control_return_log" "$cell" \
            "$cohort" "$base_seed" control-return 0 "$probe" return \
            "$return_seed" "$prompt" "$control_return_reply")"
        displaced_receipt="$(receipt_from_log "$displaced_return_log" "$cell" \
            "$cohort" "$base_seed" displaced-return 0 "$probe" return \
            "$return_seed" "$prompt" "$displaced_return_reply")"
        IFS=$'\t' read -r control_turn control_winner control_event \
            control_similarity control_members control_replaced <<< "$(
                printf '%s\n' "$control_receipt" |
                awk -F '\t' '{print $9 "\t" $12 "\t" $13 "\t" $14 "\t" $16 "\t" $19}'
            )"
        IFS=$'\t' read -r displaced_turn displaced_winner displaced_event \
            displaced_similarity displaced_members displaced_replaced <<< "$(
                printf '%s\n' "$displaced_receipt" |
                awk -F '\t' '{print $9 "\t" $12 "\t" $13 "\t" $14 "\t" $16 "\t" $19}'
            )"
        [ "$control_turn" -eq $((expected_turn + 1)) ] &&
            [ "$displaced_turn" -eq "$control_turn" ] || exit 1
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$case_name" "$cell" "$cohort" "$base_seed" "$expected_turn" \
            "$displaced_id" "$trigger_new_id" "$probe" "$kind" \
            "$return_seed" "$control_event" "$control_winner" \
            "$control_similarity" "$control_members" "$control_replaced" \
            "$displaced_event" "$displaced_winner" "$displaced_similarity" \
            "$displaced_members" "$displaced_replaced" "$prompt" \
            "$control_return_reply" >> "$RAW"
    done
    [ "$(sha256_file "$displaced_state")" = "$displaced_sha" ] &&
        [ "$(sha256_file "$control_state")" = "$control_sha" ] || exit 1
done

awk -f "$ROOT/scripts/state_swarm_displacement_report.awk" "$RAW" > "$PROBES"

printf 'case\tprobes\tqualified\tsurvivor_return\ttrigger_capture\trebirth\tverdict\n' > "$SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        rows++; probes[$1]++
        if ($19 == "true") {
            qualified[$1]++
            fate[$1 SUBSEP $20]++
        }
    }
    END {
        if (rows != 12 || length(probes) != 3) exit 1
        for (case_name in probes) {
            if (probes[case_name] != 4) exit 1
            if (qualified[case_name] < 2) verdict = "unanchored"
            else {
                kinds = (fate[case_name SUBSEP "survivor-return"] > 0) + (fate[case_name SUBSEP "trigger-capture"] > 0) + (fate[case_name SUBSEP "rebirth"] > 0)
                if (kinds > 1) verdict = "mixed-return"
                else if (fate[case_name SUBSEP "survivor-return"] > 0)
                    verdict = "survivor-return"
                else if (fate[case_name SUBSEP "trigger-capture"] > 0)
                    verdict = "trigger-capture"
                else verdict = "rebirth"
            }
            printf "%s\t%d\t%d\t%d\t%d\t%d\t%s\n",
                   case_name, probes[case_name], qualified[case_name] + 0,
                   fate[case_name SUBSEP "survivor-return"] + 0,
                   fate[case_name SUBSEP "trigger-capture"] + 0,
                   fate[case_name SUBSEP "rebirth"] + 0, verdict
        }
    }
' "$PROBES" | sort >> "$SUMMARY"

awk -F '\t' -v warmup_processes="$warmup_processes" '
    FILENAME == ARGV[1] {
        if (FNR > 1) {
            triggers++
            if ($9 != "true" || $10 != "true" || $11 != "true") exit 1
        }
        next
    }
    FNR == 1 { next }
    {
        cases++
        verdict[$7]++
        qualified += $3
        survivor_return += $4
        trigger_capture += $5
        rebirth += $6
    }
    END {
        print "state-swarm displacement return A.85"
        printf "processes=%d warmup=%d replay=97 trigger_forks=6 return_forks=24\n",
               warmup_processes + 127, warmup_processes
        printf "triggers=%d cases=%d qualified_probes=%d/12\n",
               triggers, cases, qualified
        printf "qualified_fates survivor-return=%d trigger-capture=%d rebirth=%d\n",
               survivor_return, trigger_capture, rebirth
        printf "unanchored=%d survivor-return=%d trigger-capture=%d rebirth=%d mixed-return=%d\n",
               verdict["unanchored"] + 0, verdict["survivor-return"] + 0,
               verdict["trigger-capture"] + 0, verdict["rebirth"] + 0,
               verdict["mixed-return"] + 0
        print "control anchor requires old-ID winner, mass >=0.20, and margin >=0.02"
        print "return probes do not save; their in-process observation is the measurement"
        print "state-swarm remains invisible to speech"
        if (triggers != 3 || cases != 3) exit 1
    }
' "$TRIGGERS" "$SUMMARY" > "$VERDICT"

cat "$TRIGGERS"
printf '\n'
cat "$PROBES"
printf '\n'
cat "$SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nplan: %s\nraw returns: %s\n' "$PLAN" "$RAW"
