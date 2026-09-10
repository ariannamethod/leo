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
    static const char *const opening[] = {
        "alive", "happy", "small", "remember", "new", NULL
    };
    static const char *const question[] = {
        "mysterious", "tender", "string", "grandmother", NULL
    };
    static const char *const attempted_answer[] = {
        "mysterious", "hard", "understand", "gentle", "important",
        "comfort", NULL
    };
    static const char *const voice_question[] = {
        "mysterious", "stone", "hand", "wait", NULL
    };
    static const char *const deferred[] = {
        "mysterious", "smooth", "heavy", "warm", "comforting",
        "stone", "fire", NULL
    };
    if (inspect_words("turn1", argv[1], opening)) return 3;
    if (inspect_words("turn13", argv[2], question)) return 4;
    if (inspect_words("turn14", argv[3], attempted_answer)) return 5;
    if (inspect_words("turn22", argv[4], voice_question)) return 6;
    if (inspect_words("turn23", argv[5], deferred)) return 7;
    if (inspect_words("turn24", argv[6], deferred)) return 8;
    if (save_again(argv[6], argv[7])) return 9;
    if (inspect_words("turn24-sleep", argv[7], deferred)) return 10;
    return 0;
}
