# A.110: aggregate equal-vote lives without allowing dense surfaces to dominate.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!policy_expected) policy_expected = 2
    if (!discovery_expected) discovery_expected = 32
    if (!validation_expected) validation_expected = 32
}

NR == 1 {
    if (NF != 25 || $1 != "candidate" || $4 != "cohort" ||
        $7 != "surfaces" || $25 != "social_path_ce_gain") fail()
    next
}

{
    if (NF != 25 || $1 !~ /^susceptibility-path-[a-z0-9-]+$/ ||
        !number($2) || !number($3) || $4 !~ /^(discovery|validation)$/ ||
        $5 !~ /^[ph][0-9][0-9]$/ || $6 !~ /^(primary|holdout)$/ ||
        !number($7) || $7 < 2 || $7 > 4) fail()
    for (i = 8; i <= 25; i++) if (!number($i)) fail()
    key = $1 SUBSEP $4
    if (!(key in seen)) {
        seen[key] = 1
        order[++count] = key
        candidate[key] = $1; strength[key] = $2; rank[key] = $3; cohort[key] = $4
        policy[$1] = 1
    } else if ($2 != strength[key] || $3 != rank[key]) fail()
    life_key = key SUBSEP $5
    if (life_seen[life_key]++) fail()
    lives[key]++; surfaces[key] += $7
    raw_wins[key] += $8; snapshot_wins[key] += $9
    texture_wins[key] += $10; symmetric_wins[key] += $11
    raw_ce[key] += $12; raw_brier[key] += $13
    snapshot_ce[key] += $14; snapshot_brier[key] += $15
    texture_ce[key] += $16; texture_brier[key] += $17
    symmetric_ce[key] += $18; symmetric_brier[key] += $19
    snapshot_raw[key] += $20; texture_snapshot[key] += $21
    for (t = 1; t <= 4; t++) texture_path[key SUBSEP t] += $(21 + t)
    split_key = key SUBSEP $6
    split_lives[split_key]++
    split_raw_wins[split_key] += $8; split_snapshot_wins[split_key] += $9
    split_texture_wins[split_key] += $10; split_symmetric_wins[split_key] += $11
    split_raw[split_key] += $12; split_snapshot[split_key] += $14
    split_texture[split_key] += $16; split_symmetric[split_key] += $18
}

END {
    if (fatal || length(policy) != policy_expected) exit 2
    print "candidate", "strength", "rank", "cohort", "lives", "surfaces",
        "raw_life_wins", "snapshot_life_wins", "texture_life_wins",
        "symmetric_life_wins", "mean_raw_ce_gain", "mean_raw_brier_gain",
        "mean_snapshot_ce_gain", "mean_snapshot_brier_gain",
        "mean_texture_ce_gain", "mean_texture_brier_gain",
        "mean_symmetric_ce_gain", "mean_symmetric_brier_gain",
        "mean_snapshot_raw_ce_gain", "mean_texture_snapshot_ce_gain",
        "home_path_ce_gain", "storm_path_ce_gain",
        "wonder_path_ce_gain", "social_path_ce_gain",
        "primary_lives", "holdout_lives",
        "primary_raw_wins", "holdout_raw_wins",
        "primary_snapshot_wins", "holdout_snapshot_wins",
        "primary_texture_wins", "holdout_texture_wins",
        "primary_symmetric_wins", "holdout_symmetric_wins",
        "primary_mean_raw_gain", "holdout_mean_raw_gain",
        "primary_mean_snapshot_gain", "holdout_mean_snapshot_gain",
        "primary_mean_texture_gain", "holdout_mean_texture_gain",
        "primary_mean_symmetric_gain", "holdout_mean_symmetric_gain"
    for (n = 1; n <= count; n++) {
        key = order[n]
        expected = cohort[key] == "discovery" ? discovery_expected : validation_expected
        half = expected / 2
        if (lives[key] != expected ||
            split_lives[key SUBSEP "primary"] != half ||
            split_lives[key SUBSEP "holdout"] != half) fail()
        print candidate[key], strength[key], rank[key], cohort[key], lives[key], surfaces[key],
            raw_wins[key], snapshot_wins[key], texture_wins[key], symmetric_wins[key],
            sprintf("%.9f", raw_ce[key] / lives[key]),
            sprintf("%.9f", raw_brier[key] / lives[key]),
            sprintf("%.9f", snapshot_ce[key] / lives[key]),
            sprintf("%.9f", snapshot_brier[key] / lives[key]),
            sprintf("%.9f", texture_ce[key] / lives[key]),
            sprintf("%.9f", texture_brier[key] / lives[key]),
            sprintf("%.9f", symmetric_ce[key] / lives[key]),
            sprintf("%.9f", symmetric_brier[key] / lives[key]),
            sprintf("%.9f", snapshot_raw[key] / lives[key]),
            sprintf("%.9f", texture_snapshot[key] / lives[key]),
            sprintf("%.9f", texture_path[key SUBSEP 1] / lives[key]),
            sprintf("%.9f", texture_path[key SUBSEP 2] / lives[key]),
            sprintf("%.9f", texture_path[key SUBSEP 3] / lives[key]),
            sprintf("%.9f", texture_path[key SUBSEP 4] / lives[key]),
            split_lives[key SUBSEP "primary"], split_lives[key SUBSEP "holdout"],
            split_raw_wins[key SUBSEP "primary"], split_raw_wins[key SUBSEP "holdout"],
            split_snapshot_wins[key SUBSEP "primary"], split_snapshot_wins[key SUBSEP "holdout"],
            split_texture_wins[key SUBSEP "primary"], split_texture_wins[key SUBSEP "holdout"],
            split_symmetric_wins[key SUBSEP "primary"], split_symmetric_wins[key SUBSEP "holdout"],
            sprintf("%.9f", split_raw[key SUBSEP "primary"] / half),
            sprintf("%.9f", split_raw[key SUBSEP "holdout"] / half),
            sprintf("%.9f", split_snapshot[key SUBSEP "primary"] / half),
            sprintf("%.9f", split_snapshot[key SUBSEP "holdout"] / half),
            sprintf("%.9f", split_texture[key SUBSEP "primary"] / half),
            sprintf("%.9f", split_texture[key SUBSEP "holdout"] / half),
            sprintf("%.9f", split_symmetric[key SUBSEP "primary"] / half),
            sprintf("%.9f", split_symmetric[key SUBSEP "holdout"] / half)
    }
}
