# A.85: classify return only when the no-displacement control owns the old ID.

function member_mass(value, wanted,    item, pair, n, i) {
    n = split(value, item, ",")
    for (i = 1; i <= n; i++) {
        split(item[i], pair, ":")
        if (pair[1] + 0 == wanted) return pair[2] + 0
    }
    return 0
}

function member_present(value, wanted,    item, pair, n, i) {
    n = split(value, item, ",")
    for (i = 1; i <= n; i++) {
        split(item[i], pair, ":")
        if (pair[1] + 0 == wanted) return 1
    }
    return 0
}

function other_max(value, wanted,    item, pair, n, i, best, mass) {
    best = 0
    n = split(value, item, ",")
    for (i = 1; i <= n; i++) {
        split(item[i], pair, ":")
        mass = pair[2] + 0
        if (pair[1] + 0 != wanted && mass > best) best = mass
    }
    return best
}

BEGIN {
    FS = "\t"
    OFS = "\t"
    print "case", "cell", "cohort", "base_seed", "trigger_turn",
          "displaced_id", "trigger_new_id", "probe", "kind", "return_seed",
          "control_event", "control_winner", "control_similarity",
          "control_old_mass", "control_margin", "displaced_event",
          "displaced_winner", "displaced_similarity", "qualified", "fate",
          "prompt", "reply"
}

NR == 1 { next }
{
    if (NF != 22 || $1 == "" || $6 !~ /^[0-9]+$/ ||
        $7 !~ /^[0-9]+$/ || $8 !~ /^[0-9]+$/)
        exit 2

    old_mass = member_mass($14, $6)
    margin = old_mass - other_max($14, $6)
    qualified = $11 == "updated" && $12 == $6 &&
                old_mass >= 0.20 && margin >= 0.02

    if (member_present($19, $6)) exit 2
    fate = "unanchored"
    if (qualified) {
        if ($16 == "replaced") fate = "rebirth"
        else if ($16 != "updated") exit 2
        else if ($17 == $7) fate = "trigger-capture"
        else fate = "survivor-return"
    }

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%.6f\t%.6f\t%.6f\t%s\t%s\t%.6f\t%s\t%s\t%s\t%s\n",
           $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
           $11, $12, $13, old_mass, margin, $16, $17, $18,
           qualified ? "true" : "false", fate, $21, $22
}
