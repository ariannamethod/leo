#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *kind;
    const char *surface;
    const char *relative;
    int surface_heard;
    int relative_heard;
    int learned;
} FamilyThresholdCase;

static const FamilyThresholdCase CASES[] = {
    {"natural-onions", "onions", "onion", 2, 2, 0},
    {"threshold-plural", "zorbles", "zorble", 1, 2, 0},
    {"thin-plural", "zorbles", "zorble", 1, 1, 0},
    {"surface-only", "zorbles", "zorble", 3, 0, 0},
    {"base-familiar", "zorbles", "zorble", 1, 3, 0},
    {"base-learned", "zorbles", "zorble", 1, 0, 1},
    {"past-pair", "guided", "guide", 1, 2, 0},
    {"closed-bridge", "neighbor", "neighbour", 1, 2, 0},
    {"reverse-control", "onion", "onions", 2, 2, 0},
    {"news-control", "news", "new", 2, 2, 0},
    {"doubled-s-control", "press", "pres", 2, 2, 0},
    {"substring-control", "rain", "training", 2, 2, 0},
    {NULL, NULL, NULL, 0, 0, 0}
};

static const char *evidence_name(LeoSchoolFamilyEvidence evidence) {
    switch (evidence) {
        case LEO_SCHOOL_FAMILY_MEANING: return "meaning";
        case LEO_SCHOOL_FAMILY_HEARD: return "heard";
        case LEO_SCHOOL_FAMILY_COMPOUND: return "compound";
        default: return "none";
    }
}

static Leo *seed_body(const FamilyThresholdCase *test) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return NULL;
    leo_init(leo);
    for (int n = 0; n < test->surface_heard; n++)
        leo_heard_add(&leo->heard, test->surface);
    for (int n = 0; n < test->relative_heard; n++)
        leo_heard_add(&leo->heard, test->relative);
    if (test->learned)
        leo_school_learn(
            leo, test->relative, semtok_find_glyph("water"));
    return leo;
}

static int run_interaction(void) {
    FamilyThresholdCase test = {
        "natural-onions", "onions", "onion", 2, 2, 0
    };
    Leo *leo = seed_body(&test);
    if (!leo) return 2;
    g_leo_school_lexical_role_on = 0;
    g_leo_school_negative_family_on = 0;
    g_leo_school_reciprocal_s_family_on = 0;
    puts("lexical_family\tfamily_heard_threshold\tquestion");
    for (int lexical = 0; lexical <= 1; lexical++) {
        for (int threshold = 0; threshold <= 1; threshold++) {
            char unknown[LEO_HEARD_WORDLEN] = {0};
            g_leo_school_lexical_family_on = lexical;
            g_leo_school_family_heard_threshold_on = threshold;
            int found = leo_school_find_unknown(leo, "onions", unknown);
            printf("%d\t%d\t%s\n", lexical, threshold,
                   found ? unknown : "none");
        }
    }
    leo_free(leo);
    free(leo);
    return 0;
}

static int run_corpus(const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) return 2;
    if (fseek(fp, 0, SEEK_END) != 0) return 2;
    long size = ftell(fp);
    if (size < 0 || fseek(fp, 0, SEEK_SET) != 0) return 2;
    char *text = malloc((size_t)size + 1);
    Leo *leo = calloc(1, sizeof *leo);
    if (!text || !leo) return 2;
    if (fread(text, 1, (size_t)size, fp) != (size_t)size) return 2;
    text[size] = 0;
    fclose(fp);
    leo_init(leo);
    leo_ingest(leo, text);
    leo_ingest(leo, LEO_EMBEDDED_BOOTSTRAP);
    free(text);
    puts("phase\tonion\tonions\tjoint");
    int onion = leo_heard_count(&leo->heard, "onion");
    int onions = leo_heard_count(&leo->heard, "onions");
    printf("startup\t%d\t%d\t%d\n", onion, onions, onion + onions);
    leo_heard_ingest(
        &leo->heard,
        "The kitchen smells better once the onions start browning. "
        "What are you making?");
    onion = leo_heard_count(&leo->heard, "onion");
    onions = leo_heard_count(&leo->heard, "onions");
    printf("meal-turn-1\t%d\t%d\t%d\n", onion, onions, onion + onions);
    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    g_leo_school_two_layer_family_composition_on = 0;
    if (argc == 2 && !strcmp(argv[1], "--interaction"))
        return run_interaction();
    if (argc == 3 && !strcmp(argv[1], "--corpus"))
        return run_corpus(argv[2]);
    if (argc != 1) return 2;

    puts("kind\tsurface\trelative\tsurface_heard\trelative_heard\tcandidate_evidence\tcandidate_base\tablation_evidence\tablation_base");
    for (int i = 0; CASES[i].kind; i++) {
        Leo *leo = seed_body(&CASES[i]);
        if (!leo) return 2;
        char candidate_base[LEO_HEARD_WORDLEN] = {0};
        char ablation_base[LEO_HEARD_WORDLEN] = {0};
        g_leo_school_family_heard_threshold_on = 1;
        LeoSchoolFamilyEvidence candidate = leo_school_lexical_family(
            leo, CASES[i].surface, candidate_base);
        g_leo_school_family_heard_threshold_on = 0;
        LeoSchoolFamilyEvidence ablation = leo_school_lexical_family(
            leo, CASES[i].surface, ablation_base);
        printf("%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\n",
               CASES[i].kind, CASES[i].surface, CASES[i].relative,
               CASES[i].surface_heard, CASES[i].relative_heard,
               evidence_name(candidate),
               candidate_base[0] ? candidate_base : "none",
               evidence_name(ablation),
               ablation_base[0] ? ablation_base : "none");
        leo_free(leo);
        free(leo);
    }
    g_leo_school_family_heard_threshold_on = 1;
    return 0;
}
