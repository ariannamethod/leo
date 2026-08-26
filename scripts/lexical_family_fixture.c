#define LEO_NO_MAIN
#include "../leo.c"

static const char *evidence_name(LeoSchoolFamilyEvidence evidence) {
    switch (evidence) {
        case LEO_SCHOOL_FAMILY_MEANING: return "meaning";
        case LEO_SCHOOL_FAMILY_HEARD: return "heard";
        case LEO_SCHOOL_FAMILY_COMPOUND: return "compound";
        default: return "none";
    }
}

static void print_case(Leo *leo, const char *kind, const char *surface) {
    char base[LEO_HEARD_WORDLEN] = {0};
    char unknown[LEO_HEARD_WORDLEN] = {0};
    LeoSchoolFamilyEvidence evidence =
        leo_school_lexical_family(leo, surface, base);
    g_leo_school_lexical_family_on = 1;
    int default_found = leo_school_find_unknown(leo, surface, unknown);
    char default_word[LEO_HEARD_WORDLEN] = {0};
    if (default_found) strncpy(default_word, unknown, sizeof default_word - 1);
    g_leo_school_lexical_family_on = 0;
    int ablation_found = leo_school_find_unknown(leo, surface, unknown);
    printf("%s\t%s\t%s\t%s\t%s\t%s\n", kind, surface,
           evidence_name(evidence), base[0] ? base : "none",
           default_found ? default_word : "none",
           ablation_found ? unknown : "none");
}

int main(void) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    g_leo_school_negative_family_on = 0;
    g_leo_school_reciprocal_s_family_on = 0;
    leo_init(leo);
    g_leo_school_lexical_role_on = 0;

    static const char *const witnessed[] = {
        "belong", "calm", "respect", "dust", "neighbour", "brought", NULL
    };
    for (int i = 0; witnessed[i]; i++)
        for (int n = 0; n <= LEO_SCHOOL_NOVEL_MAX; n++)
            leo_heard_add(&leo->heard, witnessed[i]);

    puts("kind\tsurface\tevidence\tbase\tdefault_question\tablation_question");
    print_case(leo, "suffix", "rainy");
    print_case(leo, "suffix", "belonged");
    print_case(leo, "compound", "outdoors");
    print_case(leo, "suffix", "dusty");
    print_case(leo, "suffix", "calmer");
    print_case(leo, "suffix", "respecting");
    print_case(leo, "suffix", "making");
    print_case(leo, "suffix", "stopped");
    print_case(leo, "suffix", "stories");
    print_case(leo, "suffix", "happiness");
    print_case(leo, "compound", "bedroom");
    print_case(leo, "orthography", "neighbor");
    print_case(leo, "irregular", "loss");
    print_case(leo, "irregular", "bring");
    print_case(leo, "whole-word-control", "beneath");
    print_case(leo, "whole-word-control", "news");
    print_case(leo, "substring-control", "lover");
    print_case(leo, "substring-control", "moth");
    print_case(leo, "substring-control", "thing");
    print_case(leo, "grammar-compound-control", "without");
    print_case(leo, "incomplete-compound-control", "raincoat");
    print_case(leo, "unwitnessed-root-control", "smooth");
    print_case(leo, "unwitnessed-root-control", "fragile");
    print_case(leo, "unlearned-root-control", "zorbled");
    leo_school_learn(leo, "zorble", semtok_find_glyph("water"));
    print_case(leo, "learned-root", "zorbled");

    g_leo_school_lexical_family_on = 1;
    leo_free(leo);
    free(leo);
    return 0;
}
