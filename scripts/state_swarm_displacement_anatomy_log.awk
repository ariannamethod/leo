# A.86: validate the complete pre-update organ witness in one debug log.

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

function parse_vector(value, target,    part, n, i) {
    n = split(value, part, "/")
    if (n != 7) fail()
    for (i = 1; i <= 7; i++) {
        if (!number(part[i]) || part[i] + 0 < 0 || part[i] + 0 > 1.001)
            fail()
        target[i] = part[i] + 0
    }
}

function weighted(value) {
    return 0.19 * value[1] + 0.19 * value[2] + 0.10 * value[3] + 0.20 * value[4] + 0.18 * value[5] + 0.07 * value[6] + 0.07 * value[7]
}

/\[state-swarm: turn=/ {
    found++
    turn = value_after($0, "turn")
    states = value_after($0, "states")
    winner = value_after($0, "winner")
    event = value_after($0, "event")
    similarity = value_after($0, "similarity")
    members = value_after($0, "members")
    organs = value_after($0, "organs")
    nearest = value_after($0, "nearest")
    nearest_raw = value_after($0, "nearest_organs")
    replaced = value_after($0, "replaced")
    removed_raw = value_after($0, "removed_organs")

    if (!unsigned_number(turn) || !unsigned_number(states) || states < 1 ||
        states > 8 || !unsigned_number(winner) || winner < 1 ||
        (event != "updated" && event != "born" && event != "replaced") ||
        !number(similarity) || similarity < 0 || similarity > 1.001 ||
        !unsigned_number(nearest) || members == "" || organs == "") fail()

    member_n = split(members, member_item, ",")
    organ_n = split(organs, organ_item, ",")
    if (member_n != states || organ_n != states) fail()
    invalid = 0
    winner_seen = 0
    nearest_seen = 0
    replaced_seen = 0
    for (i = 1; i <= member_n; i++) {
        colon = index(member_item[i], ":")
        if (!colon) fail()
        member_id[i] = substr(member_item[i], 1, colon - 1)
        activation = substr(member_item[i], colon + 1)
        if (!unsigned_number(member_id[i]) || member_id[i] < 1 ||
            !number(activation) || activation < 0 || activation > 1.001)
            fail()
        if (member_id[i] == winner) winner_seen = 1
        if (member_id[i] == nearest) nearest_seen = 1
        if (replaced != "" && member_id[i] == replaced) replaced_seen = 1
        for (j = 1; j < i; j++) if (member_id[j] == member_id[i]) fail()

        colon = index(organ_item[i], ":")
        if (!colon || substr(organ_item[i], 1, colon - 1) != member_id[i])
            fail()
        raw = substr(organ_item[i], colon + 1)
        if (raw == "na") invalid++
        else parse_vector(raw, parsed)
    }
    if (!winner_seen || (event == "updated" && invalid != 0) ||
        (event != "updated" && invalid != 1)) fail()

    if (nearest == 0) {
        if (nearest_raw != "na" || states != 1 || event != "born" ||
            similarity > 0.001) fail()
    } else {
        if (nearest_raw == "na") fail()
        parse_vector(nearest_raw, nearest_value)
        if (weighted(nearest_value) < similarity - 0.0015 ||
            weighted(nearest_value) > similarity + 0.0015) fail()
    }

    if (event == "replaced") {
        if (!unsigned_number(replaced) || replaced < 1 || replaced_seen ||
            removed_raw == "" || removed_raw == "na") fail()
        parse_vector(removed_raw, removed_value)
        if (nearest != replaced && !nearest_seen) fail()
    } else {
        if (replaced != "" || removed_raw != "") fail()
        if (nearest != 0 && !nearest_seen) fail()
    }
    if (event == "updated" && nearest != winner) fail()
}

END {
    if (fatal) exit 2
    if (found != 1) exit 1
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           turn, event, winner, similarity, members,
           (replaced == "" ? 0 : replaced), nearest, nearest_raw,
           (removed_raw == "" ? "na" : removed_raw), organs
}
