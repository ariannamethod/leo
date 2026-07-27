# Extract one A.49 two-axis regret surface from a Leo debug log.

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

/\[wonder-appetite-regret: scored=/ {
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed),
           value_after($0, "scored"),
           value_after($0, "eligible"),
           value_after($0, "abstained"),
           value_after($0, "supported"),
           value_after($0, "overreach"),
           value_after($0, "missed"),
           value_after($0, "restraint"),
           value_after($0, "policy-forming"),
           value_after($0, "policy-uncalibrated"),
           value_after($0, "policy-drifting"),
           value_after($0, "pending"),
           value_after($0, "confounded"),
           value_after($0, "legacy"),
           value_after($0, "none"),
           value_after($0, "coverage"),
           value_after($0, "overreach-axis"),
           value_after($0, "missed-axis"),
           value_after($0, "forming-cells"),
           value_after($0, "eligible-cells"),
           value_after($0, "abstention-cells"),
           value_after($0, "paired-cells"),
           value_after($0, "cells")
}
