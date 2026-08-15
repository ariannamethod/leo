# A.108: confirm one frozen boundary receipt beyond a full signed-path control.

function fail() { fatal = 1; exit 2 }

BEGIN {
    FS = "\t"
    if (!expected) expected = 32
    if (!life_win_required) life_win_required = 22
    if (!split_win_required) split_win_required = 10
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

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 29 || $1 != "candidate" || $29 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 29) fail()
    selected = $1; selected_strength = $2; selected_rank = $3
    discovery_lives = $4; discovery_receipts = $5
    discovery_raw_wins = $6; discovery_snapshot_wins = $7
    discovery_texture_wins = $8; discovery_symmetric_wins = $9
    discovery_path_wins = $10
    discovery_raw_gain = $11; discovery_raw_brier = $12
    discovery_snapshot_gain = $13; discovery_snapshot_brier = $14
    discovery_texture_gain = $15; discovery_texture_brier = $16
    discovery_symmetric_gain = $17; discovery_symmetric_brier = $18
    discovery_path_gain = $19; discovery_path_brier = $20
    qualified = $28; selection_result = $29
    next
}

FNR == 1 {
    if (NF != 50 || $1 != "candidate" || $4 != "cohort" ||
        $50 != "holdout_mean_path_gain") fail()
    next
}

$4 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 50 || $2 != selected_strength ||
        $3 != selected_rank || $5 != expected ||
        $29 != expected / 2 || $30 != expected / 2) fail()
    validation_lives = $5; validation_receipts = $6
    raw_wins = $7; snapshot_wins = $8; texture_wins = $9
    symmetric_wins = $10; path_wins = $11
    raw_gain = $12; raw_brier = $13; snapshot_gain = $14; snapshot_brier = $15
    texture_gain = $16; texture_brier = $17; symmetric_gain = $18; symmetric_brier = $19
    path_gain = $20; path_brier = $21
    snapshot_raw = $22; texture_snapshot = $23; path_symmetric = $24
    home_gain = $25; storm_gain = $26; wonder_gain = $27; social_gain = $28
    primary_raw_wins = $31; holdout_raw_wins = $32
    primary_snapshot_wins = $33; holdout_snapshot_wins = $34
    primary_texture_wins = $35; holdout_texture_wins = $36
    primary_symmetric_wins = $37; holdout_symmetric_wins = $38
    primary_path_wins = $39; holdout_path_wins = $40
    primary_raw = $41; holdout_raw = $42
    primary_snapshot = $43; holdout_snapshot = $44
    primary_texture = $45; holdout_texture = $46
    primary_symmetric = $47; holdout_symmetric = $48
    primary_path = $49; holdout_path = $50
}

END {
    if (fatal || selection_rows != 1) exit 2
    if (selection_result == "no-independent-delayed-receipt-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-independent-delayed-receipt-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (raw_wins >= life_win_required && snapshot_wins >= life_win_required &&
            texture_wins >= life_win_required && symmetric_wins >= life_win_required &&
            path_wins >= life_win_required &&
            primary_raw_wins >= split_win_required && holdout_raw_wins >= split_win_required &&
            primary_snapshot_wins >= split_win_required && holdout_snapshot_wins >= split_win_required &&
            primary_texture_wins >= split_win_required && holdout_texture_wins >= split_win_required &&
            primary_symmetric_wins >= split_win_required && holdout_symmetric_wins >= split_win_required &&
            primary_path_wins >= split_win_required && holdout_path_wins >= split_win_required &&
            raw_gain >= raw_ce_required && raw_brier >= raw_brier_required &&
            snapshot_gain >= snapshot_ce_required && snapshot_brier >= snapshot_brier_required &&
            texture_gain >= texture_ce_required && texture_brier >= texture_brier_required &&
            symmetric_gain >= symmetric_ce_required && symmetric_brier >= symmetric_brier_required &&
            path_gain >= path_ce_required && path_brier >= path_brier_required &&
            home_gain > 0 && storm_gain > 0 && wonder_gain > 0 && social_gain > 0 &&
            primary_raw > 0 && holdout_raw > 0 && primary_snapshot > 0 &&
            holdout_snapshot > 0 && primary_texture > 0 && holdout_texture > 0 &&
            primary_symmetric > 0 && holdout_symmetric > 0)
            if (primary_path > 0 && holdout_path > 0)
                result = "independent-delayed-receipt-supported"
            else
                result = "independent-delayed-receipt-not-confirmed"
        else
            result = "independent-delayed-receipt-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_strength " selected_strength
    print "selected_rank " selected_rank
    print "qualified_discovery_candidates " qualified
    print "discovery_lives " discovery_lives
    print "discovery_receipts " discovery_receipts
    print "discovery_raw_life_wins " discovery_raw_wins
    print "discovery_snapshot_life_wins " discovery_snapshot_wins
    print "discovery_texture_life_wins " discovery_texture_wins
    print "discovery_symmetric_life_wins " discovery_symmetric_wins
    print "discovery_path_life_wins " discovery_path_wins
    print "discovery_mean_raw_ce_gain " discovery_raw_gain
    print "discovery_mean_raw_brier_gain " discovery_raw_brier
    print "discovery_mean_snapshot_ce_gain " discovery_snapshot_gain
    print "discovery_mean_snapshot_brier_gain " discovery_snapshot_brier
    print "discovery_mean_texture_ce_gain " discovery_texture_gain
    print "discovery_mean_texture_brier_gain " discovery_texture_brier
    print "discovery_mean_symmetric_ce_gain " discovery_symmetric_gain
    print "discovery_mean_symmetric_brier_gain " discovery_symmetric_brier
    print "discovery_mean_path_ce_gain " discovery_path_gain
    print "discovery_mean_path_brier_gain " discovery_path_brier
    print "validation_lives " validation_lives + 0
    print "validation_receipts " validation_receipts + 0
    print "validation_raw_life_wins " raw_wins + 0
    print "validation_snapshot_life_wins " snapshot_wins + 0
    print "validation_texture_life_wins " texture_wins + 0
    print "validation_symmetric_life_wins " symmetric_wins + 0
    print "validation_path_life_wins " path_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", raw_gain + 0)
    print "validation_mean_snapshot_ce_gain " sprintf("%.9f", snapshot_gain + 0)
    print "validation_mean_texture_ce_gain " sprintf("%.9f", texture_gain + 0)
    print "validation_mean_symmetric_ce_gain " sprintf("%.9f", symmetric_gain + 0)
    print "validation_mean_path_ce_gain " sprintf("%.9f", path_gain + 0)
    print "validation_mean_snapshot_raw_ce_gain " sprintf("%.9f", snapshot_raw + 0)
    print "validation_mean_texture_snapshot_ce_gain " sprintf("%.9f", texture_snapshot + 0)
    print "validation_mean_path_symmetric_ce_gain " sprintf("%.9f", path_symmetric + 0)
    print "required_life_wins " life_win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", raw_ce_required)
    print "required_mean_snapshot_ce_gain " sprintf("%.9f", snapshot_ce_required)
    print "required_mean_texture_ce_gain " sprintf("%.9f", texture_ce_required)
    print "required_mean_symmetric_ce_gain " sprintf("%.9f", symmetric_ce_required)
    print "required_mean_path_ce_gain " sprintf("%.9f", path_ce_required)
    print "result " result
}
