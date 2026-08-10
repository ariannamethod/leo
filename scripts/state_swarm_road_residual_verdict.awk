# A.99: test a discovery-selected residual learner on the frozen validation lives.

function fail() { fatal = 1; exit 2 }

BEGIN {
    FS = "\t"
    if (!expected) expected = 12
    if (!raw_win_required) raw_win_required = 8
    if (!control_win_required) control_win_required = 8
    if (!split_win_required) split_win_required = 4
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!control_required) control_required = 0.003
    if (!destination_required) destination_required = 0.015
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 17 || $1 != "candidate" || $17 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 17) fail()
    selected = $1; selected_decay = $2; selected_strength = $3
    selected_rank = $4; discovery_lives = $5
    discovery_raw_wins = $6; discovery_control_wins = $7
    discovery_raw = $8; discovery_brier = $9; discovery_control = $10
    discovery_destination = $11; qualified = $16; selection_result = $17
    next
}

FNR == 1 {
    if (NF != 29 || $1 != "candidate" || $5 != "cohort" ||
        $29 != "holdout_mean_control_gain") fail()
    next
}

$5 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 29 || $2 != selected_decay ||
        $3 != selected_strength || $4 != selected_rank || $6 != expected ||
        $20 != 6 || $21 != 6) fail()
    validation_lives = $6; validation_turns = $7
    validation_raw_wins = $8; validation_control_wins = $9
    validation_raw = $10; validation_brier = $11
    validation_control = $12; validation_destination = $14
    home_gain = $16; storm_gain = $17; wonder_gain = $18; social_gain = $19
    primary_raw_wins = $22; holdout_raw_wins = $23
    primary_control_wins = $24; holdout_control_wins = $25
    primary_raw = $26; holdout_raw = $27
    primary_control = $28; holdout_control = $29
}

END {
    if (fatal) exit 2
    if (selection_rows != 1) fail()
    if (selection_result == "no-residual-transition-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-residual-transition-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (validation_raw_wins >= raw_win_required &&
            validation_control_wins >= control_win_required &&
            primary_raw_wins >= split_win_required &&
            holdout_raw_wins >= split_win_required &&
            primary_control_wins >= split_win_required &&
            holdout_control_wins >= split_win_required &&
            validation_raw >= ce_required && validation_brier >= brier_required &&
            validation_control >= control_required &&
            validation_destination >= destination_required &&
            primary_raw > 0 && holdout_raw > 0 &&
            primary_control > 0 && holdout_control > 0 &&
            home_gain > 0 && storm_gain > 0 && wonder_gain > 0 && social_gain > 0)
            result = "residual-transition-learning-supported"
        else
            result = "residual-transition-learning-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_decay " selected_decay
    print "selected_strength " selected_strength
    print "qualified_discovery_candidates " qualified
    print "discovery_lives " discovery_lives
    print "discovery_raw_life_wins " discovery_raw_wins
    print "discovery_control_life_wins " discovery_control_wins
    print "discovery_mean_raw_ce_gain " discovery_raw
    print "discovery_mean_raw_brier_gain " discovery_brier
    print "discovery_mean_control_ce_gain " discovery_control
    print "discovery_mean_destination_ce_gain " discovery_destination
    print "validation_lives " validation_lives + 0
    print "validation_turns " validation_turns + 0
    print "validation_raw_life_wins " validation_raw_wins + 0
    print "validation_control_life_wins " validation_control_wins + 0
    print "validation_primary_raw_wins " primary_raw_wins + 0
    print "validation_holdout_raw_wins " holdout_raw_wins + 0
    print "validation_primary_control_wins " primary_control_wins + 0
    print "validation_holdout_control_wins " holdout_control_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", validation_raw + 0)
    print "validation_mean_raw_brier_gain " sprintf("%.9f", validation_brier + 0)
    print "validation_mean_control_ce_gain " sprintf("%.9f", validation_control + 0)
    print "validation_mean_destination_ce_gain " sprintf("%.9f", validation_destination + 0)
    print "validation_primary_mean_raw_gain " sprintf("%.9f", primary_raw + 0)
    print "validation_holdout_mean_raw_gain " sprintf("%.9f", holdout_raw + 0)
    print "validation_primary_mean_control_gain " sprintf("%.9f", primary_control + 0)
    print "validation_holdout_mean_control_gain " sprintf("%.9f", holdout_control + 0)
    print "validation_home_mean_gain " sprintf("%.9f", home_gain + 0)
    print "validation_storm_mean_gain " sprintf("%.9f", storm_gain + 0)
    print "validation_wonder_mean_gain " sprintf("%.9f", wonder_gain + 0)
    print "validation_social_mean_gain " sprintf("%.9f", social_gain + 0)
    print "required_raw_life_wins " raw_win_required
    print "required_control_life_wins " control_win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", ce_required)
    print "required_mean_raw_brier_gain " sprintf("%.9f", brier_required)
    print "required_mean_control_ce_gain " sprintf("%.9f", control_required)
    print "required_mean_destination_ce_gain " sprintf("%.9f", destination_required)
    print "result " result
}
