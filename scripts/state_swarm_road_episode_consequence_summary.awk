# A.105: aggregate episode-consequence lives without pooling their votes.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t"; if (!policy_expected) policy_expected = 2 }

NR == 1 {
    if (NF != 29 || $1 != "candidate" || $4 != "cohort" ||
        $12 != "mean_raw_ce_gain" || $29 != "social_episodes") fail()
    next
}

{
    if (NF != 29 || $4 !~ /^(discovery|validation)$/ ||
        $6 !~ /^(primary|holdout)$/ || seen[$1 SUBSEP $4 SUBSEP $5]++) fail()
    for (i = 7; i <= 29; i++) if (!number($i)) fail()
    candidate = $1; cohort = $4; key = candidate SUBSEP cohort
    if (!(candidate in policy_seen)) {
        policy_seen[candidate] = 1
        policies[++policy_count] = candidate
        strength[candidate] = $2; rank[candidate] = $3
    } else if (strength[candidate] != $2 || rank[candidate] != $3) fail()
    lives[key]++; episodes[key] += $7
    if ($12 > 0) raw_life_wins[key]++
    if ($14 > 0) snapshot_life_wins[key]++
    if ($16 > 0) texture_life_wins[key]++
    if ($18 > 0) unordered_life_wins[key]++
    raw_ce_gain[key] += $12; raw_brier_gain[key] += $13
    snapshot_ce_gain[key] += $14; snapshot_brier_gain[key] += $15
    texture_ce_gain[key] += $16; texture_brier_gain[key] += $17
    unordered_ce_gain[key] += $18; unordered_brier_gain[key] += $19
    snapshot_raw_gain[key] += $20; texture_snapshot_gain[key] += $21
    for (t = 1; t <= 4; t++) {
        texture_gain[key SUBSEP t] += $(21 + t) * $(25 + t)
        texture_count[key SUBSEP t] += $(25 + t)
    }
    split_lives[key SUBSEP $6]++
    if ($12 > 0) split_raw_wins[key SUBSEP $6]++
    if ($14 > 0) split_snapshot_wins[key SUBSEP $6]++
    if ($16 > 0) split_texture_wins[key SUBSEP $6]++
    if ($18 > 0) split_unordered_wins[key SUBSEP $6]++
    split_raw_gain[key SUBSEP $6] += $12
    split_snapshot_gain[key SUBSEP $6] += $14
    split_texture_gain[key SUBSEP $6] += $16
    split_unordered_gain[key SUBSEP $6] += $18
}

END {
    if (fatal || policy_count != policy_expected) exit 2
    print "candidate", "strength", "rank", "cohort", "lives", "episodes", \
        "raw_life_wins", "snapshot_life_wins", "texture_life_wins", \
        "unordered_life_wins", "mean_raw_ce_gain", "mean_raw_brier_gain", \
        "mean_snapshot_ce_gain", "mean_snapshot_brier_gain", \
        "mean_texture_ce_gain", "mean_texture_brier_gain", \
        "mean_unordered_ce_gain", "mean_unordered_brier_gain", \
        "mean_snapshot_raw_ce_gain", "mean_texture_snapshot_ce_gain", \
        "home_consequence_ce_gain", "storm_consequence_ce_gain", \
        "wonder_consequence_ce_gain", "social_consequence_ce_gain", \
        "primary_lives", "holdout_lives", "primary_raw_wins", \
        "holdout_raw_wins", "primary_snapshot_wins", "holdout_snapshot_wins", \
        "primary_texture_wins", "holdout_texture_wins", \
        "primary_unordered_wins", "holdout_unordered_wins", \
        "primary_mean_raw_gain", "holdout_mean_raw_gain", \
        "primary_mean_snapshot_gain", "holdout_mean_snapshot_gain", \
        "primary_mean_texture_gain", "holdout_mean_texture_gain", \
        "primary_mean_unordered_gain", "holdout_mean_unordered_gain"
    for (p = 1; p <= policy_count; p++) {
        candidate = policies[p]
        for (c = 1; c <= 2; c++) {
            cohort = c == 1 ? "discovery" : "validation"
            key = candidate SUBSEP cohort
            if (!lives[key]) continue
            expected = cohort == "discovery" ? discovery_expected + 0 : validation_expected + 0
            if (!expected) expected = 10
            expected_split = expected / 2
            if (lives[key] != expected ||
                split_lives[key SUBSEP "primary"] != expected_split ||
                split_lives[key SUBSEP "holdout"] != expected_split) fail()
            for (t = 1; t <= 4; t++) if (!texture_count[key SUBSEP t]) fail()
            print candidate, strength[candidate], rank[candidate], cohort, lives[key], \
                episodes[key], raw_life_wins[key] + 0, snapshot_life_wins[key] + 0, \
                texture_life_wins[key] + 0, unordered_life_wins[key] + 0, \
                sprintf("%.9f", raw_ce_gain[key] / lives[key]), \
                sprintf("%.9f", raw_brier_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_ce_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_brier_gain[key] / lives[key]), \
                sprintf("%.9f", texture_ce_gain[key] / lives[key]), \
                sprintf("%.9f", texture_brier_gain[key] / lives[key]), \
                sprintf("%.9f", unordered_ce_gain[key] / lives[key]), \
                sprintf("%.9f", unordered_brier_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_raw_gain[key] / lives[key]), \
                sprintf("%.9f", texture_snapshot_gain[key] / lives[key]), \
                sprintf("%.9f", texture_gain[key SUBSEP 1] / texture_count[key SUBSEP 1]), \
                sprintf("%.9f", texture_gain[key SUBSEP 2] / texture_count[key SUBSEP 2]), \
                sprintf("%.9f", texture_gain[key SUBSEP 3] / texture_count[key SUBSEP 3]), \
                sprintf("%.9f", texture_gain[key SUBSEP 4] / texture_count[key SUBSEP 4]), \
                split_lives[key SUBSEP "primary"] + 0, \
                split_lives[key SUBSEP "holdout"] + 0, \
                split_raw_wins[key SUBSEP "primary"] + 0, \
                split_raw_wins[key SUBSEP "holdout"] + 0, \
                split_snapshot_wins[key SUBSEP "primary"] + 0, \
                split_snapshot_wins[key SUBSEP "holdout"] + 0, \
                split_texture_wins[key SUBSEP "primary"] + 0, \
                split_texture_wins[key SUBSEP "holdout"] + 0, \
                split_unordered_wins[key SUBSEP "primary"] + 0, \
                split_unordered_wins[key SUBSEP "holdout"] + 0, \
                sprintf("%.9f", split_raw_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_raw_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_snapshot_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_snapshot_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_texture_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_texture_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_unordered_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_unordered_gain[key SUBSEP "holdout"] / expected_split)
        }
    }
}
