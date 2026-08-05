# A.87: summarize a sealed population without changing the replacement gate.

function fail() {
    fatal = 1
    exit 2
}

function integer(value) {
    return value ~ /^[0-9]+$/
}

function number(value) {
    return value ~ /^[0-9]+([.][0-9]+)?$/
}

function wilson_low(success, total,    z2, denom, center, half) {
    if (total == 0) return 0
    z2 = 1.96 * 1.96
    denom = 1 + z2 / total
    center = (success / total + z2 / (2 * total)) / denom
    half = 1.96 * sqrt((success / total * (1 - success / total) + z2 / (4 * total)) / total) / denom
    return center - half
}

function wilson_high(success, total,    z2, denom, center, half) {
    if (total == 0) return 0
    z2 = 1.96 * 1.96
    denom = 1 + z2 / total
    center = (success / total + z2 / (2 * total)) / denom
    half = 1.96 * sqrt((success / total * (1 - success / total) + z2 / (4 * total)) / total) / denom
    return center + half
}

BEGIN { FS = "\t" }

NR == 1 {
    if (NF != 22 || $1 != "life" || $2 != "split" ||
        $4 != "settled" || $13 != "writer_replacements" ||
        $15 != "minimum_similarity" || $22 != "above_050") fail()
    next
}

{
    if (NF != 22 || $1 !~ /^[ph][0-9][0-9]$/ ||
        $2 !~ /^(primary|holdout)$/ || !integer($3) ||
        $4 !~ /^(true|false)$/) fail()
    for (i = 5; i <= 14; i++)
        if (!integer($i)) fail()
    if (!number($15) || !integer($16)) fail()
    for (i = 17; i <= 22; i++)
        if (!integer($i)) fail()
    if (($1 ~ /^p/) != ($2 == "primary") ||
        ($1 ~ /^h/) != ($2 == "holdout") || seen[$1]++) fail()
    if ($5 != 32 || $6 != 64 || $7 != 8 ||
        $11 + $12 + $13 != $6 ||
        $17 + $18 + $19 + $20 + $21 + $22 != $6) fail()
    if ($4 == "true" && ($10 != 0 || $11 != 0 || $17 != $13)) fail()
    if (($13 == 0 && $14 != 0) || ($13 > 0 && $14 == 0)) fail()

    lives++
    split_lives[$2]++
    design_writer_turns += $6
    if ($4 == "true") {
        settled++
        split_settled[$2]++
        writer_turns += $6
        split_turns[$2] += $6
        replacements += $13
        split_replacements[$2] += $13
        if ($13 > 0) {
            replacement_lives++
            split_replacement_lives[$2]++
        }
        below += $17
        near005 += $18
        near010 += $19
        near020 += $20
        near050 += $21
        above050 += $22
        if (!have_min || $15 + 0 < minimum) {
            minimum = $15 + 0
            minimum_life = $1
            minimum_turn = $16
            have_min = 1
        }
    }
}

END {
    if (fatal) exit 2
    if (lives != 32 || split_lives["primary"] != 24 ||
        split_lives["holdout"] != 8 || design_writer_turns != 2048) fail()

    printf "state-swarm displacement incidence A.87\n"
    printf "design_lives=%d primary=%d holdout=%d writer_observations=%d\n",
           lives, split_lives["primary"], split_lives["holdout"],
           design_writer_turns
    printf "settled_lives=%d/%d primary=%d/%d holdout=%d/%d\n",
           settled, lives, split_settled["primary"] + 0,
           split_lives["primary"], split_settled["holdout"] + 0,
           split_lives["holdout"]
    printf "eligible_writer_observations=%d primary=%d holdout=%d\n",
           writer_turns, split_turns["primary"] + 0,
           split_turns["holdout"] + 0
    printf "replacement_events=%d replacement_lives=%d\n",
           replacements, replacement_lives
    printf "life_incidence=%.6f wilson95=%.6f..%.6f\n",
           settled ? replacement_lives / settled : 0,
           wilson_low(replacement_lives, settled),
           wilson_high(replacement_lives, settled)
    printf "turn_incidence=%.6f wilson95=%.6f..%.6f\n",
           writer_turns ? replacements / writer_turns : 0,
           wilson_low(replacements, writer_turns),
           wilson_high(replacements, writer_turns)
    printf "primary_events=%d primary_lives=%d holdout_events=%d holdout_lives=%d\n",
           split_replacements["primary"] + 0,
           split_replacement_lives["primary"] + 0,
           split_replacements["holdout"] + 0,
           split_replacement_lives["holdout"] + 0
    printf "gate_bands below=%d near_005=%d near_010=%d near_020=%d near_050=%d above_050=%d\n",
           below, near005, near010, near020, near050, above050
    printf "minimum_similarity=%.6f life=%s turn=%d\n",
           minimum, minimum_life, minimum_turn
    print "anatomy_admission=4 events in 4 lives with primary and holdout representation"
    print "replacement threshold remains 0.40; this report grants no speech reader"

    if (settled != lives)
        print "result=settlement-incomplete"
    else if (replacements >= 4 && replacement_lives >= 4 &&
             split_replacement_lives["primary"] > 0 &&
             split_replacement_lives["holdout"] > 0)
        print "result=incidence-mapped-anatomy-admissible"
    else if (replacements > 0)
        print "result=incidence-mapped-anatomy-underpowered"
    else
        print "result=incidence-below-observation-floor"
}
