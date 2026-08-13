# A.103: aggregate episode-memory lives without pooling their votes.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t"; if (!policy_expected) policy_expected = 6 }

NR == 1 {
    if (NF != 19 || $1 != "candidate" || $5 != "cohort" ||
        $11 != "mean_raw_ce_gain" || $19 != "social_raw_ce_gain") fail()
    next
}

{
    if (NF != 19 || $5 !~ /^(discovery|validation)$/ ||
        $7 !~ /^(primary|holdout)$/ || seen[$1 SUBSEP $5 SUBSEP $6]++) fail()
    for (i = 8; i <= 19; i++) if (!number($i)) fail()
    candidate = $1; cohort = $5; key = candidate SUBSEP cohort
    if (!(candidate in policy_seen)) {
        policy_seen[candidate] = 1
        policies[++policy_count] = candidate
        decay[candidate] = $2; strength[candidate] = $3; rank[candidate] = $4
    } else if (decay[candidate] != $2 || strength[candidate] != $3 ||
               rank[candidate] != $4) fail()
    lives[key]++; turns[key] += $8
    if ($11 > 0) raw_life_wins[key]++
    if ($13 > 0) snapshot_life_wins[key]++
    raw_ce_gain[key] += $11; raw_brier_gain[key] += $12
    snapshot_ce_gain[key] += $13; snapshot_brier_gain[key] += $14
    snapshot_raw_ce_gain[key] += $15
    home_gain[key] += $16; storm_gain[key] += $17
    wonder_gain[key] += $18; social_gain[key] += $19
    split_lives[key SUBSEP $7]++
    if ($11 > 0) split_raw_wins[key SUBSEP $7]++
    if ($13 > 0) split_snapshot_wins[key SUBSEP $7]++
    split_raw_gain[key SUBSEP $7] += $11
    split_snapshot_gain[key SUBSEP $7] += $13
}

END {
    if (fatal || policy_count != policy_expected) exit 2
    print "candidate", "decay", "strength", "rank", "cohort", "lives", \
        "turns", "raw_life_wins", "snapshot_life_wins", "mean_raw_ce_gain", \
        "mean_raw_brier_gain", "mean_snapshot_ce_gain", "mean_snapshot_brier_gain", \
        "mean_snapshot_raw_ce_gain", "home_raw_ce_gain", "storm_raw_ce_gain", \
        "wonder_raw_ce_gain", "social_raw_ce_gain", "primary_lives", \
        "holdout_lives", "primary_raw_wins", "holdout_raw_wins", \
        "primary_snapshot_wins", "holdout_snapshot_wins", "primary_mean_raw_gain", \
        "holdout_mean_raw_gain", "primary_mean_snapshot_gain", "holdout_mean_snapshot_gain"
    for (p = 1; p <= policy_count; p++) {
        candidate = policies[p]
        for (c = 1; c <= 2; c++) {
            cohort = c == 1 ? "discovery" : "validation"
            key = candidate SUBSEP cohort
            if (!lives[key]) continue
            expected = cohort == "discovery" ? discovery_expected + 0 : validation_expected + 0
            if (!expected) expected = cohort == "discovery" ? 12 : 10
            expected_split = expected / 2
            if (lives[key] != expected ||
                split_lives[key SUBSEP "primary"] != expected_split ||
                split_lives[key SUBSEP "holdout"] != expected_split) fail()
            print candidate, decay[candidate], strength[candidate], rank[candidate], \
                cohort, lives[key], turns[key], raw_life_wins[key] + 0, \
                snapshot_life_wins[key] + 0, \
                sprintf("%.9f", raw_ce_gain[key] / lives[key]), \
                sprintf("%.9f", raw_brier_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_ce_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_brier_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_raw_ce_gain[key] / lives[key]), \
                sprintf("%.9f", home_gain[key] / lives[key]), \
                sprintf("%.9f", storm_gain[key] / lives[key]), \
                sprintf("%.9f", wonder_gain[key] / lives[key]), \
                sprintf("%.9f", social_gain[key] / lives[key]), \
                split_lives[key SUBSEP "primary"] + 0, \
                split_lives[key SUBSEP "holdout"] + 0, \
                split_raw_wins[key SUBSEP "primary"] + 0, \
                split_raw_wins[key SUBSEP "holdout"] + 0, \
                split_snapshot_wins[key SUBSEP "primary"] + 0, \
                split_snapshot_wins[key SUBSEP "holdout"] + 0, \
                sprintf("%.9f", split_raw_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_raw_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_snapshot_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_snapshot_gain[key SUBSEP "holdout"] / expected_split)
        }
    }
}
