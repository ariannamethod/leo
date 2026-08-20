# A.117: one equal proper-score vote per sealed A.113 overflow life.

function fail(message) {
    if (message != "") print "relational reader life: " message > "/dev/stderr"
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (expected_lives == "") expected_lives = 11
    if (expected_primary == "") expected_primary = 5
    if (expected_holdout == "") expected_holdout = 6
    if (expected_rows_per_life == "") expected_rows_per_life = 192
    if (expected_branches_per_life == "") expected_branches_per_life = 8
    if (expected_rows_per_branch == "") expected_rows_per_branch = 24
    if (minimum_eligible_per_branch == "") minimum_eligible_per_branch = 16
}

NR == 1 {
    if (NF != 34 || $1 != "cohort" || $5 != "rotation" ||
        $10 != "eligible" || $11 != "reason" ||
        $25 != "candidate_ce" || $27 != "candidate_prior_ce_gain" ||
        $34 != "candidate_over_raw_brier") fail("bad header")
    next
}

{
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
        fail("invalid row")
    for (i = 12; i <= 34; i++) if (!number($i)) fail("invalid score")
    if (($10 && $11 != "none") || (!$10 && $11 == "none"))
        fail("eligibility reason mismatch")
    if (($3 == "primary" && ($4 < 36 || $4 > 40)) ||
        ($3 == "holdout" && ($4 < 75 || $4 > 80)))
        fail("invalid overflow identity")

    key = $2
    branch = key SUBSEP $5
    identity = branch SUBSEP $6 SUBSEP $7
    if (row_seen[identity]++) fail("duplicate score identity")
    if (!(key in life_seen)) {
        life_seen[key] = 1
        life_key[++life_count] = key
        cohort[key] = $1
        split_name[key] = $3
        candidate_order[key] = $4
        split_count[$3]++
    } else if (cohort[key] != $1 || split_name[key] != $3 ||
               candidate_order[key] != $4) fail("life identity drift")
    if (!(branch in branch_seen)) {
        branch_seen[branch] = 1
        branches[key]++
    }
    rows[key]++
    branch_rows[branch]++
    if (!$10) {
        branch_censored[branch]++
        if ($11 == "event") event_censored[key]++
        else if ($11 == "topology") topology_censored[key]++
        else if ($11 == "forecast") forecast_censored[key]++
        next
    }
    eligible[key]++
    branch_eligible[branch]++
    candidate_prior_ce[key] += $27
    candidate_prior_brier[key] += $28
    raw_prior_ce[key] += $31
    raw_prior_brier[key] += $32
    candidate_over_raw_ce[key] += $33
    candidate_over_raw_brier[key] += $34
}

END {
    if (fatal) exit 2
    if (life_count != expected_lives ||
        split_count["primary"] != expected_primary ||
        split_count["holdout"] != expected_holdout)
        fail("wrong population")
    print "cohort", "life", "split", "candidate_order", "branches", \
        "scored", "eligible", "event_censored", "topology_censored", \
        "forecast_censored", "candidate_prior_ce_gain", \
        "candidate_prior_brier_gain", "raw_prior_ce_gain", \
        "raw_prior_brier_gain", "candidate_over_raw_ce", \
        "candidate_over_raw_brier", "result"
    for (n = 1; n <= life_count; n++) {
        key = life_key[n]
        if (rows[key] != expected_rows_per_life ||
            branches[key] != expected_branches_per_life)
            fail("incomplete life " key)
        for (branch in branch_seen) {
            split(branch, part, SUBSEP)
            if (part[1] != key) continue
            if (branch_rows[branch] != expected_rows_per_branch ||
                branch_eligible[branch] < minimum_eligible_per_branch)
                fail("inadmissible branch " key "/" part[2])
        }
        if (!eligible[key]) fail("empty eligible life " key)
        candidate_ce_mean = candidate_prior_ce[key] / eligible[key]
        candidate_brier_mean = candidate_prior_brier[key] / eligible[key]
        result = candidate_ce_mean > 0 && candidate_brier_mean > 0 ? \
            "reader-positive" : "prior-better"
        printf "%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d", \
            cohort[key], key, split_name[key], candidate_order[key], \
            branches[key], rows[key], eligible[key], \
            event_censored[key] + 0, topology_censored[key] + 0, \
            forecast_censored[key] + 0
        printf "\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%s\n", \
            candidate_ce_mean, candidate_brier_mean, \
            raw_prior_ce[key] / eligible[key], \
            raw_prior_brier[key] / eligible[key], \
            candidate_over_raw_ce[key] / eligible[key], \
            candidate_over_raw_brier[key] / eligible[key], result
    }
}
