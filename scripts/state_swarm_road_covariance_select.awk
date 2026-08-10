# A.100: nominate covariance using the sealed A.98 discovery lives only.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 6
    if (!policy_expected) policy_expected = 6
    if (!raw_win_required) raw_win_required = 4
    if (!prior_win_required) prior_win_required = 4
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!prior_required) prior_required = 0.015
}

NR == 1 {
    if (NF != 27 || $1 != "candidate" || $5 != "cohort" ||
        $8 != "raw_life_wins" || $27 != "holdout_mean_prior_gain") fail()
    next
}

$5 == "discovery" {
    if (NF != 27 || seen[$1]++ || $6 != expected || $18 != expected ||
        $19 != 0 || !number($10) || !number($11) || !number($12)) fail()
    rows++
    if ($8 >= raw_win_required && $9 >= prior_win_required &&
        $10 >= ce_required && $11 >= brier_required &&
        $12 >= prior_required && $14 > 0 && $15 > 0 && $16 > 0 && $17 > 0) {
        qualified++
        if (!selected || $10 > best_gain + 0.0000000005 ||
            ($10 >= best_gain - 0.0000000005 && $4 < best_rank)) {
            selected = $1; best_decay = $2; best_strength = $3; best_rank = $4
            best_raw_wins = $8; best_prior_wins = $9
            best_gain = $10; best_brier = $11; best_prior = $12
            best_home = $14; best_storm = $15
            best_wonder = $16; best_social = $17
        }
    }
}

END {
    if (fatal) exit 2
    if (rows != policy_expected) fail()
    print "candidate", "decay", "strength", "rank", "discovery_lives", \
        "raw_life_wins", "prior_life_wins", "mean_raw_ce_gain", \
        "mean_raw_brier_gain", "mean_prior_ce_gain", "home_raw_ce_gain", \
        "storm_raw_ce_gain", "wonder_raw_ce_gain", "social_raw_ce_gain", \
        "qualified_candidates", "result"
    if (selected)
        print selected, best_decay, best_strength, best_rank, expected, \
            best_raw_wins, best_prior_wins, best_gain, best_brier, best_prior, \
            best_home, best_storm, best_wonder, best_social, qualified, \
            "candidate-nominated"
    else
        print "none", 0, 0, 0, expected, 0, 0, "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", 0, "no-covariance-candidate"
}
