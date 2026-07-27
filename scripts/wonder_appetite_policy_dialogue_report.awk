# Extract one A.48 shadow-abstention surface from a Leo debug log.

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

/\[wonder-appetite-policy: eligible=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed),
           value_after($0, "eligible"),
           value_after($0, "forming"),
           value_after($0, "uncalibrated"),
           value_after($0, "drifting"),
           value_after($0, "legacy"),
           value_after($0, "none"),
           value_after($0, "supported"),
           value_after($0, "overreach"),
           value_after($0, "missed"),
           value_after($0, "restraint"),
           value_after($0, "confounded"),
           value_after($0, "pending"),
           value_after($0, "entries")
}
