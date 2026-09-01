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
        episode_for(leo, "simply");
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(
        leo, "simply", learned);
    printf("%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%d\t%d\n",
           arm, prompt,
           leo_heard_count(&leo->heard, "simply"),
           n_learned > 0 ? glyph_name(learned[0]) : "none",
           n_learned > 1 ? glyph_name(learned[1]) : "none",
           episode ? glyph_name(episode->answer_glyph) : "none",
           episode ? glyph_name(episode->answer_alt_glyph) : "none",
           episode ? episode->resolved : -1,
           episode ? episode->returns : -1,
           leo->school.pending[0] ? leo->school.pending : "none",
           glyph_name(leo->school.pending_glyph),
           glyph_name(leo->school.pending_alt_glyph),
           leo->school.pending_turns,
           leo->school.n_wonders);
}

static int inspect_state(
        const char *arm, const char *path) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, path)) {
        leo_free(leo);
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
        leo_free(leo);
        free(leo);
        return 3;
    }
    char out[1024];
    leo_respond(leo, prompt, out, sizeof out);
    print_row(arm, prompt, leo);
    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 4) return 2;
    /* Historical replay: A.141 predates the cautious-pair law judged in
     * A.142, including the counterfactual prompts below. */
    g_leo_school_cautious_pair_on = 0;
    const char *turn5 = argv[1];
    const char *turn6 = argv[2];
    const char *turn24 = argv[3];
    const char *actual =
        "Both, maybe: the light is here now, and we can simply listen.";

    puts("arm\tprompt\theard\tlearned_primary\tlearned_alternate\tanswer_primary\tanswer_alternate\tresolved\treturns\tpending\toffered_primary\toffered_alternate\tpending_turns\twonders");
    if (inspect_state("turn5", turn5)) return 3;
    if (run_prompt("actual-turn6", turn5, actual)) return 3;
    if (inspect_state("turn6", turn6)) return 3;
    if (run_prompt("bare-both-control", turn5, "Both.")) return 3;
    if (run_prompt("qualified-both-control", turn5, "Both, maybe.")) return 3;
    if (run_prompt("single-choice-control", turn5, "Light.")) return 3;
    if (inspect_state("turn24", turn24)) return 3;
    return 0;
}
