# A.98: select a past-only row policy using discovery lives alone.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 6
    if (!policy_expected) policy_expected = 6
    if (!win_required) win_required = 4
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!destination_required) destination_required = 0.015
}

NR == 1 {
    if (NF != 22 || $1 != "candidate" || $5 != "cohort" ||
        $8 != "life_wins" || $22 != "holdout_mean_gain") fail()
    next
}

$5 == "discovery" {
    if (NF != 22 || seen[$1]++ || $6 != expected || $17 != expected ||
        $18 != 0 || !number($9) || !number($10) || !number($11)) fail()
    rows++
    if ($8 >= win_required && $9 >= ce_required &&
        $10 >= brier_required && $11 >= destination_required &&
        $13 > 0 && $14 > 0 && $15 > 0 && $16 > 0) {
        qualified++
        if (!selected || $9 > best_gain + 0.0000000005 ||
            ($9 >= best_gain - 0.0000000005 && $4 < best_rank)) {
            selected = $1; best_decay = $2; best_strength = $3; best_rank = $4
            best_wins = $8; best_gain = $9; best_brier = $10
            best_destination = $11; best_home = $13; best_storm = $14
            best_wonder = $15; best_social = $16
        }
    }
}

END {
    if (fatal) exit 2
    if (rows != policy_expected) fail()
    print "candidate", "decay", "strength", "rank", "discovery_lives", \
        "life_wins", "mean_raw_ce_gain", "mean_raw_brier_gain", \
        "mean_destination_ce_gain", "home_raw_ce_gain", \
        "storm_raw_ce_gain", "wonder_raw_ce_gain", "social_raw_ce_gain", \
        "qualified_candidates", "result"
    if (selected)
        print selected, best_decay, best_strength, best_rank, expected, \
            best_wins, best_gain, best_brier, best_destination, best_home, \
            best_storm, best_wonder, best_social, qualified, "candidate-nominated"
    else
        print "none", 0, 0, 0, expected, 0, "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", 0, "no-prequential-authority-candidate"
}
