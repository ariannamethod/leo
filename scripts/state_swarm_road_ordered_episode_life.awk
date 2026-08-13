# A.104: make each ordered-path life one statistical vote.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!min_turns) min_turns = 32
    if (!policy_expected) policy_expected = 6
    if (!life_expected) life_expected = 12
}

NR == 1 {
    if (NF != 25 || $1 != "candidate" || $5 != "cohort" ||
        $18 != "raw_ce_gain" || $22 != "unordered_ce_gain" ||
        $25 != "snapshot_raw_brier_gain") fail()
    next
}

{
    if (NF != 25 || $1 !~ /^path-[a-z0-9-]+$/ ||
        !number($2) || !number($3) || !number($4) ||
        $5 !~ /^(discovery|validation)$/ || $6 !~ /^[ph][0-9][0-9]$/ ||
        $7 !~ /^(primary|holdout)$/ || $8 !~ /^[0-9]+$/ ||
        $9 !~ /^(home|storm|wonder|social)$/) fail()
    for (i = 10; i <= 25; i++) if (!number($i)) fail()
    candidate = $1; life = $6; key = candidate SUBSEP life
    if (seen_turn[key SUBSEP $8]++) fail()
    if (!(candidate in policy_seen)) {
        policy_seen[candidate] = 1
        policies[++policy_count] = candidate
        decay[candidate] = $2; strength[candidate] = $3; rank[candidate] = $4
    } else if (decay[candidate] != $2 || strength[candidate] != $3 ||
               rank[candidate] != $4) fail()
    if (!(life in life_seen)) {
        life_seen[life] = 1
        lives[++life_count] = life
        cohort[life] = $5; split_name[life] = $7
    } else if (cohort[life] != $5 || split_name[life] != $7) fail()
    count[key]++
    if ($18 > 0) raw_wins[key]++
    if ($20 > 0) snapshot_wins[key]++
    if ($22 > 0) unordered_wins[key]++
    raw_ce_gain[key] += $18; raw_brier_gain[key] += $19
    snapshot_ce_gain[key] += $20; snapshot_brier_gain[key] += $21
    unordered_ce_gain[key] += $22; unordered_brier_gain[key] += $23
    snapshot_raw_ce_gain[key] += $24
    texture_count[key SUBSEP $9]++
    texture_gain[key SUBSEP $9] += $22
}

END {
    if (fatal) exit 2
    if (policy_count != policy_expected || life_count != life_expected) fail()
    print "candidate", "decay", "strength", "rank", "cohort", "life", \
        "split", "turns", "raw_turn_wins", "snapshot_turn_wins", \
        "unordered_turn_wins", "mean_raw_ce_gain", "mean_raw_brier_gain", \
        "mean_snapshot_ce_gain", "mean_snapshot_brier_gain", \
        "mean_unordered_ce_gain", "mean_unordered_brier_gain", \
        "mean_snapshot_raw_ce_gain", "home_order_ce_gain", \
        "storm_order_ce_gain", "wonder_order_ce_gain", "social_order_ce_gain"
    for (p = 1; p <= policy_count; p++) {
        candidate = policies[p]
        for (l = 1; l <= life_count; l++) {
            life = lives[l]; key = candidate SUBSEP life
            if (count[key] < min_turns) fail()
            for (t = 1; t <= 4; t++) {
                texture = t == 1 ? "home" : (t == 2 ? "storm" : (t == 3 ? "wonder" : "social"))
                if (!texture_count[key SUBSEP texture]) fail()
                texture_mean[t] = texture_gain[key SUBSEP texture] / texture_count[key SUBSEP texture]
            }
            print candidate, decay[candidate], strength[candidate], rank[candidate], \
                cohort[life], life, split_name[life], count[key], \
                raw_wins[key] + 0, snapshot_wins[key] + 0, unordered_wins[key] + 0, \
                sprintf("%.9f", raw_ce_gain[key] / count[key]), \
                sprintf("%.9f", raw_brier_gain[key] / count[key]), \
                sprintf("%.9f", snapshot_ce_gain[key] / count[key]), \
                sprintf("%.9f", snapshot_brier_gain[key] / count[key]), \
                sprintf("%.9f", unordered_ce_gain[key] / count[key]), \
                sprintf("%.9f", unordered_brier_gain[key] / count[key]), \
                sprintf("%.9f", snapshot_raw_ce_gain[key] / count[key]), \
                sprintf("%.9f", texture_mean[1]), sprintf("%.9f", texture_mean[2]), \
                sprintf("%.9f", texture_mean[3]), sprintf("%.9f", texture_mean[4])
        }
    }
}
