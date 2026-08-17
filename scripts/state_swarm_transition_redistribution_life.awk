# A.112: one equal vote per counterbalanced life.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 17 || $1 != "cohort" || $8 != "source_order" ||
        $10 != "eligible" || $14 != "surprise_gain" ||
        $17 != "brier_gain") fail()
    next
}

{
    if (NF != 17 || $1 != "discovery" ||
        $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
        $4 !~ /^[0-9]+$/ || $4 < 17 || $4 > 32 ||
        $5 !~ /^[0-7]$/ || $6 < 4 || $6 > 6 || $7 < 1 || $7 > 8 ||
        $8 < 1 || $8 > 8 || $9 !~ /^(home|storm|wonder|social)$/ ||
        ($10 != 0 && $10 != 1) ||
        $11 !~ /^(none|event|topology|forecast)$/ ||
        !number($14) || !number($17)) fail()
    key = $2
    if (!(key in seen)) {
        seen[key] = 1
        keys[++life_count] = key
        cohort[key] = $1
        split_name[key] = $3
        rank[key] = $4
        rotation[key] = $5
    } else if (cohort[key] != $1 || split_name[key] != $3 ||
               rank[key] != $4 || rotation[key] != $5) fail()
    rows[key]++
    if (!$10) {
        censored[key]++
        if ($11 == "event") event_censored[key]++
        else if ($11 == "topology") topology_censored[key]++
        else if ($11 == "forecast") forecast_censored[key]++
        next
    }
    eligible[key]++
    surprise[key] += $14
    brier[key] += $17
    texture_rows[key SUBSEP $9]++
    texture_gain[key SUBSEP $9] += $14
    position_rows[key SUBSEP $7]++
    position_gain[key SUBSEP $7] += $14
}

END {
    if (fatal) exit 2
    print "cohort", "life", "split", "rank", "rotation", "paired_turns", \
        "eligible", "event_censored", "topology_censored", \
        "forecast_censored", "surprise_gain", "brier_gain", "home_gain", \
        "storm_gain", "wonder_gain", "social_gain", "position_1_gain", \
        "position_2_gain", "position_3_gain", "position_4_gain", \
        "position_5_gain", "position_6_gain", "position_7_gain", \
        "position_8_gain", "result"
    for (n = 1; n <= life_count; n++) {
        key = keys[n]
        if (rows[key] != 24) fail()
        result = eligible[key] >= 16 ? "life-admissible" : "life-inadmissible"
        printf "%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.9f\t%.9f", \
            cohort[key], key, split_name[key], rank[key], rotation[key], \
            rows[key], eligible[key] + 0, event_censored[key] + 0, \
            topology_censored[key] + 0, forecast_censored[key] + 0, \
            eligible[key] ? surprise[key] / eligible[key] : 0, \
            eligible[key] ? brier[key] / eligible[key] : 0
        for (t = 1; t <= 4; t++) {
            if (t == 1) name = "home"
            else if (t == 2) name = "storm"
            else if (t == 3) name = "wonder"
            else name = "social"
            texture_key = key SUBSEP name
            printf "\t%.9f", texture_rows[texture_key] ? \
                texture_gain[texture_key] / texture_rows[texture_key] : 0
        }
        for (p = 1; p <= 8; p++) {
            position_key = key SUBSEP p
            printf "\t%.9f", position_rows[position_key] ? \
                position_gain[position_key] / position_rows[position_key] : 0
        }
        printf "\t%s\n", result
    }
}
