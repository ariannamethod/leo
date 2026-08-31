#define LEO_NO_MAIN
#include "../leo.c"

static const char *glyph_name(int glyph) {
    return glyph >= 0 && glyph < GLYPH_COUNT ?
        GLYPH_NAMES[glyph] : "none";
}

static const LeoWonderEpisode *episode_for(
        const Leo *leo, const char *word) {
    for (int i = 0; i < leo->school.n_wonders; i++)
        if (!strcmp(leo->school.wonders[i].word, word))
            return &leo->school.wonders[i];
    return NULL;
}

static void print_row(
        const char *arm, const char *prompt,
        const Leo *leo) {
    const LeoWonderEpisode *episode =
        episode_for(leo, "difficult");
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(
        leo, "difficult", learned);
    printf("%s\t%s\t%d\t%s\t%s\t%d\t%d\t%s\t%s\t%s\n",
           arm, prompt,
           leo_heard_count(&leo->heard, "difficult"),
           n_learned > 0 ? glyph_name(learned[0]) : "none",
           episode ? glyph_name(episode->answer_glyph) : "none",
           episode ? episode->resolved : -1,
           episode ? episode->returns : -1,
           leo->school.pending[0] ? leo->school.pending : "none",
           glyph_name(leo->school.pending_glyph),
           glyph_name(leo->school.pending_alt_glyph));
}

static int inspect_state(
        const char *arm, const char *path) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, path)) {
        free(leo);
        return 3;
    }
    print_row(arm, "none", leo);
    leo_free(leo);
    free(leo);
    return 0;
}

static int run_prompt(
        const char *arm, const char *path,
        const char *prompt) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, path)) {
        free(leo);
        return 3;
    }
    g_leo_school_reference_predication_on = 1;
    char out[1024];
    leo_respond(leo, prompt, out, sizeof out);
    print_row(arm, prompt, leo);
    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    const char *prefix_state = argv[1];
    const char *final_state = argv[2];
    const char *actual =
        "I meant the feeling he might be carrying. "
        "Does anything feel difficult right now?";

    puts("arm\tprompt\theard\tlearned\tanswer\tresolved\treturns\tpending\tprimary\talternate");
    if (inspect_state("turn25", prefix_state)) return 3;
    if (run_prompt("actual-turn26", prefix_state, actual)) return 3;
    if (run_prompt(
            "positive-control", prefix_state,
            "Difficult is pain.")) return 3;
    if (inspect_state("turn35", final_state)) return 3;
    g_leo_school_reference_predication_on = 1;
    return 0;
}
