# A.117: a better road earns no reader until it beats its own destination prior.

function fail(message) {
    if (message != "") print "relational reader verdict: " message > "/dev/stderr"
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }

BEGIN {
    FS = OFS = "\t"
    if (expected_lives == "") expected_lives = 11
    if (expected_primary == "") expected_primary = 5
    if (expected_holdout == "") expected_holdout = 6
    if (expected_rows == "") expected_rows = 2112
    if (expected_eligible == "") expected_eligible = 2107
    if (expected_branches_per_life == "") expected_branches_per_life = 8
    if (expected_rows_per_life == "") expected_rows_per_life = 192
    if (expected_rows_per_branch == "") expected_rows_per_branch = 24
    if (expected_event_censored == "") expected_event_censored = 2
    if (expected_topology_censored == "") expected_topology_censored = 0
    if (expected_forecast_censored == "") expected_forecast_censored = 3
    if (required_life_wins == "") required_life_wins = 8
    if (required_primary_wins == "") required_primary_wins = 4
    if (required_holdout_wins == "") required_holdout_wins = 4
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 34 || $1 != "cohort" || $5 != "rotation" ||
            $10 != "eligible" || $25 != "candidate_ce" ||
            $27 != "candidate_prior_ce_gain" ||
            $34 != "candidate_over_raw_brier") fail("bad score header")
        next
    }
    if (NF != 34 || $1 != "validation" ||
        $2 !~ /^(p3[6-9]|p40|h3[5-9]|h40)$/ ||
        $3 !~ /^(primary|holdout)$/ || !integer($4) ||
        !integer($5) || $5 < 0 || $5 > 7 ||
        !integer($6) || $6 < 4 || $6 > 6 ||
        !integer($7) || $7 < 1 || $7 > 8 ||
        !integer($8) || $8 < 1 || $8 > 8 ||
        $9 !~ /^(home|storm|wonder|social)$/ ||
        ($10 != 0 && $10 != 1) ||
        $11 !~ /^(none|event|topology|forecast)$/)
        fail("invalid score row")
    for (i = 12; i <= 34; i++) if (!number($i)) fail("invalid score value")
    if (abs(($26 - $25) - $27) > 0.000000002 ||
        abs(($30 - $29) - $31) > 0.000000002 ||
        abs(($29 - $25) - $33) > 0.000000002 ||
        abs(($20 - $22) - $34) > 0.000000002)
        fail("score relation mismatch")
    if (($10 && $11 != "none") || (!$10 && $11 == "none"))
        fail("score eligibility mismatch")
    if (($3 == "primary" && ($4 < 36 || $4 > 40)) ||
        ($3 == "holdout" && ($4 < 75 || $4 > 80)))
        fail("invalid score identity")
    key = $2
    branch = key SUBSEP $5
    identity = branch SUBSEP $6 SUBSEP $7
    if (score_seen[identity]++) fail("duplicate score identity")
    if (!(key in score_life_seen)) {
        score_life_seen[key] = 1
        score_life_key[++score_lives] = key
        score_split[key] = $3
        score_order[key] = $4
    } else if (score_split[key] != $3 || score_order[key] != $4)
        fail("score life drift")
    score_rows++
    score_life_rows[key]++
    score_branch_rows[branch]++
    if (!$10) {
        if ($11 == "event") score_event++
        else if ($11 == "topology") score_topology++
        else if ($11 == "forecast") score_forecast++
        next
    }
    score_eligible++
    score_life_eligible[key]++
    texture_key = key SUBSEP $9
    position_key = key SUBSEP $7
    texture_rows[texture_key]++
    texture_gain[texture_key] += $27
    position_rows[position_key]++
    position_gain[position_key] += $27
    score_candidate_ce[key] += $27
    score_candidate_brier[key] += $28
    score_raw_ce[key] += $31
    score_raw_brier[key] += $32
    score_over_raw_ce[key] += $33
    score_over_raw_brier[key] += $34
    pooled_candidate_ce += $27
    pooled_candidate_brier += $28
    pooled_raw_ce += $31
    pooled_raw_brier += $32
    pooled_over_raw_ce += $33
    pooled_over_raw_brier += $34
    next
}

FNR == 1 {
    if (NF != 17 || $1 != "cohort" || $5 != "branches" ||
        $7 != "eligible" || $11 != "candidate_prior_ce_gain" ||
        $16 != "candidate_over_raw_brier" || $17 != "result")
        fail("bad life header")
    next
}

{
    if (NF != 17 || $1 != "validation" ||
        $2 !~ /^(p3[6-9]|p40|h3[5-9]|h40)$/ ||
        $3 !~ /^(primary|holdout)$/ || !integer($4) ||
        !integer($5) || !integer($6) || !integer($7) ||
        !integer($8) || !integer($9) || !integer($10) ||
        $17 !~ /^(reader-positive|prior-better)$/ || life_seen[$2]++)
        fail("invalid life row")
    for (i = 11; i <= 16; i++) if (!number($i)) fail("invalid life score")
    if (($3 == "primary" && ($4 < 36 || $4 > 40)) ||
        ($3 == "holdout" && ($4 < 75 || $4 > 80)))
        fail("invalid life identity")
    key = $2
    if (!(key in score_life_seen) || score_split[key] != $3 ||
        score_order[key] != $4 || $5 != expected_branches_per_life ||
        $6 != expected_rows_per_life || $7 != score_life_eligible[key] ||
        $8 + $9 + $10 != $6 - $7) fail("life/score mismatch")
    if (abs($11 - score_candidate_ce[key] / $7) > 0.000000002 ||
        abs($12 - score_candidate_brier[key] / $7) > 0.000000002 ||
        abs($13 - score_raw_ce[key] / $7) > 0.000000002 ||
        abs($14 - score_raw_brier[key] / $7) > 0.000000002 ||
        abs($15 - score_over_raw_ce[key] / $7) > 0.000000002 ||
        abs($16 - score_over_raw_brier[key] / $7) > 0.000000002)
        fail("life mean mismatch")
    expected_result = $11 > 0 && $12 > 0 ? "reader-positive" : "prior-better"
    if ($17 != expected_result) fail("false life result")

    lives++
    split_lives[$3]++
    eligible += $7
    event_censored += $8
    topology_censored += $9
    forecast_censored += $10
    candidate_ce += $11
    candidate_brier += $12
    raw_ce += $13
    raw_brier += $14
    over_raw_ce += $15
    over_raw_brier += $16
    split_candidate_ce[$3] += $11
    split_candidate_brier[$3] += $12
    if ($11 > 0) {
        ce_wins++
        split_ce_wins[$3]++
    }
    if ($12 > 0) brier_wins++
    if ($11 > 0 && $12 > 0) {
        reader_wins++
        split_reader_wins[$3]++
    }
    if ($15 > 0 && $16 > 0) over_raw_wins++
}

END {
    if (fatal) exit 2
    if (ARGC < 3 || score_rows != expected_rows ||
        score_eligible != expected_eligible || score_lives != expected_lives ||
        lives != expected_lives || split_lives["primary"] != expected_primary ||
        split_lives["holdout"] != expected_holdout || eligible != expected_eligible ||
        score_event != expected_event_censored ||
        score_topology != expected_topology_censored ||
        score_forecast != expected_forecast_censored ||
        event_censored != expected_event_censored ||
        topology_censored != expected_topology_censored ||
        forecast_censored != expected_forecast_censored)
        fail("wrong sealed population")
    for (n = 1; n <= score_lives; n++) {
        key = score_life_key[n]
        if (!life_seen[key] || score_life_rows[key] != expected_rows_per_life)
            fail("incomplete score life " key)
        for (r = 0; r <= 7; r++) {
            branch = key SUBSEP r
            if (r < expected_branches_per_life &&
                score_branch_rows[branch] != expected_rows_per_branch)
                fail("incomplete score branch " key "/" r)
            if (r >= expected_branches_per_life && score_branch_rows[branch])
                fail("unexpected score branch " key "/" r)
        }
        for (t = 1; t <= 4; t++) {
            name = t == 1 ? "home" : t == 2 ? "storm" : \
                t == 3 ? "wonder" : "social"
            texture_key = key SUBSEP name
            if (!texture_rows[texture_key]) fail("missing texture " key "/" name)
            texture[t] += texture_gain[texture_key] / texture_rows[texture_key]
        }
        for (p = 1; p <= 8; p++) {
            position_key = key SUBSEP p
            if (!position_rows[position_key]) fail("missing position " key "/" p)
            position[p] += position_gain[position_key] / position_rows[position_key]
        }
    }
    mean_candidate_ce = candidate_ce / lives
    mean_candidate_brier = candidate_brier / lives
    mean_raw_ce = raw_ce / lives
    mean_raw_brier = raw_brier / lives
    mean_over_raw_ce = over_raw_ce / lives
    mean_over_raw_brier = over_raw_brier / lives
    primary_ce = split_candidate_ce["primary"] / split_lives["primary"]
    holdout_ce = split_candidate_ce["holdout"] / split_lives["holdout"]
    primary_brier = split_candidate_brier["primary"] / split_lives["primary"]
    holdout_brier = split_candidate_brier["holdout"] / split_lives["holdout"]
    safe_texture = safe_position = 1
    for (t = 1; t <= 4; t++) {
        texture[t] /= lives
        if (texture[t] <= 0) safe_texture = 0
    }
    for (p = 1; p <= 8; p++) {
        position[p] /= lives
        if (position[p] <= 0) safe_position = 0
    }
    nominated = mean_candidate_ce > 0 && mean_candidate_brier > 0 &&
        reader_wins >= required_life_wins &&
        split_reader_wins["primary"] >= required_primary_wins &&
        split_reader_wins["holdout"] >= required_holdout_wins &&
        primary_ce > 0 && holdout_ce > 0 &&
        primary_brier > 0 && holdout_brier > 0 &&
        mean_over_raw_ce > 0 && mean_over_raw_brier > 0 &&
        over_raw_wins >= required_life_wins && safe_texture && safe_position

    print "cohort", "validation"
    print "question", "may-the-admitted-relational-road-reenter-reader-work"
    print "decision_scope", "reader-reentry-nomination-only"
    print "source", "A.113-sealed-aggregate"
    print "new_efficacy_votes", 0
    print "lives", lives
    print "primary_lives", split_lives["primary"] + 0
    print "holdout_lives", split_lives["holdout"] + 0
    print "branches", expected_branches_per_life * lives
    print "scored_turns", score_rows
    print "eligible_turns", eligible
    print "event_censored", event_censored
    print "topology_censored", topology_censored
    print "forecast_censored", forecast_censored
    print "candidate_prior_ce_wins", ce_wins + 0
    print "candidate_prior_brier_wins", brier_wins + 0
    print "reader_life_wins", reader_wins + 0
    print "primary_reader_wins", split_reader_wins["primary"] + 0
    print "holdout_reader_wins", split_reader_wins["holdout"] + 0
    print "candidate_over_raw_life_wins", over_raw_wins + 0
    printf "candidate_prior_ce_gain\t%.9f\n", mean_candidate_ce
    printf "candidate_prior_brier_gain\t%.9f\n", mean_candidate_brier
    printf "primary_candidate_prior_ce_gain\t%.9f\n", primary_ce
    printf "holdout_candidate_prior_ce_gain\t%.9f\n", holdout_ce
    printf "primary_candidate_prior_brier_gain\t%.9f\n", primary_brier
    printf "holdout_candidate_prior_brier_gain\t%.9f\n", holdout_brier
    printf "raw_prior_ce_gain\t%.9f\n", mean_raw_ce
    printf "raw_prior_brier_gain\t%.9f\n", mean_raw_brier
    printf "candidate_over_raw_ce_gain\t%.9f\n", mean_over_raw_ce
    printf "candidate_over_raw_brier_gain\t%.9f\n", mean_over_raw_brier
    printf "pooled_candidate_prior_ce_gain\t%.9f\n", \
        pooled_candidate_ce / eligible
    printf "pooled_candidate_prior_brier_gain\t%.9f\n", \
        pooled_candidate_brier / eligible
    printf "pooled_raw_prior_ce_gain\t%.9f\n", pooled_raw_ce / eligible
    printf "pooled_raw_prior_brier_gain\t%.9f\n", pooled_raw_brier / eligible
    printf "pooled_candidate_over_raw_ce_gain\t%.9f\n", \
        pooled_over_raw_ce / eligible
    printf "pooled_candidate_over_raw_brier_gain\t%.9f\n", \
        pooled_over_raw_brier / eligible
    print "required_reader_life_wins", required_life_wins
    print "required_primary_reader_wins", required_primary_wins
    print "required_holdout_reader_wins", required_holdout_wins
    print "required_split_sign", "positive-both-proper-scores"
    print "required_texture_sign", "positive-all-four-ce"
    print "required_position_sign", "positive-all-eight-ce"
    printf "home_candidate_prior_ce_gain\t%.9f\n", texture[1]
    printf "storm_candidate_prior_ce_gain\t%.9f\n", texture[2]
    printf "wonder_candidate_prior_ce_gain\t%.9f\n", texture[3]
    printf "social_candidate_prior_ce_gain\t%.9f\n", texture[4]
    for (p = 1; p <= 8; p++)
        printf "position_%d_candidate_prior_ce_gain\t%.9f\n", p, position[p]
    print "result", nominated ? \
        "relational-road-reader-reentry-nominated" : \
        "relational-road-reader-reentry-refused"
}
