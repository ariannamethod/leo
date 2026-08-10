# A.101: confirm only a frozen correction on ten untouched lives.

function fail() { fatal = 1; exit 2 }

BEGIN {
    FS = "\t"
    if (!expected) expected = 10
    if (!raw_win_required) raw_win_required = 7
    if (!bias_win_required) bias_win_required = 7
    if (!split_win_required) split_win_required = 3
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!bias_ce_required) bias_ce_required = 0.002
    if (!bias_brier_required) bias_brier_required = 0.0005
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 18 || $1 != "candidate" || $18 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 18) fail()
    selected = $1; selected_decay = $2; selected_strength = $3
    selected_rank = $4; discovery_lives = $5
    discovery_raw_wins = $6; discovery_bias_wins = $7
    discovery_gain = $8; discovery_brier = $9
    discovery_bias_gain = $10; discovery_bias_brier = $11
    qualified = $17; selection_result = $18
    next
}

FNR == 1 {
    if (NF != 28 || $1 != "candidate" || $5 != "cohort" ||
        $28 != "holdout_mean_bias_gain") fail()
    next
}

$5 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 28 || $2 != selected_decay ||
        $3 != selected_strength || $4 != selected_rank || $6 != expected ||
        $19 != 5 || $20 != 5) fail()
    validation_lives = $6; validation_turns = $7
    validation_raw_wins = $8; validation_bias_wins = $9
    validation_gain = $10; validation_brier = $11
    validation_bias_gain = $12; validation_bias_brier = $13
    home_gain = $15; storm_gain = $16; wonder_gain = $17; social_gain = $18
    primary_raw_wins = $21; holdout_raw_wins = $22
    primary_bias_wins = $23; holdout_bias_wins = $24
    primary_raw = $25; holdout_raw = $26
    primary_bias = $27; holdout_bias = $28
}

END {
    if (fatal) exit 2
    if (selection_rows != 1) fail()
    if (selection_result == "no-error-memory-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-error-memory-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (validation_raw_wins >= raw_win_required &&
            validation_bias_wins >= bias_win_required &&
            primary_raw_wins >= split_win_required &&
            holdout_raw_wins >= split_win_required &&
            primary_bias_wins >= split_win_required &&
            holdout_bias_wins >= split_win_required &&
            validation_gain >= ce_required && validation_brier >= brier_required &&
            validation_bias_gain >= bias_ce_required &&
            validation_bias_brier >= bias_brier_required &&
            primary_raw > 0 && holdout_raw > 0 &&
            primary_bias > 0 && holdout_bias > 0 &&
            home_gain > 0 && storm_gain > 0 && wonder_gain > 0 && social_gain > 0)
            result = "conditional-error-memory-supported"
        else
            result = "conditional-error-memory-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_decay " selected_decay
    print "selected_strength " selected_strength
    print "qualified_discovery_candidates " qualified
    print "discovery_lives " discovery_lives
    print "discovery_raw_life_wins " discovery_raw_wins
    print "discovery_bias_life_wins " discovery_bias_wins
    print "discovery_mean_raw_ce_gain " discovery_gain
    print "discovery_mean_raw_brier_gain " discovery_brier
    print "discovery_mean_bias_ce_gain " discovery_bias_gain
    print "discovery_mean_bias_brier_gain " discovery_bias_brier
    print "validation_lives " validation_lives + 0
    print "validation_turns " validation_turns + 0
    print "validation_raw_life_wins " validation_raw_wins + 0
    print "validation_bias_life_wins " validation_bias_wins + 0
    print "validation_primary_raw_wins " primary_raw_wins + 0
    print "validation_holdout_raw_wins " holdout_raw_wins + 0
    print "validation_primary_bias_wins " primary_bias_wins + 0
    print "validation_holdout_bias_wins " holdout_bias_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", validation_gain + 0)
    print "validation_mean_raw_brier_gain " sprintf("%.9f", validation_brier + 0)
    print "validation_mean_bias_ce_gain " sprintf("%.9f", validation_bias_gain + 0)
    print "validation_mean_bias_brier_gain " sprintf("%.9f", validation_bias_brier + 0)
    print "validation_primary_mean_raw_gain " sprintf("%.9f", primary_raw + 0)
    print "validation_holdout_mean_raw_gain " sprintf("%.9f", holdout_raw + 0)
    print "validation_primary_mean_bias_gain " sprintf("%.9f", primary_bias + 0)
    print "validation_holdout_mean_bias_gain " sprintf("%.9f", holdout_bias + 0)
    print "validation_home_mean_gain " sprintf("%.9f", home_gain + 0)
    print "validation_storm_mean_gain " sprintf("%.9f", storm_gain + 0)
    print "validation_wonder_mean_gain " sprintf("%.9f", wonder_gain + 0)
    print "validation_social_mean_gain " sprintf("%.9f", social_gain + 0)
    print "required_raw_life_wins " raw_win_required
    print "required_bias_life_wins " bias_win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", ce_required)
    print "required_mean_raw_brier_gain " sprintf("%.9f", brier_required)
    print "required_mean_bias_ce_gain " sprintf("%.9f", bias_ce_required)
    print "required_mean_bias_brier_gain " sprintf("%.9f", bias_brier_required)
    print "result " result
}
