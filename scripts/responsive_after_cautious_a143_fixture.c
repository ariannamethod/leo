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

static int inspect_word(
        const char *point, const char *state, const char *word) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, state)) {
        leo_free(leo);
        free(leo);
        return 3;
    }

    const LeoWonderEpisode *episode = episode_for(leo, word);
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(leo, word, learned);
    printf("%s\t%s\t%d\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\t%d\t%ld\t%ld\t%s\t%s\t%s\t%d\t%d\n",
           point, word, leo_heard_count(&leo->heard, word),
           n_learned > 0 ? glyph_name(learned[0]) : "none",
           n_learned > 1 ? glyph_name(learned[1]) : "none",
           episode ? 1 : 0,
           episode ? glyph_name(episode->offered_glyph) : "none",
           episode ? glyph_name(episode->offered_alt_glyph) : "none",
           episode ? glyph_name(episode->answer_glyph) : "none",
           episode ? glyph_name(episode->answer_alt_glyph) : "none",
           episode ? episode->resolved : -1,
           episode ? episode->returns : -1,
           episode ? episode->opened_step : -1,
           episode ? episode->closed_step : -1,
           leo->school.pending[0] ? leo->school.pending : "none",
           glyph_name(leo->school.pending_glyph),
           glyph_name(leo->school.pending_alt_glyph),
           leo->school.pending_turns,
           leo->school.n_wonders);

    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 5) return 2;
    puts("point\tword\theard\tlearned_primary\tlearned_alternate\tepisode\toffered_primary\toffered_alternate\tanswer_primary\tanswer_alternate\tresolved\treturns\topened_step\tclosed_step\tpending\tpending_primary\tpending_alternate\tpending_turns\twonders");
    if (inspect_word("turn6", argv[1], "simply")) return 3;
    if (inspect_word("turn19", argv[2], "simply")) return 3;
    if (inspect_word("turn19", argv[2], "receive")) return 3;
    if (inspect_word("turn20", argv[3], "receive")) return 3;
    if (inspect_word("turn24", argv[4], "simply")) return 3;
    if (inspect_word("turn24", argv[4], "receive")) return 3;
    return 0;
}
