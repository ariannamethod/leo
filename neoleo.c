/* Neo Leo: four causal co-occurrence readers in Leo's own meaning field.
 * The ordinary leo target compiles without these three optional hooks.
 * No pretrained body, gradient tape or external runtime is needed. */
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
static void neo_prepare(void *, const float *, const uint16_t *, int);
static float neo_score(void *, uint16_t, const float *, float);
static void neo_choice(void *, uint16_t);
#define LEO_EXPERT_PREPARE neo_prepare
#define LEO_EXPERT_SCORE neo_score
#define LEO_EXPERT_CHOICE neo_choice
#define main leo_service_main
#include "leo.c"
#undef main

#define NEO_SEATS 4
#define NEO_GAIN 0.75f

/* Each reader accumulates directional co-occurrences at one time scale.
 * These are online statistics, with no optimizer or pretrained tensors.
 * A target is observed AFTER its prediction has been scored. */
static const float neo_decay[NEO_SEATS] = {0.0f, 0.5f, 0.85f, 0.97f};
typedef struct {
    float association[LEO_DIM][LEO_DIM];
    float heard[LEO_DIM];
    float quality;
    uint64_t observations;
} NeoExpert;

typedef struct {
    NeoExpert expert[NEO_SEATS];
    uint64_t human_turns;
} NeoMemory;

typedef struct {
    NeoMemory memory;
    float prediction[NEO_SEATS][LEO_DIM];
    float gate[NEO_SEATS];
    float gain;
    unsigned mask;
    FILE *trace;
    uint64_t choices, changed_top, candidates;
    float base_best, voted_best;
    uint16_t base_id, voted_id;
} NeoParliament;

/* This executable owns one body. Tests may swap the owner between calls. */
static NeoParliament *neo_owner;

static void neo_prediction(const NeoExpert *e, const float *context, float *out) {
    leo_project(e->association, context, out);
    leo_normalize(out, LEO_DIM);
}

static void neo_observe(NeoExpert *e, const float *context, const float *target) {
    if (leo_norm(context, LEO_DIM) < 0.1f ||
        leo_norm(target, LEO_DIM) < 0.1f || e->observations == UINT64_MAX) return;
    float prediction[LEO_DIM];
    neo_prediction(e, context, prediction);
    float quality = leo_cosine(prediction, target, LEO_DIM);
    e->observations++;
    float rate = 1.0f / (float)(e->observations < 4096 ? e->observations : 4096);
    e->quality += rate * (quality - e->quality);
    for (int row = 0; row < LEO_DIM; row++)
        for (int col = 0; col < LEO_DIM; col++) {
            float joint = target[row] * context[col];
            e->association[row][col] += rate * (joint - e->association[row][col]);
        }
}

static void neo_advance(float *context, const float *token, int seat) {
    for (int d = 0; d < LEO_DIM; d++)
        context[d] = neo_decay[seat] * context[d] + (1.0f - neo_decay[seat]) * token[d];
    /* Preserve the EMA's magnitude; normalize a copy when reading it. */
}

static void neo_hear_ids(NeoParliament *p, const Leo *leo,
                         const uint16_t *ids, int count, int birth) {
    float context[NEO_SEATS][LEO_DIM] = {{0}};
    for (int i = 0; i < count; i++) {
        if (ids[i] >= leo->model.bpe.vocab) continue;
        const LeoToken *token = &leo->model.bpe.token[ids[i]];
        /* Stable corpus coordinates, shared with every candidate's projection.
         * Heard traces are independent from Leo's mutable adaptation vectors. */
        for (int e = 0; e < NEO_SEATS; e++) {
            float query[LEO_DIM];
            memcpy(query, context[e], sizeof query);
            leo_normalize(query, LEO_DIM);
            neo_observe(&p->memory.expert[e], query, token->semantic);
            neo_advance(context[e], token->semantic, e);
            if (!birth) neo_advance(p->memory.expert[e].heard, token->semantic, e);
        }
    }
}

static int neo_bootstrap(NeoParliament *p, const Leo *leo,
                         const uint8_t *text, size_t length) {
    if (length > INT_MAX || length > SIZE_MAX / sizeof(uint16_t)) return 0;
    uint16_t *ids = malloc((length + 1) * sizeof *ids);
    if (!ids) return 0;
    int n = leo_bpe_encode(&leo->model.bpe, text, (int)length, ids, (int)length);
    neo_hear_ids(p, leo, ids, n, 1);
    free(ids);
    return n > 0;
}

static void neo_hear_line(NeoParliament *p, const Leo *leo, const char *line) {
    uint16_t ids[LEO_LINE_BYTES];
    int n = leo_bpe_encode(&leo->model.bpe, (const uint8_t *)line,
                           (int)strlen(line), ids, LEO_LINE_BYTES);
    if (!n) return;
    neo_hear_ids(p, leo, ids, n, 0);
    if (p->memory.human_turns != UINT64_MAX) p->memory.human_turns++;
}

static void neo_prepare(void *body, const float *intention,
                         const uint16_t *history, int history_n) {
    NeoParliament *p = neo_owner;
    if (!p) return;
    Leo *leo = body;
    p->candidates = 0;
    p->base_best = p->voted_best = -INFINITY;
    p->base_id = p->voted_id = UINT16_MAX;
    float total = 0.0f;
    for (int e = 0; e < NEO_SEATS; e++) {
        float spoken[LEO_DIM] = {0}, context[LEO_DIM], heard[LEO_DIM];
        for (int i = 0; i < history_n; i++)
            if (history[i] < leo->model.bpe.vocab)
                neo_advance(spoken, leo->model.bpe.token[history[i]].semantic, e);
        leo_normalize(spoken, LEO_DIM);
        memcpy(heard, p->memory.expert[e].heard, sizeof heard);
        leo_normalize(heard, LEO_DIM);
        for (int d = 0; d < LEO_DIM; d++)
            context[d] = 0.55f * intention[d] + 0.25f * heard[d] + 0.20f * spoken[d];
        leo_normalize(context, LEO_DIM);
        neo_prediction(&p->memory.expert[e], context, p->prediction[e]);
        p->gate[e] = (p->mask & (1u << e)) && p->memory.expert[e].observations
                   ? expf(2.0f * p->memory.expert[e].quality) : 0.0f;
        total += p->gate[e];
    }
    if (total > 0.0f)
        for (int e = 0; e < NEO_SEATS; e++) p->gate[e] /= total;
}

static float neo_votes(const NeoParliament *p, const Leo *leo, uint16_t id,
                        float votes[NEO_SEATS]) {
    float sum = 0.0f;
    for (int e = 0; e < NEO_SEATS; e++) {
        votes[e] = leo_cosine(p->prediction[e], leo->model.bpe.token[id].semantic, LEO_DIM);
        sum += p->gate[e] * votes[e];
    }
    return p->gain * sum;
}

static float neo_score(void *body, uint16_t id, const float *vector, float base) {
    (void)vector;
    NeoParliament *p = neo_owner;
    if (!p) return 0.0f;
    float votes[NEO_SEATS];
    float delta = neo_votes(p, body, id, votes);
    p->candidates++;
    if (base > p->base_best) { p->base_best = base; p->base_id = id; }
    if (base + delta > p->voted_best) { p->voted_best = base + delta; p->voted_id = id; }
    return delta;
}

static void neo_choice(void *body, uint16_t id) {
    NeoParliament *p = neo_owner;
    if (!p) return;
    float votes[NEO_SEATS];
    float delta = neo_votes(p, body, id, votes);
    p->choices++;
    p->changed_top += p->base_id != p->voted_id;
    if (p->trace)
        fprintf(p->trace,
          "{\"choice\":%llu,\"candidates\":%llu,\"base_top\":%u,\"voted_top\":%u,"
          "\"selected\":%u,\"delta\":%.9g,\"votes\":[%.9g,%.9g,%.9g,%.9g],"
          "\"gates\":[%.9g,%.9g,%.9g,%.9g]}\n",
          (unsigned long long)p->choices, (unsigned long long)p->candidates,
          p->base_id, p->voted_id, id, delta, votes[0], votes[1], votes[2], votes[3],
          p->gate[0], p->gate[1], p->gate[2], p->gate[3]);
}

/* One snapshot contains Leo's exact body followed by the expert memory.
 * New-path publication prevents overwriting a live Leo or an older experiment.
 * This native-endian format has the same host portability as Leo's body file. */
typedef struct {
    char magic[8];
    uint32_t version, dimension, seats, memory_bytes;
    uint64_t body_bytes, body_hash, memory_hash;
} NeoFooter;

static int neo_memory_valid(const NeoMemory *memory) {
    for (int e = 0; e < NEO_SEATS; e++) {
        const NeoExpert *x = &memory->expert[e];
        if (!isfinite(x->quality) || fabsf(x->quality) > 1.001f) return 0;
        for (int d = 0; d < LEO_DIM; d++) {
            if (!isfinite(x->heard[d]) || fabsf(x->heard[d]) > 1.001f) return 0;
            for (int c = 0; c < LEO_DIM; c++)
                if (!isfinite(x->association[d][c]) || fabsf(x->association[d][c]) > 1.001f)
                    return 0;
        }
    }
    return 1;
}

static int neo_file_hash(FILE *f, uint64_t length, uint64_t *out) {
    uint64_t hash = UINT64_C(1469598103934665603);
    uint8_t buffer[8192];
    if (fseek(f, 0, SEEK_SET)) return 0;
    while (length) {
        size_t n = length < sizeof buffer ? (size_t)length : sizeof buffer;
        if (fread(buffer, 1, n, f) != n) return 0;
        for (size_t i = 0; i < n; i++) { hash ^= buffer[i]; hash *= UINT64_C(1099511628211); }
        length -= n;
    }
    *out = hash;
    return 1;
}

static int neo_save(const Leo *leo, const NeoParliament *p, const char *path) {
    if (!neo_memory_valid(&p->memory) || !leo_state_finite(leo)) return 0;
    char directory[1100], staged[1200];
    int n = snprintf(directory, sizeof directory, "%s.stage.XXXXXX", path);
    if (n <= 0 || n >= (int)sizeof directory || !mkdtemp(directory)) return 0;
    snprintf(staged, sizeof staged, "%s/body", directory);
    int ok = leo_save_state(leo, staged);
    FILE *f = ok ? fopen(staged, "r+b") : NULL;
    if (!f) ok = 0;
    if (f) {
        struct stat st;
        NeoFooter footer = {0};
        memcpy(footer.magic, "NEOLEO01", 8);
        footer.version = 1;
        footer.dimension = LEO_DIM;
        footer.seats = NEO_SEATS;
        footer.memory_bytes = sizeof p->memory;
        ok = !fstat(fileno(f), &st) && st.st_size > 0;
        if (ok) {
            footer.body_bytes = (uint64_t)st.st_size;
            footer.memory_hash = leo_hash64(&p->memory, sizeof p->memory);
            ok = neo_file_hash(f, footer.body_bytes, &footer.body_hash) &&
                 fseek(f, 0, SEEK_END) == 0 &&
                 leo_write_block(f, &p->memory, sizeof p->memory) &&
                 leo_write_block(f, &footer, sizeof footer) &&
                 fflush(f) == 0 && fsync(fileno(f)) == 0;
        }
        if (fclose(f)) ok = 0;
    }
    if (ok && link(staged, path)) ok = 0;
    int saved = errno;
    unlink(staged);
    rmdir(directory);
    errno = saved;
    return ok;
}

static int neo_load(Leo *leo, NeoParliament *p, const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    struct stat st;
    NeoFooter footer;
    NeoMemory memory;
    uint64_t hash = 0;
    int ok = !fstat(fileno(f), &st) && st.st_size > (off_t)(sizeof footer + sizeof memory) &&
             !fseek(f, -(long)sizeof footer, SEEK_END) &&
             leo_read_block(f, &footer, sizeof footer);
    if (ok) ok = !memcmp(footer.magic, "NEOLEO01", 8) && footer.version == 1 &&
        footer.dimension == LEO_DIM && footer.seats == NEO_SEATS &&
        footer.memory_bytes == sizeof memory &&
        footer.body_bytes == (uint64_t)st.st_size - sizeof memory - sizeof footer &&
        neo_file_hash(f, footer.body_bytes, &hash) && hash == footer.body_hash &&
        leo_read_block(f, &memory, sizeof memory) &&
        leo_hash64(&memory, sizeof memory) == footer.memory_hash && neo_memory_valid(&memory);
    fclose(f);
    if (!ok || !leo_load_state(leo, path)) return 0;
    p->memory = memory;
    leo_heard_replay(leo);
    leo_origin_moment(leo);
    return 1;
}

static Leo *neo_birth(const char *corpus_path, NeoParliament *p) {
    size_t length = 0;
    char *corpus = leo_read_file(corpus_path, &length);
    if (!corpus) return NULL;
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) { free(corpus); return NULL; }
    leo_school_init(&leo->school);
    leo->rng = leo_hash64(corpus, length) ^ UINT64_C(0x4c454f2d414c4956);
    int ok = leo_model_build(leo, (const uint8_t *)corpus, length);
    if (ok) ok = neo_bootstrap(p, leo, (const uint8_t *)corpus, length);
    free(corpus);
    if (!ok) { leo_model_free(&leo->model); free(leo); return NULL; }
    leo_attention_init(leo);
    memcpy(leo->presence, leo->model.origin, sizeof leo->presence);
    memcpy(leo->retention, leo->model.origin, sizeof leo->retention);
    leo_origin_moment(leo);
    leo_mode_update(leo);
    return leo;
}

#ifndef NEO_NO_MAIN
static int neo_usage(const char *name) {
    fprintf(stderr, "usage: %s [--corpus FILE] [--load SNAPSHOT] [--save NEW_SNAPSHOT]\n"
                    "       [--seed UINT64] [--off] [--mask 0..15] [--trace NEW_JSONL]\n"
                    "One input line per turn; EOF saves the requested snapshot.\n", name);
    return 2;
}

int main(int argc, char **argv) {
    const char *corpus = "leo.txt", *input = NULL, *output = NULL, *trace = NULL;
    uint64_t seed = 0;
    int seeded = 0;
    NeoParliament parliament = {.gain = NEO_GAIN, .mask = 15};
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--off")) { parliament.gain = 0; continue; }
        if (i + 1 >= argc) return neo_usage(argv[0]);
        const char *arg = argv[++i];
        if (!strcmp(argv[i-1], "--corpus")) corpus = arg;
        else if (!strcmp(argv[i-1], "--load")) input = arg;
        else if (!strcmp(argv[i-1], "--save")) output = arg;
        else if (!strcmp(argv[i-1], "--trace")) trace = arg;
        else if (!strcmp(argv[i-1], "--seed") || !strcmp(argv[i-1], "--mask")) {
            char *end;
            errno = 0;
            unsigned long long value = strtoull(arg, &end, 10);
            if (errno || !*arg || *arg == '-' || *end) return neo_usage(argv[0]);
            if (!strcmp(argv[i-1], "--mask")) {
                if (value > 15) return neo_usage(argv[0]);
                parliament.mask = (unsigned)value;
            } else { seed = (uint64_t)value; seeded = 1; }
        } else return neo_usage(argv[0]);
    }
    if (output) {
        struct stat existing;
        if (!lstat(output, &existing) || errno != ENOENT) {
            fprintf(stderr, "neoleo: snapshot destination must be a new path: %s\n", output);
            return 1;
        }
    }
    if (trace) {
        int fd = open(trace, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR);
        if (fd < 0) { perror("neoleo trace"); return 1; }
        parliament.trace = fdopen(fd, "w");
        if (!parliament.trace) { close(fd); perror("neoleo trace"); return 1; }
    }
    Leo *leo = neo_birth(corpus, &parliament);
    if (!leo) { fprintf(stderr, "neoleo: cannot grow the corpus field\n"); return 1; }
    if (input && !neo_load(leo, &parliament, input)) {
        fprintf(stderr, "neoleo: snapshot does not match this body or is damaged\n");
        leo_model_free(&leo->model); free(leo); return 1;
    }
    if (seeded) leo->rng = seed;
    neo_owner = &parliament;
    char line[LEO_LINE_BYTES], reply[LEO_LINE_BYTES];
    int status = 0;
    while (fgets(line, sizeof line, stdin)) {
        size_t length = strlen(line);
        if (length && line[length-1] != '\n' && !feof(stdin)) {
            fprintf(stderr, "neoleo: input line exceeds %d bytes\n", LEO_LINE_BYTES-2);
            status = 1; break;
        }
        while (length && (line[length-1] == '\n' || line[length-1] == '\r')) line[--length] = 0;
        if (!length) continue;
        neo_hear_line(&parliament, leo, line);
        leo_respond(leo, line, reply, sizeof reply);
        puts(reply);
        fflush(stdout);
    }
    if (ferror(stdin) || ferror(stdout)) status = 1;
    if (!status && output && !neo_save(leo, &parliament, output)) {
        fprintf(stderr, "neoleo: cannot publish new snapshot %s: %s\n", output, strerror(errno));
        status = 1;
    }
    fprintf(stderr, "neoleo: choices=%llu changed_top=%llu human_turns=%llu\n",
            (unsigned long long)parliament.choices,
            (unsigned long long)parliament.changed_top,
            (unsigned long long)parliament.memory.human_turns);
    if (parliament.trace && fclose(parliament.trace)) status = 1;
    neo_owner = NULL;
    leo_model_free(&leo->model);
    free(leo);
    return status;
}
#endif
