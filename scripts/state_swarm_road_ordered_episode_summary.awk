# A.104: aggregate ordered-path lives without pooling their votes.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t"; if (!policy_expected) policy_expected = 6 }

NR == 1 {
    if (NF != 22 || $1 != "candidate" || $5 != "cohort" ||
        $12 != "mean_raw_ce_gain" || $22 != "social_order_ce_gain") fail()
    next
}

{
    if (NF != 22 || $5 !~ /^(discovery|validation)$/ ||
        $7 !~ /^(primary|holdout)$/ || seen[$1 SUBSEP $5 SUBSEP $6]++) fail()
    for (i = 8; i <= 22; i++) if (!number($i)) fail()
    candidate = $1; cohort = $5; key = candidate SUBSEP cohort
    if (!(candidate in policy_seen)) {
        policy_seen[candidate] = 1
        policies[++policy_count] = candidate
        decay[candidate] = $2; strength[candidate] = $3; rank[candidate] = $4
    } else if (decay[candidate] != $2 || strength[candidate] != $3 ||
               rank[candidate] != $4) fail()
    lives[key]++; turns[key] += $8
    if ($12 > 0) raw_life_wins[key]++
    if ($14 > 0) snapshot_life_wins[key]++
    if ($16 > 0) unordered_life_wins[key]++
    raw_ce_gain[key] += $12; raw_brier_gain[key] += $13
    snapshot_ce_gain[key] += $14; snapshot_brier_gain[key] += $15
    unordered_ce_gain[key] += $16; unordered_brier_gain[key] += $17
    snapshot_raw_ce_gain[key] += $18
    home_gain[key] += $19; storm_gain[key] += $20
    wonder_gain[key] += $21; social_gain[key] += $22
    split_lives[key SUBSEP $7]++
    if ($12 > 0) split_raw_wins[key SUBSEP $7]++
    if ($14 > 0) split_snapshot_wins[key SUBSEP $7]++
    if ($16 > 0) split_unordered_wins[key SUBSEP $7]++
    split_raw_gain[key SUBSEP $7] += $12
    split_snapshot_gain[key SUBSEP $7] += $14
    split_unordered_gain[key SUBSEP $7] += $16
}

END {
    if (fatal || policy_count != policy_expected) exit 2
    print "candidate", "decay", "strength", "rank", "cohort", "lives", \
        "turns", "raw_life_wins", "snapshot_life_wins", "unordered_life_wins", \
        "mean_raw_ce_gain", "mean_raw_brier_gain", "mean_snapshot_ce_gain", \
        "mean_snapshot_brier_gain", "mean_unordered_ce_gain", \
        "mean_unordered_brier_gain", "mean_snapshot_raw_ce_gain", \
        "home_order_ce_gain", "storm_order_ce_gain", "wonder_order_ce_gain", \
        "social_order_ce_gain", "primary_lives", "holdout_lives", \
        "primary_raw_wins", "holdout_raw_wins", "primary_snapshot_wins", \
        "holdout_snapshot_wins", "primary_unordered_wins", \
        "holdout_unordered_wins", "primary_mean_raw_gain", \
        "holdout_mean_raw_gain", "primary_mean_snapshot_gain", \
        "holdout_mean_snapshot_gain", "primary_mean_unordered_gain", \
        "holdout_mean_unordered_gain"
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
                snapshot_life_wins[key] + 0, unordered_life_wins[key] + 0, \
                sprintf("%.9f", raw_ce_gain[key] / lives[key]), \
                sprintf("%.9f", raw_brier_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_ce_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_brier_gain[key] / lives[key]), \
                sprintf("%.9f", unordered_ce_gain[key] / lives[key]), \
                sprintf("%.9f", unordered_brier_gain[key] / lives[key]), \
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
                split_unordered_wins[key SUBSEP "primary"] + 0, \
                split_unordered_wins[key SUBSEP "holdout"] + 0, \
                sprintf("%.9f", split_raw_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_raw_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_snapshot_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_snapshot_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_unordered_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_unordered_gain[key SUBSEP "holdout"] / expected_split)
        }
    }
}
