# Extract one read-only School decision receipt per lived turn.

function clean(value) {
    gsub(/\t/, "\\t", value)
    gsub(/\r/, "", value)
    return value
}

function value_after(line, key,    start, tail, parts) {
    start = index(line, key "=")
    if (!start) return ""
    tail = substr(line, start + length(key) + 1)
    split(tail, parts, /[ ]/)
    gsub(/\]$/, "", parts[1])
    return parts[1]
}

/\[curiosity: turn=/ {
    turn = value_after($0, "turn")
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed), turn,
           value_after($0, "outcome"), value_after($0, "candidate"),
           value_after($0, "deferred"), value_after($0, "heard"),
           value_after($0, "distress"), value_after($0, "gate")
}
