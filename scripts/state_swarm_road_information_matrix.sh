#!/usr/bin/env bash
# A.95: measure conditional information in the mature state road.
set -Eeuo pipefail

trap 'rc=$?; printf "road information runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
A89="${LEO_STATE_INFORMATION_A89_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
A94="${LEO_STATE_INFORMATION_A94_SOURCE:-/private/tmp/leo-state-swarm-transition-consequence-a94-r1-20260809}"
EXPECTED="${LEO_STATE_INFORMATION_EXPECTED_ARMS:-30}"
EXPECTED_PLAN_SHA="${LEO_STATE_INFORMATION_PLAN_SHA:-9b0434bfa9bcc4c5cb6051cf7a6133f3fe0f51add036b5273721ece327e5ca2a}"
EXPECTED_LOCK_SHA="${LEO_STATE_INFORMATION_LOCK_SHA:-fdc4366493455177041b04e04fe7e2653c5e44ee79625002d059dfeb362b2d28}"
EXPECTED_WRITER_SHA="${LEO_STATE_INFORMATION_WRITER_SHA:-10bf4251848f4edaec4a34d66d3d811afff187df9f10aeb71ff761a342c0e833}"
AGGREGATE_ONLY="${LEO_STATE_INFORMATION_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-information-$STAMP}"

case "$EXPECTED" in
    ''|*[!0-9]*|0) printf 'invalid road information arm count: %s\n' "$EXPECTED" >&2; exit 2 ;;
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

A94_PLAN="$A94/plan.tsv"
A94_LOCKS="$A94/replay-locks.tsv"
WRITER_RECEIPTS="$A89/writer-receipts.tsv"
seal "$A94_PLAN" "$EXPECTED_PLAN_SHA" "A.94 plan"
seal "$A94_LOCKS" "$EXPECTED_LOCK_SHA" "A.94 replay locks"
seal "$WRITER_RECEIPTS" "$EXPECTED_WRITER_SHA" "A.89 writer receipts"

PLAN="$OUT/plan.tsv"
LOCKS="$OUT/replay-locks.tsv"
SCORES="$OUT/scores.tsv"
SUMMARY="$OUT/summary.tsv"
VERDICT="$OUT/verdict.txt"

if [ "$AGGREGATE_ONLY" = 1 ]; then
    [ -s "$PLAN" ] && [ -s "$LOCKS" ] && [ -s "$SCORES" ] || {
        printf 'incomplete road information run: %s\n' "$OUT" >&2
        exit 2
    }
    cmp -s "$PLAN" "$A94_PLAN" && cmp -s "$LOCKS" "$A94_LOCKS" || {
        printf 'road information provenance diverged from A.94\n' >&2
        exit 2
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT"
    cp "$A94_PLAN" "$PLAN"
    cp "$A94_LOCKS" "$LOCKS"
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
            $7 !~ /^[0-9]+$/ || $7 >= 96 ||
            $10 !~ /^(home|storm|wonder|social)$/ || $12 == "" || $13 == "")
            exit 1
        rows++
    }
    END { if (rows != expected) exit 1 }
' "$PLAN" || {
    printf 'invalid A.95 plan: %s\n' "$PLAN" >&2
    exit 2
}

if [ "${LEO_STATE_INFORMATION_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

if [ "$AGGREGATE_ONLY" != 1 ]; then
    FIXTURE="$OUT/road-information-fixture"
    "$CC" "$ROOT/tests/state_swarm_road_information_fixture.c" \
        -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread
    printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turn\ttexture\ttransition\tanchor_activation\ttarget_activation\tconditional_prediction\tdestination_prior\ttransition_total\tdestination_entropy\tmutual_information\tnormalized_mi\tmean_row_tv\tconditional_ce\tdestination_ce\tuniform_ce\tpersistence_ce\tconditional_brier\tdestination_brier\tuniform_brier\tpersistence_brier\tprompt\treply\n' > "$SCORES"
    while IFS=$'\t' read -r pair arm anchor life split base_seed turn session \
        order texture run_seed prompt reply pre_state post_state final_state \
        pre_sha post_sha final_sha; do
        if [ "$arm" = event ]; then
            anchor_log="$A89/candidates/$life/events/$anchor/trigger.log"
        else
            printf -v padded_anchor '%02d' "$order"
            anchor_log="$A89/candidates/$life/writer-logs/s${session}-${padded_anchor}-${texture}.log"
        fi
        [ -s "$anchor_log" ] || {
            printf 'missing A.95 anchor log: %s %s\n' "$arm" "$anchor" >&2
            exit 2
        }
        anchor_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$anchor_log")"
        IFS=$'\t' read -r observed_turn observed_event observed_new \
            observed_similarity observed_members observed_displaced \
            observed_nearest observed_nearest_organs observed_removed_organs \
            observed_organs <<< "$anchor_shape"
        [ "$observed_turn" -eq "$turn" ] && [ "$observed_nearest" -gt 0 ] || {
            printf 'A.95 anchor geometry mismatch: %s %s\n' "$arm" "$anchor" >&2
            exit 2
        }

        next_receipt="$OUT/$pair-$arm-next.tsv"
        awk -F '\t' -v life="$life" -v turn="$((turn + 1))" '
            BEGIN { OFS = "\t" }
            NR == 1 {
                if (NF != 34 || $1 != "life" || $5 != "session" ||
                    $8 != "run_seed" || $9 != "turn" ||
                    $33 != "prompt" || $34 != "reply") exit 2
                next
            }
            $1 == life && $9 == turn {
                print $5, $6, $7, $8, $9, $33, $34
                rows++
            }
            END { if (rows != 1) exit 2 }
        ' "$WRITER_RECEIPTS" > "$next_receipt"
        IFS=$'\t' read -r next_session next_order next_texture next_seed \
            next_turn next_prompt next_reply < "$next_receipt"
        printf -v padded '%02d' "$next_order"
        next_log="$A89/candidates/$life/writer-logs/s${next_session}-${padded}-${next_texture}.log"
        next_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$next_log")"
        IFS=$'\t' read -r shape_turn shape_event shape_new shape_similarity \
            shape_members shape_displaced shape_nearest shape_nearest_organs \
            shape_removed_organs shape_organs <<< "$next_shape"
        [ "$shape_turn" -eq "$next_turn" ] && [ "$shape_nearest" -gt 0 ] || {
            printf 'A.95 future geometry mismatch: %s turn=%s\n' \
                "$anchor" "$next_turn" >&2
            exit 2
        }
        "$FIXTURE" "$pair" "$arm" "$anchor" "$life" "$split" "$turn" \
            "$next_turn" "$next_texture" "$run_seed" "$prompt" "$reply" \
            "$pre_state" "$observed_nearest" "$observed_similarity" \
            "$observed_nearest_organs" "$next_seed" "$next_prompt" \
            "$next_reply" "$post_state" "$shape_nearest" "$shape_similarity" \
            "$shape_nearest_organs" >> "$SCORES"
        rm -f "$next_receipt"
    done < <(tail -n +2 "$PLAN")
    rm -f "$FIXTURE"
fi

awk -v expected="$EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_information_report.awk" \
    "$LOCKS" "$SCORES" > "$SUMMARY"
awk -v expected="$EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_information_verdict.awk" \
    "$SUMMARY" > "$VERDICT"

cat "$SUMMARY"
printf '\n'
cat "$VERDICT"
printf '\nsource-a89: %s\nsource-a94: %s\nrun: %s\n' "$A89" "$A94" "$OUT"
