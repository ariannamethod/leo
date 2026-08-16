# A.110: reduce counterfactual response surfaces to equal-vote life summaries.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!policy_expected) policy_expected = 2
    if (!life_expected) life_expected = 32
    if (!min_surfaces) min_surfaces = 2
}

NR == 1 {
    if (NF != 32 || $1 != "candidate" || $4 != "cohort" ||
        $19 != "raw_ce_gain" || $32 != "social_path_ce_gain") fail()
    next
}

{
    if (NF != 32 || $1 !~ /^susceptibility-path-[a-z0-9-]+$/ ||
        !number($2) || !number($3) || $4 !~ /^(discovery|validation)$/ ||
        $5 !~ /^[ph][0-9][0-9]$/ || $6 !~ /^(primary|holdout)$/ ||
        !number($7) || $7 < 5 || $7 > 8) fail()
    for (i = 8; i <= 32; i++) if (!number($i)) fail()
    key = $1 SUBSEP $5
    if (!(key in seen)) {
        seen[key] = 1
        order[++count] = key
        candidate[key] = $1; strength[key] = $2; rank[key] = $3
        cohort[key] = $4; life[key] = $5; split_name[key] = $6
        policy[$1] = 1
    } else if ($2 != strength[key] || $3 != rank[key] ||
               $4 != cohort[key] || $6 != split_name[key]) fail()
    if (session_seen[key SUBSEP $7]++) fail()
    surfaces[key]++
    raw_ce[key] += $19; raw_brier[key] += $20
    snapshot_ce[key] += $21; snapshot_brier[key] += $22
    texture_ce[key] += $23; texture_brier[key] += $24
    symmetric_ce[key] += $25; symmetric_brier[key] += $26
    snapshot_raw[key] += $27; texture_snapshot[key] += $28
    for (t = 1; t <= 4; t++) texture_path[key SUBSEP t] += $(28 + t)
}

END {
    if (fatal || length(policy) != policy_expected ||
        count != policy_expected * life_expected) exit 2
    print "candidate", "strength", "rank", "cohort", "life", "split",
        "surfaces", "raw_win", "snapshot_win", "texture_win", "symmetric_win",
        "mean_raw_ce_gain", "mean_raw_brier_gain",
        "mean_snapshot_ce_gain", "mean_snapshot_brier_gain",
        "mean_texture_ce_gain", "mean_texture_brier_gain",
        "mean_symmetric_ce_gain", "mean_symmetric_brier_gain",
        "mean_snapshot_raw_ce_gain", "mean_texture_snapshot_ce_gain",
        "home_path_ce_gain", "storm_path_ce_gain",
        "wonder_path_ce_gain", "social_path_ce_gain"
    for (n = 1; n <= count; n++) {
        key = order[n]
        if (surfaces[key] < min_surfaces || surfaces[key] > 4) fail()
        print candidate[key], strength[key], rank[key], cohort[key], life[key],
            split_name[key], surfaces[key],
            (raw_ce[key] > 0 ? 1 : 0),
            (snapshot_ce[key] > 0 ? 1 : 0),
            (texture_ce[key] > 0 ? 1 : 0),
            (symmetric_ce[key] > 0 ? 1 : 0),
            sprintf("%.9f", raw_ce[key] / surfaces[key]),
            sprintf("%.9f", raw_brier[key] / surfaces[key]),
            sprintf("%.9f", snapshot_ce[key] / surfaces[key]),
            sprintf("%.9f", snapshot_brier[key] / surfaces[key]),
            sprintf("%.9f", texture_ce[key] / surfaces[key]),
            sprintf("%.9f", texture_brier[key] / surfaces[key]),
            sprintf("%.9f", symmetric_ce[key] / surfaces[key]),
            sprintf("%.9f", symmetric_brier[key] / surfaces[key]),
            sprintf("%.9f", snapshot_raw[key] / surfaces[key]),
            sprintf("%.9f", texture_snapshot[key] / surfaces[key]),
            sprintf("%.9f", texture_path[key SUBSEP 1] / surfaces[key]),
            sprintf("%.9f", texture_path[key SUBSEP 2] / surfaces[key]),
            sprintf("%.9f", texture_path[key SUBSEP 3] / surfaces[key]),
            sprintf("%.9f", texture_path[key SUBSEP 4] / surfaces[key])
    }
}
