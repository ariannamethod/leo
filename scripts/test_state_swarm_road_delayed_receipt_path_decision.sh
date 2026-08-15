#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-road-delayed-receipt-path-decision.XXXXXX")"
trap 'rc=$?; rm -rf "$TMP"; exit "$rc"' EXIT

write_lives() {
    local mode="$1" candidate cohort i split life raw snapshot texture symmetric path strength rank
    printf 'candidate\tstrength\trank\tcohort\tlife\tsplit\treceipts\traw_receipt_wins\tsnapshot_receipt_wins\ttexture_receipt_wins\tsymmetric_receipt_wins\tpath_receipt_wins\tmean_raw_ce_gain\tmean_raw_brier_gain\tmean_snapshot_ce_gain\tmean_snapshot_brier_gain\tmean_texture_ce_gain\tmean_texture_brier_gain\tmean_symmetric_ce_gain\tmean_symmetric_brier_gain\tmean_path_ce_gain\tmean_path_brier_gain\tmean_snapshot_raw_ce_gain\tmean_texture_snapshot_ce_gain\tmean_path_symmetric_ce_gain\thome_receipt_ce_gain\tstorm_receipt_ce_gain\twonder_receipt_ce_gain\tsocial_receipt_ce_gain\thome_receipts\tstorm_receipts\twonder_receipts\tsocial_receipts\n'
    for candidate in receipt-path-good receipt-path-carried receipt-path-bad; do
        case "$candidate" in
            receipt-path-good) strength=1; rank=1 ;;
            receipt-path-carried) strength=0.5; rank=2 ;;
            *) strength=0.25; rank=3 ;;
        esac
        for cohort in discovery validation; do
            for ((i = 1; i <= 32; i++)); do
                if [ "$i" -le 16 ]; then
                    split=primary; life="p$(printf '%02d' "$i")"
                else
                    split=holdout; life="h$(printf '%02d' "$((i - 16))")"
                fi
                raw=0; snapshot=0; texture=0; symmetric=0; path=0
                if { [ "$mode" = supported ] ||
                     { [ "$mode" = validation-fail ] && [ "$cohort" = discovery ]; }; } &&
                   [ "$candidate" = receipt-path-good ]; then
                    raw=0.010000000; snapshot=0.003000000
                    texture=0.002000000; symmetric=0.001500000; path=0.001200000
                elif [ "$candidate" = receipt-path-carried ]; then
                    raw=0.010000000; snapshot=0.003000000
                    texture=0.002000000; symmetric=0.001500000
                fi
                printf '%s\t%s\t%s\t%s\t%s\t%s\t4\t4\t4\t4\t4\t4\t%s\t0.002000000\t%s\t0.001000000\t%s\t0.000500000\t%s\t0.000400000\t%s\t0.000300000\t0.007000000\t0.001000000\t0.000300000\t%s\t%s\t%s\t%s\t1\t1\t1\t1\n' \
                    "$candidate" "$strength" "$rank" "$cohort" "$life" "$split" \
                    "$raw" "$snapshot" "$texture" \
                    "$symmetric" "$path" "$path" "$path" "$path" "$path"
            done
        done
    done
}

run_decision() {
    local mode="$1"
    write_lives "$mode" > "$TMP/$mode-life.tsv"
    awk -v policy_expected=3 -v discovery_expected=32 -v validation_expected=32 \
        -f "$ROOT/scripts/state_swarm_road_delayed_receipt_path_summary.awk" \
        "$TMP/$mode-life.tsv" > "$TMP/$mode-summary.tsv"
    awk -v policy_expected=3 -v expected=32 -v life_win_required=22 \
        -v split_win_required=10 \
        -f "$ROOT/scripts/state_swarm_road_delayed_receipt_path_select.awk" \
        "$TMP/$mode-summary.tsv" > "$TMP/$mode-selection.tsv"
    awk -v expected=32 -v life_win_required=22 -v split_win_required=10 \
        -f "$ROOT/scripts/state_swarm_road_delayed_receipt_path_verdict.awk" \
        "$TMP/$mode-selection.tsv" "$TMP/$mode-summary.tsv" \
        > "$TMP/$mode-verdict.txt"
}

run_decision supported
grep -q $'^receipt-path-good\t1\t1\t32\t128\t32\t32\t32\t32\t32' \
    "$TMP/supported-selection.tsv"
grep -q '^required_life_wins 22$' "$TMP/supported-verdict.txt"
grep -q '^required_split_wins 10$' "$TMP/supported-verdict.txt"
grep -q '^required_mean_path_ce_gain 0.001000000$' "$TMP/supported-verdict.txt"
grep -q '^result independent-delayed-receipt-supported$' "$TMP/supported-verdict.txt"

run_decision validation-fail
grep -q $'^receipt-path-good\t1\t1\t32\t128\t32\t32\t32\t32\t32' \
    "$TMP/validation-fail-selection.tsv"
grep -q '^result independent-delayed-receipt-not-confirmed$' \
    "$TMP/validation-fail-verdict.txt"

run_decision none
grep -q $'^none\t0\t0\t32' "$TMP/none-selection.tsv"
grep -q '^result no-independent-delayed-receipt-candidate$' "$TMP/none-verdict.txt"

printf 'state-swarm road delayed receipt path decision: ok\n'
