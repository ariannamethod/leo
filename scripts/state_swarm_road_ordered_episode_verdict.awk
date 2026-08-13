# A.104: confirm one frozen temporal-arrow reader on ten untouched lives.

function fail() { fatal = 1; exit 2 }

BEGIN {
    FS = "\t"
    if (!expected) expected = 10
    if (!raw_win_required) raw_win_required = 7
    if (!snapshot_win_required) snapshot_win_required = 7
    if (!unordered_win_required) unordered_win_required = 7
    if (!split_win_required) split_win_required = 3
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!snapshot_ce_required) snapshot_ce_required = 0.002
    if (!snapshot_brier_required) snapshot_brier_required = 0.0005
    if (!unordered_ce_required) unordered_ce_required = 0.001
    if (!unordered_brier_required) unordered_brier_required = 0.00025
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 21 || $1 != "candidate" || $21 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 21) fail()
    selected = $1; selected_decay = $2; selected_strength = $3
    selected_rank = $4; discovery_lives = $5
    discovery_raw_wins = $6; discovery_snapshot_wins = $7
    discovery_unordered_wins = $8; discovery_gain = $9; discovery_brier = $10
    discovery_snapshot_gain = $11; discovery_snapshot_brier = $12
    discovery_order_gain = $13; discovery_order_brier = $14
    qualified = $20; selection_result = $21
    next
}

FNR == 1 {
    if (NF != 35 || $1 != "candidate" || $5 != "cohort" ||
        $35 != "holdout_mean_unordered_gain") fail()
    next
}

$5 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 35 || $2 != selected_decay ||
        $3 != selected_strength || $4 != selected_rank || $6 != expected ||
        $22 != 5 || $23 != 5) fail()
    validation_lives = $6; validation_turns = $7
    validation_raw_wins = $8; validation_snapshot_wins = $9
    validation_unordered_wins = $10; validation_gain = $11
    validation_brier = $12; validation_snapshot_gain = $13
    validation_snapshot_brier = $14; validation_order_gain = $15
    validation_order_brier = $16
    home_gain = $18; storm_gain = $19; wonder_gain = $20; social_gain = $21
    primary_raw_wins = $24; holdout_raw_wins = $25
    primary_snapshot_wins = $26; holdout_snapshot_wins = $27
    primary_unordered_wins = $28; holdout_unordered_wins = $29
    primary_raw = $30; holdout_raw = $31
    primary_snapshot = $32; holdout_snapshot = $33
    primary_unordered = $34; holdout_unordered = $35
}

END {
    if (fatal || selection_rows != 1) exit 2
    if (selection_result == "no-ordered-path-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-ordered-path-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (validation_raw_wins >= raw_win_required &&
            validation_snapshot_wins >= snapshot_win_required &&
            validation_unordered_wins >= unordered_win_required &&
            primary_raw_wins >= split_win_required && holdout_raw_wins >= split_win_required &&
            primary_snapshot_wins >= split_win_required && holdout_snapshot_wins >= split_win_required &&
            primary_unordered_wins >= split_win_required && holdout_unordered_wins >= split_win_required &&
            validation_gain >= ce_required && validation_brier >= brier_required &&
            validation_snapshot_gain >= snapshot_ce_required &&
            validation_snapshot_brier >= snapshot_brier_required &&
            validation_order_gain >= unordered_ce_required &&
            validation_order_brier >= unordered_brier_required &&
            primary_raw > 0 && holdout_raw > 0 &&
            primary_snapshot > 0 && holdout_snapshot > 0 &&
            primary_unordered > 0 && holdout_unordered > 0 &&
            home_gain > 0 && storm_gain > 0 && wonder_gain > 0 && social_gain > 0)
            result = "ordered-path-supported"
        else
            result = "ordered-path-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_decay " selected_decay
    print "selected_strength " selected_strength
    print "qualified_discovery_candidates " qualified
    print "discovery_lives " discovery_lives
    print "discovery_raw_life_wins " discovery_raw_wins
    print "discovery_snapshot_life_wins " discovery_snapshot_wins
    print "discovery_unordered_life_wins " discovery_unordered_wins
    print "discovery_mean_raw_ce_gain " discovery_gain
    print "discovery_mean_raw_brier_gain " discovery_brier
    print "discovery_mean_snapshot_ce_gain " discovery_snapshot_gain
    print "discovery_mean_snapshot_brier_gain " discovery_snapshot_brier
    print "discovery_mean_unordered_ce_gain " discovery_order_gain
    print "discovery_mean_unordered_brier_gain " discovery_order_brier
    print "validation_lives " validation_lives + 0
    print "validation_turns " validation_turns + 0
    print "validation_raw_life_wins " validation_raw_wins + 0
    print "validation_snapshot_life_wins " validation_snapshot_wins + 0
    print "validation_unordered_life_wins " validation_unordered_wins + 0
    print "validation_primary_raw_wins " primary_raw_wins + 0
    print "validation_holdout_raw_wins " holdout_raw_wins + 0
    print "validation_primary_snapshot_wins " primary_snapshot_wins + 0
    print "validation_holdout_snapshot_wins " holdout_snapshot_wins + 0
    print "validation_primary_unordered_wins " primary_unordered_wins + 0
    print "validation_holdout_unordered_wins " holdout_unordered_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", validation_gain + 0)
    print "validation_mean_raw_brier_gain " sprintf("%.9f", validation_brier + 0)
    print "validation_mean_snapshot_ce_gain " sprintf("%.9f", validation_snapshot_gain + 0)
    print "validation_mean_snapshot_brier_gain " sprintf("%.9f", validation_snapshot_brier + 0)
    print "validation_mean_unordered_ce_gain " sprintf("%.9f", validation_order_gain + 0)
    print "validation_mean_unordered_brier_gain " sprintf("%.9f", validation_order_brier + 0)
    print "validation_primary_mean_raw_gain " sprintf("%.9f", primary_raw + 0)
    print "validation_holdout_mean_raw_gain " sprintf("%.9f", holdout_raw + 0)
    print "validation_primary_mean_snapshot_gain " sprintf("%.9f", primary_snapshot + 0)
    print "validation_holdout_mean_snapshot_gain " sprintf("%.9f", holdout_snapshot + 0)
    print "validation_primary_mean_unordered_gain " sprintf("%.9f", primary_unordered + 0)
    print "validation_holdout_mean_unordered_gain " sprintf("%.9f", holdout_unordered + 0)
    print "validation_home_mean_order_gain " sprintf("%.9f", home_gain + 0)
    print "validation_storm_mean_order_gain " sprintf("%.9f", storm_gain + 0)
    print "validation_wonder_mean_order_gain " sprintf("%.9f", wonder_gain + 0)
    print "validation_social_mean_order_gain " sprintf("%.9f", social_gain + 0)
    print "required_raw_life_wins " raw_win_required
    print "required_snapshot_life_wins " snapshot_win_required
    print "required_unordered_life_wins " unordered_win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", ce_required)
    print "required_mean_raw_brier_gain " sprintf("%.9f", brier_required)
    print "required_mean_snapshot_ce_gain " sprintf("%.9f", snapshot_ce_required)
    print "required_mean_snapshot_brier_gain " sprintf("%.9f", snapshot_brier_required)
    print "required_mean_unordered_ce_gain " sprintf("%.9f", unordered_ce_required)
    print "required_mean_unordered_brier_gain " sprintf("%.9f", unordered_brier_required)
    print "result " result
}
