/*
 * Leo's court. It opens a copy of a lived body without writing it back, lets
 * him answer the lines humans have actually said to him under many seeds, and
 * prices the speech:
 *
 *   M1 copying  sentences found verbatim in leo.txt; coverage by verbatim runs
 *               of at least 32 bytes and the longest one (Netta's census)
 *   M2 rails    word choices whose four-word frame had exactly one lived
 *               continuation
 *   M3 floor    words outside the lexicon; the mouth law makes this zero
 *   M4 body     answers that change when the same seed meets a rested body
 *
 * The court hears nothing: the heard record is marked full, so the shipped
 * overflow law keeps the shared grammar tables untouched between samples.
 *
 *   make court && ./court "copy of leo.state.body3" [leo.txt]
 *   ./court --self-check [leo.txt]
 */

#define main leo_body_main
#include "leo.c"
#undef main

#define COURT_SEEDS     20
#define COURT_RUN_BYTES 32

static const char *const COURT_LINES[] = {
    "Leo, are you here?", "I am here with you.", "I am listening.",
    "I am still here.", "I am staying with you.", "I am here, Leo.",
    "I am listening to you.", "I came back to listen.", "I am here again.",
};
#define COURT_N_LINES ((int)(sizeof COURT_LINES / sizeof COURT_LINES[0]))

static char *court_world;
static size_t court_world_n;

static int court_found(const char *needle, size_t m) {
    if (!m) return 1;
    for (size_t i = 0; i + m <= court_world_n; i++) {
        const char *at = memchr(court_world + i, needle[0], court_world_n - m + 1 - i);
        if (!at) return 0;
        i = (size_t)(at - court_world);
        if (memcmp(at, needle, m) == 0) return 1;
    }
    return 0;
}

static void court_lower(const char *in, char *out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = (char)tolower((unsigned char)in[i]);
}

static void court_census(const char *speech, size_t n, int *longest, float *coverage) {
    char low[4096];
    unsigned char covered[4096] = {0};
    if (n > sizeof low) n = sizeof low;
    court_lower(speech, low, n);
    size_t z = 0, best = 0, count = 0;
    for (size_t at = 0; at < n; at++) {
        size_t remain = n - at;
        z = z ? z - 1 : 0;
        if (z > remain) z = remain;
        while (z < remain && court_found(low + at, z + 1)) z++;
        if (z > best) best = z;
        if (z >= COURT_RUN_BYTES) memset(covered + at, 1, z);
    }
    for (size_t i = 0; i < n; i++) count += covered[i];
    *longest = (int)best;
    *coverage = n ? (float)count / (float)n : 0.0f;
}

/* Returns sentences, counts the verbatim ones. */
static int court_sentences(const char *speech, int *verbatim) {
    int sentences = 0;
    *verbatim = 0;
    size_t begin = 0, n = strlen(speech);
    for (size_t i = 0; i < n; i++) {
        if (speech[i] != '.' && speech[i] != '?' && speech[i] != '!' && i + 1 < n) continue;
        while (begin <= i && isspace((unsigned char)speech[begin])) begin++;
        size_t m = i + 1 - begin;
        int words = 0;
        for (size_t k = begin; k <= i; k++) words += leo_word_byte((uint8_t)speech[k]);
        if (m && words) {
            char low[4096];
            if (m > sizeof low) m = sizeof low;
            court_lower(speech + begin, low, m);
            sentences++;
            *verbatim += court_found(low, m);
        }
        begin = i + 1;
    }
    return sentences;
}

static int court_branches(const LeoModel *model, const LeoWordFrame *frame) {
    int n = 0;
    for (size_t i = 0; i < LEO_WORD_FOURGRAM_CAP; i++) {
        const LeoWordFourgram *edge = &model->word_fourgram[i];
        n += edge->used && edge->a == frame->previous[0] &&
             edge->b == frame->previous[1] && edge->c == frame->previous[2];
    }
    return n;
}

/* Walks the visible words through the same frame the mouth uses. */
static void court_rails(const LeoModel *model, const char *speech,
                        int *rails, int *choices, int *unknown, int *low) {
    LeoWordFrame frame;
    memset(&frame, 0, sizeof frame);
    leo_word_frame_reset(&frame);
    char word[LEO_WORD_BYTES];
    int n = 0;
    for (size_t i = 0;; i++) {
        char c = speech[i];
        if (leo_word_byte((uint8_t)c) && n < LEO_WORD_BYTES - 1) {
            word[n++] = (char)tolower((unsigned char)c);
            continue;
        }
        if (n) {
            word[n] = 0;
            *rails += court_branches(model, &frame) == 1;
            (*choices)++;
            *low += leo_word_frame_transition(model, &frame, leo_word_hash(word, n)) <= 0.0f;
            *unknown += !leo_lexicon_has(model, word, n, 1);
            leo_word_frame_push(&frame, leo_word_hash(word, n));
            n = 0;
        }
        if (c == '.' || c == '?' || c == '!' || !c) {
            if (frame.n_previous) {
                *rails += court_branches(model, &frame) == 1;
                (*choices)++;
                *low += leo_word_frame_transition(model, &frame, LEO_WORD_EOS) <= 0.0f;
            }
            leo_word_frame_reset(&frame);
        }
        if (!c) break;
    }
}

static int court_open(Leo *leo, const char *corpus_path, const char *state_path) {
    size_t length = 0;
    char *corpus = leo_read_file(corpus_path, &length);
    if (!corpus) return 0;
    memset(leo, 0, sizeof *leo);
    leo_school_init(&leo->school);
    int ok = leo_model_build(leo, (const uint8_t *)corpus, length);
    free(corpus);
    if (!ok) return 0;
    leo_attention_init(leo);
    if (!leo_load_state(leo, state_path)) return 0;
    leo_heard_replay(leo);
    leo_origin_moment(leo);
    return 1;
}

static int court_self_check(const LeoModel *model) {
    int verbatim = 0, rails = 0, choices = 0, unknown = 0, low = 0, longest = 0, fail = 0;
    float coverage = 0.0f;
    const char *quoted = "Leo walked in her footprints once at the beach.";
    const char *joined = "He is a small gift to the whole house.";
    court_sentences(quoted, &verbatim);
    court_census(quoted, strlen(quoted), &longest, &coverage);
    court_rails(model, quoted, &rails, &choices, &unknown, &low);
    printf("quoted: verbatim %d  longest %d  coverage %.3f  rails %d/%d  unknown %d\n",
           verbatim, longest, coverage, rails, choices, unknown);
    fail |= verbatim != 1 || longest != (int)strlen(quoted) || coverage < 0.99f ||
            unknown != 0;
    court_sentences(joined, &verbatim);
    court_census(joined, strlen(joined), &longest, &coverage);
    printf("joined: verbatim %d  longest %d of %zu\n", verbatim, longest, strlen(joined));
    fail |= verbatim != 0 || longest >= (int)strlen(joined);
    rails = choices = unknown = 0;
    court_rails(model, "Leo walked in her zzyzx.", &rails, &choices, &unknown, &low);
    printf("invented word: unknown %d\n", unknown);
    fail |= unknown != 1;
    printf("%s\n", fail ? "SELF-CHECK FAIL" : "SELF-CHECK PASS");
    return fail;
}

int main(int argc, char **argv) {
    const char *corpus = argc > 2 ? argv[2] : "leo.txt";
    if (argc < 2) {
        fprintf(stderr, "usage: %s STATE_COPY | --self-check [leo.txt]\n", argv[0]);
        return 2;
    }
    size_t world_n = 0;
    char *world = leo_read_file(corpus, &world_n);
    if (!world) { fprintf(stderr, "court: cannot read %s\n", corpus); return 1; }
    court_lower(world, world, world_n);
    court_world = world;
    court_world_n = world_n;

    Leo *base = calloc(1, sizeof *base);
    Leo *work = calloc(1, sizeof *work);
    if (!base || !work) return 1;
    if (strcmp(argv[1], "--self-check") == 0) {
        size_t length = 0;
        char *text = leo_read_file(corpus, &length);
        if (!text || !leo_model_build(base, (const uint8_t *)text, length)) return 1;
        free(text);
        return court_self_check(&base->model);
    }
    if (!court_open(base, corpus, argv[1])) {
        fprintf(stderr, "court: cannot open body %s\n", argv[1]);
        return 1;
    }
    printf("law: floor %d, corridor K=%d\n", LEO_WORD_FLOOR, LEO_CORRIDOR_K);
    printf("body: turns=%llu moments=%u mode=%u heard=%u\n",
           (unsigned long long)base->turns, base->n_moment, base->mode, base->n_heard);

    long answers = 0, school = 0, sentences = 0, verbatim = 0;
    long rails = 0, choices = 0, unknown = 0, low = 0, changed = 0;
    double coverage_sum = 0.0;
    int longest_max = 0;
    for (int l = 0; l < COURT_N_LINES; l++) {
        long line_sentences = 0, line_verbatim = 0, line_rails = 0, line_choices = 0;
        for (int s = 1; s <= COURT_SEEDS; s++) {
            char reply[4096], rested[4096];
            uint64_t rng = leo_mix64(UINT64_C(0x434f555254) ^ (uint64_t)s);

            memcpy(work, base, sizeof *work);
            work->n_heard = LEO_HEARD_BYTES;
            work->rng = rng;
            int n = leo_respond(work, COURT_LINES[l], reply, sizeof reply);
            if (n < 0) n = 0;
            reply[n] = 0;
            int asked = work->school.pending[0] != 0 &&
                        strcmp(work->school.pending, base->school.pending) != 0;

            memcpy(work, base, sizeof *work);
            work->n_heard = LEO_HEARD_BYTES;
            work->rng = rng;
            memset(work->chamber, 0, sizeof work->chamber);
            memset(work->chamber_input, 0, sizeof work->chamber_input);
            memset(work->scar, 0, sizeof work->scar);
            memset(work->capsule, 0, sizeof work->capsule);
            int m = leo_respond(work, COURT_LINES[l], rested, sizeof rested);
            if (m < 0) m = 0;
            rested[m] = 0;

            answers++;
            changed += strcmp(reply, rested) != 0;
            if (asked) { school++; continue; }
            int v = 0, longest = 0;
            float coverage = 0.0f;
            int k = court_sentences(reply, &v);
            court_census(reply, (size_t)n, &longest, &coverage);
            int r = 0, c = 0, u = 0, w = 0;
            court_rails(&base->model, reply, &r, &c, &u, &w);
            low += w;
            line_sentences += k; line_verbatim += v; line_rails += r; line_choices += c;
            unknown += u;
            coverage_sum += coverage;
            if (longest > longest_max) longest_max = longest;
            if (s == 1) printf("  [%s] %s\n", COURT_LINES[l], reply);
        }
        printf("line %d: verbatim %ld/%ld sentences, rails %ld/%ld choices\n", l + 1,
               line_verbatim, line_sentences, line_rails, line_choices);
        sentences += line_sentences; verbatim += line_verbatim;
        rails += line_rails; choices += line_choices;
    }
    long spoken = answers - school;
    printf("\nanswers %ld (school questions %ld)\n", answers, school);
    printf("M1 verbatim sentences %ld/%ld = %.3f; mean coverage %.3f; longest run %d bytes\n",
           verbatim, sentences, sentences ? (double)verbatim / (double)sentences : 0.0,
           spoken ? coverage_sum / (double)spoken : 0.0, longest_max);
    printf("M2 rails %ld/%ld = %.3f\n", rails, choices,
           choices ? (double)rails / (double)choices : 0.0);
    printf("M2b choices below the four-word order %ld/%ld = %.3f\n", low, choices,
           choices ? (double)low / (double)choices : 0.0);
    printf("M3 words outside lexicon %ld\n", unknown);
    printf("M4 answers changed by a rested body %ld/%ld = %.3f\n", changed, answers,
           answers ? (double)changed / (double)answers : 0.0);
    return 0;
}
