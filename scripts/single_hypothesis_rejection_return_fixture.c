#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *kind;
    const char *prompt;
    int sleep_after_rejection;
} RejectionReturnCase;

static const RejectionReturnCase CASES[] = {
    {"literal-return", "what is zorble?", 0},
    {"sleep-literal-return", "what is zorble?", 1},
    {"rejected-anaphora", "is it water?", 0},
    {"unoffered-anaphora", "is it animal?", 0},
    {"later-positive", "a zorble is animal", 0},
    {NULL, NULL, 0}
};

static const char *glyph_name(int glyph) {
    return glyph >= 0 && glyph < GLYPH_COUNT ? GLYPH_NAMES[glyph] : "none";
}

static const LeoWonderEpisode *episode_for(const Leo *leo, const char *word) {
    for (int i = 0; i < leo->school.n_wonders; i++)
        if (!strcmp(leo->school.wonders[i].word, word))
            return &leo->school.wonders[i];
    return NULL;
}

static void seed_single_hypothesis(Leo *leo) {
    leo_init(leo);
    leo_ingest(
        leo,
        "the rain falls. his mother is warm. the cat drinks water.");
    leo->school.turn_clock = 1;
    strncpy(leo->school.pending, "zorble",
            sizeof leo->school.pending - 1);
    leo->school.pending_glyph = semtok_word("water");
    leo->school.pending_alt_glyph = -1;
    leo->school.pending_turns = 0;
    leo_pending_wonder_origin_begin(
        leo, leo->school.pending,
        leo->school.pending_glyph,
        leo->school.pending_alt_glyph,
        1, NULL, NULL);
    leo_wonder_open(
        leo, leo->school.pending,
        leo->school.pending_glyph,
        leo->school.pending_alt_glyph);
}

static int reject_only_hypothesis(Leo *leo) {
    char out[1024];
    leo_respond(leo, "a zorble is not water", out, sizeof out);
    const LeoWonderEpisode *episode = episode_for(leo, "zorble");
    return !leo_school_is_learned(leo, "zorble") &&
           !strcmp(leo->school.pending, "zorble") &&
           leo->school.pending_glyph == -1 &&
           leo->school.pending_alt_glyph == -1 &&
           episode && !episode->resolved &&
           episode->offered_glyph == -1 &&
           episode->offered_alt_glyph == -1;
}

static void print_row(
        const char *kind, const char *prompt,
        const Leo *leo, const char *word, const char *reply) {
    const LeoWonderEpisode *episode = episode_for(leo, word);
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(leo, word, learned);
    const char *reply_kind = episode && episode->returns > 0 ? reply : "ordinary";
    printf("%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\n",
           kind, prompt,
           leo->school.pending[0] ? leo->school.pending : "none",
           glyph_name(leo->school.pending_glyph),
           glyph_name(leo->school.pending_alt_glyph),
           n_learned > 0 ? glyph_name(learned[0]) : "none",
           episode ? episode->resolved : -1,
           episode ? episode->returns : -1,
           reply_kind);
}

static int run_synthetic(const char *state_path) {
    puts("kind\treturn_prompt\tpending\tprimary\talternate\tlearned\tresolved\treturns\treply");
    for (int i = 0; CASES[i].kind; i++) {
        Leo *leo = calloc(1, sizeof *leo);
        Leo *woke = NULL;
        if (!leo) return 2;
        seed_single_hypothesis(leo);
        if (!reject_only_hypothesis(leo)) return 3;
        Leo *body = leo;
        if (CASES[i].sleep_after_rejection) {
            if (!leo_save_state(leo, state_path)) return 4;
            woke = calloc(1, sizeof *woke);
            if (!woke) return 2;
            leo_init(woke);
            if (!leo_load_state(woke, state_path)) return 5;
            body = woke;
        }
        char out[1024];
        leo_respond(body, CASES[i].prompt, out, sizeof out);
        print_row(CASES[i].kind, CASES[i].prompt,
                  body, "zorble", out);
        leo_free(leo);
        if (woke) leo_free(woke);
        free(leo);
        free(woke);
    }
    return 0;
}

static int run_natural(const char *state_path) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, state_path)) return 3;
    if (strcmp(leo->school.pending, "difficult") ||
        leo->school.pending_glyph != -1 ||
        leo->school.pending_alt_glyph != -1 ||
        leo_school_is_learned(leo, "difficult"))
        return 4;
    char out[1024];
    const char *prompt = "What is difficult?";
    leo_respond(leo, prompt, out, sizeof out);
    puts("kind\treturn_prompt\tpending\tprimary\talternate\tlearned\tresolved\treturns\treply");
    print_row("natural-a134", prompt, leo, "difficult", out);
    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    if (argc == 3 && !strcmp(argv[1], "--synthetic"))
        return run_synthetic(argv[2]);
    if (argc == 3 && !strcmp(argv[1], "--natural"))
        return run_natural(argv[2]);
    return 2;
}
