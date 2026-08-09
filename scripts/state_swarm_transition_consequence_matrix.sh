#!/usr/bin/env bash
# A.94: ask whether a crossing exposes debt in the frozen state graph.
set -Eeuo pipefail

trap 'rc=$?; printf "transition consequence runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
A89="${LEO_STATE_CONSEQUENCE_A89_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
A91="${LEO_STATE_CONSEQUENCE_A91_SOURCE:-/private/tmp/leo-state-swarm-near-gate-controls-a91-r2-20260807}"
A92="${LEO_STATE_CONSEQUENCE_A92_SOURCE:-/private/tmp/leo-state-swarm-liminal-confirmation-a92-r6-20260807}"
EXPECTED="${LEO_STATE_CONSEQUENCE_EXPECTED_PAIRS:-15}"
EXPECTED_SELECTION_SHA="${LEO_STATE_CONSEQUENCE_SELECTION_SHA:-394a1b43fa915fc144a67019711b311c6092e9b075c4ba62ede680d590be26ec}"
EXPECTED_PLAN_SHA="${LEO_STATE_CONSEQUENCE_PLAN_SHA:-9b0434bfa9bcc4c5cb6051cf7a6133f3fe0f51add036b5273721ece327e5ca2a}"
EXPECTED_LOCK_SHA="${LEO_STATE_CONSEQUENCE_LOCK_SHA:-e60d20854dda2f352a21014bb87b72959895fecd95d5953061afc13cd0409197}"
EXPECTED_WRITER_SHA="${LEO_STATE_CONSEQUENCE_WRITER_SHA:-10bf4251848f4edaec4a34d66d3d811afff187df9f10aeb71ff761a342c0e833}"
AGGREGATE_ONLY="${LEO_STATE_CONSEQUENCE_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-transition-consequence-$STAMP}"

case "$EXPECTED" in
    ''|*[!0-9]*|0) printf 'invalid consequence pair count: %s\n' "$EXPECTED" >&2; exit 2 ;;
esac

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

seal() {
    local path="$1" expected="$2" label="$3"
    [ -s "$path" ] && [ "$(sha256_file "$path")" = "$expected" ] || {
        printf '%s is not the sealed source: %s\n' "$label" "$path" >&2
        exit 2
    }
}

A92_SELECTION="$A92/selection.tsv"
A92_PLAN="$A92/plan.tsv"
A92_LOCKS="$A92/trajectory-locks.tsv"
WRITER_RECEIPTS="$A89/writer-receipts.tsv"
seal "$A92_SELECTION" "$EXPECTED_SELECTION_SHA" "A.92 selection"
seal "$A92_PLAN" "$EXPECTED_PLAN_SHA" "A.92 anchor plan"
seal "$A92_LOCKS" "$EXPECTED_LOCK_SHA" "A.92 trajectory locks"
seal "$WRITER_RECEIPTS" "$EXPECTED_WRITER_SHA" "A.89 writer receipts"

PLAN="$OUT/plan.tsv"
LOCKS="$OUT/replay-locks.tsv"
SCORES="$OUT/scores.tsv"
PAIR_SUMMARY="$OUT/pair-summary.tsv"
VERDICT="$OUT/verdict.txt"

select_plan() {
    awk -f "$ROOT/scripts/state_swarm_transition_consequence_select.awk" \
        "$A92_SELECTION" "$A92_PLAN" "$A92_LOCKS"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    [ -s "$PLAN" ] && [ -s "$LOCKS" ] && [ -s "$SCORES" ] || {
        printf 'incomplete transition consequence run: %s\n' "$OUT" >&2
        exit 2
    }
    plan_check="$(mktemp "${TMPDIR:-/tmp}/leo-transition-consequence-plan.XXXXXX")"
    select_plan > "$plan_check"
    cmp -s "$PLAN" "$plan_check" || {
        rm -f "$plan_check"
        printf 'transition consequence plan no longer matches A.92: %s\n' \
            "$PLAN" >&2
        exit 2
    }
    rm -f "$plan_check"
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT/replays"
    select_plan > "$PLAN"
fi

awk -F '\t' -v expected="$EXPECTED" '
    NR == 1 {
        if (NF != 19 || $1 != "pair" || $2 != "arm" ||
            $7 != "turn" || $14 != "pre_state" || $19 != "final_sha")
            exit 1
        next
    }
    {
        key = $1 SUBSEP $2
        if (NF != 19 || $1 !~ /^[0-9][0-9]$/ ||
            $2 !~ /^(event|ecology)$/ || seen[key]++ || $3 == "" ||
            $4 !~ /^[ph][0-9][0-9]$/ || $5 !~ /^(primary|holdout)$/ ||
            $7 !~ /^[0-9]+$/ || $7 >= 96 ||
            $10 !~ /^(home|storm|wonder|social)$/ ||
            $12 == "" || $13 == "") exit 1
        for (i = 17; i <= 19; i++)
            if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) exit 1
        rows++
    }
    END { if (rows != expected * 2) exit 1 }
' "$PLAN" || {
    printf 'invalid A.94 plan: %s\n' "$PLAN" >&2
    exit 2
}

while IFS=$'\t' read -r pair arm anchor life split base_seed turn session \
    order texture run_seed prompt reply pre_state post_state final_state \
    pre_sha post_sha final_sha; do
    [ "$(sha256_file "$pre_state")" = "$pre_sha" ] &&
        [ "$(sha256_file "$post_state")" = "$post_sha" ] &&
        [ "$(sha256_file "$final_state")" = "$final_sha" ] || {
        printf 'A.94 anchor package changed: %s %s\n' "$arm" "$anchor" >&2
        exit 2
    }
done < <(tail -n +2 "$PLAN")

if [ "${LEO_STATE_CONSEQUENCE_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

normalize_log() {
    sed -E \
        -e 's|^\[leo\] loaded state from .*$|[leo] loaded state from BODY|' \
        -e 's|^\[leo\] saved state to .* \(step=|[leo] saved state to BODY (step=|' \
        "$1"
}

if [ "$AGGREGATE_ONLY" != 1 ]; then
    make -C "$ROOT" leo >/dev/null
    FIXTURE="$OUT/transition-consequence-fixture"
    "$CC" "$ROOT/tests/state_swarm_transition_consequence_fixture.c" \
        -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread
    printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turns\tpre_sha\tpost_sha\tsource_log_sha\treplay_log_sha\tnormalized_sha\ta92_reply_equal\ta92_state_equal\tnext_log_equal\tgeometry_equal\n' > "$LOCKS"
    printf 'pair\tarm\tanchor\tanchor_turn\tfuture_turn\ttexture\tanchor_similarity\tanchor_entropy\tnext_similarity\tnext_entropy\ttransition_mass\tforward_overlap\treverse_mass\treverse_overlap\ttransition_debt\tarrow_margin\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tactual_grounded\tactual_distress_relief\tactual_gap_relief\tactual_alignment_delta\toutcome_mae\tjoint_debt\tprompt\treply\n' > "$SCORES"
    while IFS=$'\t' read -r pair arm anchor life split base_seed turn session \
        order texture run_seed prompt reply pre_state post_state final_state \
        pre_sha post_sha final_sha; do
        replay="$OUT/replays/$pair-$arm-$anchor"
        mkdir -p "$replay"
        graph="$replay/frozen-graph.bin"
        work_state="$replay/work.state"
        if [ "$arm" = event ]; then
            anchor_log="$A89/candidates/$life/events/$anchor/trigger.log"
        else
            anchor_log="$A91/controls/$anchor/source.log"
        fi
        anchor_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$anchor_log")"
        IFS=$'\t' read -r observed_turn observed_event observed_new \
            observed_similarity observed_members observed_displaced \
            observed_nearest observed_nearest_organs observed_removed_organs \
            observed_organs <<< "$anchor_shape"
        [ "$observed_turn" -eq "$turn" ] && [ "$observed_nearest" -gt 0 ] || {
            printf 'A.94 anchor geometry mismatch: %s %s\n' "$arm" "$anchor" >&2
            exit 2
        }
        "$FIXTURE" start "$graph" "$turn" "$run_seed" "$prompt" "$reply" \
            "$pre_state" "$observed_nearest" "$observed_similarity" \
            "$observed_nearest_organs"

        next_receipt="$replay/next.tsv"
        awk -F '\t' -v life="$life" -v turn="$((turn + 1))" '
            BEGIN { OFS = "\t" }
            NR == 1 {
                if (NF != 34 || $1 != "life" || $5 != "session" ||
                    $8 != "run_seed" || $9 != "turn" ||
                    $25 != "observed_grounded" || $28 != "observed_alignment_delta" ||
                    $33 != "prompt" || $34 != "reply") exit 2
                next
            }
            $1 == life && $9 == turn {
                print $5, $6, $7, $8, $9, $25, $26, $27, $28, $33, $34
                rows++
            }
            END { if (rows != 1) exit 2 }
        ' "$WRITER_RECEIPTS" > "$next_receipt"
        IFS=$'\t' read -r next_session next_order next_texture next_seed \
            next_turn actual_grounded actual_distress actual_gap \
            actual_alignment next_prompt next_reply < "$next_receipt"
        printf -v padded '%02d' "$next_order"
        source_log="$A89/candidates/$life/writer-logs/s${next_session}-${padded}-${next_texture}.log"
        [ -s "$source_log" ] || {
            printf 'missing A.94 next source log: %s turn=%s\n' "$anchor" "$next_turn" >&2
            exit 2
        }
        next_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$source_log")"
        IFS=$'\t' read -r shape_turn shape_event shape_new shape_similarity \
            shape_members shape_displaced shape_nearest shape_nearest_organs \
            shape_removed_organs shape_organs <<< "$next_shape"
        [ "$shape_turn" -eq "$next_turn" ] && [ "$shape_nearest" -gt 0 ] || {
            printf 'A.94 next geometry mismatch: %s turn=%s\n' "$anchor" "$next_turn" >&2
            exit 2
        }

        cp "$post_state" "$work_state"
        "$FIXTURE" score "$graph" "$pair" "$arm" "$anchor" "$turn" \
            "$next_turn" 1 "$next_texture" "$next_seed" "$next_prompt" \
            "$next_reply" "$work_state" "$shape_nearest" \
            "$shape_similarity" "$shape_nearest_organs" \
            "$actual_grounded" "$actual_distress" "$actual_gap" \
            "$actual_alignment" >> "$SCORES"

        generated_log="$replay/next.generated.log"
        source_normalized="$replay/next.source.normalized"
        generated_normalized="$replay/next.generated.normalized"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$work_state" \
            --seed "$next_seed" --respond "$next_prompt" --debug-field \
            --save "$work_state" > "$generated_log" 2>&1
        normalize_log "$source_log" > "$source_normalized"
        normalize_log "$generated_log" > "$generated_normalized"
        cmp -s "$source_normalized" "$generated_normalized" || {
            printf 'A.94 next full-log replay mismatch: %s turn=%s\n' \
                "$anchor" "$next_turn" >&2
            exit 1
        }

        a92_lock="$replay/a92-lock.tsv"
        awk -F '\t' -v pair="$pair" -v arm="$arm" '
            NR == 1 { next }
            $1 == pair && $2 == arm { print $7 "\t" $12 "\t" $13; rows++ }
            END { if (rows != 1) exit 2 }
        ' "$A92_LOCKS" > "$a92_lock"
        IFS=$'\t' read -r future_turns a92_reply_equal a92_state_equal \
            < "$a92_lock"
        [ "$a92_reply_equal" = true ] && [ "$a92_state_equal" = true ] || {
            printf 'A.94 inherited an open A.92 lock: %s %s\n' "$arm" "$anchor" >&2
            exit 2
        }
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' \
            "$pair" "$arm" "$anchor" "$life" "$split" "$turn" \
            "$future_turns" "$pre_sha" "$post_sha" \
            "$(sha256_file "$source_log")" "$(sha256_file "$generated_log")" \
            "$(sha256_file "$generated_normalized")" >> "$LOCKS"
        rm -f "$work_state" "$graph"
    done < <(tail -n +2 "$PLAN")
    rm -f "$FIXTURE"
fi

awk -v expected="$EXPECTED" \
    -f "$ROOT/scripts/state_swarm_transition_consequence_report.awk" \
    "$LOCKS" "$SCORES" > "$PAIR_SUMMARY"
awk -v expected="$EXPECTED" \
    -f "$ROOT/scripts/state_swarm_transition_consequence_verdict.awk" \
    "$PAIR_SUMMARY" > "$VERDICT"

cat "$LOCKS"
printf '\n'
cat "$PAIR_SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nsource-a89: %s\nsource-a91: %s\nsource-a92: %s\nrun: %s\n' \
    "$A89" "$A91" "$A92" "$OUT"
