# A.113: one equal vote per sealed overflow life, balanced over eight branches.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 24 || $5 != "rotation" || $10 != "eligible" ||
        $14 != "semantic_share" || $18 != "surprise_gain" ||
        $23 != "brier_gain") fail()
    next
}

{
    if (NF != 24 || $1 != "validation" ||
        $2 !~ /^(p3[6-9]|p40|h3[5-9]|h40)$/ ||
        $3 !~ /^(primary|holdout)$/ || $4 !~ /^[0-9]+$/ ||
        $5 !~ /^[0-7]$/ || $6 < 4 || $6 > 6 || $7 < 1 || $7 > 8 ||
        $8 < 1 || $8 > 8 || $9 !~ /^(home|storm|wonder|social)$/ ||
        ($10 != 0 && $10 != 1) ||
        $11 !~ /^(none|event|topology|forecast)$/ ||
        !number($14) || $14 < 0 || $14 > 1.0000001 ||
        !number($18) || !number($19) || !number($23) || !number($24))
        fail()
    key = $2
    branch = key SUBSEP $5
    if (!(key in seen)) {
        seen[key] = 1
        keys[++life_count] = key
        cohort[key] = $1
        split_name[key] = $3
        candidate_order[key] = $4
    } else if (cohort[key] != $1 || split_name[key] != $3 ||
               candidate_order[key] != $4) fail()
    if (!(branch in branch_seen)) {
        branch_seen[branch] = 1
        branches[key]++
        rotation_count[key SUBSEP $5]++
    }
    branch_rows[branch]++
    rows[key]++
    if (!$10) {
        censored[key]++
        branch_censored[branch]++
        if ($11 == "event") event_censored[key]++
        else if ($11 == "topology") topology_censored[key]++
        else if ($11 == "forecast") forecast_censored[key]++
        next
    }
    eligible[key]++
    branch_eligible[branch]++
    surprise[key] += $18
    relational_over_ungated_surprise[key] += $19
    brier[key] += $23
    relational_over_ungated_brier[key] += $24
    ungated_surprise[key] += $15 - $16
    ungated_brier[key] += $20 - $21
    semantic_share[key] += $14
    texture_rows[key SUBSEP $9]++
    texture_gain[key SUBSEP $9] += $18
    position_rows[key SUBSEP $7]++
    position_gain[key SUBSEP $7] += $18
}

END {
    if (fatal) exit 2
    print "cohort", "life", "split", "candidate_order", "branches", \
        "paired_turns", "eligible", "event_censored", \
        "topology_censored", "forecast_censored", "surprise_gain", \
        "brier_gain", "ungated_surprise_gain", "ungated_brier_gain", \
        "relational_over_ungated_surprise", \
        "relational_over_ungated_brier", "home_gain", "storm_gain", \
        "wonder_gain", "social_gain", "position_1_gain", \
        "position_2_gain", "position_3_gain", "position_4_gain", \
        "position_5_gain", "position_6_gain", "position_7_gain", \
        "position_8_gain", "semantic_share", "result"
    for (n = 1; n <= life_count; n++) {
        key = keys[n]
        if (rows[key] != 192 || branches[key] != 8) fail()
        admissible = 1
        for (r = 0; r <= 7; r++) {
            branch = key SUBSEP r
            if (rotation_count[branch] != 1 || branch_rows[branch] != 24 ||
                branch_eligible[branch] < 16) admissible = 0
        }
        result = admissible ? "life-admissible" : "life-inadmissible"
        printf "%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d", \
            cohort[key], key, split_name[key], candidate_order[key], \
            branches[key], rows[key], eligible[key] + 0, \
            event_censored[key] + 0, topology_censored[key] + 0, \
            forecast_censored[key] + 0
        printf "\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f", \
            eligible[key] ? surprise[key] / eligible[key] : 0, \
            eligible[key] ? brier[key] / eligible[key] : 0, \
            eligible[key] ? ungated_surprise[key] / eligible[key] : 0, \
            eligible[key] ? ungated_brier[key] / eligible[key] : 0, \
            eligible[key] ? relational_over_ungated_surprise[key] / eligible[key] : 0, \
            eligible[key] ? relational_over_ungated_brier[key] / eligible[key] : 0
        for (t = 1; t <= 4; t++) {
            name = t == 1 ? "home" : t == 2 ? "storm" : \
                t == 3 ? "wonder" : "social"
            texture_key = key SUBSEP name
            printf "\t%.9f", texture_rows[texture_key] ? \
                texture_gain[texture_key] / texture_rows[texture_key] : 0
        }
        for (p = 1; p <= 8; p++) {
            position_key = key SUBSEP p
            printf "\t%.9f", position_rows[position_key] ? \
                position_gain[position_key] / position_rows[position_key] : 0
        }
        printf "\t%.9f\t%s\n", eligible[key] ? \
            semantic_share[key] / eligible[key] : 0, result
    }
}
