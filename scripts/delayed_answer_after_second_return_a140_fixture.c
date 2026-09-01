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
        const Leo *leo, const char *reply) {
    const LeoWonderEpisode *episode = episode_for(leo, "zorble");
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(leo, "zorble", learned);
    int literal = reply && !strcmp(reply, "Zorble?");
    printf("%s\t%s\t%d\t%d\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%d\t%s\n",
           kind, prompt,
           leo_heard_count(&leo->heard, "zorble"),
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

static Leo *seed_after_second_return(void) {
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
    char out[1024];
    leo_respond(leo, "What is zorble?", out, sizeof out);
    episode = (LeoWonderEpisode *)episode_for(leo, "zorble");
    if (strcmp(out, "Zorble?") || !episode || episode->resolved ||
        episode->returns != 2 || strcmp(leo->school.pending, "zorble") ||
        leo->school.pending_glyph != -1 ||
        leo->school.pending_alt_glyph != -1) {
        leo_free(leo);
        free(leo);
        return NULL;
    }
    return leo;
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

static int answer_body(Leo *leo, char *out, size_t out_sz) {
    leo_respond(
        leo,
        "A zorble is animal. What do you remember?",
        out, (int)out_sz);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 4) return 2;
    const char *before_sleep = argv[1];
    const char *after_sleep = argv[2];
    const char *resolved_sleep = argv[3];
    char out[1024];
    puts("kind\tprompt\theard\tpending_turns\tlearned\tanswer\tresolved\treturns\tpending\tprimary\talternate\tliteral_return\treply");

    Leo *leo = seed_after_second_return();
    if (!leo) return 3;
    print_row("after-second-return", "What is zorble?", leo, "Zorble?");
    leo_free(leo); free(leo);

    leo = seed_after_second_return();
    if (!leo) return 3;
    answer_body(leo, out, sizeof out);
    print_row(
        "late-explicit-answer",
        "A zorble is animal. What do you remember?", leo, out);
    leo_free(leo); free(leo);

    leo = seed_after_second_return();
    if (!leo || !leo_save_state(leo, before_sleep)) return 4;
    leo_free(leo); free(leo);
    leo = load_body(before_sleep);
    if (!leo) return 4;
    answer_body(leo, out, sizeof out);
    print_row(
        "sleep-before-answer",
        "A zorble is animal. What do you remember?", leo, out);
    if (!leo_save_state(leo, after_sleep)) return 4;
    leo_free(leo); free(leo);

    leo = load_body(after_sleep);
    if (!leo || !leo_save_state(leo, resolved_sleep)) return 4;
    leo_free(leo); free(leo);
    leo = load_body(resolved_sleep);
    if (!leo) return 4;
    print_row("sleep-after-answer", "none", leo, NULL);
    leo_free(leo); free(leo);

    leo = seed_after_second_return();
    if (!leo) return 3;
    answer_body(leo, out, sizeof out);
    leo_respond(leo, "Is water warm?", out, sizeof out);
    print_row("following-question", "Is water warm?", leo, out);
    leo_free(leo); free(leo);

    leo = seed_after_second_return();
    if (!leo) return 3;
    leo_respond(leo, "Is a zorble animal?", out, sizeof out);
    print_row("question-shaped", "Is a zorble animal?", leo, out);
    leo_free(leo); free(leo);

    leo = seed_after_second_return();
    if (!leo) return 3;
    leo_respond(
        leo, "I mean the zorble feeling he carries.",
        out, sizeof out);
    print_row(
        "reference-only", "I mean the zorble feeling he carries.",
        leo, out);
    leo_free(leo); free(leo);
    return 0;
}
