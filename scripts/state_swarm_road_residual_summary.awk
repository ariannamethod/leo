# A.99: aggregate residual-learning evidence with one vote per life.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t"; if (!policy_expected) policy_expected = 6 }

NR == 1 {
    if (NF != 20 || $1 != "candidate" || $5 != "cohort" ||
        $11 != "mean_raw_ce_gain" || $20 != "social_raw_ce_gain") fail()
    next
}

{
    if (NF != 20 || $5 !~ /^(discovery|validation)$/ ||
        $7 !~ /^(primary|holdout)$/ || seen[$1 SUBSEP $5 SUBSEP $6]++) fail()
    for (i = 8; i <= 20; i++) if (!number($i)) fail()
    candidate = $1; cohort = $5; key = candidate SUBSEP cohort
    if (!(candidate in policy_seen)) {
        policy_seen[candidate] = 1
        policies[++policy_count] = candidate
        decay[candidate] = $2; strength[candidate] = $3; rank[candidate] = $4
    } else if (decay[candidate] != $2 || strength[candidate] != $3 ||
               rank[candidate] != $4) fail()
    lives[key]++; turns[key] += $8
    if ($11 > 0) raw_life_wins[key]++
    if ($13 > 0) control_life_wins[key]++
    raw_ce_gain[key] += $11; raw_brier_gain[key] += $12
    control_ce_gain[key] += $13; control_brier_gain[key] += $14
    destination_ce_gain[key] += $15; destination_brier_gain[key] += $16
    home_gain[key] += $17; storm_gain[key] += $18
    wonder_gain[key] += $19; social_gain[key] += $20
    split_lives[key SUBSEP $7]++
    if ($11 > 0) split_raw_wins[key SUBSEP $7]++
    if ($13 > 0) split_control_wins[key SUBSEP $7]++
    split_raw_gain[key SUBSEP $7] += $11
    split_control_gain[key SUBSEP $7] += $13
}

END {
    if (fatal) exit 2
    if (policy_count != policy_expected) fail()
    print "candidate", "decay", "strength", "rank", "cohort", "lives", \
        "turns", "raw_life_wins", "control_life_wins", "mean_raw_ce_gain", \
        "mean_raw_brier_gain", "mean_control_ce_gain", \
        "mean_control_brier_gain", "mean_destination_ce_gain", \
        "mean_destination_brier_gain", "home_raw_ce_gain", \
        "storm_raw_ce_gain", "wonder_raw_ce_gain", "social_raw_ce_gain", \
        "primary_lives", "holdout_lives", "primary_raw_wins", \
        "holdout_raw_wins", "primary_control_wins", "holdout_control_wins", \
        "primary_mean_raw_gain", "holdout_mean_raw_gain", \
        "primary_mean_control_gain", "holdout_mean_control_gain"
    for (p = 1; p <= policy_count; p++) {
        candidate = policies[p]
        for (c = 1; c <= 2; c++) {
            cohort = c == 1 ? "discovery" : "validation"
            key = candidate SUBSEP cohort
            expected = cohort == "discovery" ? 6 : 12
            if (lives[key] != expected ||
                split_lives[key SUBSEP "primary"] != 6 ||
                (cohort == "discovery" && split_lives[key SUBSEP "holdout"] != 0) ||
                (cohort == "validation" && split_lives[key SUBSEP "holdout"] != 6)) fail()
            print candidate, decay[candidate], strength[candidate], rank[candidate], \
                cohort, lives[key], turns[key], raw_life_wins[key] + 0, \
                control_life_wins[key] + 0, \
                sprintf("%.9f", raw_ce_gain[key] / lives[key]), \
                sprintf("%.9f", raw_brier_gain[key] / lives[key]), \
                sprintf("%.9f", control_ce_gain[key] / lives[key]), \
                sprintf("%.9f", control_brier_gain[key] / lives[key]), \
                sprintf("%.9f", destination_ce_gain[key] / lives[key]), \
                sprintf("%.9f", destination_brier_gain[key] / lives[key]), \
                sprintf("%.9f", home_gain[key] / lives[key]), \
                sprintf("%.9f", storm_gain[key] / lives[key]), \
                sprintf("%.9f", wonder_gain[key] / lives[key]), \
                sprintf("%.9f", social_gain[key] / lives[key]), \
                split_lives[key SUBSEP "primary"] + 0, \
                split_lives[key SUBSEP "holdout"] + 0, \
                split_raw_wins[key SUBSEP "primary"] + 0, \
                split_raw_wins[key SUBSEP "holdout"] + 0, \
                split_control_wins[key SUBSEP "primary"] + 0, \
                split_control_wins[key SUBSEP "holdout"] + 0, \
                sprintf("%.9f", split_raw_gain[key SUBSEP "primary"] / split_lives[key SUBSEP "primary"]), \
                sprintf("%.9f", split_lives[key SUBSEP "holdout"] ? split_raw_gain[key SUBSEP "holdout"] / split_lives[key SUBSEP "holdout"] : 0), \
                sprintf("%.9f", split_control_gain[key SUBSEP "primary"] / split_lives[key SUBSEP "primary"]), \
                sprintf("%.9f", split_lives[key SUBSEP "holdout"] ? split_control_gain[key SUBSEP "holdout"] / split_lives[key SUBSEP "holdout"] : 0)
        }
    }
}
