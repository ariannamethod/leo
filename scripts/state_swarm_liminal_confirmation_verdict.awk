# A.92: classify whether a second lived turn can selectively confirm a crossing.

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
    if (!expected) expected = 15
}

NR == 1 {
    if (NF != 20 || $1 != "pair" || $4 != "split" ||
        $8 != "event_support" || $9 != "event_confirmation" ||
        $14 != "ecology_support" || $15 != "ecology_confirmation" ||
        $20 != "paired_max_margin_delta") fail()
    next
}

{
    if (NF != 20 || $1 !~ /^[0-9][0-9]$/ || seen[$1]++ ||
        $4 !~ /^(primary|holdout)$/ || !integer($5) ||
        !integer($6) || !integer($7) ||
        $8 !~ /^(true|false)$/ || $9 !~ /^(true|false)$/ ||
        $14 !~ /^(true|false)$/ || $15 !~ /^(true|false)$/ ||
        !number($12) || !number($13) || !number($18) ||
        !number($19) || !number($20)) fail()
    event_support += $8 == "true"
    event_confirmation += $9 == "true"
    ecology_support += $14 == "true"
    ecology_confirmation += $15 == "true"
    event_only += $9 == "true" && $15 == "false"
    ecology_only += $9 == "false" && $15 == "true"
    if ($20 + 0 > 0) margin_wins++
    margin_delta += $20
    if ($9 == "true") split_confirmation[$4]++
    split_total[$4]++
    rows++
}

END {
    if (fatal) exit 2
    if (rows != expected || !split_total["primary"] ||
        !split_total["holdout"]) fail()
    if (event_confirmation == 0)
        result = "no-temporal-confirmation"
    else if (event_confirmation * 100 >= expected * 87)
        result = "delay-without-selection"
    else if (event_confirmation >= 4 &&
             split_confirmation["primary"] > 0 &&
             split_confirmation["holdout"] > 0)
        result = "selective-temporal-confirmation"
    else
        result = "temporal-confirmation-underpowered"

    print "eligible_pairs " rows
    print "primary_pairs " split_total["primary"]
    print "holdout_pairs " split_total["holdout"]
    print "event_support " event_support
    print "ecology_support " ecology_support
    print "event_confirmation " event_confirmation
    print "ecology_confirmation " ecology_confirmation
    print "event_only_confirmation " event_only
    print "ecology_only_confirmation " ecology_only
    print "event_margin_wins " margin_wins
    print "mean_paired_max_margin_delta " sprintf("%.6f", margin_delta / rows)
    print "result " result
}
