# A.94: carry all followable A.92 event/ecology pairs into graph anatomy.

function fail() {
    fatal = 1
    exit 2
}

BEGIN { FS = OFS = "\t" }

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 13 || $1 != "pair" || $2 != "arm" || $13 != "reply") fail()
        next
    }
    key = $1 SUBSEP $2
    if (NF != 13 || selected[key]++) fail()
    for (i = 1; i <= 13; i++) field[key, i] = $i
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
    for (i = 1; i <= 13; i++) if ($i != field[key, i]) fail()
    plan[key] = $0
    plans++
    next
}

FILENAME == ARGV[3] {
    if (FNR == 1) {
        if (NF != 13 || $1 != "pair" || $2 != "arm" ||
            $7 != "future_turns" || $12 != "reply_equal" ||
            $13 != "state_equal") fail()
        next
    }
    key = $1 SUBSEP $2
    if (NF != 13 || !(key in selected) || locked[key]++ ||
        $7 !~ /^[0-9]+$/ || $7 < 1 ||
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
        print plan[event]
        print plan[ecology]
        pairs++
    }
    if (pairs != 15) fail()
}
