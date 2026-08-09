# A.97: test the frozen discovery threshold on untouched validation controls.

function fail() { fatal = 1; exit 2 }
function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = "\t"
    if (!expected) expected = 15
    if (!accepted_min) accepted_min = 4
    if (!accepted_max) accepted_max = 11
    if (!gain_required) gain_required = 0.015
    if (!separation_required) separation_required = 0.010
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 12 || $1 != "feature" || $12 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 12) fail()
    selected = $1
    selected_kind = $2
    selected_rank = $3
    threshold = $4 + 0
    discovery_arms = $5
    discovery_high = $6
    discovery_wins = $7
    discovery_high_gain = $8
    discovery_low_gain = $9
    discovery_separation = $10
    qualified = $11
    selection_result = $12
    next
}

FNR == 1 {
    if (NF != 14 || $1 != "cohort" || $6 != "feature" ||
        $9 != "authority_score" || $14 != "target_entropy") fail()
    next
}

$1 == "validation" && $6 == selected {
    if (NF != 14 || seen[$2]++ || $3 != "organism" ||
        $5 !~ /^(primary|holdout)$/ || $7 != selected_kind ||
        $8 != selected_rank || !number($9) || !number($10)) fail()
    validation_rows++
    value = $10 + 0
    if (($9 + 0) >= threshold) {
        accepted++
        accepted_sum += value
        if (value > 0) accepted_wins++
        if ($5 == "primary") {
            accepted_primary++
            accepted_primary_sum += value
        } else {
            accepted_holdout++
            accepted_holdout_sum += value
        }
    } else {
        rejected++
        rejected_sum += value
    }
}

END {
    if (fatal) exit 2
    if (selection_rows != 1) fail()
    if (selection_result == "no-row-authority-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-row-authority-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != expected || !rejected) fail()
        accepted_mean = accepted ? accepted_sum / accepted : 0
        rejected_mean = rejected_sum / rejected
        validation_separation = accepted_mean - rejected_mean
        primary_mean = accepted_primary ? accepted_primary_sum / accepted_primary : 0
        holdout_mean = accepted_holdout ? accepted_holdout_sum / accepted_holdout : 0
        wins_required = int((2 * accepted + 2) / 3)
        if (accepted >= accepted_min && accepted <= accepted_max &&
            accepted_wins >= wins_required && accepted_mean >= gain_required &&
            validation_separation >= separation_required &&
            accepted_primary && accepted_holdout &&
            primary_mean > 0 && holdout_mean > 0)
            result = "row-authority-supported"
        else
            result = "row-authority-not-confirmed"
    }

    print "selected_feature " selected
    print "selected_kind " selected_kind
    print "selected_rank " selected_rank
    print "threshold " sprintf("%.9f", threshold)
    print "qualified_discovery_features " qualified
    print "discovery_arms " discovery_arms
    print "discovery_high_arms " discovery_high
    print "discovery_high_wins " discovery_wins
    print "discovery_high_mean_gain " discovery_high_gain
    print "discovery_low_mean_gain " discovery_low_gain
    print "discovery_separation " discovery_separation
    print "validation_arms " validation_rows + 0
    print "validation_accepted " accepted + 0
    print "validation_rejected " rejected + 0
    print "validation_accepted_wins " accepted_wins + 0
    print "validation_required_wins " wins_required + 0
    print "validation_accepted_mean_gain " sprintf("%.9f", accepted_mean + 0)
    print "validation_rejected_mean_gain " sprintf("%.9f", rejected_mean + 0)
    print "validation_separation " sprintf("%.9f", validation_separation + 0)
    print "validation_accepted_primary " accepted_primary + 0
    print "validation_accepted_holdout " accepted_holdout + 0
    print "validation_primary_mean_gain " sprintf("%.9f", primary_mean + 0)
    print "validation_holdout_mean_gain " sprintf("%.9f", holdout_mean + 0)
    print "required_accepted_min " accepted_min
    print "required_accepted_max " accepted_max
    print "required_mean_gain " sprintf("%.9f", gain_required)
    print "required_separation " sprintf("%.9f", separation_required)
    print "result " result
}
