# A.94: verify graph arithmetic and reduce event/ecology transition debt.

function fail() {
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 15
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 16 || $1 != "pair" || $2 != "arm" ||
            $7 != "future_turns" || $13 != "a92_reply_equal" ||
            $16 != "geometry_equal") fail()
        next
    }
    key = $1 SUBSEP $2
    if (NF != 16 || $1 !~ /^[0-9][0-9]$/ ||
        $2 !~ /^(event|ecology)$/ || seen_lock[key]++ ||
        $3 == "" || $4 !~ /^[ph][0-9][0-9]$/ ||
        $5 !~ /^(primary|holdout)$/ || !integer($6) || !integer($7) ||
        $7 < 1 || $6 + $7 != 96) fail()
    for (i = 8; i <= 12; i++)
        if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) fail()
    for (i = 13; i <= 16; i++) if ($i != "true") fail()
    anchor[key] = $3
    split_name[key] = $5
    anchor_turn[key] = $6 + 0
    locks++
    next
}

FNR == 1 {
    if (NF != 28 || $1 != "pair" || $2 != "arm" ||
        $11 != "transition_mass" || $12 != "forward_overlap" ||
        $15 != "transition_debt" || $16 != "arrow_margin" ||
        $25 != "outcome_mae" || $26 != "joint_debt" ||
        $28 != "reply") fail()
    next
}

{
    key = $1 SUBSEP $2
    if (NF != 28 || !(key in anchor) || seen_score[key]++ ||
        $3 != anchor[key] || !integer($4) || !integer($5) ||
        $4 + 0 != anchor_turn[key] || $5 != $4 + 1 ||
        $6 !~ /^(home|storm|wonder|social)$/) fail()
    for (i = 7; i <= 26; i++) if (!number($i)) fail()
    if ($7 < 0 || $7 > 1 || $8 < 0 || $8 > 1 ||
        $9 < 0 || $9 > 1 || $10 < 0 || $10 > 1 ||
        $11 < 0 || $12 < 0 || $12 > 1 || $13 < 0 ||
        $14 < 0 || $14 > 1 || $15 < 0 || $15 > 1 ||
        $25 < 0 || $25 > 2 || $26 < 0 || $26 > 2 ||
        abs((1 - $12) - $15) > 0.000002 ||
        abs(($12 - $14) - $16) > 0.000002) fail()
    mae = (abs($17 - $21) + abs($18 - $22) + \
           abs($19 - $23) + abs($20 - $24)) / 4
    if (abs(mae - $25) > 0.000002 ||
        abs(($15 * $25) - $26) > 0.000002 ||
        $27 == "" || $28 == "") fail()
    mass[key] = $11 + 0
    overlap[key] = $12 + 0
    reverse_overlap[key] = $14 + 0
    transition_debt[key] = $15 + 0
    arrow[key] = $16 + 0
    outcome_mae[key] = $25 + 0
    joint_debt[key] = $26 + 0
    scores++
    next
}

END {
    if (fatal) exit 2
    if (locks != expected * 2 || scores != expected * 2) fail()
    print "pair", "event_anchor", "ecology_anchor", "split", "anchor_turn", \
          "event_transition_mass", "event_overlap", "event_reverse_overlap", \
          "event_transition_debt", "event_outcome_mae", "event_joint_debt", \
          "event_arrow_margin", "ecology_transition_mass", \
          "ecology_overlap", "ecology_reverse_overlap", \
          "ecology_transition_debt", "ecology_outcome_mae", \
          "ecology_joint_debt", "ecology_arrow_margin", \
          "paired_transition_debt_delta", "paired_outcome_mae_delta", \
          "paired_joint_debt_delta", "paired_arrow_margin_delta"
    emitted = 0
    for (i = 1; i <= 99; i++) {
        pair = sprintf("%02d", i)
        event = pair SUBSEP "event"
        ecology = pair SUBSEP "ecology"
        if (!(event in anchor) && !(ecology in anchor)) continue
        if (!(event in anchor) || !(ecology in anchor) ||
            !(event in seen_score) || !(ecology in seen_score) ||
            split_name[event] != split_name[ecology] ||
            anchor_turn[event] != anchor_turn[ecology]) fail()
        print pair, anchor[event], anchor[ecology], split_name[event], \
              anchor_turn[event], sprintf("%.6f", mass[event]), \
              sprintf("%.6f", overlap[event]), \
              sprintf("%.6f", reverse_overlap[event]), \
              sprintf("%.6f", transition_debt[event]), \
              sprintf("%.6f", outcome_mae[event]), \
              sprintf("%.6f", joint_debt[event]), \
              sprintf("%.6f", arrow[event]), \
              sprintf("%.6f", mass[ecology]), \
              sprintf("%.6f", overlap[ecology]), \
              sprintf("%.6f", reverse_overlap[ecology]), \
              sprintf("%.6f", transition_debt[ecology]), \
              sprintf("%.6f", outcome_mae[ecology]), \
              sprintf("%.6f", joint_debt[ecology]), \
              sprintf("%.6f", arrow[ecology]), \
              sprintf("%.6f", transition_debt[event] - transition_debt[ecology]), \
              sprintf("%.6f", outcome_mae[event] - outcome_mae[ecology]), \
              sprintf("%.6f", joint_debt[event] - joint_debt[ecology]), \
              sprintf("%.6f", arrow[event] - arrow[ecology])
        emitted++
    }
    if (emitted != expected) fail()
}
