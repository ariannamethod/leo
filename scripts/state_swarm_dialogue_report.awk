# Extract one A.80 state-swarm witness from a single-turn Leo debug log.

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
        if (index(fields[i], prefix) != 1)
            continue
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

function parse_quad(value, out,    n, i) {
    n = split(value, out, "/")
    if (n != 4) fail()
    for (i = 1; i <= 4; i++)
        if (!number(out[i]) || out[i] + 0 < -1.001 || out[i] + 0 > 1.001)
            fail()
}

/\[state-swarm: turn=/ {
    found++
    turn = value_after($0, "turn")
    states = value_after($0, "states")
    active = value_after($0, "active")
    winner = value_after($0, "winner")
    event = value_after($0, "event")
    similarity = value_after($0, "similarity")
    entropy = value_after($0, "entropy")
    members = value_after($0, "members")
    adjacent = value_after($0, "adjacent")
    replaced = value_after($0, "replaced")
    expected_raw = value_after($0, "expected")
    overlap = value_after($0, "overlap")
    surprise = value_after($0, "surprise")
    observed_raw = value_after($0, "observed")
    forecast_raw = value_after($0, "forecast")

    if (!unsigned_number(turn) || !unsigned_number(states) || states + 0 < 1 ||
        states + 0 > 8 || !unsigned_number(active) || active + 0 < 1 ||
        active + 0 > states + 0 || !unsigned_number(winner) || winner + 0 < 1 ||
        (event != "updated" && event != "born" && event != "replaced") ||
        !number(similarity) || similarity + 0 < 0 || similarity + 0 > 1.001 ||
        !number(entropy) || entropy + 0 < 0 || entropy + 0 > 1.001 ||
        (adjacent != "0" && adjacent != "1"))
        fail()

    if (event == "replaced") {
        if (!unsigned_number(replaced) || replaced + 0 < 1) fail()
    } else if (replaced != "") {
        fail()
    } else {
        replaced = 0
    }

    member_n = split(members, member_items, ",")
    member_sum = 0
    winner_seen = 0
    if (member_n != states + 0) fail()
    for (i = 1; i <= member_n; i++) {
        colon = index(member_items[i], ":")
        if (!colon) fail()
        member_id = substr(member_items[i], 1, colon - 1)
        member_activation = substr(member_items[i], colon + 1)
        if (!unsigned_number(member_id) || member_id + 0 < 1 ||
            !number(member_activation) || member_activation + 0 < 0 ||
            member_activation + 0 > 1.001)
            fail()
        if (member_id == winner) winner_seen = 1
        member_sum += member_activation
        for (j = 1; j < i; j++)
            if (member_items[j] ~ ("^" member_id ":")) fail()
    }
    if (!winner_seen || member_sum < 0.995 || member_sum > 1.005) fail()

    if (adjacent == "1") {
        if (observed_raw == "") fail()
        parse_quad(observed_raw, observed)
    } else {
        if (observed_raw != "") fail()
        for (i = 1; i <= 4; i++) observed[i] = "na"
    }

    has_prediction = expected_raw != "" ? 1 : 0
    if (has_prediction) {
        open_pos = index(expected_raw, "(")
        close_pos = index(expected_raw, ")")
        if (!open_pos || close_pos != length(expected_raw)) fail()
        expected = substr(expected_raw, 1, open_pos - 1)
        expected_probability = substr(expected_raw, open_pos + 1,
                                      close_pos - open_pos - 1)
        if (!unsigned_number(expected) || expected + 0 < 1 ||
            !number(expected_probability) || expected_probability + 0 < 0 ||
            expected_probability + 0 > 1.001 || !number(overlap) ||
            overlap + 0 < 0 || overlap + 0 > 1.001 ||
            !number(surprise) || surprise + 0 < 0 || forecast_raw == "")
            fail()
        parse_quad(forecast_raw, forecast)
    } else {
        if (overlap != "" || surprise != "" || forecast_raw != "") fail()
        expected = 0
        expected_probability = 0
        overlap = 0
        surprise = 0
        for (i = 1; i <= 4; i++) forecast[i] = "na"
    }
}

END {
    if (fatal) exit 2
    if (found != 1) exit 1
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%.3f\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(cell), clean(cohort), clean(base_seed), clean(phase),
           clean(session), clean(order), clean(texture), clean(run_seed),
           turn, states, active, winner, event, similarity, entropy, members,
           member_sum, adjacent, replaced, has_prediction, expected,
           expected_probability, overlap, surprise,
           observed[1], observed[2], observed[3], observed[4],
           forecast[1], forecast[2], forecast[3], forecast[4],
           clean(prompt), clean(reply)
}
