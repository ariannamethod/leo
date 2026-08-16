# A.109: nominate an unexpected outcome receipt only when it beats the full signed-path control.

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
    if (!symmetric_ce_required) symmetric_ce_required = 0.001
    if (!symmetric_brier_required) symmetric_brier_required = 0.00025
    if (!path_ce_required) path_ce_required = 0.001
    if (!path_brier_required) path_brier_required = 0.00025
}

NR == 1 {
    if (NF != 50 || $1 != "candidate" || $4 != "cohort" ||
        $7 != "raw_life_wins" || $50 != "holdout_mean_path_gain") fail()
    next
}

$4 == "discovery" {
    if (NF != 50 || seen[$1]++ || $5 != expected || $29 != expected / 2 ||
        $30 != expected / 2) fail()
    for (i = 6; i <= 50; i++) if (!number($i)) fail()
    rows++
    if ($7 >= life_win_required && $8 >= life_win_required &&
        $9 >= life_win_required && $10 >= life_win_required &&
        $11 >= life_win_required &&
        $31 >= split_win_required && $32 >= split_win_required &&
        $33 >= split_win_required && $34 >= split_win_required &&
        $35 >= split_win_required && $36 >= split_win_required &&
        $37 >= split_win_required && $38 >= split_win_required &&
        $39 >= split_win_required && $40 >= split_win_required &&
        $12 >= raw_ce_required && $13 >= raw_brier_required &&
        $14 >= snapshot_ce_required && $15 >= snapshot_brier_required &&
        $16 >= texture_ce_required && $17 >= texture_brier_required &&
        $18 >= symmetric_ce_required && $19 >= symmetric_brier_required &&
        $20 >= path_ce_required && $21 >= path_brier_required &&
        $25 > 0 && $26 > 0 && $27 > 0 && $28 > 0 &&
        $41 > 0 && $42 > 0 && $43 > 0 && $44 > 0 &&
        $45 > 0 && $46 > 0 && $47 > 0 && $48 > 0 &&
        $49 > 0 && $50 > 0) {
        qualified++
        if (!selected || $20 > best_gain + 0.0000000005 ||
            ($20 >= best_gain - 0.0000000005 && $3 < best_rank)) {
            selected = $1; best_strength = $2; best_rank = $3
            best_lives = $5; best_receipts = $6
            best_raw_wins = $7; best_snapshot_wins = $8
            best_texture_wins = $9; best_symmetric_wins = $10
            best_path_wins = $11
            best_raw_gain = $12; best_raw_brier = $13
            best_snapshot_gain = $14; best_snapshot_brier = $15
            best_texture_gain = $16; best_texture_brier = $17
            best_symmetric_gain = $18; best_symmetric_brier = $19
            best_gain = $20; best_brier = $21
            best_snapshot_raw = $22; best_texture_snapshot = $23
            best_path_symmetric = $24
            best_home = $25; best_storm = $26; best_wonder = $27; best_social = $28
        }
    }
}

END {
    if (fatal || rows != policy_expected) exit 2
    print "candidate", "strength", "rank", "discovery_lives", \
        "discovery_receipts", "raw_life_wins", "snapshot_life_wins", \
        "texture_life_wins", "symmetric_life_wins", "path_life_wins", \
        "mean_raw_ce_gain", \
        "mean_raw_brier_gain", "mean_snapshot_ce_gain", \
        "mean_snapshot_brier_gain", "mean_texture_ce_gain", \
        "mean_texture_brier_gain", "mean_symmetric_ce_gain", \
        "mean_symmetric_brier_gain", "mean_path_ce_gain", \
        "mean_path_brier_gain", "mean_snapshot_raw_ce_gain", \
        "mean_texture_snapshot_ce_gain", "mean_path_symmetric_ce_gain", \
        "home_receipt_ce_gain", \
        "storm_receipt_ce_gain", "wonder_receipt_ce_gain", \
        "social_receipt_ce_gain", "qualified_candidates", "result"
    if (selected)
        print selected, best_strength, best_rank, best_lives, best_receipts, \
            best_raw_wins, best_snapshot_wins, best_texture_wins, \
            best_symmetric_wins, best_path_wins, best_raw_gain, best_raw_brier, \
            best_snapshot_gain, best_snapshot_brier, best_texture_gain, \
            best_texture_brier, best_symmetric_gain, best_symmetric_brier, \
            best_gain, best_brier, best_snapshot_raw, \
            best_texture_snapshot, best_path_symmetric, best_home, best_storm, best_wonder, \
            best_social, qualified, "candidate-nominated"
    else
        print "none", 0, 0, expected, 0, 0, 0, 0, 0, 0, \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", "0.000000000", "0.000000000", "0.000000000", \
            "0.000000000", 0, "no-independent-delayed-outcome-receipt-candidate"
}
