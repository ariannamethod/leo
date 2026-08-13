# A.105: nominate an ending only when it beats every matched control.

function fail() { fatal = 1; exit 2 }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 10
    if (!policy_expected) policy_expected = 2
    if (!life_win_required) life_win_required = 7
    if (!split_win_required) split_win_required = 3
    if (!raw_ce_required) raw_ce_required = 0.005
    if (!raw_brier_required) raw_brier_required = 0.001
    if (!snapshot_ce_required) snapshot_ce_required = 0.002
    if (!snapshot_brier_required) snapshot_brier_required = 0.0005
    if (!texture_ce_required) texture_ce_required = 0.001
    if (!texture_brier_required) texture_brier_required = 0.00025
    if (!unordered_ce_required) unordered_ce_required = 0.001
    if (!unordered_brier_required) unordered_brier_required = 0.00025
}

NR == 1 {
    if (NF != 42 || $1 != "candidate" || $4 != "cohort" ||
        $7 != "raw_life_wins" || $42 != "holdout_mean_unordered_gain") fail()
    next
}

$4 == "discovery" {
    if (NF != 42 || seen[$1]++ || $5 != expected || $25 != expected / 2 ||
        $26 != expected / 2) fail()
    for (i = 6; i <= 42; i++) if (!number($i)) fail()
    rows++
    if ($7 >= life_win_required && $8 >= life_win_required &&
        $9 >= life_win_required && $10 >= life_win_required &&
        $27 >= split_win_required && $28 >= split_win_required &&
        $29 >= split_win_required && $30 >= split_win_required &&
        $31 >= split_win_required && $32 >= split_win_required &&
        $33 >= split_win_required && $34 >= split_win_required &&
        $11 >= raw_ce_required && $12 >= raw_brier_required &&
        $13 >= snapshot_ce_required && $14 >= snapshot_brier_required &&
        $15 >= texture_ce_required && $16 >= texture_brier_required &&
        $17 >= unordered_ce_required && $18 >= unordered_brier_required &&
        $21 > 0 && $22 > 0 && $23 > 0 && $24 > 0 &&
        $35 > 0 && $36 > 0 && $37 > 0 && $38 > 0 &&
        $39 > 0 && $40 > 0 && $41 > 0 && $42 > 0) {
        qualified++
        if (!selected || $17 > best_gain + 0.0000000005 ||
            ($17 >= best_gain - 0.0000000005 && $3 < best_rank)) {
            selected = $1; best_strength = $2; best_rank = $3
            best_lives = $5; best_episodes = $6
            best_raw_wins = $7; best_snapshot_wins = $8
            best_texture_wins = $9; best_unordered_wins = $10
            best_raw_gain = $11; best_raw_brier = $12
            best_snapshot_gain = $13; best_snapshot_brier = $14
            best_texture_gain = $15; best_texture_brier = $16
            best_gain = $17; best_brier = $18
            best_snapshot_raw = $19; best_texture_snapshot = $20
            best_home = $21; best_storm = $22; best_wonder = $23; best_social = $24
        }
    }
}

END {
    if (fatal || rows != policy_expected) exit 2
    print "candidate", "strength", "rank", "discovery_lives", \
        "discovery_episodes", "raw_life_wins", "snapshot_life_wins", \
        "texture_life_wins", "unordered_life_wins", "mean_raw_ce_gain", \
        "mean_raw_brier_gain", "mean_snapshot_ce_gain", \
        "mean_snapshot_brier_gain", "mean_texture_ce_gain", \
        "mean_texture_brier_gain", "mean_unordered_ce_gain", \
        "mean_unordered_brier_gain", "mean_snapshot_raw_ce_gain", \
        "mean_texture_snapshot_ce_gain", "home_consequence_ce_gain", \
        "storm_consequence_ce_gain", "wonder_consequence_ce_gain", \
        "social_consequence_ce_gain", "qualified_candidates", "result"
    if (selected)
        print selected, best_strength, best_rank, best_lives, best_episodes, \
            best_raw_wins, best_snapshot_wins, best_texture_wins, \
            best_unordered_wins, best_raw_gain, best_raw_brier, \
            best_snapshot_gain, best_snapshot_brier, best_texture_gain, \
            best_texture_brier, best_gain, best_brier, best_snapshot_raw, \
            best_texture_snapshot, best_home, best_storm, best_wonder, \
            best_social, qualified, "candidate-nominated"
    else
        print "none", 0, 0, expected, 0, 0, 0, 0, 0, "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", 0, "no-episode-consequence-candidate"
}
