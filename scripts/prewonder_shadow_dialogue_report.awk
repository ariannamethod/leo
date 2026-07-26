# Extract one transient semantic pre-Wonder receipt per lived turn.

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

/\[pre-wonder-shadow: turn=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed), value_after($0, "turn"),
           value_after($0, "status"), value_after($0, "winner"),
           value_after($0, "margin"), value_after($0, "pending"),
           value_after($0, "entries")
}
