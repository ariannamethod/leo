# A.112: admit only a population-balanced, texture- and position-safe road.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    required_life_wins = 22
    required_split_wins = 10
    required_surprise_gain = 0.001
    required_brier_gain = 0.00025
}

NR == 1 {
    if (NF != 25 || $1 != "cohort" || $7 != "eligible" ||
        $11 != "surprise_gain" || $12 != "brier_gain" ||
        $16 != "social_gain" || $24 != "position_8_gain" ||
        $25 != "result") fail()
    next
}

{
    if (NF != 25 || $1 != "discovery" ||
        $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
        $4 !~ /^[0-9]+$/ || $4 < 17 || $4 > 32 || $5 !~ /^[0-7]$/ ||
        $6 != 24 || $7 < 0 || $7 > 24 || $8 < 0 || $9 < 0 || $10 < 0 ||
        !number($11) || !number($12) || $25 !~ /^life-(in)?admissible$/ ||
        seen[$2]++) fail()
    for (i = 13; i <= 24; i++) if (!number($i)) fail()
    lives++
    split_lives[$3]++
    rotation_count[$3 SUBSEP $5]++
    if ($25 == "life-admissible") admissible++
    event_censored += $8
    topology_censored += $9
    forecast_censored += $10
    surprise += $11
    brier += $12
    for (i = 13; i <= 16; i++) texture[i] += $i
    for (i = 17; i <= 24; i++) position[i] += $i
    if ($25 == "life-admissible" && $11 > 0 && $12 > 0) {
        wins++
        split_wins[$3]++
    }
}

END {
    if (fatal || lives != 32 || split_lives["primary"] != 16 ||
        split_lives["holdout"] != 16) fail()
    for (s = 1; s <= 2; s++) {
        name = s == 1 ? "primary" : "holdout"
        for (r = 0; r <= 7; r++)
            if (rotation_count[name SUBSEP r] != 2) fail()
    }
    mean_surprise = surprise / lives
    mean_brier = brier / lives
    safe_texture = safe_position = 1
    for (i = 13; i <= 16; i++) {
        texture[i] /= lives
        if (texture[i] <= 0) safe_texture = 0
    }
    for (i = 17; i <= 24; i++) {
        position[i] /= lives
        if (position[i] <= 0) safe_position = 0
    }
    candidate = admissible == lives && wins >= required_life_wins &&
        split_wins["primary"] >= required_split_wins &&
        split_wins["holdout"] >= required_split_wins &&
        mean_surprise >= required_surprise_gain &&
        mean_brier >= required_brier_gain && safe_texture && safe_position

    print "cohort", "discovery"
    print "lives", lives
    print "admissible_lives", admissible + 0
    print "eligible_turns", 24 * lives - event_censored - \
        topology_censored - forecast_censored
    print "event_censored", event_censored + 0
    print "topology_censored", topology_censored + 0
    print "forecast_censored", forecast_censored + 0
    print "life_wins", wins + 0
    print "primary_wins", split_wins["primary"] + 0
    print "holdout_wins", split_wins["holdout"] + 0
    printf "mean_surprise_gain\t%.9f\n", mean_surprise
    printf "mean_brier_gain\t%.9f\n", mean_brier
    printf "home_gain\t%.9f\n", texture[13]
    printf "storm_gain\t%.9f\n", texture[14]
    printf "wonder_gain\t%.9f\n", texture[15]
    printf "social_gain\t%.9f\n", texture[16]
    for (i = 17; i <= 24; i++)
        printf "position_%d_gain\t%.9f\n", i - 16, position[i]
    print "required_life_wins", required_life_wins
    print "required_split_wins", required_split_wins
    printf "required_surprise_gain\t%.9f\n", required_surprise_gain
    printf "required_brier_gain\t%.9f\n", required_brier_gain
    print "required_texture_sign", "positive-all-four"
    print "required_position_sign", "positive-all-eight"
    print "result", candidate ? \
        "transition-surprise-redistribution-candidate" : \
        "no-transition-surprise-redistribution-candidate"
}
