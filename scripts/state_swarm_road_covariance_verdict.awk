# A.100: confirm only a frozen covariance policy on ten untouched lives.

function fail() { fatal = 1; exit 2 }

BEGIN {
    FS = "\t"
    if (!expected) expected = 10
    if (!raw_win_required) raw_win_required = 7
    if (!prior_win_required) prior_win_required = 7
    if (!split_win_required) split_win_required = 3
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!prior_required) prior_required = 0.015
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 16 || $1 != "candidate" || $16 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 16) fail()
    selected = $1; selected_decay = $2; selected_strength = $3
    selected_rank = $4; discovery_lives = $5
    discovery_raw_wins = $6; discovery_prior_wins = $7
    discovery_gain = $8; discovery_brier = $9; discovery_prior = $10
    qualified = $15; selection_result = $16
    next
}

FNR == 1 {
    if (NF != 27 || $1 != "candidate" || $5 != "cohort" ||
        $27 != "holdout_mean_prior_gain") fail()
    next
}

$5 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 27 || $2 != selected_decay ||
        $3 != selected_strength || $4 != selected_rank || $6 != expected ||
        $18 != 5 || $19 != 5) fail()
    validation_lives = $6; validation_turns = $7
    validation_raw_wins = $8; validation_prior_wins = $9
    validation_gain = $10; validation_brier = $11; validation_prior = $12
    home_gain = $14; storm_gain = $15; wonder_gain = $16; social_gain = $17
    primary_raw_wins = $20; holdout_raw_wins = $21
    primary_prior_wins = $22; holdout_prior_wins = $23
    primary_raw = $24; holdout_raw = $25
    primary_prior = $26; holdout_prior = $27
}

END {
    if (fatal) exit 2
    if (selection_rows != 1) fail()
    if (selection_result == "no-covariance-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-covariance-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (validation_raw_wins >= raw_win_required &&
            validation_prior_wins >= prior_win_required &&
            primary_raw_wins >= split_win_required &&
            holdout_raw_wins >= split_win_required &&
            primary_prior_wins >= split_win_required &&
            holdout_prior_wins >= split_win_required &&
            validation_gain >= ce_required && validation_brier >= brier_required &&
            validation_prior >= prior_required &&
            primary_raw > 0 && holdout_raw > 0 &&
            primary_prior > 0 && holdout_prior > 0 &&
            home_gain > 0 && storm_gain > 0 && wonder_gain > 0 && social_gain > 0)
            result = "temporal-covariance-supported"
        else
            result = "temporal-covariance-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_decay " selected_decay
    print "selected_strength " selected_strength
    print "qualified_discovery_candidates " qualified
    print "discovery_lives " discovery_lives
    print "discovery_raw_life_wins " discovery_raw_wins
    print "discovery_prior_life_wins " discovery_prior_wins
    print "discovery_mean_raw_ce_gain " discovery_gain
    print "discovery_mean_raw_brier_gain " discovery_brier
    print "discovery_mean_prior_ce_gain " discovery_prior
    print "validation_lives " validation_lives + 0
    print "validation_turns " validation_turns + 0
    print "validation_raw_life_wins " validation_raw_wins + 0
    print "validation_prior_life_wins " validation_prior_wins + 0
    print "validation_primary_raw_wins " primary_raw_wins + 0
    print "validation_holdout_raw_wins " holdout_raw_wins + 0
    print "validation_primary_prior_wins " primary_prior_wins + 0
    print "validation_holdout_prior_wins " holdout_prior_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", validation_gain + 0)
    print "validation_mean_raw_brier_gain " sprintf("%.9f", validation_brier + 0)
    print "validation_mean_prior_ce_gain " sprintf("%.9f", validation_prior + 0)
    print "validation_primary_mean_raw_gain " sprintf("%.9f", primary_raw + 0)
    print "validation_holdout_mean_raw_gain " sprintf("%.9f", holdout_raw + 0)
    print "validation_primary_mean_prior_gain " sprintf("%.9f", primary_prior + 0)
    print "validation_holdout_mean_prior_gain " sprintf("%.9f", holdout_prior + 0)
    print "validation_home_mean_gain " sprintf("%.9f", home_gain + 0)
    print "validation_storm_mean_gain " sprintf("%.9f", storm_gain + 0)
    print "validation_wonder_mean_gain " sprintf("%.9f", wonder_gain + 0)
    print "validation_social_mean_gain " sprintf("%.9f", social_gain + 0)
    print "required_raw_life_wins " raw_win_required
    print "required_prior_life_wins " prior_win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", ce_required)
    print "required_mean_raw_brier_gain " sprintf("%.9f", brier_required)
    print "required_mean_prior_ce_gain " sprintf("%.9f", prior_required)
    print "result " result
}
