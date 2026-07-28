# Extract the A.56 source-aware checkpoint and sequence from a Leo debug log.

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

/\[wonder-appetite-checkpoint: budget=/ {
    checkpoint = 1
    budget = value_after($0, "budget")
    epochs = value_after($0, "epochs")
    history = value_after($0, "history")
    active = value_after($0, "active")
    terminal = value_after($0, "terminal")
    blocked = value_after($0, "blocked")
    checkpoint_cells = value_after($0, "cells")
}

/\[wonder-appetite-checkpoint-sequence: one=/ {
    sequence = 1
    one = value_after($0, "one")
    stable = value_after($0, "stable-provisional")
    emerging = value_after($0, "emerging-shift")
    persistent = value_after($0, "persistent-shift")
    recovered = value_after($0, "recovered")
    insufficient = value_after($0, "insufficient")
    incompatible = value_after($0, "incompatible")
    sequence_cells = value_after($0, "cells")
}

END {
    if (!checkpoint || !sequence)
        exit
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
           clean(scenario), clean(seed), budget, epochs, history,
           active, terminal, blocked, clean(checkpoint_cells),
           one, stable, emerging, persistent, recovered,
           insufficient, incompatible, clean(sequence_cells)
}
