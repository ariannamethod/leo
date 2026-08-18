# A.113: confirm only a balanced, ecological, relation-bearing redistribution.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    required_life_wins = 8
    required_primary_wins = 4
    required_holdout_wins = 4
    required_surprise_gain = 0.001
    required_brier_gain = 0.00025
}

NR == 1 {
    if (NF != 30 || $7 != "eligible" || $11 != "surprise_gain" ||
        $15 != "relational_over_ungated_surprise" ||
        $20 != "social_gain" || $28 != "position_8_gain" ||
        $29 != "semantic_share" || $30 != "result") fail()
    next
}

{
    if (NF != 30 || $1 != "validation" ||
        $2 !~ /^(p3[6-9]|p40|h3[5-9]|h40)$/ ||
        $3 !~ /^(primary|holdout)$/ || $4 !~ /^[0-9]+$/ ||
        $5 != 8 || $6 != 192 || $7 < 0 || $7 > 192 ||
        $8 < 0 || $9 < 0 || $10 < 0 || !number($11) || !number($12) ||
        !number($13) || !number($14) || !number($15) || !number($16) ||
        !number($29) || $29 < 0 || $29 > 1.0000001 ||
        $30 !~ /^life-(in)?admissible$/ || seen[$2]++) fail()
    if (($3 == "primary" && ($4 < 36 || $4 > 40)) ||
        ($3 == "holdout" && ($4 < 75 || $4 > 80))) fail()
    for (i = 17; i <= 28; i++) if (!number($i)) fail()
    lives++
    split_lives[$3]++
    if ($30 == "life-admissible") admissible++
    event_censored += $8
    topology_censored += $9
    forecast_censored += $10
    surprise += $11
    brier += $12
    ungated_surprise += $13
    ungated_brier += $14
    relational_over_ungated_surprise += $15
    relational_over_ungated_brier += $16
    semantic_share += $29
    for (i = 17; i <= 20; i++) texture[i] += $i
    for (i = 21; i <= 28; i++) position[i] += $i
    if ($30 == "life-admissible" && $11 > 0 && $12 > 0) {
        wins++
        split_wins[$3]++
    }
}

END {
    if (fatal || lives != 11 || split_lives["primary"] != 5 ||
        split_lives["holdout"] != 6) fail()
    mean_surprise = surprise / lives
    mean_brier = brier / lives
    mean_ungated_surprise = ungated_surprise / lives
    mean_ungated_brier = ungated_brier / lives
    mean_over_ungated_surprise = relational_over_ungated_surprise / lives
    mean_over_ungated_brier = relational_over_ungated_brier / lives
    safe_texture = safe_position = 1
    for (i = 17; i <= 20; i++) {
        texture[i] /= lives
        if (texture[i] <= 0) safe_texture = 0
    }
    for (i = 21; i <= 28; i++) {
        position[i] /= lives
        if (position[i] <= 0) safe_position = 0
    }
    confirmed = admissible == lives && wins >= required_life_wins &&
        split_wins["primary"] >= required_primary_wins &&
        split_wins["holdout"] >= required_holdout_wins &&
        mean_surprise >= required_surprise_gain &&
        mean_brier >= required_brier_gain &&
        mean_over_ungated_surprise > 0 && safe_texture && safe_position

    print "cohort", "validation"
    print "lives", lives
    print "primary_lives", split_lives["primary"] + 0
    print "holdout_lives", split_lives["holdout"] + 0
    print "branches", 8 * lives
    print "paired_turns", 192 * lives
    print "admissible_lives", admissible + 0
    print "eligible_turns", 192 * lives - event_censored - \
        topology_censored - forecast_censored
    print "event_censored", event_censored + 0
    print "topology_censored", topology_censored + 0
    print "forecast_censored", forecast_censored + 0
    print "life_wins", wins + 0
    print "primary_wins", split_wins["primary"] + 0
    print "holdout_wins", split_wins["holdout"] + 0
    printf "mean_surprise_gain\t%.9f\n", mean_surprise
    printf "mean_brier_gain\t%.9f\n", mean_brier
    printf "ungated_surprise_gain\t%.9f\n", mean_ungated_surprise
    printf "ungated_brier_gain\t%.9f\n", mean_ungated_brier
    printf "relational_over_ungated_surprise\t%.9f\n", \
        mean_over_ungated_surprise
    printf "relational_over_ungated_brier\t%.9f\n", mean_over_ungated_brier
    printf "home_gain\t%.9f\n", texture[17]
    printf "storm_gain\t%.9f\n", texture[18]
    printf "wonder_gain\t%.9f\n", texture[19]
    printf "social_gain\t%.9f\n", texture[20]
    for (i = 21; i <= 28; i++)
        printf "position_%d_gain\t%.9f\n", i - 20, position[i]
    printf "mean_semantic_share\t%.9f\n", semantic_share / lives
    print "required_life_wins", required_life_wins
    print "required_primary_wins", required_primary_wins
    print "required_holdout_wins", required_holdout_wins
    printf "required_surprise_gain\t%.9f\n", required_surprise_gain
    printf "required_brier_gain\t%.9f\n", required_brier_gain
    print "required_relational_over_ungated_surprise", "positive"
    print "required_texture_sign", "positive-all-four"
    print "required_position_sign", "positive-all-eight"
    print "result", confirmed ? \
        "relational-transition-redistribution-confirmed" : \
        "relational-transition-redistribution-not-confirmed"
}
