#!/usr/bin/env bash
# A.96: test source-readout dilution without changing Leo's road or voice.
set -Eeuo pipefail

trap 'rc=$?; printf "road readout runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
A89="${LEO_STATE_READOUT_A89_SOURCE:-/private/tmp/leo-state-swarm-balanced-event-reservoir-a89-r1-20260807}"
A91="${LEO_STATE_READOUT_A91_SOURCE:-/private/tmp/leo-state-swarm-near-gate-controls-a91-r2-20260807}"
A95="${LEO_STATE_READOUT_A95_SOURCE:-/private/tmp/leo-state-swarm-road-information-a95-r1-20260810}"
DISCOVERY_EXPECTED="${LEO_STATE_READOUT_DISCOVERY_EXPECTED:-12}"
VALIDATION_EXPECTED="${LEO_STATE_READOUT_VALIDATION_EXPECTED:-15}"
AGGREGATE_ONLY="${LEO_STATE_READOUT_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-readout-$STAMP}"

A95_SCORES="$A95/scores.tsv"
A91_CONTROLS="$A91/controls.tsv"
A91_LOCKS="$A91/control-replay-locks.tsv"
WRITER_RECEIPTS="$A89/writer-receipts.tsv"
EXPECTED_A95_SCORES_SHA="${LEO_STATE_READOUT_A95_SCORES_SHA:-1406b654ef7fdf21b8d2511c55f90d24a4181abda6572a788a04a54249be3ae0}"
EXPECTED_A91_CONTROLS_SHA="${LEO_STATE_READOUT_A91_CONTROLS_SHA:-50e4b6f513a6ddfe375b69c0246005fd4f9990542d2d15790cc64fb9e871bab5}"
EXPECTED_A91_LOCKS_SHA="${LEO_STATE_READOUT_A91_LOCKS_SHA:-1d28607ea891338403f8ed2c94c3f935752afe7680dedf42b70a8106cfb07321}"
EXPECTED_WRITER_SHA="${LEO_STATE_READOUT_WRITER_SHA:-10bf4251848f4edaec4a34d66d3d811afff187df9f10aeb71ff761a342c0e833}"

case "$DISCOVERY_EXPECTED:$VALIDATION_EXPECTED" in
    *[!0-9:]*|0:*|*:0) printf 'invalid road readout dimensions\n' >&2; exit 2 ;;
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

seal "$A95_SCORES" "$EXPECTED_A95_SCORES_SHA" "A.95 scores"
seal "$A91_CONTROLS" "$EXPECTED_A91_CONTROLS_SHA" "A.91 controls"
seal "$A91_LOCKS" "$EXPECTED_A91_LOCKS_SHA" "A.91 control locks"
seal "$WRITER_RECEIPTS" "$EXPECTED_WRITER_SHA" "A.89 writer receipts"

CANDIDATES="$OUT/candidates.tsv"
DISCOVERY="$OUT/discovery-witnesses.tsv"
PLAN="$OUT/validation-plan.tsv"
LOCKS="$OUT/validation-locks.tsv"
VALIDATION="$OUT/validation-witnesses.tsv"
SCORES="$OUT/readout-scores.tsv"
SUMMARY="$OUT/candidate-summary.tsv"
SELECTION="$OUT/selection.tsv"
VERDICT="$OUT/verdict.txt"

write_candidates() {
    printf 'candidate\tkind\tparameter\trank\n'
    printf 'power-1p25\tpower\t1.25\t1\n'
    printf 'power-1p50\tpower\t1.50\t2\n'
    printf 'power-2p00\tpower\t2.00\t3\n'
    printf 'power-3p00\tpower\t3.00\t4\n'
    printf 'top-4\ttopk\t4\t5\n'
    printf 'top-3\ttopk\t3\t6\n'
    printf 'top-2\ttopk\t2\t7\n'
    printf 'top-1\ttopk\t1\t8\n'
}

write_plan() {
    awk -F '\t' -v OFS='\t' -v a91="$A91" \
        -v expected="$VALIDATION_EXPECTED" '
        FILENAME == ARGV[1] {
            if (FNR == 1) {
                if (NF != 21 || $1 != "control" || $3 != "family" ||
                    $12 != "precontrol_sha" || $21 != "reply_equal") exit 2
                next
            }
            if ($3 != "organism" || $7 >= 96) next
            key = $1
            if (seen_lock[key]++ || $5 !~ /^(primary|holdout)$/) exit 2
            for (i = 17; i <= 21; i++) if ($i != "true") exit 2
            pair[key] = $2; life[key] = $4; split_name[key] = $5
            base[key] = $6; turn[key] = $7; session[key] = $8
            order[key] = $9; texture[key] = $10; seed[key] = $11
            pre_sha[key] = $12; post_sha[key] = $13
            log_sha[key] = $14
            locks++
            next
        }
        FNR == 1 {
            if (NF != 16 || $1 != "control" || $3 != "family" ||
                $13 != "prompt" || $16 != "source_log_sha") exit 2
            print "control", "pair", "life", "split", "base_seed", \
                "turn", "session", "order", "texture", "run_seed", \
                "prompt", "reply", "pre_state", "post_state", \
                "pre_sha", "post_sha", "source_log", "source_log_sha"
            next
        }
        $1 in pair {
            key = $1
            if ($2 != pair[key] || $3 != "organism" || $4 != life[key] ||
                $5 != split_name[key] || $6 != base[key] || $7 != turn[key] ||
                $8 != session[key] || $9 != order[key] ||
                $10 != texture[key] || $11 != seed[key] ||
                $16 != log_sha[key] || emitted[key]++) exit 2
            print key, pair[key], life[key], split_name[key], base[key], turn[key], \
                session[key], order[key], texture[key], seed[key], $13, $14, \
                a91 "/controls/" key "/precontrol.state", \
                a91 "/controls/" key "/updated.state", pre_sha[key], \
                post_sha[key], $15, log_sha[key]
            rows++
        }
        END { if (locks != expected || rows != expected) exit 2 }
    ' "$A91_LOCKS" "$A91_CONTROLS"
}

write_locks() {
    awk -F '\t' -v expected="$VALIDATION_EXPECTED" '
        NR == 1 { print; next }
        $3 == "organism" && $7 < 96 {
            for (i = 17; i <= 21; i++) if ($i != "true") exit 2
            print
            rows++
        }
        END { if (rows != expected) exit 2 }
    ' "$A91_LOCKS"
}

write_discovery() {
    awk -F '\t' -v expected="$DISCOVERY_EXPECTED" '
        NR == 1 { print; next }
        $5 == "primary" {
            if ($2 !~ /^(event|ecology)$/) exit 2
            print
            rows++
        }
        END { if (rows != expected) exit 2 }
    ' "$A95_SCORES"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$CANDIDATES" "$DISCOVERY" "$PLAN" "$LOCKS" "$VALIDATION"; do
        [ -s "$path" ] || {
            printf 'incomplete road readout run: %s\n' "$OUT" >&2
            exit 2
        }
    done
    write_candidates | cmp -s - "$CANDIDATES" || {
        printf 'A.96 candidate ledger diverged\n' >&2
        exit 2
    }
    write_discovery | cmp -s - "$DISCOVERY" || {
        printf 'A.96 discovery population diverged\n' >&2
        exit 2
    }
    write_plan | cmp -s - "$PLAN" || {
        printf 'A.96 validation plan diverged\n' >&2
        exit 2
    }
    write_locks | cmp -s - "$LOCKS" || {
        printf 'A.96 validation locks diverged\n' >&2
        exit 2
    }
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT"
    write_candidates > "$CANDIDATES"
    write_discovery > "$DISCOVERY"
    write_plan > "$PLAN"
    write_locks > "$LOCKS"
fi

if [ "${LEO_STATE_READOUT_PLAN_ONLY:-0}" = 1 ]; then
    cat "$CANDIDATES"
    printf '\n'
    cat "$PLAN"
    exit 0
fi

if [ "$AGGREGATE_ONLY" != 1 ]; then
    FIXTURE="$OUT/road-readout-fixture"
    "$CC" "$ROOT/tests/state_swarm_road_information_fixture.c" \
        -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread
    printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turn\ttexture\ttransition\tanchor_activation\ttarget_activation\tconditional_prediction\tdestination_prior\ttransition_total\tdestination_entropy\tmutual_information\tnormalized_mi\tmean_row_tv\tconditional_ce\tdestination_ce\tuniform_ce\tpersistence_ce\tconditional_brier\tdestination_brier\tuniform_brier\tpersistence_brier\tprompt\treply\n' > "$VALIDATION"
    while IFS=$'\t' read -r control pair life split base_seed turn session \
        order texture run_seed prompt reply pre_state post_state pre_sha \
        post_sha source_log source_log_sha; do
        [ "$(sha256_file "$pre_state")" = "$pre_sha" ] && \
            [ "$(sha256_file "$post_state")" = "$post_sha" ] && \
            [ "$(sha256_file "$source_log")" = "$source_log_sha" ] || {
            printf 'A.96 validation source drift: %s\n' "$control" >&2
            exit 2
        }
        anchor_shape="$(awk -f "$ROOT/scripts/state_swarm_displacement_anatomy_log.awk" "$source_log")"
        IFS=$'\t' read -r observed_turn observed_event observed_new \
            observed_similarity observed_members observed_displaced \
            observed_nearest observed_nearest_organs observed_removed_organs \
            observed_organs <<< "$anchor_shape"
        [ "$observed_turn" -eq "$turn" ] && [ "$observed_nearest" -gt 0 ] || {
            printf 'A.96 anchor geometry mismatch: %s\n' "$control" >&2
            exit 2
        }

        next_receipt="$OUT/$control-next.tsv"
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
            printf 'A.96 future geometry mismatch: %s turn=%s\n' \
                "$control" "$next_turn" >&2
            exit 2
        }
        "$FIXTURE" "$pair" organism "$control" "$life" "$split" "$turn" \
            "$next_turn" "$next_texture" "$run_seed" "$prompt" "$reply" \
            "$pre_state" "$observed_nearest" "$observed_similarity" \
            "$observed_nearest_organs" "$next_seed" "$next_prompt" \
            "$next_reply" "$post_state" "$shape_nearest" "$shape_similarity" \
            "$shape_nearest_organs" >> "$VALIDATION"
        rm -f "$next_receipt"
    done < <(tail -n +2 "$PLAN")
    rm -f "$FIXTURE"
fi

awk -v discovery_expected="$DISCOVERY_EXPECTED" \
    -v validation_expected="$VALIDATION_EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_readout_report.awk" \
    "$CANDIDATES" "$DISCOVERY" "$VALIDATION" > "$SCORES"
awk -v discovery_expected="$DISCOVERY_EXPECTED" \
    -v validation_expected="$VALIDATION_EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_readout_summary.awk" \
    "$SCORES" > "$SUMMARY"
awk -v expected="$DISCOVERY_EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_readout_select.awk" \
    "$SUMMARY" > "$SELECTION"
awk -v expected="$VALIDATION_EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_readout_verdict.awk" \
    "$SELECTION" "$SUMMARY" > "$VERDICT"

cat "$SUMMARY"
printf '\n'
cat "$SELECTION"
printf '\n'
cat "$VERDICT"
printf '\nsource-a91: %s\nsource-a95: %s\nrun: %s\n' "$A91" "$A95" "$OUT"
