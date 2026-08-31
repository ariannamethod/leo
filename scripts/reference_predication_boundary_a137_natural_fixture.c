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

static int print_state(const char *arm, const char *path) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, path)) return 3;
    const LeoWonderEpisode *episode =
        episode_for(leo, "difficult");
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(
        leo, "difficult", learned);
    int resolved = 0;
    for (int i = 0; i < leo->school.n_wonders; i++)
        resolved += !!leo->school.wonders[i].resolved;

    printf("%s\t%d\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%d\t%d\n",
           arm,
           leo_heard_count(&leo->heard, "difficult"),
           n_learned > 0 ? glyph_name(learned[0]) : "none",
           episode ? glyph_name(episode->answer_glyph) : "none",
           episode ? episode->resolved : -1,
           episode ? episode->returns : -1,
           leo->school.pending[0] ? leo->school.pending : "none",
           glyph_name(leo->school.pending_glyph),
           glyph_name(leo->school.pending_alt_glyph),
           leo->school.n_wonders, resolved);
    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    puts("arm\tdifficult_heard\tlearned\tanswer\tresolved\treturns\tpending\tprimary\talternate\twonder_count\tresolved_count");
    if (print_state("candidate", argv[1])) return 3;
    if (print_state("control", argv[2])) return 3;
    return 0;
}
