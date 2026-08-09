# A.96: confirm the primary-selected readout on unused organism controls.

function fail() { fatal = 1; exit 2 }
function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = "\t"
    if (!expected) expected = 15
    if (!win_required) win_required = 10
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!destination_required) destination_required = 0.015
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 11 || $1 != "candidate" || $11 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++) fail()
    selected = $1
    selected_kind = $2
    selected_parameter = $3
    selected_rank = $4
    discovery_arms = $5
    discovery_wins = $6
    discovery_gain = $7
    discovery_brier = $8
    discovery_destination = $9
    qualified = $10
    selection_result = $11
    next
}

FNR == 1 {
    if (NF != 17 || $1 != "candidate" || $5 != "cohort" ||
        $17 != "holdout_raw_ce_gain") fail()
    next
}

$5 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 17 || $2 != selected_kind ||
        $3 != selected_parameter || $4 != selected_rank || $6 != expected ||
        !integer($9)) fail()
    validation_arms = $6
    primary_arms = $7
    holdout_arms = $8
    validation_wins = $9
    validation_gain = $12
    validation_brier = $13
    validation_destination = $14
    validation_destination_brier = $15
    primary_gain = $16
    holdout_gain = $17
}

END {
    if (fatal) exit 2
    if (selection_rows != 1) fail()
    if (selection_result == "no-primary-readout-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-primary-readout-candidate"
    } else {
        if (selection_result != "candidate-nominated" ||
            selected == "none" || validation_rows != 1 ||
            !primary_arms || !holdout_arms) fail()
        if (validation_wins >= win_required && validation_gain >= ce_required &&
            validation_brier >= brier_required &&
            validation_destination >= destination_required &&
            primary_gain > 0 && holdout_gain > 0)
            result = "readout-dilution-supported"
        else
            result = "readout-sharpening-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_kind " selected_kind
    print "selected_parameter " selected_parameter
    print "qualified_discovery_candidates " qualified
    print "discovery_arms " discovery_arms
    print "discovery_ce_wins " discovery_wins
    print "discovery_mean_raw_ce_gain " discovery_gain
    print "discovery_mean_raw_brier_gain " discovery_brier
    print "discovery_mean_destination_ce_gain " discovery_destination
    print "validation_arms " validation_arms + 0
    print "validation_primary_arms " primary_arms + 0
    print "validation_holdout_arms " holdout_arms + 0
    print "validation_ce_wins " validation_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", validation_gain + 0)
    print "validation_mean_raw_brier_gain " sprintf("%.9f", validation_brier + 0)
    print "validation_mean_destination_ce_gain " sprintf("%.9f", validation_destination + 0)
    print "validation_primary_raw_ce_gain " sprintf("%.9f", primary_gain + 0)
    print "validation_holdout_raw_ce_gain " sprintf("%.9f", holdout_gain + 0)
    print "required_validation_ce_wins " win_required
    print "required_validation_mean_raw_ce_gain " sprintf("%.9f", ce_required)
    print "required_validation_mean_raw_brier_gain " sprintf("%.9f", brier_required)
    print "required_validation_mean_destination_ce_gain " sprintf("%.9f", destination_required)
    print "result " result
}
