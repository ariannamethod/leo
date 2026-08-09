# A.96: nominate one readout using discovery only.

function fail() { fatal = 1; exit 2 }
function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 12
    if (!win_required) win_required = 8
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.000000001
    if (!destination_required) destination_required = 0.015
    if (!candidate_expected) candidate_expected = 8
}

NR == 1 {
    if (NF != 17 || $1 != "candidate" || $5 != "cohort" ||
        $9 != "ce_wins" || $12 != "mean_raw_ce_gain") fail()
    next
}

$5 == "discovery" {
    if (NF != 17 || seen[$1]++ || $2 !~ /^(power|topk)$/ ||
        !number($3) || !integer($4) || $6 != expected ||
        $7 != expected || $8 != 0) fail()
    for (i = 9; i <= 17; i++) if (!number($i)) fail()
    rows++
    if ($9 >= win_required && $12 >= ce_required &&
        $13 >= brier_required && $14 >= destination_required) {
        if (!qualified || $12 > best_gain + 0.0000000005 ||
            ($12 >= best_gain - 0.0000000005 && $4 < best_rank)) {
            best_candidate = $1
            best_kind = $2
            best_parameter = $3
            best_rank = $4
            best_arms = $6
            best_wins = $9
            best_gain = $12
            best_brier = $13
            best_destination = $14
        }
        qualified++
    }
}

END {
    if (fatal) exit 2
    if (rows != candidate_expected) fail()
    print "candidate", "kind", "parameter", "rank", "discovery_arms", \
        "discovery_ce_wins", "discovery_mean_raw_ce_gain", \
        "discovery_mean_raw_brier_gain", \
        "discovery_mean_destination_ce_gain", "qualified_candidates", "result"
    if (qualified)
        print best_candidate, best_kind, best_parameter, best_rank, best_arms, \
            best_wins, best_gain, best_brier, best_destination, qualified, \
            "candidate-nominated"
    else
        print "none", "none", 0, 0, expected, 0, "0.000000000", \
            "0.000000000", "0.000000000", 0, \
            "no-primary-readout-candidate"
}
