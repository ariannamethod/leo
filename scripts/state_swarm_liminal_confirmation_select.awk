# A.92: admit only exact event/ecology pairs with life after the anchor.

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
        if (NF != 41 || $1 != "pair" || $2 != "event" ||
            $6 != "event_turn" || $28 != "ecology_control" ||
            $31 != "ecology_turn" || $41 != "ecology_reply") fail()
        next
    }
    if (NF != 41 || $1 !~ /^[0-9][0-9]$/ || seen_pair[$1]++ ||
        $2 != sprintf("%s-t%03d", $3, $6) ||
        $3 !~ /^[ph][0-9][0-9]$/ ||
        $4 !~ /^(primary|holdout)$/ || !integer($5) ||
        !integer($6) || !integer($7) || !integer($8) ||
        $9 !~ /^(home|storm|wonder|social)$/ || !integer($10) ||
        $11 !~ /^[0-9]+([.][0-9]+)?$/ || $13 == "" || $14 == "" ||
        $28 != sprintf("%s-t%03d", $29, $31) ||
        $29 !~ /^[ph][0-9][0-9]$/ || $29 == $3 || !integer($30) ||
        !integer($31) || !integer($32) || !integer($33) ||
        $34 !~ /^(home|storm|wonder|social)$/ || !integer($35) ||
        $36 !~ /^[0-9]+([.][0-9]+)?$/ || $40 == "" || $41 == "" ||
        $4 != (substr($29, 1, 1) == "p" ? "primary" : "holdout") ||
        $6 != $31 || $7 != $32 || $8 != $33 || $9 != $34 ||
        $10 == $35 || $13 != $40) fail()
    pair_event[$1] = $2
    pair_ecology[$1] = $28
    event_line[$1] = $2 OFS $3 OFS $4 OFS $5 OFS $6 OFS $7 OFS $8 OFS \
        $9 OFS $10 OFS $13 OFS $14
    ecology_line[$1] = $28 OFS $29 OFS $4 OFS $30 OFS $31 OFS $32 OFS \
        $33 OFS $34 OFS $35 OFS $40 OFS $41
    if ($6 < 96) eligible[$1] = 1
    else if ($6 == 96) censored[$1] = 1
    else fail()
    pairs++
    next
}

FILENAME == ARGV[2] {
    if (FNR == 1) {
        if (NF != 19 || $1 != "event" || $6 != "trigger_turn" ||
            $16 != "state_equal" || $19 != "reply_equal") fail()
        next
    }
    if (NF != 19 || seen_event_lock[$1]++ ||
        $1 !~ /^[ph][0-9][0-9]-t[0-9][0-9][0-9]$/)
        fail()
    for (i = 16; i <= 19; i++) if ($i != "true") fail()
    event_lock[$1] = 1
    event_locks++
    next
}

FILENAME == ARGV[3] {
    if (FNR == 1) {
        if (NF != 21 || $1 != "control" || $3 != "family" ||
            $17 != "life_state_equal" || $21 != "reply_equal") fail()
        next
    }
    if (NF != 21 || control_lock[$1]++ ||
        $3 !~ /^(organism|ecology)$/) fail()
    for (i = 17; i <= 21; i++) if ($i != "true") fail()
    control_family[$1] = $3
    control_locks++
    next
}

END {
    if (fatal) exit 2
    if (pairs != 19 || length(eligible) != 15 || length(censored) != 4 ||
        event_locks != 19 || control_locks != 38) fail()
    for (i = 1; i <= 19; i++) {
        pair = sprintf("%02d", i)
        if (!(pair in pair_event) || !(pair_event[pair] in event_lock) ||
            !(pair_ecology[pair] in control_lock) ||
            control_family[pair_ecology[pair]] != "ecology") fail()
    }
    print "pair", "arm", "anchor", "life", "split", "base_seed", \
          "turn", "session", "order", "texture", "run_seed", "prompt", \
          "reply"
    for (i = 1; i <= 19; i++) {
        pair = sprintf("%02d", i)
        if (!(pair in eligible)) continue
        print pair, "event", event_line[pair]
        print pair, "ecology", ecology_line[pair]
    }
}
