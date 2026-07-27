# Extract one A.50 readiness frontier from a Leo debug log.

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

/\[wonder-appetite-readiness: ceiling=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed),
           value_after($0, "ceiling"),
           value_after($0, "min-arm"),
           value_after($0, "forming"),
           value_after($0, "unpaired"),
           value_after($0, "observing"),
           value_after($0, "motion-unbounded"),
           value_after($0, "restraint-unbounded"),
           value_after($0, "both-unbounded"),
           value_after($0, "candidate"),
           value_after($0, "cells")
}
