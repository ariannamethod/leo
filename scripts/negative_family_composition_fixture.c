#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *kind;
    const char *surface;
} NegativeFamilyCase;

static const NegativeFamilyCase CASES[] = {
    {"natural", "unhurried"},
    {"direct", "unhappy"},
    {"nested", "unloved"},
    {"nested", "unrainy"},
    {"learned-root", "unzorbled"},
    {"unknown-root", "unflimmed"},
    {"indivisible", "uncle"},
    {"indivisible", "unique"},
    {"indivisible", "union"},
    {"other-prefix", "invisible"},
    {"short-relative", "unit"},
    {"a120-control", "hurried"},
    {NULL, NULL}
};

static const char *evidence_name(
        LeoSchoolFamilyEvidence evidence) {
    switch (evidence) {
        case LEO_SCHOOL_FAMILY_MEANING: return "meaning";
        case LEO_SCHOOL_FAMILY_HEARD: return "heard";
        case LEO_SCHOOL_FAMILY_COMPOUND: return "compound";
        default: return "none";
    }
}

static void seed_body(Leo *leo) {
    leo_init(leo);
    for (int n = 0; n <= LEO_SCHOOL_NOVEL_MAX; n++)
        leo_heard_add(&leo->heard, "hurry");
    leo_school_learn(
        leo, "zorble", semtok_find_glyph("water"));
}

static int run_interaction(Leo *leo) {
    puts("lexical_family\tnegative_family\tquestion");
    for (int lexical = 0; lexical <= 1; lexical++) {
        for (int negative = 0; negative <= 1; negative++) {
            char unknown[LEO_HEARD_WORDLEN] = {0};
            g_leo_school_lexical_family_on = lexical;
            g_leo_school_negative_family_on = negative;
            int found = leo_school_find_unknown(
                leo, "unhurried", unknown);
            printf("%d\t%d\t%s\n", lexical, negative,
                   found ? unknown : "none");
        }
    }
    return 0;
}

int main(int argc, char **argv) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    g_leo_school_reciprocal_s_family_on = 0;
    g_leo_school_family_heard_threshold_on = 0;
    g_leo_school_two_layer_family_composition_on = 0;
    seed_body(leo);
    if (argc == 2 && !strcmp(argv[1], "--interaction")) {
        int rc = run_interaction(leo);
        leo_free(leo);
        free(leo);
        return rc;
    }
    if (argc != 1) {
        leo_free(leo);
        free(leo);
        return 2;
    }

    puts("kind\tsurface\tevidence\tbase\tdefault_question\tablation_question");
    for (int i = 0; CASES[i].kind; i++) {
        char base[LEO_HEARD_WORDLEN] = {0};
        char unknown[LEO_HEARD_WORDLEN] = {0};
        LeoSchoolFamilyEvidence evidence =
            leo_school_negative_family(
                leo, CASES[i].surface, base);
        g_leo_school_negative_family_on = 1;
        int default_found = leo_school_find_unknown(
            leo, CASES[i].surface, unknown);
        char default_word[LEO_HEARD_WORDLEN] = {0};
        if (default_found)
            strncpy(default_word, unknown,
                    sizeof default_word - 1);
        g_leo_school_negative_family_on = 0;
        int ablation_found = leo_school_find_unknown(
            leo, CASES[i].surface, unknown);
        printf("%s\t%s\t%s\t%s\t%s\t%s\n",
               CASES[i].kind, CASES[i].surface,
               evidence_name(evidence),
               base[0] ? base : "none",
               default_found ? default_word : "none",
               ablation_found ? unknown : "none");
    }

    g_leo_school_lexical_family_on = 1;
    g_leo_school_negative_family_on = 1;
    leo_free(leo);
    free(leo);
    return 0;
}
