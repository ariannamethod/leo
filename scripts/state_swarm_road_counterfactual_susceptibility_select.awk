# A.110: nominate a signed-path response-surface reader only beyond every frozen control.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 32
    if (!policy_expected) policy_expected = 2
    if (!life_win_required) life_win_required = 22
    if (!split_win_required) split_win_required = 10
    if (!raw_ce_required) raw_ce_required = 0.005
    if (!raw_brier_required) raw_brier_required = 0.001
    if (!snapshot_ce_required) snapshot_ce_required = 0.002
    if (!snapshot_brier_required) snapshot_brier_required = 0.0005
    if (!texture_ce_required) texture_ce_required = 0.001
    if (!texture_brier_required) texture_brier_required = 0.00025
    if (!symmetric_ce_required) symmetric_ce_required = 0.001
    if (!symmetric_brier_required) symmetric_brier_required = 0.00025
}

NR == 1 {
    if (NF != 42 || $1 != "candidate" || $4 != "cohort" ||
        $42 != "holdout_mean_symmetric_gain") fail()
    next
}

$4 == "discovery" {
    if (NF != 42 || seen[$1]++ || $5 != expected ||
        $25 != expected / 2 || $26 != expected / 2) fail()
    if (!number($2) || !number($3))
        fail()
    for (i = 5; i <= 42; i++) if (!number($i)) fail()
    rows++
    if ($7 >= life_win_required && $8 >= life_win_required &&
        $9 >= life_win_required && $10 >= life_win_required &&
        $27 >= split_win_required && $28 >= split_win_required &&
        $29 >= split_win_required && $30 >= split_win_required &&
        $31 >= split_win_required && $32 >= split_win_required &&
        $33 >= split_win_required && $34 >= split_win_required &&
        $11 >= raw_ce_required && $12 >= raw_brier_required &&
        $13 >= snapshot_ce_required && $14 >= snapshot_brier_required &&
        $15 >= texture_ce_required && $16 >= texture_brier_required &&
        $17 >= symmetric_ce_required && $18 >= symmetric_brier_required &&
        $21 > 0 && $22 > 0 && $23 > 0 && $24 > 0 &&
        $35 > 0 && $36 > 0 && $37 > 0 && $38 > 0 &&
        $39 > 0 && $40 > 0 && $41 > 0 && $42 > 0) {
        qualified++
        if (!selected || $17 > best_gain + 0.0000000005 ||
            ($17 >= best_gain - 0.0000000005 && $3 < best_rank)) {
            selected = $1; best_strength = $2; best_rank = $3
            for (i = 4; i <= 24; i++) best[i] = $i
            best_gain = $17
        }
    }
}

END {
    if (fatal || rows != policy_expected) exit 2
    print "candidate", "strength", "rank", "discovery_lives", "discovery_surfaces",
        "raw_life_wins", "snapshot_life_wins", "texture_life_wins",
        "symmetric_life_wins", "mean_raw_ce_gain", "mean_raw_brier_gain",
        "mean_snapshot_ce_gain", "mean_snapshot_brier_gain",
        "mean_texture_ce_gain", "mean_texture_brier_gain",
        "mean_symmetric_ce_gain", "mean_symmetric_brier_gain",
        "mean_snapshot_raw_ce_gain", "mean_texture_snapshot_ce_gain",
        "home_path_ce_gain", "storm_path_ce_gain",
        "wonder_path_ce_gain", "social_path_ce_gain",
        "qualified_candidates", "result"
    if (selected)
        print selected, best_strength, best_rank, best[5], best[6],
            best[7], best[8], best[9], best[10], best[11], best[12],
            best[13], best[14], best[15], best[16], best[17], best[18],
            best[19], best[20], best[21], best[22], best[23], best[24],
            qualified, "candidate-nominated"
    else
        print "none", 0, 0, expected, 0, 0, 0, 0, 0,
            "0.000000000", "0.000000000", "0.000000000", "0.000000000",
            "0.000000000", "0.000000000", "0.000000000", "0.000000000",
            "0.000000000", "0.000000000", "0.000000000", "0.000000000",
            "0.000000000", "0.000000000", 0,
            "no-counterfactual-susceptibility-candidate"
}
