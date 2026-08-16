# A.110: confirm one frozen counterfactual susceptibility reader on unopened lives.

function fail() { fatal = 1; exit 2 }

BEGIN {
    FS = "\t"
    if (!expected) expected = 32
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

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 25 || $1 != "candidate" || $25 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 25) fail()
    selected = $1; selected_strength = $2; selected_rank = $3
    discovery_lives = $4; discovery_surfaces = $5
    for (i = 6; i <= 23; i++) discovery[i] = $i
    qualified = $24; selection_result = $25
    next
}

FNR == 1 {
    if (NF != 42 || $1 != "candidate" || $4 != "cohort" ||
        $42 != "holdout_mean_symmetric_gain") fail()
    next
}

$4 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 42 || $2 != selected_strength ||
        $3 != selected_rank || $5 != expected ||
        $25 != expected / 2 || $26 != expected / 2) fail()
    for (i = 5; i <= 42; i++) validation[i] = $i
}

END {
    if (fatal || selection_rows != 1) exit 2
    if (selection_result == "no-counterfactual-susceptibility-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-counterfactual-susceptibility-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (validation[7] >= life_win_required &&
            validation[8] >= life_win_required &&
            validation[9] >= life_win_required &&
            validation[10] >= life_win_required &&
            validation[27] >= split_win_required &&
            validation[28] >= split_win_required &&
            validation[29] >= split_win_required &&
            validation[30] >= split_win_required &&
            validation[31] >= split_win_required &&
            validation[32] >= split_win_required &&
            validation[33] >= split_win_required &&
            validation[34] >= split_win_required &&
            validation[11] >= raw_ce_required &&
            validation[12] >= raw_brier_required &&
            validation[13] >= snapshot_ce_required &&
            validation[14] >= snapshot_brier_required &&
            validation[15] >= texture_ce_required &&
            validation[16] >= texture_brier_required &&
            validation[17] >= symmetric_ce_required &&
            validation[18] >= symmetric_brier_required &&
            validation[21] > 0 && validation[22] > 0 &&
            validation[23] > 0 && validation[24] > 0 &&
            validation[35] > 0 && validation[36] > 0 &&
            validation[37] > 0 && validation[38] > 0 &&
            validation[39] > 0 && validation[40] > 0 &&
            validation[41] > 0 && validation[42] > 0)
            result = "counterfactual-susceptibility-supported"
        else
            result = "counterfactual-susceptibility-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_strength " selected_strength
    print "selected_rank " selected_rank
    print "qualified_discovery_candidates " qualified
    print "discovery_lives " discovery_lives
    print "discovery_surfaces " discovery_surfaces
    print "discovery_raw_life_wins " discovery[6]
    print "discovery_snapshot_life_wins " discovery[7]
    print "discovery_texture_life_wins " discovery[8]
    print "discovery_symmetric_life_wins " discovery[9]
    print "discovery_mean_raw_ce_gain " discovery[10]
    print "discovery_mean_snapshot_ce_gain " discovery[12]
    print "discovery_mean_texture_ce_gain " discovery[14]
    print "discovery_mean_symmetric_ce_gain " discovery[16]
    print "validation_lives " validation[5] + 0
    print "validation_surfaces " validation[6] + 0
    print "validation_raw_life_wins " validation[7] + 0
    print "validation_snapshot_life_wins " validation[8] + 0
    print "validation_texture_life_wins " validation[9] + 0
    print "validation_symmetric_life_wins " validation[10] + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", validation[11] + 0)
    print "validation_mean_snapshot_ce_gain " sprintf("%.9f", validation[13] + 0)
    print "validation_mean_texture_ce_gain " sprintf("%.9f", validation[15] + 0)
    print "validation_mean_symmetric_ce_gain " sprintf("%.9f", validation[17] + 0)
    print "required_life_wins " life_win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", raw_ce_required)
    print "required_mean_snapshot_ce_gain " sprintf("%.9f", snapshot_ce_required)
    print "required_mean_texture_ce_gain " sprintf("%.9f", texture_ce_required)
    print "required_mean_symmetric_ce_gain " sprintf("%.9f", symmetric_ce_required)
    print "result " result
}
