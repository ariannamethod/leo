# Extract one A.46 reliability surface from a Leo debug log.

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

/\[wonder-appetite-reliability: scored=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed),
           value_after($0, "scored"),
           value_after($0, "positives"),
           value_after($0, "sustained"),
           value_after($0, "grounded"),
           value_after($0, "faded"),
           value_after($0, "pending"),
           value_after($0, "external"),
           value_after($0, "lost"),
           value_after($0, "unscorable"),
           value_after($0, "brier"),
           value_after($0, "ece"),
           value_after($0, "cells")
}
