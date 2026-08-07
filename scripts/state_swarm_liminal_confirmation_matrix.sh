#!/usr/bin/env bash
# A.92: ask later life whether a frozen crossing deserves a stable coordinate.
set -Eeuo pipefail

trap 'rc=$?; printf "liminal confirmation runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
A89="${LEO_STATE_LIMINAL_A89_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
A90="${LEO_STATE_LIMINAL_A90_SOURCE:-/private/tmp/leo-state-swarm-trigger-gate-anatomy-a90-r1-20260807}"
A91="${LEO_STATE_LIMINAL_A91_SOURCE:-/private/tmp/leo-state-swarm-near-gate-controls-a91-r2-20260807}"
EXPECTED="${LEO_STATE_LIMINAL_EXPECTED_PAIRS:-15}"
EXPECTED_TRIGGER_SHA="${LEO_STATE_LIMINAL_TRIGGER_SHA:-72de2d7bfc3dd873d513457867c440f36709b80c3f7dcd1bb43e728aa9d0c9a3}"
EXPECTED_EVENT_LOCK_SHA="${LEO_STATE_LIMINAL_EVENT_LOCK_SHA:-2f1a4e341745a2dda5a1c74550a73da574653dbbc08c5717e382ebd4fd4e3bc1}"
EXPECTED_MATCH_SHA="${LEO_STATE_LIMINAL_MATCH_SHA:-16db7b1f0f865f93f2a7e261889660dc1f3df7f0f63eec7cfb41a547697b54f2}"
EXPECTED_CONTROL_LOCK_SHA="${LEO_STATE_LIMINAL_CONTROL_LOCK_SHA:-1d28607ea891338403f8ed2c94c3f935752afe7680dedf42b70a8106cfb07321}"
AGGREGATE_ONLY="${LEO_STATE_LIMINAL_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-liminal-confirmation-$STAMP}"

case "$EXPECTED" in
    ''|*[!0-9]*|0) printf 'invalid eligible pair count: %s\n' "$EXPECTED" >&2; exit 2 ;;
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

TRIGGERS="$A89/trigger-events.tsv"
WRITER_RECEIPTS="$A89/writer-receipts.tsv"
EVENT_LOCKS="$A90/replay-locks.tsv"
MATCHES="$A91/matches.tsv"
CONTROL_LOCKS="$A91/control-replay-locks.tsv"
seal "$TRIGGERS" "$EXPECTED_TRIGGER_SHA" "A.89 trigger ledger"
seal "$EVENT_LOCKS" "$EXPECTED_EVENT_LOCK_SHA" "A.90 event locks"
seal "$MATCHES" "$EXPECTED_MATCH_SHA" "A.91 matches"
seal "$CONTROL_LOCKS" "$EXPECTED_CONTROL_LOCK_SHA" "A.91 control locks"
[ -s "$WRITER_RECEIPTS" ] || {
    printf 'missing A.89 writer receipts: %s\n' "$WRITER_RECEIPTS" >&2
    exit 2
}

SELECTION="$OUT/selection.tsv"
PLAN="$OUT/plan.tsv"
LOCKS="$OUT/trajectory-locks.tsv"
OBSERVATIONS="$OUT/observations.tsv"
PAIR_SUMMARY="$OUT/pair-summary.tsv"
VERDICT="$OUT/verdict.txt"

if [ "$AGGREGATE_ONLY" = 1 ]; then
    [ -s "$SELECTION" ] && [ -s "$PLAN" ] && [ -s "$LOCKS" ] &&
        [ -s "$OBSERVATIONS" ] || {
        printf 'incomplete liminal trajectories cannot be aggregated: %s\n' "$OUT" >&2
        exit 2
    }
    selection_check="$(mktemp "${TMPDIR:-/tmp}/leo-liminal-selection.XXXXXX")"
    awk -f "$ROOT/scripts/state_swarm_liminal_confirmation_select.awk" \
        "$MATCHES" "$EVENT_LOCKS" "$CONTROL_LOCKS" > "$selection_check"
    cmp -s "$SELECTION" "$selection_check" || {
        rm -f "$selection_check"
        printf 'liminal selection no longer matches sealed sources: %s\n' \
            "$SELECTION" >&2
        exit 2
    }
    rm -f "$selection_check"
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT/trajectories"
    awk -f "$ROOT/scripts/state_swarm_liminal_confirmation_select.awk" \
        "$MATCHES" "$EVENT_LOCKS" "$CONTROL_LOCKS" > "$SELECTION"
    [ "$(($(wc -l < "$SELECTION") - 1))" -eq "$((EXPECTED * 2))" ] || {
        printf 'eligible A.92 selection is incomplete\n' >&2
        exit 2
    }

    printf 'pair\tarm\tanchor\tlife\tsplit\tbase_seed\tturn\tsession\torder\ttexture\trun_seed\tprompt\treply\tpre_state\tpost_state\tfinal_state\tpre_sha\tpost_sha\tfinal_sha\n' > "$PLAN"
    while IFS=$'\t' read -r pair arm anchor life split base_seed turn \
        session order texture run_seed prompt reply; do
        if [ "$arm" = event ]; then
            anchor_dir="$A89/candidates/$life/events/$anchor"
            pre_state="$anchor_dir/pretrigger.state"
            post_state="$anchor_dir/displaced.state"
        else
            anchor_dir="$A91/controls/$anchor"
            pre_state="$anchor_dir/precontrol.state"
            post_state="$anchor_dir/updated.state"
        fi
        final_state="$A89/candidates/$life/leo.state"
        [ -s "$pre_state" ] && [ -s "$post_state" ] &&
            [ -s "$final_state" ] || {
            printf 'incomplete anchor package: %s %s\n' "$arm" "$anchor" >&2
            exit 2
        }
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$pair" "$arm" "$anchor" "$life" "$split" "$base_seed" \
            "$turn" "$session" "$order" "$texture" "$run_seed" \
            "$prompt" "$reply" "$pre_state" "$post_state" "$final_state" \
            "$(sha256_file "$pre_state")" "$(sha256_file "$post_state")" \
            "$(sha256_file "$final_state")" >> "$PLAN"
    done < <(tail -n +2 "$SELECTION")
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
            $3 == "" || $4 !~ /^[ph][0-9][0-9]$/ ||
            $5 !~ /^(primary|holdout)$/ || $7 !~ /^[0-9]+$/ ||
            $7 >= 96 || $10 !~ /^(home|storm|wonder|social)$/ ||
            $12 == "" || $13 == "") exit 1
        for (i = 17; i <= 19; i++)
            if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) exit 1
        rows++
    }
    END { if (rows != expected * 2) exit 1 }
' "$PLAN" || {
    printf 'invalid A.92 anchor plan: %s\n' "$PLAN" >&2
    exit 2
}

awk -F '\t' -v expected="$EXPECTED" '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        key = $1 SUBSEP $2
        if (NF != 13 || selected[key]++) exit 1
        for (i = 1; i <= 13; i++) field[key, i] = $i
        selections++
        next
    }
    FNR == 1 { next }
    {
        key = $1 SUBSEP $2
        if (NF != 19 || !(key in selected) || planned[key]++) exit 1
        for (i = 1; i <= 13; i++) if ($i != field[key, i]) exit 1
        plans++
    }
    END {
        if (selections != expected * 2 || plans != expected * 2) exit 1
        for (key in selected) if (!(key in planned)) exit 1
    }
' "$SELECTION" "$PLAN" || {
    printf 'A.92 anchor plan diverges from sealed selection: %s\n' "$PLAN" >&2
    exit 2
}

while IFS=$'\t' read -r pair arm anchor life split base_seed turn session \
    order texture run_seed prompt reply pre_state post_state final_state \
    pre_sha post_sha final_sha; do
    [ "$(sha256_file "$pre_state")" = "$pre_sha" ] &&
        [ "$(sha256_file "$post_state")" = "$post_sha" ] &&
        [ "$(sha256_file "$final_state")" = "$final_sha" ] || {
        printf 'anchor package changed after sealing: %s %s\n' "$arm" "$anchor" >&2
        exit 2
    }
done < <(tail -n +2 "$PLAN")

if [ "${LEO_STATE_LIMINAL_PLAN_ONLY:-0}" = 1 ]; then
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
    FIXTURE="$OUT/liminal-trajectory-fixture"
    "$CC" "$ROOT/tests/state_swarm_liminal_trajectory_fixture.c" \
        -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread
    printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turns\tpre_sha\tpost_sha\tfinal_sha\treproduced_sha\treply_equal\tstate_equal\n' > "$LOCKS"
    printf 'pair\tarm\tanchor\tanchor_turn\tfuture_turn\trelative\ttexture\tcandidate_similarity\tstable_similarity\tmargin\tstable_nearest_id\tcandidate_nearest\tsupport\tconfirmation\tcandidate_organs\tstable_organs\tprompt\treply\n' > "$OBSERVATIONS"
    while IFS=$'\t' read -r pair arm anchor life split base_seed turn session \
        order texture run_seed prompt reply pre_state post_state final_state \
        pre_sha post_sha final_sha; do
        trajectory="$OUT/trajectories/$pair-$arm-$anchor"
        mkdir -p "$trajectory"
        future="$trajectory/future.tsv"
        work_state="$trajectory/work.state"
        frozen="$trajectory/frozen.bin"
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
            printf 'anchor source geometry mismatch: %s %s\n' "$arm" "$anchor" >&2
            exit 2
        }
        "$FIXTURE" freeze "$frozen" "$turn" "$run_seed" "$prompt" "$reply" \
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
            printf -v future_order_padded '%02d' "$future_order"
            source_log="$A89/candidates/$life/writer-logs/s${future_session}-${future_order_padded}-${future_texture}.log"
            [ -s "$source_log" ] || {
                printf 'missing future source log: %s turn=%s\n' "$anchor" "$future_turn" >&2
                exit 2
            }
            future_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$source_log")"
            IFS=$'\t' read -r shape_turn shape_event shape_new \
                shape_similarity shape_members shape_displaced shape_nearest \
                shape_nearest_organs shape_removed_organs shape_organs \
                <<< "$future_shape"
            [ "$shape_turn" -eq "$future_turn" ] && [ "$shape_nearest" -gt 0 ] || {
                printf 'future source geometry mismatch: %s turn=%s\n' "$anchor" "$future_turn" >&2
                exit 2
            }
            if [ "$relative" -le 8 ]; then
                "$FIXTURE" project "$frozen" "$pair" "$arm" "$anchor" \
                    "$turn" "$future_turn" "$relative" "$future_texture" \
                    "$future_seed" "$future_prompt" "$future_reply" \
                    "$work_state" "$shape_nearest" "$shape_similarity" \
                    "$shape_nearest_organs" >> "$OBSERVATIONS"
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
                printf 'future full-log replay mismatch: %s turn=%s\n' "$anchor" "$future_turn" >&2
                exit 1
            }
        done < <(tail -n +2 "$future")
        cmp -s "$final_state" "$work_state"
        future_turns="$((96 - turn))"
        reproduced_sha="$(sha256_file "$work_state")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\n' \
            "$pair" "$arm" "$anchor" "$life" "$split" "$turn" \
            "$future_turns" "$pre_sha" "$post_sha" "$final_sha" \
            "$reproduced_sha" >> "$LOCKS"
        rm -f "$work_state" "$frozen"
    done < <(tail -n +2 "$PLAN")
    rm -f "$FIXTURE"
fi

awk -v expected="$EXPECTED" \
    -f "$ROOT/scripts/state_swarm_liminal_confirmation_report.awk" \
    "$LOCKS" "$OBSERVATIONS" > "$PAIR_SUMMARY"
awk -v expected="$EXPECTED" \
    -f "$ROOT/scripts/state_swarm_liminal_confirmation_verdict.awk" \
    "$PAIR_SUMMARY" > "$VERDICT"

cat "$LOCKS"
printf '\n'
cat "$PAIR_SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nsource-a89: %s\nsource-a90: %s\nsource-a91: %s\nrun: %s\n' \
    "$A89" "$A90" "$A91" "$OUT"
