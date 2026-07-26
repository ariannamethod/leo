# Extract one read-only pre-Wonder inventory receipt per lived turn.

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

/\[pre-wonder: turn=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed), value_after($0, "turn"),
           value_after($0, "count"), value_after($0, "pending"),
           value_after($0, "episodes"), value_after($0, "resolved"),
           value_after($0, "entries")
}
