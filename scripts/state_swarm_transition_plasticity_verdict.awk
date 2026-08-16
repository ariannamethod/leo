# A.111: frozen discovery/validation law for bounded transition plasticity.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = "\t"
    required_lives = 32
    required_wins = 22
    required_split_wins = 10
    required_surprise_gain = 0.001
    required_brier_gain = 0.00025
    entropy_floor = -0.01
}

NR == 1 {
    if (NF != 17 || $1 != "cohort" || $6 != "eligible" ||
        $10 != "surprise_gain" || $11 != "brier_gain" ||
        $12 != "entropy_delta" || $17 != "result") fail()
    next
}

{
    if (NF != 17 || $1 != cohort || $2 !~ /^[ph][0-9][0-9]$/ ||
        $3 !~ /^(primary|holdout)$/ || $4 !~ /^[0-9]+$/ ||
        $5 != 24 || $6 < 0 || $6 > 24 ||
        !number($10) || !number($11) || !number($12) ||
        !number($13) || !number($14) || !number($15) || !number($16) ||
        $17 !~ /^life-(in)?admissible$/) fail()
    rows++
    split_count[$3]++
    if ($17 == "life-admissible") admissible++
    if ($10 > 0 && $11 > 0) {
        wins++
        split_wins[$3]++
    }
    surprise += $10
    brier += $11
    entropy += $12
    home += $13
    storm += $14
    wonder += $15
    social += $16
    eligible_turns += $6
    event_censored += $7
    topology_censored += $8
    forecast_censored += $9
}

END {
    if (fatal) exit 2
    if (rows != required_lives || split_count["primary"] != 16 ||
        split_count["holdout"] != 16) fail()
    mean_surprise = surprise / rows
    mean_brier = brier / rows
    mean_entropy = entropy / rows
    home /= rows; storm /= rows; wonder /= rows; social /= rows
    admitted = admissible == required_lives && wins >= required_wins &&
        split_wins["primary"] >= required_split_wins &&
        split_wins["holdout"] >= required_split_wins &&
        mean_surprise >= required_surprise_gain &&
        mean_brier >= required_brier_gain && mean_entropy >= entropy_floor &&
        home > 0 && storm > 0 && wonder > 0 && social > 0
    print "cohort " cohort
    print "lives " rows
    print "admissible_lives " admissible
    print "eligible_turns " eligible_turns
    print "event_censored " event_censored
    print "topology_censored " topology_censored
    print "forecast_censored " forecast_censored
    print "life_wins " wins + 0
    print "primary_wins " split_wins["primary"] + 0
    print "holdout_wins " split_wins["holdout"] + 0
    printf "mean_surprise_gain %.9f\n", mean_surprise
    printf "mean_brier_gain %.9f\n", mean_brier
    printf "mean_entropy_delta %.9f\n", mean_entropy
    printf "home_gain %.9f\n", home
    printf "storm_gain %.9f\n", storm
    printf "wonder_gain %.9f\n", wonder
    printf "social_gain %.9f\n", social
    print "required_life_wins " required_wins
    print "required_split_wins " required_split_wins
    printf "required_surprise_gain %.9f\n", required_surprise_gain
    printf "required_brier_gain %.9f\n", required_brier_gain
    printf "entropy_floor %.9f\n", entropy_floor
    if (admitted)
        print "result transition-surprise-plasticity-candidate"
    else
        print "result no-transition-surprise-plasticity-candidate"
}
