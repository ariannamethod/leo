# A.95: classify conditional road information without tuning on the result.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }

BEGIN {
    FS = "\t"
    if (!expected) expected = 30
    if (!win_required) win_required = 24
    if (!ce_required) ce_required = 0.02
    if (!brier_required) brier_required = 0.001
    if (!mi_required) mi_required = 0.01
    if (!equiv_ce) equiv_ce = 0.01
    if (!equiv_brier) equiv_brier = 0.002
    if (!equiv_mi) equiv_mi = 0.02
    if (!equiv_split_ce) equiv_split_ce = 0.015
}

NR == 1 {
    if (NF != 22 || $1 != "pair" || $2 != "arm" || $5 != "split" ||
        $15 != "destination_ce_gain" || $19 != "normalized_mi") fail()
    next
}

{
    if (NF != 22 || $1 !~ /^[0-9][0-9]$/ ||
        $2 !~ /^(event|ecology)$/ || seen[$1 SUBSEP $2]++ ||
        $5 !~ /^(primary|holdout)$/) fail()
    for (i = 6; i <= 22; i++) if (!number($i)) fail()
    ce_gain += $15
    brier_gain += $16
    uniform_ce_gain += $17
    uniform_brier_gain += $18
    nmi += $19
    tv += $20
    destination_entropy += $21
    target_entropy += $22
    split_ce[$5] += $15
    split_n[$5]++
    if ($15 > 0) ce_wins++
    else if ($15 < 0) ce_losses++
    else ce_ties++
    if ($16 > 0) brier_wins++
    rows++
}

END {
    if (fatal) exit 2
    if (rows != expected || !split_n["primary"] || !split_n["holdout"])
        fail()
    mean_ce = ce_gain / rows
    mean_brier = brier_gain / rows
    mean_nmi = nmi / rows
    primary_ce = split_ce["primary"] / split_n["primary"]
    holdout_ce = split_ce["holdout"] / split_n["holdout"]
    if (ce_wins >= win_required && mean_ce >= ce_required &&
        mean_brier >= brier_required && primary_ce > 0 && holdout_ce > 0 &&
        mean_nmi >= mi_required)
        result = "conditional-road-supported"
    else if (abs(mean_ce) <= equiv_ce && abs(mean_brier) <= equiv_brier &&
             mean_nmi <= equiv_mi && abs(primary_ce) <= equiv_split_ce &&
             abs(holdout_ce) <= equiv_split_ce)
        result = "destination-prior-equivalent"
    else
        result = "conditional-road-unresolved"

    print "eligible_arms " rows
    print "primary_arms " split_n["primary"]
    print "holdout_arms " split_n["holdout"]
    print "conditional_ce_wins " ce_wins + 0
    print "conditional_ce_losses " ce_losses + 0
    print "conditional_ce_ties " ce_ties + 0
    print "conditional_brier_wins " brier_wins + 0
    print "mean_destination_ce_gain " sprintf("%.9f", mean_ce)
    print "mean_destination_brier_gain " sprintf("%.9f", mean_brier)
    print "mean_uniform_ce_gain " sprintf("%.9f", uniform_ce_gain / rows)
    print "mean_uniform_brier_gain " sprintf("%.9f", uniform_brier_gain / rows)
    print "primary_destination_ce_gain " sprintf("%.9f", primary_ce)
    print "holdout_destination_ce_gain " sprintf("%.9f", holdout_ce)
    print "mean_normalized_mi " sprintf("%.9f", mean_nmi)
    print "mean_row_tv " sprintf("%.9f", tv / rows)
    print "mean_destination_entropy " sprintf("%.9f", destination_entropy / rows)
    print "mean_target_entropy " sprintf("%.9f", target_entropy / rows)
    print "required_ce_wins " win_required
    print "required_mean_ce_gain " sprintf("%.9f", ce_required)
    print "required_mean_brier_gain " sprintf("%.9f", brier_required)
    print "required_mean_normalized_mi " sprintf("%.9f", mi_required)
    print "result " result
}
