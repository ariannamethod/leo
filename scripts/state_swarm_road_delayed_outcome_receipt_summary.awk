# A.109: aggregate outcome-receipt lives without pooling their votes.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t"; if (!policy_expected) policy_expected = 2 }

NR == 1 {
    if (NF != 33 || $1 != "candidate" || $4 != "cohort" ||
        $13 != "mean_raw_ce_gain" || $33 != "social_receipts") fail()
    next
}

{
    if (NF != 33 || $4 !~ /^(discovery|validation)$/ ||
        $6 !~ /^(primary|holdout)$/ || seen[$1 SUBSEP $4 SUBSEP $5]++) fail()
    for (i = 7; i <= 33; i++) if (!number($i)) fail()
    candidate = $1; cohort = $4; key = candidate SUBSEP cohort
    if (!(candidate in policy_seen)) {
        policy_seen[candidate] = 1
        policies[++policy_count] = candidate
        strength[candidate] = $2; rank[candidate] = $3
    } else if (strength[candidate] != $2 || rank[candidate] != $3) fail()
    lives[key]++; receipts[key] += $7
    if ($13 > 0) raw_life_wins[key]++
    if ($15 > 0) snapshot_life_wins[key]++
    if ($17 > 0) texture_life_wins[key]++
    if ($19 > 0) symmetric_life_wins[key]++
    if ($21 > 0) path_life_wins[key]++
    raw_ce_gain[key] += $13; raw_brier_gain[key] += $14
    snapshot_ce_gain[key] += $15; snapshot_brier_gain[key] += $16
    texture_ce_gain[key] += $17; texture_brier_gain[key] += $18
    symmetric_ce_gain[key] += $19; symmetric_brier_gain[key] += $20
    path_ce_gain[key] += $21; path_brier_gain[key] += $22
    snapshot_raw_gain[key] += $23; texture_snapshot_gain[key] += $24
    path_symmetric_gain[key] += $25
    for (t = 1; t <= 4; t++) {
        texture_gain[key SUBSEP t] += $(25 + t) * $(29 + t)
        texture_count[key SUBSEP t] += $(29 + t)
    }
    split_lives[key SUBSEP $6]++
    if ($13 > 0) split_raw_wins[key SUBSEP $6]++
    if ($15 > 0) split_snapshot_wins[key SUBSEP $6]++
    if ($17 > 0) split_texture_wins[key SUBSEP $6]++
    if ($19 > 0) split_symmetric_wins[key SUBSEP $6]++
    if ($21 > 0) split_path_wins[key SUBSEP $6]++
    split_raw_gain[key SUBSEP $6] += $13
    split_snapshot_gain[key SUBSEP $6] += $15
    split_texture_gain[key SUBSEP $6] += $17
    split_symmetric_gain[key SUBSEP $6] += $19
    split_path_gain[key SUBSEP $6] += $21
}

END {
    if (fatal || policy_count != policy_expected) exit 2
    print "candidate", "strength", "rank", "cohort", "lives", "receipts", \
        "raw_life_wins", "snapshot_life_wins", "texture_life_wins", \
        "symmetric_life_wins", "path_life_wins", \
        "mean_raw_ce_gain", "mean_raw_brier_gain", \
        "mean_snapshot_ce_gain", "mean_snapshot_brier_gain", \
        "mean_texture_ce_gain", "mean_texture_brier_gain", \
        "mean_symmetric_ce_gain", "mean_symmetric_brier_gain", \
        "mean_path_ce_gain", "mean_path_brier_gain", \
        "mean_snapshot_raw_ce_gain", "mean_texture_snapshot_ce_gain", \
        "mean_path_symmetric_ce_gain", \
        "home_receipt_ce_gain", "storm_receipt_ce_gain", \
        "wonder_receipt_ce_gain", "social_receipt_ce_gain", \
        "primary_lives", "holdout_lives", "primary_raw_wins", \
        "holdout_raw_wins", "primary_snapshot_wins", "holdout_snapshot_wins", \
        "primary_texture_wins", "holdout_texture_wins", \
        "primary_symmetric_wins", "holdout_symmetric_wins", \
        "primary_path_wins", "holdout_path_wins", \
        "primary_mean_raw_gain", "holdout_mean_raw_gain", \
        "primary_mean_snapshot_gain", "holdout_mean_snapshot_gain", \
        "primary_mean_texture_gain", "holdout_mean_texture_gain", \
        "primary_mean_symmetric_gain", "holdout_mean_symmetric_gain", \
        "primary_mean_path_gain", "holdout_mean_path_gain"
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
                receipts[key], raw_life_wins[key] + 0, snapshot_life_wins[key] + 0, \
                texture_life_wins[key] + 0, symmetric_life_wins[key] + 0, \
                path_life_wins[key] + 0, \
                sprintf("%.9f", raw_ce_gain[key] / lives[key]), \
                sprintf("%.9f", raw_brier_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_ce_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_brier_gain[key] / lives[key]), \
                sprintf("%.9f", texture_ce_gain[key] / lives[key]), \
                sprintf("%.9f", texture_brier_gain[key] / lives[key]), \
                sprintf("%.9f", symmetric_ce_gain[key] / lives[key]), \
                sprintf("%.9f", symmetric_brier_gain[key] / lives[key]), \
                sprintf("%.9f", path_ce_gain[key] / lives[key]), \
                sprintf("%.9f", path_brier_gain[key] / lives[key]), \
                sprintf("%.9f", snapshot_raw_gain[key] / lives[key]), \
                sprintf("%.9f", texture_snapshot_gain[key] / lives[key]), \
                sprintf("%.9f", path_symmetric_gain[key] / lives[key]), \
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
                split_symmetric_wins[key SUBSEP "primary"] + 0, \
                split_symmetric_wins[key SUBSEP "holdout"] + 0, \
                split_path_wins[key SUBSEP "primary"] + 0, \
                split_path_wins[key SUBSEP "holdout"] + 0, \
                sprintf("%.9f", split_raw_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_raw_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_snapshot_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_snapshot_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_texture_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_texture_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_symmetric_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_symmetric_gain[key SUBSEP "holdout"] / expected_split), \
                sprintf("%.9f", split_path_gain[key SUBSEP "primary"] / expected_split), \
                sprintf("%.9f", split_path_gain[key SUBSEP "holdout"] / expected_split)
        }
    }
}
