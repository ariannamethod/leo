# A.93: admit only A.92 pairs with three build and five score turns.

function fail() {
    fatal = 1
    exit 2
}

function integer(value) {
    return value ~ /^[0-9]+$/
}

BEGIN {
    FS = OFS = "\t"
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 13 || $1 != "pair" || $2 != "arm" || $13 != "reply") fail()
        next
    }
    key = $1 SUBSEP $2
    if (NF != 13 || $1 !~ /^[0-9][0-9]$/ ||
        $2 !~ /^(event|ecology)$/ || selected[key]++) fail()
    for (i = 1; i <= 13; i++) selected_field[key, i] = $i
    selections++
    next
}

FILENAME == ARGV[2] {
    if (FNR == 1) {
        if (NF != 19 || $1 != "pair" || $2 != "arm" ||
            $14 != "pre_state" || $19 != "final_sha") fail()
        header = $0
        next
    }
    key = $1 SUBSEP $2
    if (NF != 19 || !(key in selected) || planned[key]++) fail()
    for (i = 1; i <= 13; i++)
        if ($i != selected_field[key, i]) fail()
    plan[key] = $0
    plans++
    next
}

FILENAME == ARGV[3] {
    if (FNR == 1) {
        if (NF != 13 || $1 != "pair" || $2 != "arm" ||
            $6 != "anchor_turn" || $7 != "future_turns" ||
            $12 != "reply_equal" || $13 != "state_equal") fail()
        next
    }
    key = $1 SUBSEP $2
    if (NF != 13 || !(key in selected) || locked[key]++ ||
        !integer($6) || !integer($7) || $6 + $7 != 96 ||
        $12 != "true" || $13 != "true") fail()
    future[key] = $7 + 0
    locks++
    next
}

END {
    if (fatal) exit 2
    if (selections != 30 || plans != 30 || locks != 30) fail()
    print header
    for (i = 1; i <= 99; i++) {
        pair = sprintf("%02d", i)
        event = pair SUBSEP "event"
        ecology = pair SUBSEP "ecology"
        if (!(event in selected) && !(ecology in selected)) continue
        if (!(event in planned) || !(ecology in planned) ||
            !(event in locked) || !(ecology in locked) ||
            future[event] != future[ecology]) fail()
        pairs++
        if (future[event] < 8) {
            censored++
            continue
        }
        print plan[event]
        print plan[ecology]
        eligible++
    }
    if (pairs != 15 || eligible != 14 || censored != 1) fail()
}
