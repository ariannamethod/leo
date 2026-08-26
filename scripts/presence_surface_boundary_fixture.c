#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *kind;
    const char *word;
    const char *text;
} PresenceSurfaceCase;

static const PresenceSurfaceCase CASES[] = {
    {"exact-lower", "rain", "Rain waits."},
    {"exact-case", "rain", "RAIN."},
    {"exact-punctuation", "rain", "The rain, then quiet."},
    {"infix-training", "rain", "Training takes time."},
    {"infix-brain", "rain", "A brain remembers."},
    {"infix-train", "rain", "The train stops."},
    {"compound-raincoat", "rain", "His raincoat is warm."},
    {"possessive-rains", "rain", "Rain's sound remains."},
    {"infix-kindness", "kind", "Kindness arrived."},
    {"unrelated", "rain", "The window is quiet."},
    {NULL, NULL, NULL}
};

static int run_interaction(void) {
    puts("school_word_boundary\tpresence_surface_boundary\tvoice_seen\tschool_seen");
    for (int school = 0; school <= 1; school++) {
        for (int presence = 0; presence <= 1; presence++) {
            g_leo_school_natural_word_boundary_on = school;
            g_leo_presence_surface_boundary_on = presence;
            printf("%d\t%d\t%d\t%d\n", school, presence,
                   leo_presence_surface_seen("Training takes time.", "rain"),
                   leo_school_text_has_word("Training takes time.", "rain"));
        }
    }
    g_leo_school_natural_word_boundary_on = 1;
    g_leo_presence_surface_boundary_on = 1;
    return 0;
}

int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "--interaction"))
        return run_interaction();
    if (argc != 1) return 2;

    puts("kind\tword\tdisplayed_text\tcandidate_seen\tablation_seen");
    for (int i = 0; CASES[i].kind; i++) {
        g_leo_presence_surface_boundary_on = 1;
        int candidate = leo_presence_surface_seen(CASES[i].text, CASES[i].word);
        g_leo_presence_surface_boundary_on = 0;
        int ablation = leo_presence_surface_seen(CASES[i].text, CASES[i].word);
        printf("%s\t%s\t%s\t%d\t%d\n",
               CASES[i].kind, CASES[i].word, CASES[i].text,
               candidate, ablation);
    }
    g_leo_presence_surface_boundary_on = 1;
    return 0;
}
