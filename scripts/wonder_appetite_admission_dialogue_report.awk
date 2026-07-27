# Extract one A.52 immutable admission receipt from a Leo debug log.

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

/\[wonder-appetite-admission: attested=/ {
    printf "%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed),
           value_after($0, "attested"),
           value_after($0, "legacy"),
           value_after($0, "cells")
}
