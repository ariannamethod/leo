# Turn a raw Leo chat transcript into one causal row per shadow proposal.

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

BEGIN {
    n_prompts = 0
    while ((getline prompt < prompt_file) > 0) {
        if (prompt == "/quit" || prompt == "/exit") continue
        prompts[++n_prompts] = clean(prompt)
    }
    close(prompt_file)
    turn = 0
}

/^you> leo> / {
    turn++
    replies[turn] = clean(substr($0, length("you> leo> ") + 1))
    in_reply = 1
    next
}

/^     \[/ { in_reply = 0 }
/^you> / { in_reply = 0 }

in_reply {
    replies[turn] = replies[turn] "\\n" clean($0)
    next
}

/\[shadow: observed=/ {
    observed = value_after($0, "observed") + 0
    actions[observed] = value_after($0, "action")
    targets[observed] = value_after($0, "target")
    confidences[observed] = value_after($0, "confidence")
    reasons[observed] = value_after($0, "reasons")
    if (observed > max_proposal) max_proposal = observed
    next
}

/\[shadow-calibration: proposal=/ {
    proposal = value_after($0, "proposal") + 0
    calibration_turns[proposal] = value_after($0, "observed")
    verdicts[proposal] = value_after($0, "verdict")
    next
}

END {
    for (proposal = 1; proposal <= max_proposal; proposal++) {
        if (!(proposal in actions)) continue
        observed = proposal + 1
        if (proposal in calibration_turns) observed = calibration_turns[proposal]
        printf "%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
               clean(scenario), clean(seed), proposal,
               prompts[proposal], replies[proposal], actions[proposal],
               targets[proposal], confidences[proposal], reasons[proposal],
               (proposal in calibration_turns ? observed : ""),
               prompts[observed], replies[observed], verdicts[proposal]
    }
}
