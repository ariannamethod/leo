#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-counterfactual-susceptibility-decision.XXXXXX")"
trap 'rc=$?; rm -rf "$TMP"; exit "$rc"' EXIT

write_scores() {
    local cohort="$1" policies="$2" out="$3"
    awk -v cohort="$cohort" -v policies="$policies" 'BEGIN {
        OFS = "\t"
        print "candidate", "path_strength", "rank", "cohort", "life", "split",
            "session", "history_surfaces", "raw_ce", "path_ce", "symmetric_ce",
            "texture_ce", "snapshot_ce", "raw_brier", "path_brier",
            "symmetric_brier", "texture_brier", "snapshot_brier",
            "raw_ce_gain", "raw_brier_gain", "snapshot_ce_gain",
            "snapshot_brier_gain", "texture_ce_gain", "texture_brier_gain",
            "symmetric_ce_gain", "symmetric_brier_gain",
            "snapshot_raw_ce_gain", "texture_snapshot_ce_gain",
            "home_path_ce_gain", "storm_path_ce_gain",
            "wonder_path_ce_gain", "social_path_ce_gain"
        for (p = 1; p <= policies; p++) {
            candidate = p == 1 ? "susceptibility-path-light" : "susceptibility-path-gentle"
            strength = p == 1 ? 0.10 : 0.25
            rank = p
            for (n = 1; n <= 32; n++) {
                split_name = n <= 16 ? "primary" : "holdout"
                life = (n <= 16 ? "p" : "h") sprintf("%02d", n <= 16 ? n : n - 16)
                for (session = 5; session <= 6; session++) {
                    final = p == 1 ? 0.002 : -0.002
                    final_brier = p == 1 ? 0.0005 : -0.0005
                    print candidate, strength, rank, cohort, life, split_name,
                        session, session - 1, 2.0, 1.0, 1.0 + final,
                        1.005, 1.01, 0.3, 0.1, 0.1 + final_brier,
                        0.101, 0.102, 0.02, 0.004, 0.01, 0.002,
                        0.005, 0.001, final, final_brier, 0.01, 0.005,
                        final, final, final, final
                }
            }
        }
    }' > "$out"
}

write_scores discovery 2 "$TMP/discovery-scores.tsv"
awk -v policy_expected=2 -v life_expected=32 -v min_surfaces=2 \
    -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_life.awk" \
    "$TMP/discovery-scores.tsv" > "$TMP/discovery-life.tsv"
awk -v policy_expected=2 -v discovery_expected=32 -v validation_expected=32 \
    -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_summary.awk" \
    "$TMP/discovery-life.tsv" > "$TMP/discovery-summary.tsv"
awk -v policy_expected=2 -v expected=32 -v life_win_required=22 \
    -v split_win_required=10 \
    -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_select.awk" \
    "$TMP/discovery-summary.tsv" > "$TMP/selection.tsv"

awk -F '\t' '
    NR == 2 {
        if ($1 != "susceptibility-path-light" || $24 != 1 ||
            $25 != "candidate-nominated") exit 1
        found = 1
    }
    END { if (!found) exit 1 }
' "$TMP/selection.tsv"

write_scores validation 1 "$TMP/validation-scores.tsv"
awk -v policy_expected=1 -v life_expected=32 -v min_surfaces=2 \
    -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_life.awk" \
    "$TMP/validation-scores.tsv" > "$TMP/validation-life.tsv"
{ sed -n '1p' "$TMP/discovery-life.tsv"; tail -n +2 "$TMP/discovery-life.tsv"; tail -n +2 "$TMP/validation-life.tsv"; } \
    > "$TMP/all-life.tsv"
awk -v policy_expected=2 -v discovery_expected=32 -v validation_expected=32 \
    -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_summary.awk" \
    "$TMP/all-life.tsv" > "$TMP/all-summary.tsv"
awk -v expected=32 -v life_win_required=22 -v split_win_required=10 \
    -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_verdict.awk" \
    "$TMP/selection.tsv" "$TMP/all-summary.tsv" > "$TMP/verdict.txt"
grep -q '^result counterfactual-susceptibility-supported$' "$TMP/verdict.txt"

awk -F '\t' -v OFS='\t' '
    NR == 1 { print; next }
    {
        $7 = $8 = $9 = $10 = 0
        $11 = $12 = $13 = $14 = $15 = $16 = $17 = $18 = -0.1
        $21 = $22 = $23 = $24 = -0.1
        $27 = $28 = $29 = $30 = $31 = $32 = $33 = $34 = 0
        $35 = $36 = $37 = $38 = $39 = $40 = $41 = $42 = -0.1
        print
    }
' "$TMP/discovery-summary.tsv" > "$TMP/negative-summary.tsv"
awk -v policy_expected=2 -v expected=32 -v life_win_required=22 \
    -v split_win_required=10 \
    -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_select.awk" \
    "$TMP/negative-summary.tsv" > "$TMP/negative-selection.tsv"
grep -q $'^none\t.*\tno-counterfactual-susceptibility-candidate$' \
    "$TMP/negative-selection.tsv"
awk -v expected=32 \
    -f "$ROOT/scripts/state_swarm_road_counterfactual_susceptibility_verdict.awk" \
    "$TMP/negative-selection.tsv" "$TMP/negative-summary.tsv" > "$TMP/negative-verdict.txt"
grep -q '^result no-counterfactual-susceptibility-candidate$' "$TMP/negative-verdict.txt"

printf 'state-swarm road counterfactual susceptibility decision: ok\n'
