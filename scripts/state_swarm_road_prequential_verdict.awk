# A.98: confirm the frozen past-only policy across unused primary and holdout lives.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = "\t"
    if (!expected) expected = 12
    if (!win_required) win_required = 8
    if (!split_win_required) split_win_required = 4
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!destination_required) destination_required = 0.015
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 15 || $1 != "candidate" || $15 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 15) fail()
    selected = $1; selected_decay = $2; selected_strength = $3
    selected_rank = $4; discovery_lives = $5; discovery_wins = $6
    discovery_gain = $7; discovery_brier = $8; discovery_destination = $9
    qualified = $14; selection_result = $15
    next
}

FNR == 1 {
    if (NF != 22 || $1 != "candidate" || $5 != "cohort" ||
        $22 != "holdout_mean_gain") fail()
    next
}

$5 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 22 || $2 != selected_decay ||
        $3 != selected_strength || $4 != selected_rank || $6 != expected ||
        $17 != 6 || $18 != 6) fail()
    validation_lives = $6; validation_turns = $7; validation_wins = $8
    validation_gain = $9; validation_brier = $10
    validation_destination = $11
    home_gain = $13; storm_gain = $14; wonder_gain = $15; social_gain = $16
    primary_wins = $19; holdout_wins = $20
    primary_gain = $21; holdout_gain = $22
}

END {
    if (fatal) exit 2
    if (selection_rows != 1) fail()
    if (selection_result == "no-prequential-authority-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-prequential-authority-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (validation_wins >= win_required &&
            primary_wins >= split_win_required && holdout_wins >= split_win_required &&
            validation_gain >= ce_required && validation_brier >= brier_required &&
            validation_destination >= destination_required &&
            primary_gain > 0 && holdout_gain > 0 &&
            home_gain > 0 && storm_gain > 0 && wonder_gain > 0 && social_gain > 0)
            result = "prequential-row-authority-supported"
        else
            result = "prequential-row-authority-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_decay " selected_decay
    print "selected_strength " selected_strength
    print "qualified_discovery_candidates " qualified
    print "discovery_lives " discovery_lives
    print "discovery_life_wins " discovery_wins
    print "discovery_mean_raw_ce_gain " discovery_gain
    print "discovery_mean_raw_brier_gain " discovery_brier
    print "discovery_mean_destination_ce_gain " discovery_destination
    print "validation_lives " validation_lives + 0
    print "validation_turns " validation_turns + 0
    print "validation_life_wins " validation_wins + 0
    print "validation_primary_wins " primary_wins + 0
    print "validation_holdout_wins " holdout_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", validation_gain + 0)
    print "validation_mean_raw_brier_gain " sprintf("%.9f", validation_brier + 0)
    print "validation_mean_destination_ce_gain " sprintf("%.9f", validation_destination + 0)
    print "validation_primary_mean_gain " sprintf("%.9f", primary_gain + 0)
    print "validation_holdout_mean_gain " sprintf("%.9f", holdout_gain + 0)
    print "validation_home_mean_gain " sprintf("%.9f", home_gain + 0)
    print "validation_storm_mean_gain " sprintf("%.9f", storm_gain + 0)
    print "validation_wonder_mean_gain " sprintf("%.9f", wonder_gain + 0)
    print "validation_social_mean_gain " sprintf("%.9f", social_gain + 0)
    print "required_life_wins " win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", ce_required)
    print "required_mean_raw_brier_gain " sprintf("%.9f", brier_required)
    print "required_mean_destination_ce_gain " sprintf("%.9f", destination_required)
    print "result " result
}
