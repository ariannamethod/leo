#!/usr/bin/env bash
# A.93: test whether ordered short experience outlives its reversed control.
set -Eeuo pipefail

trap 'rc=$?; printf "liminal trace runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
A89="${LEO_STATE_TRACE_A89_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
A91="${LEO_STATE_TRACE_A91_SOURCE:-/private/tmp/leo-state-swarm-near-gate-controls-a91-r2-20260807}"
A92="${LEO_STATE_TRACE_A92_SOURCE:-/private/tmp/leo-state-swarm-liminal-confirmation-a92-r6-20260807}"
EXPECTED="${LEO_STATE_TRACE_EXPECTED_PAIRS:-14}"
EXPECTED_SELECTION_SHA="${LEO_STATE_TRACE_SELECTION_SHA:-394a1b43fa915fc144a67019711b311c6092e9b075c4ba62ede680d590be26ec}"
EXPECTED_PLAN_SHA="${LEO_STATE_TRACE_PLAN_SHA:-9b0434bfa9bcc4c5cb6051cf7a6133f3fe0f51add036b5273721ece327e5ca2a}"
EXPECTED_LOCK_SHA="${LEO_STATE_TRACE_LOCK_SHA:-e60d20854dda2f352a21014bb87b72959895fecd95d5953061afc13cd0409197}"
EXPECTED_WRITER_SHA="${LEO_STATE_TRACE_WRITER_SHA:-10bf4251848f4edaec4a34d66d3d811afff187df9f10aeb71ff761a342c0e833}"
AGGREGATE_ONLY="${LEO_STATE_TRACE_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-liminal-trace-$STAMP}"

case "$EXPECTED" in
    ''|*[!0-9]*|0) printf 'invalid trace pair count: %s\n' "$EXPECTED" >&2; exit 2 ;;
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
LOCKS="$OUT/trajectory-locks.tsv"
SCORES="$OUT/scores.tsv"
PAIR_SUMMARY="$OUT/pair-summary.tsv"
VERDICT="$OUT/verdict.txt"

select_plan() {
    awk -f "$ROOT/scripts/state_swarm_liminal_trace_select.awk" \
        "$A92_SELECTION" "$A92_PLAN" "$A92_LOCKS"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    [ -s "$PLAN" ] && [ -s "$LOCKS" ] && [ -s "$SCORES" ] || {
        printf 'incomplete liminal trace cannot be aggregated: %s\n' "$OUT" >&2
        exit 2
    }
    plan_check="$(mktemp "${TMPDIR:-/tmp}/leo-liminal-trace-plan.XXXXXX")"
    select_plan > "$plan_check"
    cmp -s "$PLAN" "$plan_check" || {
        rm -f "$plan_check"
        printf 'liminal trace plan no longer matches A.92: %s\n' "$PLAN" >&2
        exit 2
    }
    rm -f "$plan_check"
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT/trajectories"
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
            $2 !~ /^(event|ecology)$/ || seen[key]++ ||
            $4 !~ /^[ph][0-9][0-9]$/ || $5 !~ /^(primary|holdout)$/ ||
            $7 !~ /^[0-9]+$/ || $7 > 88 ||
            $10 !~ /^(home|storm|wonder|social)$/) exit 1
        for (i = 17; i <= 19; i++)
            if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) exit 1
        rows++
    }
    END { if (rows != expected * 2) exit 1 }
' "$PLAN" || {
    printf 'invalid A.93 plan: %s\n' "$PLAN" >&2
    exit 2
}

while IFS=$'\t' read -r pair arm anchor life split base_seed turn session \
    order texture run_seed prompt reply pre_state post_state final_state \
    pre_sha post_sha final_sha; do
    [ "$(sha256_file "$pre_state")" = "$pre_sha" ] &&
        [ "$(sha256_file "$post_state")" = "$post_sha" ] &&
        [ "$(sha256_file "$final_state")" = "$final_sha" ] || {
        printf 'A.93 anchor package changed: %s %s\n' "$arm" "$anchor" >&2
        exit 2
    }
done < <(tail -n +2 "$PLAN")

if [ "${LEO_STATE_TRACE_PLAN_ONLY:-0}" = 1 ]; then
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
    FIXTURE="$OUT/liminal-trace-fixture"
    "$CC" "$ROOT/tests/state_swarm_liminal_trace_fixture.c" \
        -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread
    printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turns\tbuild_turns\tscore_turns\tpre_sha\tpost_sha\tfinal_sha\treproduced_sha\tlog_equal\tstate_equal\tgeometry_equal\n' > "$LOCKS"
    printf 'pair\tarm\tanchor\tanchor_turn\tfuture_turn\trelative\ttexture\tforward_similarity\treverse_similarity\tstable_similarity\tstable_nearest_id\tforward_stable_margin\treverse_stable_margin\torder_margin\tdirectional_nearest\tsupport\tstrong\tforward_organs\treverse_organs\tstable_organs\tprompt\treply\n' > "$SCORES"
    while IFS=$'\t' read -r pair arm anchor life split base_seed turn session \
        order texture run_seed prompt reply pre_state post_state final_state \
        pre_sha post_sha final_sha; do
        trajectory="$OUT/trajectories/$pair-$arm-$anchor"
        mkdir -p "$trajectory"
        future="$trajectory/future.tsv"
        work_state="$trajectory/work.state"
        trace="$trajectory/trace.bin"
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
            printf 'A.93 anchor geometry mismatch: %s %s\n' "$arm" "$anchor" >&2
            exit 2
        }
        "$FIXTURE" start "$trace" "$turn" "$run_seed" "$prompt" "$reply" \
            "$pre_state" "$observed_nearest" "$observed_similarity" \
            "$observed_nearest_organs"
        cp "$post_state" "$work_state"
        printf 'relative\tturn\tsession\torder\ttexture\trun_seed\tprompt\treply\n' > "$future"
        awk -F '\t' -v life="$life" -v anchor="$turn" '
            NR == 1 {
                if (NF != 34 || $1 != "life" || $5 != "session" ||
                    $8 != "run_seed" || $9 != "turn" ||
                    $33 != "prompt" || $34 != "reply") exit 2
                next
            }
            $1 == life && $9 > anchor {
                print ($9 - anchor) "\t" $9 "\t" $5 "\t" $6 "\t" $7 \
                      "\t" $8 "\t" $33 "\t" $34
                rows++
            }
            END { if (rows != 96 - anchor) exit 2 }
        ' "$WRITER_RECEIPTS" >> "$future"
        while IFS=$'\t' read -r relative future_turn future_session \
            future_order future_texture future_seed future_prompt \
            future_reply; do
            printf -v padded '%02d' "$future_order"
            source_log="$A89/candidates/$life/writer-logs/s${future_session}-${padded}-${future_texture}.log"
            [ -s "$source_log" ] || {
                printf 'missing A.93 source log: %s turn=%s\n' "$anchor" "$future_turn" >&2
                exit 2
            }
            future_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$source_log")"
            IFS=$'\t' read -r shape_turn shape_event shape_new \
                shape_similarity shape_members shape_displaced shape_nearest \
                shape_nearest_organs shape_removed_organs shape_organs \
                <<< "$future_shape"
            [ "$shape_turn" -eq "$future_turn" ] && [ "$shape_nearest" -gt 0 ] || {
                printf 'A.93 future geometry mismatch: %s turn=%s\n' "$anchor" "$future_turn" >&2
                exit 2
            }
            if [ "$relative" -le 3 ]; then
                "$FIXTURE" absorb "$trace" "$future_turn" "$future_seed" \
                    "$future_prompt" "$future_reply" "$work_state" \
                    "$shape_nearest" "$shape_similarity" "$shape_nearest_organs"
            elif [ "$relative" -le 8 ]; then
                "$FIXTURE" score "$trace" "$pair" "$arm" "$anchor" \
                    "$turn" "$future_turn" "$relative" "$future_texture" \
                    "$future_seed" "$future_prompt" "$future_reply" \
                    "$work_state" "$shape_nearest" "$shape_similarity" \
                    "$shape_nearest_organs" >> "$SCORES"
            fi
            generated_log="$trajectory/t${future_turn}.log"
            source_normalized="$trajectory/t${future_turn}.source.normalized"
            generated_normalized="$trajectory/t${future_turn}.generated.normalized"
            "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$work_state" \
                --seed "$future_seed" --respond "$future_prompt" \
                --debug-field --save "$work_state" > "$generated_log" 2>&1
            normalize_log "$source_log" > "$source_normalized"
            normalize_log "$generated_log" > "$generated_normalized"
            cmp -s "$source_normalized" "$generated_normalized" || {
                printf 'A.93 full-log replay mismatch: %s turn=%s\n' "$anchor" "$future_turn" >&2
                exit 1
            }
        done < <(tail -n +2 "$future")
        cmp -s "$final_state" "$work_state"
        reproduced_sha="$(sha256_file "$work_state")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t3\t5\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\n' \
            "$pair" "$arm" "$anchor" "$life" "$split" "$turn" \
            "$((96 - turn))" "$pre_sha" "$post_sha" "$final_sha" \
            "$reproduced_sha" >> "$LOCKS"
        rm -f "$work_state" "$trace"
    done < <(tail -n +2 "$PLAN")
    rm -f "$FIXTURE"
fi

awk -v expected="$EXPECTED" \
    -f "$ROOT/scripts/state_swarm_liminal_trace_report.awk" \
    "$LOCKS" "$SCORES" > "$PAIR_SUMMARY"
awk -v expected="$EXPECTED" \
    -f "$ROOT/scripts/state_swarm_liminal_trace_verdict.awk" \
    "$PAIR_SUMMARY" > "$VERDICT"

cat "$LOCKS"
printf '\n'
cat "$PAIR_SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nsource-a92: %s\nrun: %s\n' "$A92" "$OUT"
