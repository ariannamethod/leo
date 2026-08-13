# A.106: confirm one frozen ending reader on untouched counterbalanced lives.

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
    if (!unordered_ce_required) unordered_ce_required = 0.001
    if (!unordered_brier_required) unordered_brier_required = 0.00025
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 25 || $1 != "candidate" || $25 != "result") fail()
        next
    }
    if (FNR != 2 || selection_rows++ || NF != 25) fail()
    selected = $1; selected_strength = $2; selected_rank = $3
    discovery_lives = $4; discovery_episodes = $5
    discovery_raw_wins = $6; discovery_snapshot_wins = $7
    discovery_texture_wins = $8; discovery_unordered_wins = $9
    discovery_raw_gain = $10; discovery_raw_brier = $11
    discovery_snapshot_gain = $12; discovery_snapshot_brier = $13
    discovery_texture_gain = $14; discovery_texture_brier = $15
    discovery_unordered_gain = $16; discovery_unordered_brier = $17
    qualified = $24; selection_result = $25
    next
}

FNR == 1 {
    if (NF != 42 || $1 != "candidate" || $4 != "cohort" ||
        $42 != "holdout_mean_unordered_gain") fail()
    next
}

$4 == "validation" && $1 == selected {
    if (validation_rows++ || NF != 42 || $2 != selected_strength ||
        $3 != selected_rank || $5 != expected ||
        $25 != expected / 2 || $26 != expected / 2) fail()
    validation_lives = $5; validation_episodes = $6
    raw_wins = $7; snapshot_wins = $8; texture_wins = $9; unordered_wins = $10
    raw_gain = $11; raw_brier = $12; snapshot_gain = $13; snapshot_brier = $14
    texture_gain = $15; texture_brier = $16; unordered_gain = $17; unordered_brier = $18
    snapshot_raw = $19; texture_snapshot = $20
    home_gain = $21; storm_gain = $22; wonder_gain = $23; social_gain = $24
    primary_raw_wins = $27; holdout_raw_wins = $28
    primary_snapshot_wins = $29; holdout_snapshot_wins = $30
    primary_texture_wins = $31; holdout_texture_wins = $32
    primary_unordered_wins = $33; holdout_unordered_wins = $34
    primary_raw = $35; holdout_raw = $36
    primary_snapshot = $37; holdout_snapshot = $38
    primary_texture = $39; holdout_texture = $40
    primary_unordered = $41; holdout_unordered = $42
}

END {
    if (fatal || selection_rows != 1) exit 2
    if (selection_result == "no-episode-consequence-candidate") {
        if (selected != "none" || qualified != 0) fail()
        result = "no-episode-consequence-candidate"
    } else {
        if (selection_result != "candidate-nominated" || selected == "none" ||
            validation_rows != 1) fail()
        if (raw_wins >= life_win_required && snapshot_wins >= life_win_required &&
            texture_wins >= life_win_required && unordered_wins >= life_win_required &&
            primary_raw_wins >= split_win_required && holdout_raw_wins >= split_win_required &&
            primary_snapshot_wins >= split_win_required && holdout_snapshot_wins >= split_win_required &&
            primary_texture_wins >= split_win_required && holdout_texture_wins >= split_win_required &&
            primary_unordered_wins >= split_win_required && holdout_unordered_wins >= split_win_required &&
            raw_gain >= raw_ce_required && raw_brier >= raw_brier_required &&
            snapshot_gain >= snapshot_ce_required && snapshot_brier >= snapshot_brier_required &&
            texture_gain >= texture_ce_required && texture_brier >= texture_brier_required &&
            unordered_gain >= unordered_ce_required && unordered_brier >= unordered_brier_required &&
            home_gain > 0 && storm_gain > 0 && wonder_gain > 0 && social_gain > 0 &&
            primary_raw > 0 && holdout_raw > 0 && primary_snapshot > 0 &&
            holdout_snapshot > 0 && primary_texture > 0 && holdout_texture > 0 &&
            primary_unordered > 0 && holdout_unordered > 0)
            result = "episode-consequence-supported"
        else
            result = "episode-consequence-not-confirmed"
    }

    print "selected_candidate " selected
    print "selected_strength " selected_strength
    print "selected_rank " selected_rank
    print "qualified_discovery_candidates " qualified
    print "discovery_lives " discovery_lives
    print "discovery_episodes " discovery_episodes
    print "discovery_raw_life_wins " discovery_raw_wins
    print "discovery_snapshot_life_wins " discovery_snapshot_wins
    print "discovery_texture_life_wins " discovery_texture_wins
    print "discovery_unordered_life_wins " discovery_unordered_wins
    print "discovery_mean_raw_ce_gain " discovery_raw_gain
    print "discovery_mean_raw_brier_gain " discovery_raw_brier
    print "discovery_mean_snapshot_ce_gain " discovery_snapshot_gain
    print "discovery_mean_snapshot_brier_gain " discovery_snapshot_brier
    print "discovery_mean_texture_ce_gain " discovery_texture_gain
    print "discovery_mean_texture_brier_gain " discovery_texture_brier
    print "discovery_mean_unordered_ce_gain " discovery_unordered_gain
    print "discovery_mean_unordered_brier_gain " discovery_unordered_brier
    print "validation_lives " validation_lives + 0
    print "validation_episodes " validation_episodes + 0
    print "validation_raw_life_wins " raw_wins + 0
    print "validation_snapshot_life_wins " snapshot_wins + 0
    print "validation_texture_life_wins " texture_wins + 0
    print "validation_unordered_life_wins " unordered_wins + 0
    print "validation_mean_raw_ce_gain " sprintf("%.9f", raw_gain + 0)
    print "validation_mean_snapshot_ce_gain " sprintf("%.9f", snapshot_gain + 0)
    print "validation_mean_texture_ce_gain " sprintf("%.9f", texture_gain + 0)
    print "validation_mean_unordered_ce_gain " sprintf("%.9f", unordered_gain + 0)
    print "validation_mean_snapshot_raw_ce_gain " sprintf("%.9f", snapshot_raw + 0)
    print "validation_mean_texture_snapshot_ce_gain " sprintf("%.9f", texture_snapshot + 0)
    print "required_life_wins " life_win_required
    print "required_split_wins " split_win_required
    print "required_mean_raw_ce_gain " sprintf("%.9f", raw_ce_required)
    print "required_mean_snapshot_ce_gain " sprintf("%.9f", snapshot_ce_required)
    print "required_mean_texture_ce_gain " sprintf("%.9f", texture_ce_required)
    print "required_mean_unordered_ce_gain " sprintf("%.9f", unordered_ce_required)
    print "result " result
}
