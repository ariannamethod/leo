#define LEO_NO_MAIN
#include "../leo.c"

typedef enum {
    SEED_NONE = 0,
    SEED_HEARD,
    SEED_THIN,
    SEED_MEANING
} SeedKind;

typedef struct {
    const char *kind;
    const char *surface;
    const char *relative;
    SeedKind seed;
} ReciprocalSCase;

static const ReciprocalSCase CASES[] = {
    {"natural", "prefer", "prefers", SEED_HEARD},
    {"learned", "prefer", "prefers", SEED_MEANING},
    {"unlisted", "zorble", "zorbles", SEED_HEARD},
    {"threshold", "prefer", "prefers", SEED_THIN},
    {"unheard", "narp", "narps", SEED_NONE},
    {"indivisible", "new", "news", SEED_HEARD},
    {"doubled-s", "pres", "press", SEED_HEARD},
    {"grammar", "alway", "always", SEED_HEARD},
    {"short", "thi", "this", SEED_HEARD},
    {"forward", "prefers", "prefer", SEED_HEARD},
    {NULL, NULL, NULL, SEED_NONE}
};

static const char *evidence_name(LeoSchoolFamilyEvidence evidence) {
    switch (evidence) {
        case LEO_SCHOOL_FAMILY_MEANING: return "meaning";
        case LEO_SCHOOL_FAMILY_HEARD: return "heard";
        case LEO_SCHOOL_FAMILY_COMPOUND: return "compound";
        default: return "none";
    }
}

static Leo *seed_body(const ReciprocalSCase *test) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return NULL;
    leo_init(leo);
    if (test->seed == SEED_HEARD) {
        for (int n = 0; n <= LEO_SCHOOL_NOVEL_MAX; n++)
            leo_heard_add(&leo->heard, test->relative);
    } else if (test->seed == SEED_THIN) {
        leo_heard_add(&leo->heard, test->relative);
    } else if (test->seed == SEED_MEANING) {
        leo_school_learn(leo, test->relative, semtok_find_glyph("water"));
    }
    return leo;
}

static int run_interaction(void) {
    ReciprocalSCase test = {"natural", "prefer", "prefers", SEED_HEARD};
    Leo *leo = seed_body(&test);
    if (!leo) return 2;
    g_leo_school_negative_family_on = 0;
    g_leo_school_family_heard_threshold_on = 0;
    g_leo_school_lexical_role_on = 0;
    puts("lexical_family\treciprocal_s_family\tquestion");
    for (int lexical = 0; lexical <= 1; lexical++) {
        for (int reciprocal = 0; reciprocal <= 1; reciprocal++) {
            char unknown[LEO_HEARD_WORDLEN] = {0};
            g_leo_school_lexical_family_on = lexical;
            g_leo_school_reciprocal_s_family_on = reciprocal;
            int found = leo_school_find_unknown(leo, "prefer", unknown);
            printf("%d\t%d\t%s\n", lexical, reciprocal,
                   found ? unknown : "none");
        }
    }
    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    g_leo_school_two_layer_family_composition_on = 0;
    if (argc == 2 && !strcmp(argv[1], "--interaction"))
        return run_interaction();
    if (argc != 1) return 2;

    g_leo_school_lexical_family_on = 0;
    g_leo_school_lexical_role_on = 0;
    g_leo_school_negative_family_on = 0;
    g_leo_school_family_heard_threshold_on = 0;
    puts("kind\tsurface\tevidence\trelative\tdefault_question\tablation_question");
    for (int i = 0; CASES[i].kind; i++) {
        Leo *leo = seed_body(&CASES[i]);
        if (!leo) return 2;
        char relative[LEO_HEARD_WORDLEN] = {0};
        char unknown[LEO_HEARD_WORDLEN] = {0};
        LeoSchoolFamilyEvidence evidence = leo_school_reciprocal_s_family(
            leo, CASES[i].surface, relative);
        g_leo_school_reciprocal_s_family_on = 1;
        int default_found = leo_school_find_unknown(
            leo, CASES[i].surface, unknown);
        char default_word[LEO_HEARD_WORDLEN] = {0};
        if (default_found)
            strncpy(default_word, unknown, sizeof default_word - 1);
        g_leo_school_reciprocal_s_family_on = 0;
        int ablation_found = leo_school_find_unknown(
            leo, CASES[i].surface, unknown);
        printf("%s\t%s\t%s\t%s\t%s\t%s\n",
               CASES[i].kind, CASES[i].surface,
               evidence_name(evidence), relative[0] ? relative : "none",
               default_found ? default_word : "none",
               ablation_found ? unknown : "none");
        leo_free(leo);
        free(leo);
    }
    g_leo_school_lexical_family_on = 1;
    g_leo_school_lexical_role_on = 1;
    g_leo_school_negative_family_on = 1;
    g_leo_school_reciprocal_s_family_on = 1;
    return 0;
}
