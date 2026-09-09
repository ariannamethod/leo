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

static const LeoDeferredWonder *deferred_for(
        const Leo *leo, const char *word) {
    int index = leo_deferred_wonder_find(leo, word);
    return index >= 0 ? &leo->school.deferred[index] : NULL;
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
    const LeoDeferredWonder *deferred = deferred_for(leo, word);
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(leo, word, learned);
    printf("%s\t%s\t%d\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%u\t%llu\t%llu\t%d\t%ld\n",
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
           leo->school.pending[0] ? leo->school.pending : "none",
           glyph_name(leo->school.pending_glyph),
           glyph_name(leo->school.pending_alt_glyph),
           leo->school.pending_turns,
           leo->school.n_wonders,
           leo->school.n_learned,
           deferred ? 1 : 0,
           deferred ? deferred->blocks : 0,
           deferred ? (unsigned long long)deferred->born_turn : 0,
           deferred ? (unsigned long long)deferred->last_seen_turn : 0,
           leo->school.n_deferred,
           leo->school.turn_clock);

    leo_free(leo);
    free(leo);
    return 0;
}

static int inspect_words(
        const char *point, const char *state,
        const char *const *words) {
    for (int i = 0; words[i]; i++)
        if (inspect_word(point, state, words[i])) return 1;
    return 0;
}

static int save_again(const char *source, const char *saved) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, source)) {
        leo_free(leo);
        free(leo);
        return 3;
    }
    int ok = leo_save_state(leo, saved);
    leo_free(leo);
    free(leo);
    return ok ? 0 : 4;
}

int main(int argc, char **argv) {
    if (argc != 8) return 2;
    puts("point\tword\theard\tmeaning_primary\tmeaning_alternate\tepisode\toffered_primary\toffered_alternate\tanswer_primary\tanswer_alternate\tresolved\treturns\tpending\tpending_primary\tpending_alternate\tpending_turns\twonders\tschool_learned\tdeferred\tdeferred_blocks\tdeferred_born_turn\tdeferred_last_seen_turn\tdeferred_count\tturn_clock");
    static const char *const finished_yes[] = {"finished", "yes", NULL};
    static const char *const both[] = {"finished", "shelter", NULL};
    static const char *const shelter[] = {"shelter", NULL};
    static const char *const answer_scope[] = {
        "finished", "shelter", "man", "safe", "place", "one", NULL
    };
    if (inspect_words("turn2", argv[1], finished_yes)) return 3;
    if (inspect_words("turn9", argv[2], both)) return 4;
    if (inspect_words("turn10", argv[3], both)) return 5;
    if (inspect_words("turn12", argv[4], shelter)) return 6;
    if (inspect_words("turn13", argv[5], answer_scope)) return 7;
    if (inspect_words("turn24", argv[6], both)) return 8;
    if (save_again(argv[6], argv[7])) return 9;
    if (inspect_words("turn24-sleep", argv[7], both)) return 10;
    return 0;
}
