# A.94: decide whether crossings expose graph aliasing that controls do not.

function fail() {
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = "\t"
    if (!expected) expected = 15
    if (!sign_required) sign_required = 12
    if (!mean_required) mean_required = 0.01
}

NR == 1 {
    if (NF != 23 || $1 != "pair" || $4 != "split" ||
        $9 != "event_transition_debt" || $16 != "ecology_transition_debt" ||
        $20 != "paired_transition_debt_delta" ||
        $22 != "paired_joint_debt_delta") fail()
    next
}

{
    if (NF != 23 || $1 !~ /^[0-9][0-9]$/ || seen[$1]++ ||
        $4 !~ /^(primary|holdout)$/ || !integer($5)) fail()
    for (i = 6; i <= 23; i++) if (!number($i)) fail()
    transition_delta += $20
    outcome_delta += $21
    joint_delta += $22
    arrow_delta += $23
    split_joint[$4] += $22
    split_total[$4]++
    if ($22 > 0) joint_positive++
    else if ($22 < 0) joint_negative++
    else joint_tie++
    if ($6 <= 0) event_no_prediction++
    if ($13 <= 0) ecology_no_prediction++
    rows++
}

END {
    if (fatal) exit 2
    if (rows != expected || !split_total["primary"] ||
        !split_total["holdout"]) fail()
    mean_transition = transition_delta / rows
    mean_outcome = outcome_delta / rows
    mean_joint = joint_delta / rows
    mean_arrow = arrow_delta / rows
    primary_joint = split_joint["primary"] / split_total["primary"]
    holdout_joint = split_joint["holdout"] / split_total["holdout"]
    if (joint_positive >= sign_required && mean_joint >= mean_required &&
        mean_transition > 0 && mean_outcome > 0 &&
        primary_joint > 0 && holdout_joint > 0)
        result = "crossing-specific-transition-consequence-debt"
    else
        result = "transition-consequence-debt-not-distinguished"

    print "eligible_pairs " rows
    print "primary_pairs " split_total["primary"]
    print "holdout_pairs " split_total["holdout"]
    print "joint_delta_positive " joint_positive + 0
    print "joint_delta_negative " joint_negative + 0
    print "joint_delta_tie " joint_tie + 0
    print "event_no_prediction " event_no_prediction + 0
    print "ecology_no_prediction " ecology_no_prediction + 0
    print "mean_paired_transition_debt_delta " sprintf("%.6f", mean_transition)
    print "mean_paired_outcome_mae_delta " sprintf("%.6f", mean_outcome)
    print "mean_paired_joint_debt_delta " sprintf("%.6f", mean_joint)
    print "mean_paired_arrow_margin_delta " sprintf("%.6f", mean_arrow)
    print "primary_mean_joint_debt_delta " sprintf("%.6f", primary_joint)
    print "holdout_mean_joint_debt_delta " sprintf("%.6f", holdout_joint)
    print "required_positive " sign_required
    print "required_mean_joint_delta " sprintf("%.6f", mean_required)
    print "result " result
}
