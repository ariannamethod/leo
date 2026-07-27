# Extract one A.53 current-life transport witness from a Leo debug log.

function clean(value) {
    gsub(/\t/, "\\t", value)
    gsub(/\r/, "", value)
    return value
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

/\[wonder-appetite-transport: min-arm=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed),
           value_after($0, "min-arm"),
           value_after($0, "ceiling"),
           value_after($0, "unattested"),
           value_after($0, "pending"),
           value_after($0, "refuted"),
           value_after($0, "incompatible"),
           value_after($0, "observing"),
           value_after($0, "shifted"),
           value_after($0, "provisional"),
           value_after($0, "cells")
}
