# Extract one A.47 chronological drift surface from a Leo debug log.

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

/\[wonder-appetite-drift: measured=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed),
           value_after($0, "measured"),
           value_after($0, "forming"),
           value_after($0, "stable"),
           value_after($0, "rising"),
           value_after($0, "falling"),
           value_after($0, "cells")
}
