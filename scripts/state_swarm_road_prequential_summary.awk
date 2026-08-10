# A.98: aggregate life votes without turning correlated turns into lives.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t"; if (!policy_expected) policy_expected = 6 }

NR == 1 {
    if (NF != 17 || $1 != "candidate" || $5 != "cohort" ||
        $10 != "mean_raw_ce_gain" || $17 != "social_raw_ce_gain") fail()
    next
}

{
    if (NF != 17 || $5 !~ /^(discovery|validation)$/ ||
        $7 !~ /^(primary|holdout)$/ || seen[$1 SUBSEP $5 SUBSEP $6]++) fail()
    for (i = 8; i <= 17; i++) if (!number($i)) fail()
    candidate = $1; cohort = $5; key = candidate SUBSEP cohort
    if (!(candidate in policy_seen)) {
        policy_seen[candidate] = 1
        policies[++policy_count] = candidate
        decay[candidate] = $2; strength[candidate] = $3; rank[candidate] = $4
    } else if (decay[candidate] != $2 || strength[candidate] != $3 || rank[candidate] != $4) fail()
    lives[key]++
    turns[key] += $8
    if ($10 > 0) life_wins[key]++
    raw_ce_gain[key] += $10
    raw_brier_gain[key] += $11
    destination_ce_gain[key] += $12
    destination_brier_gain[key] += $13
    home_gain[key] += $14; storm_gain[key] += $15
    wonder_gain[key] += $16; social_gain[key] += $17
    split_lives[key SUBSEP $7]++
    if ($10 > 0) split_wins[key SUBSEP $7]++
    split_gain[key SUBSEP $7] += $10
}

END {
    if (fatal) exit 2
    if (policy_count != policy_expected) fail()
    print "candidate", "decay", "strength", "rank", "cohort", "lives", \
        "turns", "life_wins", "mean_raw_ce_gain", "mean_raw_brier_gain", \
        "mean_destination_ce_gain", "mean_destination_brier_gain", \
        "home_raw_ce_gain", "storm_raw_ce_gain", "wonder_raw_ce_gain", \
        "social_raw_ce_gain", "primary_lives", "holdout_lives", \
        "primary_wins", "holdout_wins", "primary_mean_gain", "holdout_mean_gain"
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
                cohort, lives[key], turns[key], life_wins[key] + 0, \
                sprintf("%.9f", raw_ce_gain[key] / lives[key]), \
                sprintf("%.9f", raw_brier_gain[key] / lives[key]), \
                sprintf("%.9f", destination_ce_gain[key] / lives[key]), \
                sprintf("%.9f", destination_brier_gain[key] / lives[key]), \
                sprintf("%.9f", home_gain[key] / lives[key]), \
                sprintf("%.9f", storm_gain[key] / lives[key]), \
                sprintf("%.9f", wonder_gain[key] / lives[key]), \
                sprintf("%.9f", social_gain[key] / lives[key]), \
                split_lives[key SUBSEP "primary"] + 0, \
                split_lives[key SUBSEP "holdout"] + 0, \
                split_wins[key SUBSEP "primary"] + 0, \
                split_wins[key SUBSEP "holdout"] + 0, \
                sprintf("%.9f", split_gain[key SUBSEP "primary"] / split_lives[key SUBSEP "primary"]), \
                sprintf("%.9f", split_lives[key SUBSEP "holdout"] ? split_gain[key SUBSEP "holdout"] / split_lives[key SUBSEP "holdout"] : 0)
        }
    }
}
