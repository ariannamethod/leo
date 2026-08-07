# A.89: validate a balanced prospective reservoir and its inert trigger packages.

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

function vector(value,    part, n, i) {
    n = split(value, part, "/")
    if (n != 7) return 0
    for (i = 1; i <= 7; i++)
        if (!number(part[i]) || part[i] + 0 < 0 || part[i] + 0 > 1.001)
            return 0
    return 1
}

function weighted_vector(value,    part) {
    split(value, part, "/")
    return 0.19 * part[1] + 0.19 * part[2] + 0.10 * part[3] + 0.20 * part[4] + 0.18 * part[5] + 0.07 * part[6] + 0.07 * part[7]
}

function absolute(value) {
    return value < 0 ? -value : value
}

function witness(members, organs, trigger_new, displaced, nearest,
                 member, organ, member_n, organ_n, i, j, colon,
                 member_id, activation, organ_id, raw, trigger_seen,
                 displaced_seen, nearest_seen, nas) {
    member_n = split(members, member, ",")
    organ_n = split(organs, organ, ",")
    if (member_n != 8 || organ_n != member_n) return 0
    for (i = 1; i <= member_n; i++) {
        colon = index(member[i], ":")
        if (!colon) return 0
        member_id[i] = substr(member[i], 1, colon - 1)
        activation = substr(member[i], colon + 1)
        if (!integer(member_id[i]) || member_id[i] < 1 ||
            !number(activation) || activation < 0 || activation > 1.001)
            return 0
        for (j = 1; j < i; j++)
            if (member_id[j] == member_id[i]) return 0
        if (member_id[i] == trigger_new) trigger_seen = 1
        if (member_id[i] == displaced) displaced_seen = 1
        if (member_id[i] == nearest) nearest_seen = 1

        colon = index(organ[i], ":")
        if (!colon) return 0
        organ_id = substr(organ[i], 1, colon - 1)
        raw = substr(organ[i], colon + 1)
        if (organ_id != member_id[i]) return 0
        if (raw == "na") {
            nas++
            if (organ_id != trigger_new) return 0
        } else if (!vector(raw)) return 0
    }
    return trigger_seen && !displaced_seen && nas == 1 &&
           (nearest == displaced || nearest_seen)
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
    target["primary"] = 32
    target["holdout"] = 32
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

FILENAME == ARGV[2] {
    if (FNR == 1) {
        if (NF != 22 || $1 != "life" || $2 != "split" ||
            $4 != "enrollment_rank" || $7 != "warm_final_states" ||
            $13 != "writer_replacements" || $15 != "minimum_similarity" ||
            $22 != "above_050") fail()
        next
    }
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
    writer_replacements[$1] = $13
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
    next
}

FNR == 1 {
    if (NF != 20 || $1 != "event" || $2 != "life" ||
        $5 != "enrollment_rank" || $6 != "trigger_turn" ||
        $11 != "displaced_id" || $15 != "nearest_organs" ||
        $20 != "reply") fail()
    next
}

{
    if (NF != 20 || !enrolled[$2] || $3 != screen_split[$2] ||
        $4 != screen_seed[$2] || $5 != screen_rank[$2] ||
        !integer($6) || $6 < 33 || $6 > 96 ||
        !integer($7) || $7 < 1 || $7 > 8 ||
        !integer($8) || $8 < 1 || $8 > 8 ||
        $9 !~ /^(home|storm|wonder|social)$/ || !integer($10) ||
        !integer($11) || $11 < 1 || !integer($12) || $12 < 1 ||
        !number($13) || $13 > 0.4001 || !integer($14) ||
        !vector($15) || !vector($16) || $17 == "" || $18 == "" ||
        $19 == "" || $20 == "" || seen_event[$1]++) fail()
    if ($1 != sprintf("%s-t%03d", $2, $6) ||
        $6 != 32 + ($7 - 1) * 8 + $8 || $10 != $4 + $7 * 100 + $8 ||
        absolute(weighted_vector($15) - $13) > 0.0015 ||
        !witness($17, $18, $12, $11, $14))
        fail()
    event_count++
    event_life[$2]++
    event_split[$3]++
    event_lives[$2] = 1
}

END {
    if (fatal) exit 2
    if (candidates != 80 || candidate_split["primary"] != 40 ||
        candidate_split["holdout"] != 40 ||
        enrolled_split["primary"] != 32 ||
        enrolled_split["holdout"] != 32 || lives != 64 ||
        split_lives["primary"] != 32 || split_lives["holdout"] != 32 ||
        writer_turns != 4096 || length(seen_writer) != length(enrolled) ||
        event_count != replacements || length(event_lives) != replacement_lives)
        fail()
    for (life in enrolled)
        if (event_life[life] + 0 != writer_replacements[life] + 0) fail()

    gate = replacements >= 4 && replacement_lives >= 4 &&
           split_replacement_lives["primary"] > 0 &&
           split_replacement_lives["holdout"] > 0
    printf "state-swarm balanced displacement event reservoir A.89\n"
    printf "screened_candidates=%d primary=%d holdout=%d\n",
           candidates, candidate_split["primary"], candidate_split["holdout"]
    printf "settled_candidates=%d/%d primary=%d/%d holdout=%d/%d\n",
           settled_split["primary"] + settled_split["holdout"], candidates,
           settled_split["primary"] + 0, candidate_split["primary"],
           settled_split["holdout"] + 0, candidate_split["holdout"]
    printf "enrolled_lives=%d primary=%d holdout=%d writer_observations=%d\n",
           lives, split_lives["primary"], split_lives["holdout"], writer_turns
    print "post_writer_exclusions=0"
    printf "replacement_events=%d replacement_lives=%d trigger_packages=%d\n",
           replacements, replacement_lives, event_count
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
    printf "anatomy_gate=%s anatomy_analysis=not-run\n", gate ? "open" : "closed"
    print "anatomy admission requires >=4 events in >=4 lives with both split representations"
    print "trigger packages are readerless; A.89 runs no return probe or organ projection"
    print "replacement threshold remains 0.40; this report grants no speech reader"

    if (gate)
        print "result=balanced-reservoir-anatomy-admissible"
    else if (replacements > 0)
        print "result=balanced-reservoir-anatomy-underpowered"
    else
        print "result=balanced-reservoir-below-observation-floor"
}
