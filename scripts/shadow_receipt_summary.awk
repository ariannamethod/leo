BEGIN { FS = "\t" }

NR == 1 { next }

{
    proposals++
    action[$6]++
    if ($13 == "") {
        pending++
    } else {
        verdict[$13]++
        pair[$6 SUBSEP $13]++
    }
    if ($13 != "" && $13 != "unscorable") {
        scored++
        confidence[$6] += $8
        confidence_n[$6]++
    } else if ($13 == "unscorable") {
        unscorable++
    }
}

END {
    print "Leo shadow dialogue observatory"
    print "proposals=" proposals + 0, "scored=" scored + 0,
          "unscorable=" unscorable + 0, "pending=" pending + 0
    print ""
    print "actions"
    for (name in action) printf "  %-16s %d\n", name, action[name]
    print ""
    print "verdicts"
    for (name in verdict) printf "  %-16s %d\n", name, verdict[name]
    print ""
    print "action x verdict"
    for (key in pair) {
        split(key, names, SUBSEP)
        printf "  %-16s %-16s %d\n", names[1], names[2], pair[key]
    }
    print ""
    print "mean confidence (scored proposals)"
    for (name in confidence)
        printf "  %-16s %.3f\n", name, confidence[name] / confidence_n[name]
}
