# Extract one A.51 out-of-sample holdout ledger from a Leo debug log.

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

/\[wonder-appetite-holdout: budget=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed),
           value_after($0, "budget"),
           value_after($0, "min-arm"),
           value_after($0, "ceiling"),
           value_after($0, "pending"),
           value_after($0, "confirmed"),
           value_after($0, "motion-failed"),
           value_after($0, "restraint-failed"),
           value_after($0, "both-failed"),
           value_after($0, "coverage-starved"),
           value_after($0, "invalidated"),
           value_after($0, "cells")
}
