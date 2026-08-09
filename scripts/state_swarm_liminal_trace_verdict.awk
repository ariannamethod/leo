# A.93: decide whether chronological trace carries selective evidence.

function fail() {
    fatal = 1
    exit 2
}

function integer(value) {
    return value ~ /^[0-9]+$/
}

function number(value) {
    return value ~ /^-?[0-9]+([.][0-9]+)?$/
}

BEGIN {
    FS = "\t"
    if (!expected) expected = 14
}

NR == 1 {
    if (NF != 21 || $1 != "pair" || $4 != "split" ||
        $10 != "event_confirmation" || $17 != "ecology_confirmation" ||
        $20 != "paired_max_stable_margin_delta" ||
        $21 != "paired_max_order_margin_delta") fail()
    next
}

{
    if (NF != 21 || $1 !~ /^[0-9][0-9]$/ || seen[$1]++ ||
        $4 !~ /^(primary|holdout)$/ || !integer($5) ||
        !integer($6) || !integer($7) || !integer($8) || !integer($9) ||
        $10 !~ /^(true|false)$/ || !number($11) || !number($12) ||
        !integer($13) || !integer($14) || !integer($15) || !integer($16) ||
        $17 !~ /^(true|false)$/ || !number($18) || !number($19) ||
        !number($20) || !number($21)) fail()
    event_confirmation += $10 == "true"
    ecology_confirmation += $17 == "true"
    event_only += $10 == "true" && $17 == "false"
    ecology_only += $10 == "false" && $17 == "true"
    event_support += $6
    ecology_support += $13
    event_order_wins += $9
    ecology_order_wins += $16
    stable_delta += $20
    order_delta += $21
    if ($10 == "true") split_confirmation[$4]++
    split_total[$4]++
    rows++
}

END {
    if (fatal) exit 2
    if (rows != expected || !split_total["primary"] ||
        !split_total["holdout"]) fail()
    mean_stable = stable_delta / rows
    mean_order = order_delta / rows
    if (event_confirmation == 0)
        result = "no-directional-trace-confirmation"
    else if (event_confirmation * 100 >= expected * 87 &&
             ecology_confirmation * 100 >= expected * 87)
        result = "trace-delay-without-selection"
    else if (event_confirmation >= 4 &&
             split_confirmation["primary"] > 0 &&
             split_confirmation["holdout"] > 0 &&
             event_only >= ecology_only + 2 &&
             mean_stable >= 0.01 && mean_order >= 0.01)
        result = "selective-directional-trace"
    else if (event_confirmation >= 4)
        result = "directional-trace-not-distinguished"
    else
        result = "directional-trace-underpowered"

    print "eligible_pairs " rows
    print "primary_pairs " split_total["primary"]
    print "holdout_pairs " split_total["holdout"]
    print "event_support_hits " event_support
    print "ecology_support_hits " ecology_support
    print "event_order_wins " event_order_wins
    print "ecology_order_wins " ecology_order_wins
    print "event_confirmation " event_confirmation
    print "ecology_confirmation " ecology_confirmation
    print "event_only_confirmation " event_only
    print "ecology_only_confirmation " ecology_only
    print "mean_paired_max_stable_margin_delta " sprintf("%.6f", mean_stable)
    print "mean_paired_max_order_margin_delta " sprintf("%.6f", mean_order)
    print "result " result
}
