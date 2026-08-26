#define LEO_NO_MAIN
#include "../leo.c"

static const char *role_name(LeoSchoolLexicalRole role) {
    switch (role) {
        case LEO_SCHOOL_ROLE_RELATION: return "relation";
        case LEO_SCHOOL_ROLE_POLARITY: return "polarity";
        case LEO_SCHOOL_ROLE_DISCOURSE: return "discourse";
        default: return "none";
    }
}

static void print_case(Leo *leo, const char *kind, const char *surface) {
    const char *witness = NULL;
    char unknown[LEO_HEARD_WORDLEN] = {0};
    LeoSchoolLexicalRole role = leo_school_lexical_role(surface, &witness);
    g_leo_school_lexical_role_on = 1;
    int default_found = leo_school_find_unknown(leo, surface, unknown);
    char default_word[LEO_HEARD_WORDLEN] = {0};
    if (default_found) strncpy(default_word, unknown, sizeof default_word - 1);
    g_leo_school_lexical_role_on = 0;
    int ablation_found = leo_school_find_unknown(leo, surface, unknown);
    printf("%s\t%s\t%s\t%s\t%s\t%s\n", kind, surface,
           role_name(role), witness ? witness : "none",
           default_found ? default_word : "none",
           ablation_found ? unknown : "none");
}

int main(void) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    g_leo_school_negative_family_on = 0;
    g_leo_school_reciprocal_s_family_on = 0;
    g_leo_school_family_heard_threshold_on = 0;
    leo_init(leo);

    puts("kind\tsurface\trole\twitness\tdefault_question\tablation_question");
    for (int i = 0; LEO_SCHOOL_RELATION_WITNESSES[i].surface; i++)
        print_case(leo, "relation", LEO_SCHOOL_RELATION_WITNESSES[i].surface);
    print_case(leo, "polarity", "neither");
    print_case(leo, "polarity", "nor");
    print_case(leo, "polarity", "without");
    print_case(leo, "discourse", "except");
    print_case(leo, "discourse", "however");
    print_case(leo, "discourse", "instead");
    print_case(leo, "discourse", "rather");
    print_case(leo, "discourse", "yet");
    print_case(leo, "historical-operator", "like");
    print_case(leo, "historical-operator", "than");
    print_case(leo, "exact-control", "beneathness");
    print_case(leo, "exact-control", "nearbyish");
    print_case(leo, "exact-control", "surround");
    print_case(leo, "question-control", "toy");
    print_case(leo, "question-control", "smooth");
    print_case(leo, "question-control", "fragile");
    print_case(leo, "meaning-control", "nothing");
    print_case(leo, "meaning-control", "below");
    print_case(leo, "meaning-control", "outside");

    g_leo_school_lexical_role_on = 1;
    leo_free(leo);
    free(leo);
    return 0;
}
