#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *kind;
    const char *surface;
    const char *intermediate;
    const char *deep;
    int surface_heard;
    int intermediate_heard;
    int deep_heard;
    int deep_learned;
    int add_mean;
} TwoLayerCase;

static const TwoLayerCase CASES[] = {
    {"natural", "meaningful", "meaning", "mean", 1, 1, 7, 0, 0},
    {"edge-threshold", "zorbledness", "zorbled", "zorble", 1, 1, 2, 0, 0},
    {"learned-deep", "zorbledness", "zorbled", "zorble", 1, 1, 0, 1, 0},
    {"semantic-deep", "peacefully", "peaceful", "peace", 1, 1, 0, 0, 0},
    {"plural-outer", "kindnesses", "kindness", "kind", 1, 1, 0, 0, 0},
    {"thin-chain", "zorbledness", "zorbled", "zorble", 1, 1, 1, 0, 0},
    {"surface-only", "zorbledness", "zorbled", "zorble", 3, 0, 0, 0, 0},
    {"intermediate-only", "zorbledness", "zorbled", "zorble", 1, 3, 0, 0, 0},
    {"path-sum-only", "zorbledness", "zorbled", "zorble", 1, 1, 1, 0, 0},
    {"unseen-deep", "flimmedness", "flimmed", "flim", 1, 1, 0, 0, 0},
    {"three-layer", "meaningfully", "meaningful", "meaning", 1, 1, 1, 0, 7},
    {"unrelated", "newsworthy", "newsworth", "news", 1, 1, 7, 0, 0},
    {NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0}
};

static const char *evidence_name(LeoSchoolFamilyEvidence evidence) {
    switch (evidence) {
        case LEO_SCHOOL_FAMILY_MEANING: return "meaning";
        case LEO_SCHOOL_FAMILY_HEARD: return "heard";
        case LEO_SCHOOL_FAMILY_COMPOUND: return "compound";
        default: return "none";
    }
}

static Leo *seed_body(const TwoLayerCase *test) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return NULL;
    leo_init(leo);
    for (int n = 0; n < test->surface_heard; n++)
        leo_heard_add(&leo->heard, test->surface);
    for (int n = 0; n < test->intermediate_heard; n++)
        leo_heard_add(&leo->heard, test->intermediate);
    for (int n = 0; n < test->deep_heard; n++)
        leo_heard_add(&leo->heard, test->deep);
    for (int n = 0; n < test->add_mean; n++)
        leo_heard_add(&leo->heard, "mean");
    if (test->deep_learned)
        leo_school_learn(leo, test->deep, semtok_find_glyph("water"));
    return leo;
}

static void set_court_flags(void) {
    g_leo_school_lexical_family_on = 1;
    g_leo_school_lexical_role_on = 0;
    g_leo_school_negative_family_on = 0;
    g_leo_school_reciprocal_s_family_on = 0;
    g_leo_school_family_heard_threshold_on = 1;
}

static const char *question_for(Leo *leo, const char *surface, int composition) {
    static char unknown[LEO_HEARD_WORDLEN];
    unknown[0] = 0;
    g_leo_school_two_layer_family_composition_on = composition;
    return leo_school_find_unknown(leo, surface, unknown) ? unknown : "none";
}

static int run_interaction(void) {
    TwoLayerCase test = {
        "natural", "meaningful", "meaning", "mean", 1, 1, 7, 0, 0
    };
    Leo *leo = seed_body(&test);
    if (!leo) return 2;
    set_court_flags();
    puts("lexical_family\ttwo_layer_family_composition\tquestion");
    for (int lexical = 0; lexical <= 1; lexical++) {
        for (int composition = 0; composition <= 1; composition++) {
            char unknown[LEO_HEARD_WORDLEN] = {0};
            g_leo_school_lexical_family_on = lexical;
            g_leo_school_two_layer_family_composition_on = composition;
            int found = leo_school_find_unknown(leo, "meaningful", unknown);
            printf("%d\t%d\t%s\n", lexical, composition,
                   found ? unknown : "none");
        }
    }
    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "--interaction"))
        return run_interaction();
    if (argc != 1) return 2;

    puts("kind\tsurface\tintermediate\tdeep\tsurface_heard\tintermediate_heard\tdeep_heard\tdeep_learned\tone_layer_evidence\tone_layer_base\ttwo_layer_evidence\ttwo_layer_base\tdefault_question\tablation_question");
    for (int i = 0; CASES[i].kind; i++) {
        Leo *leo = seed_body(&CASES[i]);
        if (!leo) return 2;
        set_court_flags();

        char one_base[LEO_HEARD_WORDLEN] = {0};
        char two_base[LEO_HEARD_WORDLEN] = {0};
        LeoSchoolFamilyEvidence one = leo_school_lexical_family(
            leo, CASES[i].surface, one_base);
        LeoSchoolFamilyEvidence two = leo_school_two_layer_family_composition(
            leo, CASES[i].surface, two_base);
        const char *default_question = question_for(leo, CASES[i].surface, 1);
        char default_copy[LEO_HEARD_WORDLEN] = {0};
        strncpy(default_copy, default_question, sizeof default_copy - 1);
        const char *ablation_question = question_for(leo, CASES[i].surface, 0);

        printf("%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n",
               CASES[i].kind, CASES[i].surface, CASES[i].intermediate,
               CASES[i].deep, CASES[i].surface_heard,
               CASES[i].intermediate_heard, CASES[i].deep_heard,
               CASES[i].deep_learned, evidence_name(one),
               one_base[0] ? one_base : "none", evidence_name(two),
               two_base[0] ? two_base : "none",
               default_copy[0] ? default_copy : "none", ablation_question);
        leo_free(leo);
        free(leo);
    }
    return 0;
}
