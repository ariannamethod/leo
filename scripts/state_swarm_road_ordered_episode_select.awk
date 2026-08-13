# A.104: nominate temporal direction only when it beats its unordered control.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 12
    if (!policy_expected) policy_expected = 6
    if (!raw_win_required) raw_win_required = 8
    if (!snapshot_win_required) snapshot_win_required = 8
    if (!unordered_win_required) unordered_win_required = 8
    if (!split_win_required) split_win_required = 3
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!snapshot_ce_required) snapshot_ce_required = 0.002
    if (!snapshot_brier_required) snapshot_brier_required = 0.0005
    if (!unordered_ce_required) unordered_ce_required = 0.001
    if (!unordered_brier_required) unordered_brier_required = 0.00025
}

NR == 1 {
    if (NF != 35 || $1 != "candidate" || $5 != "cohort" ||
        $8 != "raw_life_wins" || $35 != "holdout_mean_unordered_gain") fail()
    next
}

$5 == "discovery" {
    if (NF != 35 || seen[$1]++ || $6 != expected || $22 != expected / 2 ||
        $23 != expected / 2) fail()
    for (i = 11; i <= 21; i++) if (!number($i)) fail()
    rows++
    if ($8 >= raw_win_required && $9 >= snapshot_win_required &&
        $10 >= unordered_win_required &&
        $24 >= split_win_required && $25 >= split_win_required &&
        $26 >= split_win_required && $27 >= split_win_required &&
        $28 >= split_win_required && $29 >= split_win_required &&
        $11 >= ce_required && $12 >= brier_required &&
        $13 >= snapshot_ce_required && $14 >= snapshot_brier_required &&
        $15 >= unordered_ce_required && $16 >= unordered_brier_required &&
        $18 > 0 && $19 > 0 && $20 > 0 && $21 > 0 &&
        $30 > 0 && $31 > 0 && $32 > 0 && $33 > 0 && $34 > 0 && $35 > 0) {
        qualified++
        if (!selected || $15 > best_order_gain + 0.0000000005 ||
            ($15 >= best_order_gain - 0.0000000005 && $4 < best_rank)) {
            selected = $1; best_decay = $2; best_strength = $3; best_rank = $4
            best_raw_wins = $8; best_snapshot_wins = $9; best_unordered_wins = $10
            best_gain = $11; best_brier = $12
            best_snapshot_gain = $13; best_snapshot_brier = $14
            best_order_gain = $15; best_order_brier = $16
            best_snapshot_raw = $17; best_home = $18; best_storm = $19
            best_wonder = $20; best_social = $21
        }
    }
}

END {
    if (fatal || rows != policy_expected) exit 2
    print "candidate", "decay", "strength", "rank", "discovery_lives", \
        "raw_life_wins", "snapshot_life_wins", "unordered_life_wins", \
        "mean_raw_ce_gain", "mean_raw_brier_gain", "mean_snapshot_ce_gain", \
        "mean_snapshot_brier_gain", "mean_unordered_ce_gain", \
        "mean_unordered_brier_gain", "mean_snapshot_raw_ce_gain", \
        "home_order_ce_gain", "storm_order_ce_gain", "wonder_order_ce_gain", \
        "social_order_ce_gain", "qualified_candidates", "result"
    if (selected)
        print selected, best_decay, best_strength, best_rank, expected, \
            best_raw_wins, best_snapshot_wins, best_unordered_wins, best_gain, \
            best_brier, best_snapshot_gain, best_snapshot_brier, best_order_gain, \
            best_order_brier, best_snapshot_raw, best_home, best_storm, \
            best_wonder, best_social, qualified, "candidate-nominated"
    else
        print "none", 0, 0, 0, expected, 0, 0, 0, "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", 0, "no-ordered-path-candidate"
}
