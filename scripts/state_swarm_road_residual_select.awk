# A.99: nominate one residual learner from discovery lives only.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 6
    if (!policy_expected) policy_expected = 6
    if (!raw_win_required) raw_win_required = 4
    if (!control_win_required) control_win_required = 4
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!control_required) control_required = 0.003
    if (!destination_required) destination_required = 0.015
}

NR == 1 {
    if (NF != 29 || $1 != "candidate" || $5 != "cohort" ||
        $8 != "raw_life_wins" || $29 != "holdout_mean_control_gain") fail()
    next
}

$5 == "discovery" {
    if (NF != 29 || seen[$1]++ || $6 != expected || $20 != expected ||
        $21 != 0 || !number($10) || !number($11) || !number($12) ||
        !number($14)) fail()
    rows++
    if ($8 >= raw_win_required && $9 >= control_win_required &&
        $10 >= ce_required && $11 >= brier_required &&
        $12 >= control_required && $14 >= destination_required &&
        $16 > 0 && $17 > 0 && $18 > 0 && $19 > 0) {
        qualified++
        if (!selected || $12 > best_control + 0.0000000005 ||
            ($12 >= best_control - 0.0000000005 && $4 < best_rank)) {
            selected = $1; best_decay = $2; best_strength = $3; best_rank = $4
            best_raw_wins = $8; best_control_wins = $9
            best_raw = $10; best_brier = $11; best_control = $12
            best_destination = $14; best_home = $16; best_storm = $17
            best_wonder = $18; best_social = $19
        }
    }
}

END {
    if (fatal) exit 2
    if (rows != policy_expected) fail()
    print "candidate", "decay", "strength", "rank", "discovery_lives", \
        "raw_life_wins", "control_life_wins", "mean_raw_ce_gain", \
        "mean_raw_brier_gain", "mean_control_ce_gain", \
        "mean_destination_ce_gain", "home_raw_ce_gain", \
        "storm_raw_ce_gain", "wonder_raw_ce_gain", "social_raw_ce_gain", \
        "qualified_candidates", "result"
    if (selected)
        print selected, best_decay, best_strength, best_rank, expected, \
            best_raw_wins, best_control_wins, best_raw, best_brier, best_control, \
            best_destination, best_home, best_storm, best_wonder, best_social, \
            qualified, "candidate-nominated"
    else
        print "none", 0, 0, 0, expected, 0, 0, "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", 0, \
            "no-residual-transition-candidate"
}
