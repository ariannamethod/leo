# A.93: reduce ordered and reversed short traces to paired confirmations.

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

function abs(value) {
    return value < 0 ? -value : value
}

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 14
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 16 || $1 != "pair" || $2 != "arm" ||
            $8 != "build_turns" || $9 != "score_turns" ||
            $14 != "log_equal" || $16 != "geometry_equal") fail()
        next
    }
    key = $1 SUBSEP $2
    if (NF != 16 || $1 !~ /^[0-9][0-9]$/ ||
        $2 !~ /^(event|ecology)$/ || seen_lock[key]++ ||
        $3 == "" || $4 !~ /^[ph][0-9][0-9]$/ ||
        $5 !~ /^(primary|holdout)$/ || !integer($6) || !integer($7) ||
        $7 < 8 || $8 != 3 || $9 != 5 || $6 + $7 != 96)
        fail()
    for (i = 10; i <= 13; i++)
        if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) fail()
    for (i = 14; i <= 16; i++) if ($i != "true") fail()
    lock_anchor[key] = $3
    lock_split[key] = $5
    lock_turn[key] = $6 + 0
    lock_future[key] = $7 + 0
    locks++
    next
}

FNR == 1 {
    if (NF != 22 || $1 != "pair" || $2 != "arm" ||
        $8 != "forward_similarity" || $9 != "reverse_similarity" ||
        $12 != "forward_stable_margin" || $14 != "order_margin" ||
        $16 != "support" || $17 != "strong" || $22 != "reply") fail()
    next
}

{
    key = $1 SUBSEP $2
    if (NF != 22 || !(key in lock_anchor) || $3 != lock_anchor[key] ||
        !integer($4) || !integer($5) || !integer($6) ||
        $4 + 0 != lock_turn[key] || $5 + 0 != $4 + $6 ||
        $6 < 4 || $6 > 8 || $6 > lock_future[key] ||
        $7 !~ /^(home|storm|wonder|social)$/ ||
        !number($8) || !number($9) || !number($10) || !integer($11) ||
        !number($12) || !number($13) || !number($14) ||
        $15 !~ /^(true|false)$/ || $16 !~ /^(true|false)$/ ||
        $17 !~ /^(true|false)$/ || $18 == "" || $19 == "" ||
        $20 == "" || $21 == "" || $22 == "" ||
        $8 < 0 || $8 > 1 || $9 < 0 || $9 > 1 || $10 < 0 || $10 > 1 ||
        abs(($8 - $10) - $12) > 0.000002 ||
        abs(($9 - $10) - $13) > 0.000002 ||
        abs(($8 - $9) - $14) > 0.000002 ||
        (($12 > 0.0000001 && $14 > 0.0000001) ? "true" : "false") != $15 ||
        (($15 == "true" && $8 >= 0.40) ? "true" : "false") != $16 ||
        (($15 == "true" && $8 >= 0.55) ? "true" : "false") != $17)
        fail()
    if (++rows[key] != $6 - 3) fail()
    if ($14 > 0.0000001) order_wins[key]++
    if ($16 == "true") {
        support[key]++
        support_texture[key SUBSEP $7] = 1
    }
    if ($17 == "true") strong[key]++
    if (!(key in max_stable_margin) || $12 + 0 > max_stable_margin[key])
        max_stable_margin[key] = $12 + 0
    if (!(key in max_order_margin) || $14 + 0 > max_order_margin[key])
        max_order_margin[key] = $14 + 0
    next
}

END {
    if (fatal) exit 2
    if (locks != expected * 2) fail()
    print "pair", "event_anchor", "ecology_anchor", "split", "anchor_turn", \
          "event_support_hits", "event_strong_hits", \
          "event_support_textures", "event_order_wins", \
          "event_confirmation", "event_max_stable_margin", \
          "event_max_order_margin", "ecology_support_hits", \
          "ecology_strong_hits", "ecology_support_textures", \
          "ecology_order_wins", "ecology_confirmation", \
          "ecology_max_stable_margin", "ecology_max_order_margin", \
          "paired_max_stable_margin_delta", "paired_max_order_margin_delta"
    emitted = 0
    for (i = 1; i <= 99; i++) {
        pair = sprintf("%02d", i)
        event = pair SUBSEP "event"
        ecology = pair SUBSEP "ecology"
        if (!(event in lock_anchor) && !(ecology in lock_anchor)) continue
        if (!(event in lock_anchor) || !(ecology in lock_anchor) ||
            rows[event] != 5 || rows[ecology] != 5 ||
            lock_split[event] != lock_split[ecology] ||
            lock_turn[event] != lock_turn[ecology]) fail()
        event_textures = ecology_textures = 0
        for (key in support_texture) {
            split(key, part, SUBSEP)
            if (part[1] == pair && part[2] == "event") event_textures++
            if (part[1] == pair && part[2] == "ecology") ecology_textures++
        }
        event_confirmation = support[event] >= 2 && strong[event] >= 1 &&
            event_textures >= 2
        ecology_confirmation = support[ecology] >= 2 && strong[ecology] >= 1 &&
            ecology_textures >= 2
        print pair, lock_anchor[event], lock_anchor[ecology], \
              lock_split[event], lock_turn[event], support[event] + 0, \
              strong[event] + 0, event_textures, order_wins[event] + 0, \
              (event_confirmation ? "true" : "false"), \
              sprintf("%.6f", max_stable_margin[event]), \
              sprintf("%.6f", max_order_margin[event]), \
              support[ecology] + 0, strong[ecology] + 0, ecology_textures, \
              order_wins[ecology] + 0, \
              (ecology_confirmation ? "true" : "false"), \
              sprintf("%.6f", max_stable_margin[ecology]), \
              sprintf("%.6f", max_order_margin[ecology]), \
              sprintf("%.6f", max_stable_margin[event] - \
                      max_stable_margin[ecology]), \
              sprintf("%.6f", max_order_margin[event] - \
                      max_order_margin[ecology])
        emitted++
    }
    if (emitted != expected) fail()
}
