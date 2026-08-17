# A.111: one equal vote per paired life.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 19 || $1 != "cohort" || $8 != "eligible" ||
        $12 != "surprise_gain" || $15 != "brier_gain" ||
        $18 != "entropy_delta" || $19 != "reply_equal") fail()
    next
}

{
    if (NF != 19 || $1 !~ /^(discovery|validation)$/ ||
        $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
        $4 !~ /^[0-9]+$/ || $5 < 4 || $5 > 6 || $6 < 1 || $6 > 8 ||
        $7 !~ /^(home|storm|wonder|social)$/ || ($8 != 0 && $8 != 1) ||
        $9 !~ /^(none|reply|event|forecast|topology)$/ ||
        !number($12) || !number($15) || !number($18) ||
        ($19 != 0 && $19 != 1)) fail()
    key = $1 SUBSEP $2
    if (!(key in seen)) {
        seen[key] = 1
        keys[++life_count] = key
        cohort[key] = $1
        life[key] = $2
        split_name[key] = $3
        rank[key] = $4
    } else if (cohort[key] != $1 || life[key] != $2 ||
               split_name[key] != $3 || rank[key] != $4) fail()
    rows[key]++
    if (!$19) reply_mismatch[key]++
    if (!$8) {
        censored[key]++
        if ($9 == "event") event_censored[key]++
        else if ($9 == "topology") topology_censored[key]++
        else if ($9 == "forecast") forecast_censored[key]++
        next
    }
    eligible[key]++
    surprise[key] += $12
    brier[key] += $15
    entropy[key] += $18
    texture_rows[key SUBSEP $7]++
    texture_gain[key SUBSEP $7] += $12
}

END {
    if (fatal) exit 2
    print "cohort", "life", "split", "rank", "paired_turns", "eligible", \
        "event_censored", "topology_censored", "forecast_censored", \
        "surprise_gain", "brier_gain", "entropy_delta", "home_gain", \
        "storm_gain", "wonder_gain", "social_gain", "result"
    for (n = 1; n <= life_count; n++) {
        key = keys[n]
        if (rows[key] != 24) fail()
        if (eligible[key] >= 16 && !reply_mismatch[key])
            result = "life-admissible"
        else
            result = "life-inadmissible"
        printf "%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.9f\t%.9f\t%.9f", \
            cohort[key], life[key], split_name[key], rank[key], rows[key], \
            eligible[key] + 0, event_censored[key] + 0, \
            topology_censored[key] + 0, forecast_censored[key] + 0, \
            eligible[key] ? surprise[key] / eligible[key] : 0, \
            eligible[key] ? brier[key] / eligible[key] : 0, \
            eligible[key] ? entropy[key] / eligible[key] : 0
        for (t = 1; t <= 4; t++) {
            if (t == 1) name = "home"
            else if (t == 2) name = "storm"
            else if (t == 3) name = "wonder"
            else name = "social"
            texture_key = key SUBSEP name
            texture_mean = texture_rows[texture_key] ? \
                texture_gain[texture_key] / texture_rows[texture_key] : 0
            printf "\t%.9f", texture_mean
        }
        printf "\t%s\n", result
    }
}
