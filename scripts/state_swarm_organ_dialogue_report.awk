# A.83: extract the pre-update organ witness without changing sealed receipts.

function clean(value) {
    gsub(/\t/, "\\t", value)
    gsub(/\r/, "", value)
    gsub(/\n/, "\\n", value)
    return value
}

function fail() {
    fatal = 1
    exit 2
}

function value_after(line, key,    fields, i, n, prefix, value) {
    prefix = key "="
    n = split(line, fields, /[ ]+/)
    for (i = 1; i <= n; i++) {
        if (index(fields[i], prefix) != 1) continue
        value = substr(fields[i], length(prefix) + 1)
        gsub(/\]$/, "", value)
        return value
    }
    return ""
}

function number(value) {
    return value ~ /^-?[0-9]+([.][0-9]+)?$/
}

function unsigned_number(value) {
    return value ~ /^[0-9]+$/
}

/\[state-swarm: turn=/ {
    found++
    turn = value_after($0, "turn")
    states = value_after($0, "states")
    winner = value_after($0, "winner")
    event = value_after($0, "event")
    members = value_after($0, "members")
    organs = value_after($0, "organs")

    if (!unsigned_number(turn) || !unsigned_number(states) || states + 0 < 1 ||
        states + 0 > 8 || !unsigned_number(winner) || winner + 0 < 1 ||
        (event != "updated" && event != "born" && event != "replaced") ||
        organs == "") fail()

    member_n = split(members, member_items, ",")
    organ_n = split(organs, organ_items, ",")
    if (member_n != states + 0 || organ_n != member_n) fail()
    invalid = 0
    winner_seen = 0
    for (i = 1; i <= member_n; i++) {
        colon = index(member_items[i], ":")
        if (!colon) fail()
        member_id[i] = substr(member_items[i], 1, colon - 1)
        member_activation[i] = substr(member_items[i], colon + 1)
        if (!unsigned_number(member_id[i]) || member_id[i] + 0 < 1 ||
            !number(member_activation[i]) || member_activation[i] + 0 < 0 ||
            member_activation[i] + 0 > 1.001) fail()

        colon = index(organ_items[i], ":")
        if (!colon || substr(organ_items[i], 1, colon - 1) != member_id[i])
            fail()
        raw = substr(organ_items[i], colon + 1)
        if (raw == "na") {
            organ_valid[i] = 0
            invalid++
            if (member_id[i] != winner) fail()
            for (o = 1; o <= 7; o++) organ_value[i, o] = "na"
        } else {
            organ_valid[i] = 1
            organ_fields = split(raw, part, "/")
            if (organ_fields != 7) fail()
            for (o = 1; o <= 7; o++) {
                if (!number(part[o]) || part[o] + 0 < 0 || part[o] + 0 > 1.001)
                    fail()
                organ_value[i, o] = part[o]
            }
        }
        if (member_id[i] == winner) winner_seen = 1
        for (j = 1; j < i; j++) if (member_id[j] == member_id[i]) fail()
    }
    if (!winner_seen || (event == "updated" && invalid != 0) ||
        (event != "updated" && invalid != 1)) fail()
}

END {
    if (fatal) exit 2
    if (found != 1 || cell == "" || cohort == "" ||
        !unsigned_number(base_seed) || phase == "" ||
        !unsigned_number(session) || !unsigned_number(order) ||
        texture == "" || !unsigned_number(run_seed) || prompt == "" ||
        reply == "") exit 1
    for (i = 1; i <= member_n; i++)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
               clean(cell), clean(cohort), clean(base_seed), clean(phase),
               clean(session), clean(order), clean(texture), clean(run_seed),
               turn, event, states, member_id[i], member_activation[i],
               organ_valid[i], organ_value[i, 1], organ_value[i, 2],
               organ_value[i, 3], organ_value[i, 4], organ_value[i, 5],
               organ_value[i, 6], organ_value[i, 7], clean(prompt), clean(reply)
}
