# A.107: confirm one frozen delayed receipt reader on untouched counterbalanced lives.

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
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 25 || $1 != "candidate" || $25 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 25) fail()
    selected = $1; selected_strength = $2; selected_rank = $3
    discovery_lives = $4; discovery_receipts = $5
    discovery_raw_wins = $6; discovery_snapshot_wins = $7
    discovery_texture_wins = $8; discovery_symmetric_wins = $9
    discovery_raw_gain = $10; discovery_raw_brier = $11
    discovery_snapshot_gain = $12; discovery_snapshot_brier = $13
    discovery_texture_gain = $14; discovery_texture_brier = $15
    discovery_symmetric_gain = $16; discovery_symmetric_brier = $17
    qualified = $24; selection_result = $25
    next
}

FNR == 1 {
    if (NF != 42 || $1 != "candidate" || $4 != "cohort" ||
        $42 != "holdout_mean_symmetric_gain") fail()
    next
}

$4 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 42 || $2 != selected_strength ||
        $3 != selected_rank || $5 != expected ||
        $25 != expected / 2 || $26 != expected / 2) fail()
    validation_lives = $5; validation_receipts = $6
    raw_wins = $7; snapshot_wins = $8; texture_wins = $9; symmetric_wins = $10
    raw_gain = $11; raw_brier = $12; snapshot_gain = $13; snapshot_brier = $14
    texture_gain = $15; texture_brier = $16; symmetric_gain = $17; symmetric_brier = $18
    snapshot_raw = $19; texture_snapshot = $20
    home_gain = $21; storm_gain = $22; wonder_gain = $23; social_gain = $24
    primary_raw_wins = $27; holdout_raw_wins = $28
    primary_snapshot_wins = $29; holdout_snapshot_wins = $30
    primary_texture_wins = $31; holdout_texture_wins = $32
    primary_symmetric_wins = $33; holdout_symmetric_wins = $34
    primary_raw = $35; holdout_raw = $36
    primary_snapshot = $37; holdout_snapshot = $38
    primary_texture = $39; holdout_texture = $40
    primary_symmetric = $41; holdout_symmetric = $42
}

END {
    if (fatal || selection_rows != 1) exit 2
    if (selection_result == "no-delayed-receipt-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-delayed-receipt-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (raw_wins >= life_win_required && snapshot_wins >= life_win_required &&
            texture_wins >= life_win_required && symmetric_wins >= life_win_required &&
            primary_raw_wins >= split_win_required && holdout_raw_wins >= split_win_required &&
            primary_snapshot_wins >= split_win_required && holdout_snapshot_wins >= split_win_required &&
            primary_texture_wins >= split_win_required && holdout_texture_wins >= split_win_required &&
            primary_symmetric_wins >= split_win_required && holdout_symmetric_wins >= split_win_required &&
            raw_gain >= raw_ce_required && raw_brier >= raw_brier_required &&
            snapshot_gain >= snapshot_ce_required && snapshot_brier >= snapshot_brier_required &&
            texture_gain >= texture_ce_required && texture_brier >= texture_brier_required &&
            symmetric_gain >= symmetric_ce_required && symmetric_brier >= symmetric_brier_required &&
            home_gain > 0 && storm_gain > 0 && wonder_gain > 0 && social_gain > 0 &&
            primary_raw > 0 && holdout_raw > 0 && primary_snapshot > 0 &&
            holdout_snapshot > 0 && primary_texture > 0 && holdout_texture > 0 &&
            primary_symmetric > 0 && holdout_symmetric > 0)
            result = "delayed-receipt-supported"
        else
            result = "delayed-receipt-not-confirmed"
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
    print "discovery_mean_raw_ce_gain " discovery_raw_gain
    print "discovery_mean_raw_brier_gain " discovery_raw_brier
    print "discovery_mean_snapshot_ce_gain " discovery_snapshot_gain
    print "discovery_mean_snapshot_brier_gain " discovery_snapshot_brier
    print "discovery_mean_texture_ce_gain " discovery_texture_gain
    print "discovery_mean_texture_brier_gain " discovery_texture_brier
    print "discovery_mean_symmetric_ce_gain " discovery_symmetric_gain
    print "discovery_mean_symmetric_brier_gain " discovery_symmetric_brier
    print "validation_lives " validation_lives + 0
    print "validation_receipts " validation_receipts + 0
    print "validation_raw_life_wins " raw_wins + 0
    print "validation_snapshot_life_wins " snapshot_wins + 0
    print "validation_texture_life_wins " texture_wins + 0
    print "validation_symmetric_life_wins " symmetric_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", raw_gain + 0)
    print "validation_mean_snapshot_ce_gain " sprintf("%.9f", snapshot_gain + 0)
    print "validation_mean_texture_ce_gain " sprintf("%.9f", texture_gain + 0)
    print "validation_mean_symmetric_ce_gain " sprintf("%.9f", symmetric_gain + 0)
    print "validation_mean_snapshot_raw_ce_gain " sprintf("%.9f", snapshot_raw + 0)
    print "validation_mean_texture_snapshot_ce_gain " sprintf("%.9f", texture_snapshot + 0)
    print "required_life_wins " life_win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", raw_ce_required)
    print "required_mean_snapshot_ce_gain " sprintf("%.9f", snapshot_ce_required)
    print "required_mean_texture_ce_gain " sprintf("%.9f", texture_ce_required)
    print "required_mean_symmetric_ce_gain " sprintf("%.9f", symmetric_ce_required)
    print "result " result
}
