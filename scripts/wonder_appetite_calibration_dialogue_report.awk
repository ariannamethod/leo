# Extract one slow deferred-Wonder appetite-calibration receipt per lived turn.

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

/\[wonder-appetite-calibration: turn=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed), value_after($0, "turn"),
           value_after($0, "pending"), value_after($0, "scored"),
           value_after($0, "confirmed"), value_after($0, "external"),
           value_after($0, "lost"), value_after($0, "unscorable"),
           value_after($0, "brier"), value_after($0, "entries")
}
