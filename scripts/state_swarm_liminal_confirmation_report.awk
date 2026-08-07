# A.92: reduce replay-locked frozen trajectories to paired temporal returns.

function fail() {
    fatal = 1
    exit 2
}

function integer(value) {
    return value ~ /^[0-9]+$/
}

function number(value) {
    return value ~ /^-?[0-9]+([.][0-9]+)?$/
}

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 15
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 13 || $1 != "pair" || $2 != "arm" ||
            $6 != "anchor_turn" || $11 != "reproduced_sha" ||
            $13 != "state_equal") fail()
        next
    }
    key = $1 SUBSEP $2
    if (NF != 13 || $1 !~ /^[0-9][0-9]$/ ||
        $2 !~ /^(event|ecology)$/ || seen_lock[key]++ ||
        $3 == "" || $4 !~ /^[ph][0-9][0-9]$/ ||
        $5 !~ /^(primary|holdout)$/ || !integer($6) || !integer($7) ||
        $7 < 1 || length($8) != 64 || $8 !~ /^[0-9a-f]+$/ ||
        length($9) != 64 || $9 !~ /^[0-9a-f]+$/ ||
        length($10) != 64 || $10 !~ /^[0-9a-f]+$/ ||
        length($11) != 64 || $11 !~ /^[0-9a-f]+$/ ||
        $12 != "true" || $13 != "true")
        fail()
    lock_anchor[key] = $3
    lock_life[key] = $4
    lock_split[key] = $5
    lock_turn[key] = $6 + 0
    lock_future[key] = $7 + 0
    locks++
    next
}

FNR == 1 {
    if (NF != 18 || $1 != "pair" || $2 != "arm" ||
        $4 != "anchor_turn" || $6 != "relative" ||
        $8 != "candidate_similarity" || $14 != "confirmation" ||
        $18 != "reply") fail()
    next
}

{
    key = $1 SUBSEP $2
    if (NF != 18 || !(key in lock_anchor) || $3 != lock_anchor[key] ||
        !integer($4) || !integer($5) || !integer($6) ||
        $4 + 0 != lock_turn[key] || $5 + 0 != $4 + $6 ||
        $6 < 1 || $6 > 8 || $7 !~ /^(home|storm|wonder|social)$/ ||
        !number($8) || !number($9) || !number($10) || !integer($11) ||
        $12 !~ /^(true|false)$/ || $13 !~ /^(true|false)$/ ||
        $14 !~ /^(true|false)$/ || $15 == "" || $16 == "" ||
        $17 == "" || $18 == "") fail()
    if (++rows[key] != $6 || rows[key] > lock_future[key]) fail()
    if (!(key in max_similarity) || $8 + 0 > max_similarity[key])
        max_similarity[key] = $8 + 0
    if (!(key in max_margin) || $10 + 0 > max_margin[key])
        max_margin[key] = $10 + 0
    if ($13 == "true" && !support[key]) {
        support[key] = 1
        first_support[key] = $6
    }
    if ($14 == "true" && !confirmation[key]) {
        confirmation[key] = 1
        first_confirmation[key] = $6
    }
    next
}

END {
    if (fatal) exit 2
    if (locks != expected * 2) fail()
    print "pair", "event_anchor", "ecology_anchor", "split", "anchor_turn", \
          "event_rows", "ecology_rows", "event_support", \
          "event_confirmation", "event_first_support", \
          "event_first_confirmation", "event_max_similarity", \
          "event_max_margin", "ecology_support", "ecology_confirmation", \
          "ecology_first_support", "ecology_first_confirmation", \
          "ecology_max_similarity", "ecology_max_margin", \
          "paired_max_margin_delta"
    emitted = 0
    for (i = 1; i <= 99; i++) {
        pair = sprintf("%02d", i)
        event_key = pair SUBSEP "event"
        ecology_key = pair SUBSEP "ecology"
        if (!(event_key in lock_anchor) && !(ecology_key in lock_anchor))
            continue
        event_expected = lock_future[event_key] < 8 ? lock_future[event_key] : 8
        ecology_expected = lock_future[ecology_key] < 8 ? lock_future[ecology_key] : 8
        if (!(event_key in lock_anchor) || !(ecology_key in lock_anchor) ||
            rows[event_key] != event_expected ||
            rows[ecology_key] != ecology_expected ||
            lock_split[event_key] != lock_split[ecology_key] ||
            lock_turn[event_key] != lock_turn[ecology_key] ||
            lock_future[event_key] != lock_future[ecology_key]) fail()
        event_support = support[event_key] ? "true" : "false"
        event_confirmation = confirmation[event_key] ? "true" : "false"
        ecology_support = support[ecology_key] ? "true" : "false"
        ecology_confirmation = confirmation[ecology_key] ? "true" : "false"
        print pair, lock_anchor[event_key], lock_anchor[ecology_key], \
              lock_split[event_key], lock_turn[event_key], rows[event_key], \
              rows[ecology_key], event_support, event_confirmation, \
              (support[event_key] ? first_support[event_key] : "na"), \
              (confirmation[event_key] ? first_confirmation[event_key] : "na"), \
              sprintf("%.6f", max_similarity[event_key]), \
              sprintf("%.6f", max_margin[event_key]), ecology_support, \
              ecology_confirmation, \
              (support[ecology_key] ? first_support[ecology_key] : "na"), \
              (confirmation[ecology_key] ? first_confirmation[ecology_key] : "na"), \
              sprintf("%.6f", max_similarity[ecology_key]), \
              sprintf("%.6f", max_margin[ecology_key]), \
              sprintf("%.6f", max_margin[event_key] - max_margin[ecology_key])
        emitted++
    }
    if (emitted != expected) fail()
}
