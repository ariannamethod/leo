# A.96: summarize each fixed readout candidate by sealed cohort.

function fail() { fatal = 1; exit 2 }
function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!discovery_expected) discovery_expected = 12
    if (!validation_expected) validation_expected = 15
}

NR == 1 {
    if (NF != 21 || $1 != "cohort" || $6 != "candidate" ||
        $16 != "raw_ce_gain" || $21 != "target_entropy") fail()
    next
}

{
    if (NF != 21 || $1 !~ /^(discovery|validation)$/ ||
        $3 !~ /^(event|ecology|organism)$/ || $5 !~ /^(primary|holdout)$/ ||
        $7 !~ /^(power|topk)$/ || !number($8) || !integer($9)) fail()
    for (i = 10; i <= 21; i++) if (!number($i)) fail()
    key = $6 SUBSEP $1
    identity = $2 SUBSEP $3
    if (seen[key SUBSEP identity]++) fail()
    if (!(key in kind)) {
        kind[key] = $7
        parameter[key] = $8
        rank[key] = $9
        candidate_order[++candidate_count] = key
    } else if (kind[key] != $7 || parameter[key] != $8 || rank[key] != $9) {
        fail()
    }
    arms[key]++
    split_arms[key SUBSEP $5]++
    raw_ce_gain[key] += $16
    raw_brier_gain[key] += $17
    destination_ce_gain[key] += $18
    destination_brier_gain[key] += $19
    split_ce_gain[key SUBSEP $5] += $16
    if ($16 > 0) ce_wins[key]++
    else if ($16 < 0) ce_losses[key]++
    else ce_ties[key]++
}

END {
    if (fatal) exit 2
    print "candidate", "kind", "parameter", "rank", "cohort", "arms", \
        "primary_arms", "holdout_arms", "ce_wins", "ce_losses", \
        "ce_ties", "mean_raw_ce_gain", "mean_raw_brier_gain", \
        "mean_destination_ce_gain", "mean_destination_brier_gain", \
        "primary_raw_ce_gain", "holdout_raw_ce_gain"
    for (n = 1; n <= candidate_count; n++) {
        key = candidate_order[n]
        split(key, part, SUBSEP)
        cohort = part[2]
        expected = cohort == "discovery" ? discovery_expected : validation_expected
        if (arms[key] != expected) fail()
        primary_n = split_arms[key SUBSEP "primary"] + 0
        holdout_n = split_arms[key SUBSEP "holdout"] + 0
        if ((cohort == "discovery" &&
             (primary_n != expected || holdout_n != 0)) ||
            (cohort == "validation" &&
             (!primary_n || !holdout_n || primary_n + holdout_n != expected)))
            fail()
        print part[1], kind[key], parameter[key], rank[key], cohort, arms[key], \
            primary_n, holdout_n, ce_wins[key] + 0, ce_losses[key] + 0, \
            ce_ties[key] + 0, sprintf("%.9f", raw_ce_gain[key] / arms[key]), \
            sprintf("%.9f", raw_brier_gain[key] / arms[key]), \
            sprintf("%.9f", destination_ce_gain[key] / arms[key]), \
            sprintf("%.9f", destination_brier_gain[key] / arms[key]), \
            sprintf("%.9f", split_ce_gain[key SUBSEP "primary"] / primary_n), \
            sprintf("%.9f", holdout_n ? split_ce_gain[key SUBSEP "holdout"] / holdout_n : 0)
    }
}
