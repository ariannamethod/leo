# A.88: verify prospective enrollment before summarizing writer outcomes.

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

BEGIN {
    FS = "\t"
    target["primary"] = 24
    target["holdout"] = 8
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 13 || $1 != "life" || $2 != "split" ||
            $4 != "candidate_order" || $6 != "warm_final_states" ||
            $11 != "settled" || $12 != "enrolled" ||
            $13 != "enrollment_rank") fail()
        next
    }

    if (NF != 13 || $1 !~ /^[ph][0-9][0-9]$/ ||
        $2 !~ /^(primary|holdout)$/ || !integer($3) ||
        !integer($4) || !integer($5) || !integer($6) ||
        !integer($7) || !integer($8) || !integer($9) ||
        !integer($10) || $11 !~ /^(true|false)$/ ||
        $12 !~ /^(true|false)$/ || !integer($13)) fail()
    if (($1 ~ /^p/) != ($2 == "primary") ||
        ($1 ~ /^h/) != ($2 == "holdout") || seen_candidate[$1]++ ||
        $4 != candidates + 1 || $5 != 32 ||
        $7 + $8 + $9 != $5) fail()

    expected_settled = ($6 == 8 && $10 == 0)
    if (($11 == "true") != expected_settled) fail()
    expected_enrolled = expected_settled && enrolled_split[$2] < target[$2]
    if (($12 == "true") != expected_enrolled) fail()
    if (expected_enrolled) {
        enrolled_split[$2]++
        if ($13 != enrolled_split[$2]) fail()
        enrolled[$1] = 1
        screen_split[$1] = $2
        screen_seed[$1] = $3
        screen_rank[$1] = $13
        screen_warm_turns[$1] = $5
        screen_final_states[$1] = $6
        screen_births[$1] = $7
        screen_replacements[$1] = $9
        screen_session4_changes[$1] = $10
    } else if ($13 != 0) fail()

    candidates++
    candidate_split[$2]++
    if (expected_settled) settled_split[$2]++
    next
}

FNR == 1 {
    if (NF != 22 || $1 != "life" || $2 != "split" ||
        $4 != "enrollment_rank" || $7 != "warm_final_states" ||
        $13 != "writer_replacements" || $15 != "minimum_similarity" ||
        $22 != "above_050") fail()
    next
}

{
    if (NF != 22 || !enrolled[$1] || seen_writer[$1]++ ||
        $2 != screen_split[$1] || $3 != screen_seed[$1] ||
        $4 != screen_rank[$1]) fail()
    for (i = 3; i <= 14; i++)
        if (!integer($i)) fail()
    if (!number($15) || !integer($16)) fail()
    for (i = 17; i <= 22; i++)
        if (!integer($i)) fail()
    if ($5 != screen_warm_turns[$1] || $5 != 32 || $6 != 64 ||
        $7 != screen_final_states[$1] || $8 != screen_births[$1] ||
        $9 != screen_replacements[$1] ||
        $10 != screen_session4_changes[$1] || $11 != 0 ||
        $11 + $12 + $13 != $6 || $17 != $13) fail()
    if (($13 == 0 && $14 != 0) || ($13 > 0 && $14 == 0)) fail()

    lives++
    split_lives[$2]++
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

END {
    if (fatal) exit 2
    if (candidates != 40 || candidate_split["primary"] != 30 ||
        candidate_split["holdout"] != 10 ||
        enrolled_split["primary"] != 24 ||
        enrolled_split["holdout"] != 8 || lives != 32 ||
        split_lives["primary"] != 24 || split_lives["holdout"] != 8 ||
        writer_turns != 2048 || length(seen_writer) != length(enrolled)) fail()

    printf "state-swarm prospective displacement incidence A.88\n"
    printf "screened_candidates=%d primary=%d holdout=%d\n",
           candidates, candidate_split["primary"], candidate_split["holdout"]
    printf "settled_candidates=%d/%d primary=%d/%d holdout=%d/%d\n",
           settled_split["primary"] + settled_split["holdout"], candidates,
           settled_split["primary"] + 0, candidate_split["primary"],
           settled_split["holdout"] + 0, candidate_split["holdout"]
    printf "enrolled_lives=%d primary=%d holdout=%d writer_observations=%d\n",
           lives, split_lives["primary"], split_lives["holdout"], writer_turns
    print "post_writer_exclusions=0"
    printf "replacement_events=%d replacement_lives=%d\n",
           replacements, replacement_lives
    printf "life_incidence=%.6f wilson95=%.6f..%.6f\n",
           replacement_lives / lives,
           wilson_low(replacement_lives, lives),
           wilson_high(replacement_lives, lives)
    printf "turn_incidence=%.6f wilson95=%.6f..%.6f\n",
           replacements / writer_turns,
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

    if (replacements >= 4 && replacement_lives >= 4 &&
        split_replacement_lives["primary"] > 0 &&
        split_replacement_lives["holdout"] > 0)
        print "result=prospective-incidence-mapped-anatomy-admissible"
    else if (replacements > 0)
        print "result=prospective-incidence-mapped-anatomy-underpowered"
    else
        print "result=prospective-incidence-below-observation-floor"
}
