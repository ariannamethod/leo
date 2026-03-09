/*
 * test_leo.c — tests for Leo 2.0
 *
 * cc test_leo.c -O2 -lm -lsqlite3 -lpthread -I.. -o test_leo && ./test_leo
 */

#define LEO_LIB
#include "../leo.c"

#include <assert.h>

static int tests_passed = 0;
static int tests_failed = 0;

#define TEST(name) \
    do { printf("  %-50s ", name); } while(0)

#define PASS() \
    do { printf("OK\n"); tests_passed++; } while(0)

#define FAIL(msg) \
    do { printf("FAIL: %s\n", msg); tests_failed++; } while(0)

#define ASSERT(cond, msg) \
    do { if (!(cond)) { FAIL(msg); return; } } while(0)

/* ================================================================
 * TOKENIZER TESTS
 * ================================================================ */

static void test_tok_basic(void) {
    TEST("tokenizer: add and find words");
    LeoTokenizer t;
    tok_init(&t);

    int id1 = tok_add(&t, "hello");
    int id2 = tok_add(&t, "world");
    int id3 = tok_add(&t, "hello"); /* duplicate */

    ASSERT(id1 >= 0, "id1 should be valid");
    ASSERT(id2 >= 0, "id2 should be valid");
    ASSERT(id3 == id1, "duplicate should return same id");
    ASSERT(t.n_words == 2, "should have 2 words");
    ASSERT(tok_find(&t, "hello") == id1, "find should work");
    ASSERT(tok_find(&t, "missing") == -1, "missing should return -1");

    tok_free(&t);
    PASS();
}

static void test_tok_tokenize(void) {
    TEST("tokenizer: tokenize text");
    LeoTokenizer t;
    tok_init(&t);

    int ids[32];
    int n = tok_tokenize(&t, "Hello World, hello!", ids, 32);

    ASSERT(n == 3, "should produce 3 tokens");
    ASSERT(ids[0] == ids[2], "hello and Hello should be same (lowercased)");
    ASSERT(t.n_words == 2, "vocab should be 2 (hello, world)");

    tok_free(&t);
    PASS();
}

static void test_tok_special_chars(void) {
    TEST("tokenizer: handles punctuation and hyphens");
    LeoTokenizer t;
    tok_init(&t);

    int ids[32];
    int n = tok_tokenize(&t, "don't post-transformer it's", ids, 32);

    ASSERT(n == 3, "should produce 3 tokens");
    ASSERT(strcmp(t.words[ids[0]], "don't") == 0, "should keep apostrophe");
    ASSERT(strcmp(t.words[ids[1]], "post-transformer") == 0, "should keep hyphen");

    tok_free(&t);
    PASS();
}

/* ================================================================
 * VECTOR TESTS
 * ================================================================ */

static void test_vec_operations(void) {
    TEST("vec: dot product and cosine");
    float a[] = {1, 0, 0, 0};
    float b[] = {0, 1, 0, 0};
    float c[] = {1, 0, 0, 0};

    ASSERT(fabsf(vec_dot(a, b, 4)) < 1e-6f, "orthogonal dot = 0");
    ASSERT(fabsf(vec_dot(a, c, 4) - 1.0f) < 1e-6f, "parallel dot = 1");
    ASSERT(fabsf(vec_cosine(a, b, 4)) < 1e-6f, "orthogonal cosine = 0");
    ASSERT(fabsf(vec_cosine(a, c, 4) - 1.0f) < 1e-6f, "parallel cosine = 1");

    PASS();
}

static void test_vec_normalize(void) {
    TEST("vec: normalize");
    float v[] = {3, 4, 0, 0};
    vec_normalize(v, 4);

    float norm = vec_norm(v, 4);
    ASSERT(fabsf(norm - 1.0f) < 1e-5f, "norm should be 1 after normalize");
    ASSERT(fabsf(v[0] - 0.6f) < 1e-5f, "v[0] should be 3/5");
    ASSERT(fabsf(v[1] - 0.8f) < 1e-5f, "v[1] should be 4/5");

    PASS();
}

/* ================================================================
 * COOC FIELD TESTS
 * ================================================================ */

static void test_cooc_basic(void) {
    TEST("cooc: update and get");
    CoocField c;
    cooc_init(&c, 1024);

    cooc_update(&c, 0, 1, 3.0f);
    cooc_update(&c, 0, 1, 2.0f);
    cooc_update(&c, 1, 2, 1.0f);

    ASSERT(fabsf(cooc_get(&c, 0, 1) - 5.0f) < 1e-6f, "0→1 should be 5.0");
    ASSERT(fabsf(cooc_get(&c, 1, 2) - 1.0f) < 1e-6f, "1→2 should be 1.0");
    ASSERT(fabsf(cooc_get(&c, 2, 3)) < 1e-6f, "missing should be 0");
    ASSERT(c.n_entries == 2, "should have 2 entries");

    cooc_free(&c);
    PASS();
}

static void test_cooc_row(void) {
    TEST("cooc: row extraction");
    CoocField c;
    cooc_init(&c, 1024);

    cooc_update(&c, 5, 10, 3.0f);
    cooc_update(&c, 5, 20, 1.0f);
    cooc_update(&c, 5, 30, 7.0f);
    cooc_update(&c, 6, 10, 99.0f); /* different source */

    float row[50];
    cooc_row(&c, 5, row, 50);

    ASSERT(fabsf(row[10] - 3.0f) < 1e-6f, "row[10] = 3.0");
    ASSERT(fabsf(row[20] - 1.0f) < 1e-6f, "row[20] = 1.0");
    ASSERT(fabsf(row[30] - 7.0f) < 1e-6f, "row[30] = 7.0");
    ASSERT(fabsf(row[0]) < 1e-6f, "row[0] = 0 (not set)");

    cooc_free(&c);
    PASS();
}

/* ================================================================
 * BIGRAM TABLE TESTS
 * ================================================================ */

static void test_bigram_basic(void) {
    TEST("bigram: update and row");
    BigramTable b;
    bigram_init(&b, 1024);

    bigram_update(&b, 0, 1, 1.0f);
    bigram_update(&b, 0, 2, 3.0f);
    bigram_update(&b, 0, 1, 1.0f); /* accumulate */
    bigram_update(&b, 1, 3, 5.0f);

    float row[10];
    bigram_row(&b, 0, row, 10);

    ASSERT(fabsf(row[1] - 2.0f) < 1e-6f, "0→1 should be 2.0");
    ASSERT(fabsf(row[2] - 3.0f) < 1e-6f, "0→2 should be 3.0");
    ASSERT(fabsf(row[3]) < 1e-6f, "0→3 should be 0");
    ASSERT(b.n_entries == 3, "should have 3 entries");

    bigram_free(&b);
    PASS();
}

/* ================================================================
 * SDM TESTS
 * ================================================================ */

static void test_sdm_write_read(void) {
    TEST("sdm: write and read back");
    srand(42);
    KanervaSDM sdm;
    sdm_init(&sdm, 256, 8);

    float addr[8] = {1, 0, 0, 0, 0, 0, 0, 0};
    float val[8]  = {0, 1, 0, 0, 0, 0, 0, 0};

    sdm_write(&sdm, addr, val);

    float out[8];
    sdm_read(&sdm, addr, out);

    /* out should be close to val (not exact due to averaging) */
    float sim = vec_cosine(out, val, 8);
    ASSERT(sim > 0.5f, "read should resemble written value");

    sdm_free(&sdm);
    PASS();
}

/* ================================================================
 * ROPE TESTS
 * ================================================================ */

static void test_rope_deterministic(void) {
    TEST("RoPE: same position gives same result");
    float v1[8] = {1, 0, 1, 0, 1, 0, 1, 0};
    float v2[8] = {1, 0, 1, 0, 1, 0, 1, 0};

    apply_rope(v1, 8, 42);
    apply_rope(v2, 8, 42);

    for (int i = 0; i < 8; i++)
        ASSERT(fabsf(v1[i] - v2[i]) < 1e-6f, "same pos should give same result");

    PASS();
}

static void test_rope_different_positions(void) {
    TEST("RoPE: different positions give different results");
    float v1[8] = {1, 0, 1, 0, 1, 0, 1, 0};
    float v2[8] = {1, 0, 1, 0, 1, 0, 1, 0};

    apply_rope(v1, 8, 0);
    apply_rope(v2, 8, 100);

    int different = 0;
    for (int i = 0; i < 8; i++)
        if (fabsf(v1[i] - v2[i]) > 1e-4f) different++;

    ASSERT(different > 0, "different positions should differ");
    PASS();
}

/* ================================================================
 * PROPHECY TESTS
 * ================================================================ */

static void test_prophecy_lifecycle(void) {
    TEST("prophecy: add, age, fulfill");
    ProphecySystem ps;
    prophecy_init(&ps);

    prophecy_add(&ps, 42, 0.8f);
    prophecy_add(&ps, 99, 0.5f);
    ASSERT(ps.n_active == 2, "should have 2 prophecies");

    /* age them */
    prophecy_update(&ps, 0); /* neither fulfilled */
    ASSERT(ps.prophets[0].age == 1, "should age");

    /* fulfill one */
    prophecy_update(&ps, 42);
    ASSERT(ps.n_active == 1, "fulfilled one should be removed");
    ASSERT(ps.prophets[0].target_id == 99, "remaining should be 99");

    PASS();
}

static void test_prophecy_eviction(void) {
    TEST("prophecy: eviction when full");
    ProphecySystem ps;
    prophecy_init(&ps);

    for (int i = 0; i < LEO_MAX_PROPHECY + 5; i++)
        prophecy_add(&ps, i, 0.5f);

    ASSERT(ps.n_active == LEO_MAX_PROPHECY, "should not exceed max");
    PASS();
}

/* ================================================================
 * DESTINY TESTS
 * ================================================================ */

static void test_destiny_ema(void) {
    TEST("destiny: EMA accumulates direction");
    Destiny d;
    destiny_init(&d, 4);

    float v1[4] = {1, 0, 0, 0};
    float v2[4] = {1, 0, 0, 0};
    float v3[4] = {1, 0, 0, 0};

    destiny_update(&d, v1, 4);
    destiny_update(&d, v2, 4);
    destiny_update(&d, v3, 4);

    ASSERT(d.magnitude > 0.01f, "magnitude should grow");
    ASSERT(d.direction[0] > d.direction[1], "should point toward [1,0,0,0]");

    destiny_free(&d);
    PASS();
}

/* ================================================================
 * MEMORY SEA TESTS
 * ================================================================ */

static void test_sea_record_and_decay(void) {
    TEST("memory sea: record and decay");
    MemorySea s;
    sea_init(&s, 16, 4);

    float e[4] = {1, 0, 0, 0};
    sea_record(&s, e, 42, 0.9f, 0);
    ASSERT(s.n_memories == 1, "should have 1 memory");
    ASSERT(s.memories[0].token_id == 42, "should store token_id");

    sea_decay(&s, 0.5f);
    ASSERT(s.memories[0].depth < 0.9f, "depth should decrease after decay");

    sea_free(&s);
    PASS();
}

static void test_sea_eviction(void) {
    TEST("memory sea: evicts shallowest when full");
    MemorySea s;
    sea_init(&s, 4, 4);

    float e[4] = {1, 0, 0, 0};
    for (int i = 0; i < 6; i++) {
        sea_record(&s, e, i, (float)(i + 1) * 0.1f, i);
    }
    ASSERT(s.n_memories == 4, "should not exceed capacity");

    sea_free(&s);
    PASS();
}

/* ================================================================
 * VOICE TESTS
 * ================================================================ */

static void test_voice_init(void) {
    TEST("voices: 6 initial voices");
    VoiceParliament vp;
    voices_init(&vp, 32, 8);

    ASSERT(vp.n_voices == 6, "should have 6 voices");
    ASSERT(strcmp(vp.voices[0].name, "origin") == 0, "first = origin");
    ASSERT(strcmp(vp.voices[5].name, "dreamer") == 0, "last = dreamer");

    for (int v = 0; v < 6; v++) {
        ASSERT(vp.voices[v].alpha > 0, "alpha should be positive");
        ASSERT(vp.voices[v].active == 1, "should be active");
    }

    voices_free(&vp);
    PASS();
}

static void test_voice_reinforce(void) {
    TEST("voices: Hebbian reinforcement changes alpha");
    Voice v;
    voice_init_single(&v, "test", 16, 4);

    float orig_alpha = v.alpha;
    float ctx[16];
    for (int i = 0; i < 16; i++) ctx[i] = 0.1f;

    voice_reinforce(&v, ctx, 16, 4, 1.0f);
    ASSERT(v.alpha > orig_alpha, "positive reward should increase alpha");
    ASSERT(v.resonance > 0, "resonance should accumulate");

    voice_free_single(&v);
    PASS();
}

/* ================================================================
 * RETENTION TESTS
 * ================================================================ */

static void test_retention_griffin(void) {
    TEST("retention: Griffin conservation law");
    RetentionLayer r;
    ret_init(&r, 16);

    /* verify conservation factors */
    for (int h = 0; h < LEO_RET_HEADS; h++) {
        float gamma = r.heads[h].gamma;
        float cons = r.heads[h].conservation;
        float sum = gamma * gamma + cons * cons;
        ASSERT(fabsf(sum - 1.0f) < 1e-5f,
               "γ² + (√(1-γ²))² should = 1 (conservation)");
    }

    ret_free(&r);
    PASS();
}

/* ================================================================
 * LEO INTEGRATION TESTS
 * ================================================================ */

static void test_leo_bootstrap(void) {
    TEST("leo: bootstrap creates vocab and cooc");
    srand(42);
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_bootstrap.db");
    leo_bootstrap(&leo);

    ASSERT(leo.tok.n_words > 100, "should have >100 words from bootstrap");
    ASSERT(leo.cooc.n_entries > 1000, "should have >1000 cooc entries");
    ASSERT(leo.bigrams.n_entries > 100, "should have >100 bigrams");
    ASSERT(leo.bootstrapped == 1, "should be bootstrapped");
    ASSERT(leo.step > 0, "step should be > 0");

    leo_free(&leo);
    remove("/tmp/test_leo_bootstrap.db.state");
    PASS();
}

static void test_leo_generate(void) {
    TEST("leo: generate produces non-empty output");
    srand(42);
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_generate.db");
    leo_bootstrap(&leo);

    char response[1024];
    int n = leo_generate(&leo, "hello", response, sizeof(response));

    ASSERT(n > 0, "should generate at least 1 token");
    ASSERT(strlen(response) > 0, "response should be non-empty");

    leo_free(&leo);
    remove("/tmp/test_leo_generate.db.state");
    PASS();
}

static void test_leo_ingest_grows_field(void) {
    TEST("leo: ingesting text grows vocabulary and field");
    srand(42);
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_ingest.db");
    leo_bootstrap(&leo);

    int vocab_before = leo.tok.n_words;
    int cooc_before = leo.cooc.n_entries;

    leo_ingest(&leo, "extraordinary magnificent unprecedented spectacular");

    ASSERT(leo.tok.n_words > vocab_before, "vocab should grow");
    ASSERT(leo.cooc.n_entries > cooc_before, "cooc should grow");

    leo_free(&leo);
    remove("/tmp/test_leo_ingest.db.state");
    PASS();
}

static void test_leo_save_load(void) {
    TEST("leo: save and load preserves state");
    srand(42);
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_saveload.db");
    leo_bootstrap(&leo);
    leo_ingest(&leo, "testing save and load roundtrip");

    int step1 = leo.step;
    int vocab1 = leo.tok.n_words;
    int cooc1 = leo.cooc.n_entries;

    leo_save(&leo);
    leo_free(&leo);

    /* reload */
    Leo leo2;
    leo_init(&leo2, "/tmp/test_leo_saveload.db");
    leo_load(&leo2);

    ASSERT(leo2.step == step1, "step should be preserved");
    ASSERT(leo2.tok.n_words == vocab1, "vocab should be preserved");
    ASSERT(leo2.bootstrapped == 1, "should be bootstrapped");

    leo_free(&leo2);
    remove("/tmp/test_leo_saveload.db.state");
    PASS();
}

static void test_leo_dream(void) {
    TEST("leo: dream cycle runs without crash");
    srand(42);
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_dream.db");
    leo_bootstrap(&leo);

    /* generate a few responses to fill memory sea */
    char buf[512];
    leo_generate(&leo, "what is resonance", buf, sizeof(buf));
    leo_generate(&leo, "tell me about dreams", buf, sizeof(buf));

    /* dream should not crash */
    leo_dream(&leo);

    leo_free(&leo);
    remove("/tmp/test_leo_dream.db.state");
    PASS();
}

static void test_leo_multiple_conversations(void) {
    TEST("leo: field grows across conversations");
    srand(42);
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_multi.db");
    leo_bootstrap(&leo);

    char buf[512];
    int step0 = leo.step;

    leo_generate(&leo, "hello Leo how are you", buf, sizeof(buf));
    int step1 = leo.step;
    ASSERT(step1 > step0, "step should increase after conversation");

    leo_generate(&leo, "tell me about the stars", buf, sizeof(buf));
    int step2 = leo.step;
    ASSERT(step2 > step1, "step should keep increasing");

    leo_generate(&leo, "I believe in miracles", buf, sizeof(buf));
    int step3 = leo.step;
    ASSERT(step3 > step2, "step should keep increasing");

    /* vocab should have grown from conversation words */
    ASSERT(leo.tok.n_words > 255, "vocab should grow beyond bootstrap");

    leo_free(&leo);
    remove("/tmp/test_leo_multi.db.state");
    PASS();
}

/* ================================================================
 * SUPER-TOKEN TESTS
 * ================================================================ */

static void test_supertoken_scan(void) {
    TEST("supertokens: crystallization via PMI");
    CoocField c;
    cooc_init(&c, 4096);

    /* create a strong pair: tokens 5 and 7 always appear together */
    c.total_tokens = 1000;
    c.freq[5] = 10;
    c.freq[7] = 10;
    cooc_update(&c, 5, 7, 50.0f); /* very high co-occurrence */

    /* create a weak pair */
    c.freq[10] = 100;
    c.freq[11] = 100;
    cooc_update(&c, 10, 11, 5.0f); /* low PMI */

    SuperTokens st;
    supertok_init(&st);
    supertok_scan(&st, &c, 100);

    ASSERT(st.n_supers >= 1, "should crystallize at least 1 super-token");
    /* the strong pair should be crystallized */
    int found_strong = 0;
    for (int i = 0; i < st.n_supers; i++) {
        if (st.supers[i].tokens[0] == 5 && st.supers[i].tokens[1] == 7)
            found_strong = 1;
    }
    ASSERT(found_strong, "strong pair should be crystallized");

    cooc_free(&c);
    PASS();
}

/* ================================================================
 * MAIN
 * ================================================================ */

int main(void) {
    printf("\n=== Leo 2.0 Tests ===\n\n");

    /* tokenizer */
    test_tok_basic();
    test_tok_tokenize();
    test_tok_special_chars();

    /* vectors */
    test_vec_operations();
    test_vec_normalize();

    /* co-occurrence */
    test_cooc_basic();
    test_cooc_row();

    /* bigrams */
    test_bigram_basic();

    /* SDM */
    test_sdm_write_read();

    /* RoPE */
    test_rope_deterministic();
    test_rope_different_positions();

    /* prophecy */
    test_prophecy_lifecycle();
    test_prophecy_eviction();

    /* destiny */
    test_destiny_ema();

    /* memory sea */
    test_sea_record_and_decay();
    test_sea_eviction();

    /* voices */
    test_voice_init();
    test_voice_reinforce();

    /* retention */
    test_retention_griffin();

    /* super-tokens */
    test_supertoken_scan();

    /* integration */
    test_leo_bootstrap();
    test_leo_generate();
    test_leo_ingest_grows_field();
    test_leo_save_load();
    test_leo_dream();
    test_leo_multiple_conversations();

    printf("\n=== Results: %d passed, %d failed ===\n\n",
           tests_passed, tests_failed);
    return tests_failed > 0 ? 1 : 0;
}
