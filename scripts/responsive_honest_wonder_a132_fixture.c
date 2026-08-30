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

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    g_leo_school_two_layer_family_composition_on = 0;
    if (!leo_load_state(leo, argv[1])) return 2;

    char meaningful_base[LEO_HEARD_WORDLEN] = {0};
    char meaning_base[LEO_HEARD_WORDLEN] = {0};
    LeoSchoolFamilyEvidence meaningful = leo_school_lexical_family(
        leo, "meaningful", meaningful_base);
    LeoSchoolFamilyEvidence meaning = leo_school_lexical_family(
        leo, "meaning", meaning_base);

    int lentil_glyphs[2] = {-1, -1};
    int n_lentil = leo_school_word_glyphs(leo, "lentil", lentil_glyphs);
    int lentil_episode_resolved = -1;
    for (int i = 0; i < leo->school.n_wonders; i++)
        if (!strcmp(leo->school.wonders[i].word, "lentil"))
            lentil_episode_resolved = leo->school.wonders[i].resolved;

    puts("metric\tvalue");
    printf("lentil_primary\t%s\n",
           n_lentil > 0 ? GLYPH_NAMES[lentil_glyphs[0]] : "none");
    printf("lentil_alternate\t%s\n",
           n_lentil > 1 ? GLYPH_NAMES[lentil_glyphs[1]] : "none");
    printf("lentil_episode_resolved\t%d\n", lentil_episode_resolved);
    printf("meaningful_heard\t%d\n",
           leo_heard_count(&leo->heard, "meaningful"));
    printf("meaning_heard\t%d\n",
           leo_heard_count(&leo->heard, "meaning"));
    printf("mean_heard\t%d\n", leo_heard_count(&leo->heard, "mean"));
    printf("meaningful_one_layer_evidence\t%s\n", evidence_name(meaningful));
    printf("meaningful_one_layer_base\t%s\n",
           meaningful_base[0] ? meaningful_base : "none");
    printf("meaning_one_layer_evidence\t%s\n", evidence_name(meaning));
    printf("meaning_one_layer_base\t%s\n",
           meaning_base[0] ? meaning_base : "none");
    printf("pending\t%s\n",
           leo->school.pending[0] ? leo->school.pending : "none");
    printf("wonder_count\t%d\n", leo->school.n_wonders);

    leo_free(leo);
    free(leo);
    return 0;
}
