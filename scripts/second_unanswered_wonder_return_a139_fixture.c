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
        const char *kind, const char *prompt,
        const Leo *leo, const char *word,
        const char *reply) {
    const LeoWonderEpisode *episode = episode_for(leo, word);
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(leo, word, learned);
    int literal = reply &&
        ((!strcmp(word, "difficult") && !strcmp(reply, "Difficult?")) ||
         (!strcmp(word, "zorble") && !strcmp(reply, "Zorble?")));
    printf("%s\t%s\t%d\t%d\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%d\t%s\n",
           kind, prompt,
           leo_heard_count(&leo->heard, word),
           leo->school.pending_turns,
           n_learned > 0 ? glyph_name(learned[0]) : "none",
           episode ? glyph_name(episode->answer_glyph) : "none",
           episode ? episode->resolved : -1,
           episode ? episode->returns : -1,
           leo->school.pending[0] ? leo->school.pending : "none",
           glyph_name(leo->school.pending_glyph),
           glyph_name(leo->school.pending_alt_glyph),
           literal,
           reply ? reply : "none");
}

static Leo *load_body(const char *path) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return NULL;
    leo_init(leo);
    if (!leo_load_state(leo, path)) {
        free(leo);
        return NULL;
    }
    return leo;
}

static int run_natural(
        const char *body_path, const char *sleep_path) {
    const char *prompt = "What is difficult?";
    puts("kind\tprompt\theard\tpending_turns\tlearned\tanswer\tresolved\treturns\tpending\tprimary\talternate\tliteral_return\treply");

    Leo *leo = load_body(body_path);
    if (!leo) return 2;
    print_row("turn35", "none", leo, "difficult", NULL);
    leo_free(leo); free(leo);

    leo = load_body(body_path);
    if (!leo) return 2;
    char out[1024];
    leo_respond(leo, prompt, out, sizeof out);
    print_row("second-return", prompt, leo, "difficult", out);
    leo_free(leo); free(leo);

    leo = load_body(body_path);
    if (!leo || !leo_save_state(leo, sleep_path)) return 3;
    leo_free(leo); free(leo);
    leo = load_body(sleep_path);
    if (!leo) return 3;
    leo_respond(leo, prompt, out, sizeof out);
    print_row("sleep-second-return", prompt, leo, "difficult", out);
    leo_free(leo); free(leo);

    leo = load_body(body_path);
    if (!leo) return 2;
    leo_respond(leo, prompt, out, sizeof out);
    leo_respond(leo, prompt, out, sizeof out);
    print_row("immediate-third", prompt, leo, "difficult", out);
    leo_free(leo); free(leo);
    return 0;
}

static Leo *seed_synthetic(void) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return NULL;
    leo_init(leo);
    leo_ingest(
        leo,
        "the rain falls. his mother is warm. the cat drinks water.");
    snprintf(leo->school.pending, sizeof leo->school.pending, "zorble");
    leo->school.pending_glyph = -1;
    leo->school.pending_alt_glyph = -1;
    leo->school.pending_turns = LEO_WONDER_REASK_GAP;
    LeoWonderEpisode *episode =
        leo_wonder_open(leo, "zorble", -1, -1);
    episode->returns = 1;
    return leo;
}

static int run_synthetic(const char *sleep_path) {
    const char *prompt = "What is zorble?";
    puts("kind\tprompt\theard\tpending_turns\tlearned\tanswer\tresolved\treturns\tpending\tprimary\talternate\tliteral_return\treply");

    Leo *leo = seed_synthetic();
    if (!leo) return 2;
    char out[1024];
    leo_respond(leo, prompt, out, sizeof out);
    print_row("synthetic-second", prompt, leo, "zorble", out);
    leo_free(leo); free(leo);

    leo = seed_synthetic();
    if (!leo || !leo_save_state(leo, sleep_path)) return 3;
    leo_free(leo); free(leo);
    leo = load_body(sleep_path);
    if (!leo) return 3;
    leo_respond(leo, prompt, out, sizeof out);
    print_row("synthetic-sleep-second", prompt, leo, "zorble", out);
    leo_free(leo); free(leo);

    leo = seed_synthetic();
    if (!leo) return 2;
    leo_respond(leo, prompt, out, sizeof out);
    leo_respond(leo, prompt, out, sizeof out);
    print_row("synthetic-immediate-third", prompt, leo, "zorble", out);
    leo_free(leo); free(leo);
    return 0;
}

int main(int argc, char **argv) {
    if (argc == 4 && !strcmp(argv[1], "--natural"))
        return run_natural(argv[2], argv[3]);
    if (argc == 3 && !strcmp(argv[1], "--synthetic"))
        return run_synthetic(argv[2]);
    return 2;
}
