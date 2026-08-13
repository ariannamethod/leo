# A.103: nominate an episode reader on sealed balanced discovery lives only.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 12
    if (!policy_expected) policy_expected = 6
    if (!raw_win_required) raw_win_required = 8
    if (!snapshot_win_required) snapshot_win_required = 8
    if (!split_win_required) split_win_required = 3
    if (!ce_required) ce_required = 0.005
    if (!brier_required) brier_required = 0.001
    if (!snapshot_ce_required) snapshot_ce_required = 0.002
    if (!snapshot_brier_required) snapshot_brier_required = 0.0005
}

NR == 1 {
    if (NF != 28 || $1 != "candidate" || $5 != "cohort" ||
        $8 != "raw_life_wins" || $28 != "holdout_mean_snapshot_gain") fail()
    next
}

$5 == "discovery" {
    if (NF != 28 || seen[$1]++ || $6 != expected || $19 != expected / 2 ||
        $20 != expected / 2) fail()
    for (i = 10; i <= 18; i++) if (!number($i)) fail()
    rows++
    if ($8 >= raw_win_required && $9 >= snapshot_win_required &&
        $21 >= split_win_required && $22 >= split_win_required &&
        $23 >= split_win_required && $24 >= split_win_required &&
        $10 >= ce_required && $11 >= brier_required &&
        $12 >= snapshot_ce_required && $13 >= snapshot_brier_required &&
        $15 > 0 && $16 > 0 && $17 > 0 && $18 > 0 &&
        $25 > 0 && $26 > 0 && $27 > 0 && $28 > 0) {
        qualified++
        if (!selected || $10 > best_gain + 0.0000000005 ||
            ($10 >= best_gain - 0.0000000005 && $4 < best_rank)) {
            selected = $1; best_decay = $2; best_strength = $3; best_rank = $4
            best_raw_wins = $8; best_snapshot_wins = $9
            best_gain = $10; best_brier = $11
            best_snapshot_gain = $12; best_snapshot_brier = $13
            best_snapshot_raw = $14; best_home = $15; best_storm = $16
            best_wonder = $17; best_social = $18
        }
    }
}

END {
    if (fatal || rows != policy_expected) exit 2
    print "candidate", "decay", "strength", "rank", "discovery_lives", \
        "raw_life_wins", "snapshot_life_wins", "mean_raw_ce_gain", \
        "mean_raw_brier_gain", "mean_snapshot_ce_gain", "mean_snapshot_brier_gain", \
        "mean_snapshot_raw_ce_gain", "home_raw_ce_gain", "storm_raw_ce_gain", \
        "wonder_raw_ce_gain", "social_raw_ce_gain", "qualified_candidates", "result"
    if (selected)
        print selected, best_decay, best_strength, best_rank, expected, \
            best_raw_wins, best_snapshot_wins, best_gain, best_brier, \
            best_snapshot_gain, best_snapshot_brier, best_snapshot_raw, best_home, \
            best_storm, best_wonder, best_social, qualified, "candidate-nominated"
    else
        print "none", 0, 0, 0, expected, 0, 0, "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            0, "no-episode-memory-candidate"
}
