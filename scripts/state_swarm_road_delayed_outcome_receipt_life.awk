# A.109: make each life one vote about unexpected outcomes beyond its signed carried path.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!min_receipts) min_receipts = 3
    if (!policy_expected) policy_expected = 2
    if (!life_expected) life_expected = 10
}

NR == 1 {
    if (NF != 34 || $1 != "candidate" || $4 != "cohort" ||
        $22 != "raw_ce_gain" || $28 != "symmetric_ce_gain" ||
        $30 != "path_ce_gain" || $34 != "path_symmetric_ce_gain") fail()
    next
}

{
    if (NF != 34 || $1 !~ /^outcome-receipt-path-[a-z0-9-]+$/ ||
        !number($2) || !number($3) || $4 !~ /^(discovery|validation)$/ ||
        $5 !~ /^[ph][0-9][0-9]$/ || $6 !~ /^(primary|holdout)$/ ||
        $7 !~ /^[0-9]+$/ || $8 !~ /^[0-9]+$/ ||
        $9 !~ /^(home|storm|wonder|social)$/) fail()
    for (i = 10; i <= 34; i++) if (!number($i)) fail()
    candidate = $1; life = $5; key = candidate SUBSEP life
    if (seen_turn[key SUBSEP $7]++) fail()
    if (!(candidate in policy_seen)) {
        policy_seen[candidate] = 1
        policies[++policy_count] = candidate
        strength[candidate] = $2; rank[candidate] = $3
    } else if (strength[candidate] != $2 || rank[candidate] != $3) fail()
    if (!(life in life_seen)) {
        life_seen[life] = 1
        lives[++life_count] = life
        cohort[life] = $4; split_name[life] = $6
    } else if (cohort[life] != $4 || split_name[life] != $6) fail()
    count[key]++
    if ($22 > 0) raw_wins[key]++
    if ($24 > 0) snapshot_wins[key]++
    if ($26 > 0) texture_wins[key]++
    if ($28 > 0) symmetric_wins[key]++
    if ($30 > 0) path_wins[key]++
    raw_ce_gain[key] += $22; raw_brier_gain[key] += $23
    snapshot_ce_gain[key] += $24; snapshot_brier_gain[key] += $25
    texture_ce_gain[key] += $26; texture_brier_gain[key] += $27
    symmetric_ce_gain[key] += $28; symmetric_brier_gain[key] += $29
    path_ce_gain[key] += $30; path_brier_gain[key] += $31
    snapshot_raw_ce_gain[key] += $32
    texture_snapshot_ce_gain[key] += $33
    path_symmetric_ce_gain[key] += $34
    texture_count[key SUBSEP $9]++
    texture_gain[key SUBSEP $9] += $30
}

END {
    if (fatal || policy_count != policy_expected || life_count != life_expected) exit 2
    print "candidate", "strength", "rank", "cohort", "life", "split", \
        "receipts", "raw_receipt_wins", "snapshot_receipt_wins", \
        "texture_receipt_wins", "symmetric_receipt_wins", "path_receipt_wins", \
        "mean_raw_ce_gain", "mean_raw_brier_gain", "mean_snapshot_ce_gain", \
        "mean_snapshot_brier_gain", "mean_texture_ce_gain", \
        "mean_texture_brier_gain", "mean_symmetric_ce_gain", \
        "mean_symmetric_brier_gain", "mean_path_ce_gain", \
        "mean_path_brier_gain", "mean_snapshot_raw_ce_gain", \
        "mean_texture_snapshot_ce_gain", "mean_path_symmetric_ce_gain", \
        "home_receipt_ce_gain", \
        "storm_receipt_ce_gain", "wonder_receipt_ce_gain", \
        "social_receipt_ce_gain", "home_receipts", "storm_receipts", \
        "wonder_receipts", "social_receipts"
    for (p = 1; p <= policy_count; p++) {
        candidate = policies[p]
        for (l = 1; l <= life_count; l++) {
            life = lives[l]; key = candidate SUBSEP life
            if (count[key] < min_receipts || count[key] > 4) fail()
            for (t = 1; t <= 4; t++) {
                texture = t == 1 ? "home" : (t == 2 ? "storm" : (t == 3 ? "wonder" : "social"))
                texture_n[t] = texture_count[key SUBSEP texture] + 0
                texture_mean[t] = texture_n[t] ? \
                    texture_gain[key SUBSEP texture] / texture_n[t] : 0
            }
            print candidate, strength[candidate], rank[candidate], cohort[life], \
                life, split_name[life], count[key], raw_wins[key] + 0, \
                snapshot_wins[key] + 0, texture_wins[key] + 0, \
                symmetric_wins[key] + 0, path_wins[key] + 0, \
                sprintf("%.9f", raw_ce_gain[key] / count[key]), \
                sprintf("%.9f", raw_brier_gain[key] / count[key]), \
                sprintf("%.9f", snapshot_ce_gain[key] / count[key]), \
                sprintf("%.9f", snapshot_brier_gain[key] / count[key]), \
                sprintf("%.9f", texture_ce_gain[key] / count[key]), \
                sprintf("%.9f", texture_brier_gain[key] / count[key]), \
                sprintf("%.9f", symmetric_ce_gain[key] / count[key]), \
                sprintf("%.9f", symmetric_brier_gain[key] / count[key]), \
                sprintf("%.9f", path_ce_gain[key] / count[key]), \
                sprintf("%.9f", path_brier_gain[key] / count[key]), \
                sprintf("%.9f", snapshot_raw_ce_gain[key] / count[key]), \
                sprintf("%.9f", texture_snapshot_ce_gain[key] / count[key]), \
                sprintf("%.9f", path_symmetric_ce_gain[key] / count[key]), \
                sprintf("%.9f", texture_mean[1]), sprintf("%.9f", texture_mean[2]), \
                sprintf("%.9f", texture_mean[3]), sprintf("%.9f", texture_mean[4]), \
                texture_n[1], texture_n[2], texture_n[3], texture_n[4]
        }
    }
}
