#define LEO_NO_MAIN
#include "../leo.c"

static const char *glyph_name(int glyph) {
    return glyph >= 0 && glyph < GLYPH_COUNT ? GLYPH_NAMES[glyph] : "none";
}

static const LeoWonderEpisode *episode_for(const Leo *leo, const char *word) {
    for (int i = 0; i < leo->school.n_wonders; i++)
        if (!strcmp(leo->school.wonders[i].word, word))
            return &leo->school.wonders[i];
    return NULL;
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, argv[1])) return 2;

    const LeoWonderEpisode *lentil = episode_for(leo, "lentil");
    const LeoWonderEpisode *difficult = episode_for(leo, "difficult");
    int difficult_glyphs[2] = {-1, -1};
    int n_difficult = leo_school_word_glyphs(
        leo, "difficult", difficult_glyphs);
    int resolved = 0;
    for (int i = 0; i < leo->school.n_wonders; i++)
        resolved += !!leo->school.wonders[i].resolved;

    puts("metric\tvalue");
    printf("lentil_primary\t%s\n",
           lentil ? glyph_name(lentil->answer_glyph) : "none");
    printf("lentil_episode_resolved\t%d\n",
           lentil ? lentil->resolved : -1);
    printf("difficult_heard\t%d\n",
           leo_heard_count(&leo->heard, "difficult"));
    printf("difficult_learned_primary\t%s\n",
           n_difficult > 0 ? glyph_name(difficult_glyphs[0]) : "none");
    printf("difficult_episode_offered\t%s\n",
           difficult ? glyph_name(difficult->offered_glyph) : "none");
    printf("difficult_episode_answer\t%s\n",
           difficult ? glyph_name(difficult->answer_glyph) : "none");
    printf("difficult_episode_resolved\t%d\n",
           difficult ? difficult->resolved : -1);
    printf("difficult_episode_returns\t%d\n",
           difficult ? difficult->returns : -1);
    printf("pending\t%s\n",
           leo->school.pending[0] ? leo->school.pending : "none");
    printf("pending_primary\t%s\n",
           glyph_name(leo->school.pending_glyph));
    printf("pending_alternate\t%s\n",
           glyph_name(leo->school.pending_alt_glyph));
    printf("wonder_count\t%d\n", leo->school.n_wonders);
    printf("resolved_wonder_count\t%d\n", resolved);

    leo_free(leo);
    free(leo);
    return 0;
}
