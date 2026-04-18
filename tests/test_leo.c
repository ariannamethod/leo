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

/* ================================================================
 * KURAMOTO-COUPLED EMOTIONAL CHAMBERS (paper Appendix B)
 * ================================================================ */

static void test_chambers_init(void) {
    TEST("chambers init zeros all activations and external inputs");
    Chambers ch;
    chambers_init(&ch);
    for (int i = 0; i < N_CHAMBERS; i++) {
        ASSERT(ch.act[i] == 0.0f, "init act not zero");
        ASSERT(ch.external[i] == 0.0f, "init external not zero");
    }
    PASS();
}

static void test_chambers_decay(void) {
    TEST("chambers decay with zero coupling pulls act toward zero");
    Chambers ch;
    chambers_init(&ch);
    /* Isolated decay: seed one chamber, external=0, coupling still fires
     * but decay dominates since opposing sin terms are bounded. */
    ch.act[CH_VOID] = 1.0f;
    float initial = ch.act[CH_VOID];
    for (int i = 0; i < 50; i++) chambers_crossfire(&ch, 1);
    ASSERT(ch.act[CH_VOID] < initial, "VOID did not decay");
    PASS();
}

static void test_chambers_decay_rates_paper(void) {
    TEST("chambers decay rates match paper Appendix B.3");
    ASSERT(CHAMBER_DECAY[CH_FEAR]    == 0.90f, "FEAR decay");
    ASSERT(CHAMBER_DECAY[CH_LOVE]    == 0.93f, "LOVE decay");
    ASSERT(CHAMBER_DECAY[CH_RAGE]    == 0.85f, "RAGE decay (fastest)");
    ASSERT(CHAMBER_DECAY[CH_VOID]    == 0.97f, "VOID decay (slowest)");
    ASSERT(CHAMBER_DECAY[CH_FLOW]    == 0.88f, "FLOW decay");
    ASSERT(CHAMBER_DECAY[CH_COMPLEX] == 0.94f, "COMPLEX decay");
    PASS();
}

static void test_chambers_coupling_antisymmetric_pairs(void) {
    TEST("chambers coupling: FEAR↔LOVE antisymmetric from paper");
    /* FEAR-LOVE pair: both -0.30 (not strict antisymmetric — paper value) */
    ASSERT(CHAMBER_COUPLING[CH_FEAR][CH_LOVE] == -0.30f, "FEAR→LOVE");
    ASSERT(CHAMBER_COUPLING[CH_LOVE][CH_FEAR] == -0.30f, "LOVE→FEAR");
    /* RAGE-FEAR: +0.50 / +0.50 from paper */
    ASSERT(CHAMBER_COUPLING[CH_RAGE][CH_FEAR] == 0.50f, "RAGE→FEAR");
    ASSERT(CHAMBER_COUPLING[CH_FEAR][CH_RAGE] == 0.50f, "FEAR→RAGE");
    /* self-coupling is zero */
    for (int i = 0; i < N_CHAMBERS; i++) {
        ASSERT(CHAMBER_COUPLING[i][i] == 0.0f, "self-coupling must be zero");
    }
    PASS();
}

static void test_chambers_crossfire_propagates(void) {
    TEST("chambers cross-coupling propagates activation through oscillators");
    Chambers ch;
    chambers_init(&ch);
    /* Seed FEAR; expect RAGE to receive positive perturbation via COUPLING[RAGE][FEAR]=0.5 */
    ch.act[CH_FEAR] = 0.8f;
    float rage_before = ch.act[CH_RAGE];
    chambers_crossfire(&ch, 3);
    /* RAGE should have moved away from 0 (either direction acceptable —
     * sign depends on sin(FEAR-RAGE) which is positive when FEAR > RAGE). */
    ASSERT(ch.act[CH_RAGE] != rage_before, "RAGE untouched by FEAR coupling");
    PASS();
}

static void test_chambers_clamped_to_unit_interval(void) {
    TEST("chambers activations clamped to [0,1] even under heavy drive");
    Chambers ch;
    chambers_init(&ch);
    ch.external[CH_VOID] = 5.0f; /* extreme drive — would overflow without clamp */
    for (int i = 0; i < 50; i++) chambers_crossfire(&ch, 1);
    for (int i = 0; i < N_CHAMBERS; i++) {
        ASSERT(ch.act[i] >= 0.0f && ch.act[i] <= 1.0f,
               "activation escaped [0,1]");
    }
    PASS();
}

static void test_chambers_external_input(void) {
    TEST("chambers external input drives activation");
    Chambers ch;
    chambers_init(&ch);
    ch.external[CH_LOVE] = 0.5f;
    chambers_crossfire(&ch, 1);
    /* act[LOVE] = (0 + couplings + 0.5) * 0.93 ≈ 0.465 before couplings */
    ASSERT(ch.act[CH_LOVE] > 0.3f, "external LOVE input not applied");
    PASS();
}

static void test_chamber_mods_identity_at_zero(void) {
    TEST("chamber coefficient mods = 1.0 when all activations zero");
    Chambers ch;
    chambers_init(&ch);
    ASSERT(chamber_alpha_mod(&ch) == 1.0f, "alpha_mod not 1.0");
    ASSERT(chamber_beta_mod(&ch)  == 1.0f, "beta_mod not 1.0");
    ASSERT(chamber_gamma_mod(&ch) == 1.0f, "gamma_mod not 1.0");
    ASSERT(chamber_tau_mod(&ch)   == 1.0f, "tau_mod not 1.0");
    PASS();
}

static void test_chamber_mods_paper_formulas(void) {
    TEST("chamber mods match paper Appendix B.4 formulas");
    Chambers ch;
    chambers_init(&ch);
    ch.act[CH_LOVE] = 1.0f;
    ch.act[CH_FEAR] = 0.0f;
    /* alpha_mod = 1 + 0.5·LOVE - 0.3·FEAR = 1.5 */
    float a = chamber_alpha_mod(&ch);
    ASSERT(a > 1.49f && a < 1.51f, "alpha_mod paper formula");
    ch.act[CH_FEAR] = 1.0f;
    /* alpha_mod = 1 + 0.5·1 - 0.3·1 = 1.2 */
    a = chamber_alpha_mod(&ch);
    ASSERT(a > 1.19f && a < 1.21f, "alpha_mod with FEAR");
    /* tau_mod = 1 - 0.3·RAGE + 0.2·FLOW */
    chambers_init(&ch);
    ch.act[CH_RAGE] = 1.0f;
    float t = chamber_tau_mod(&ch);
    ASSERT(t > 0.69f && t < 0.71f, "tau_mod RAGE damping");
    PASS();
}

static void test_chambers_persist_through_save_load(void) {
    TEST("chambers survive Leo save/load cycle");
    const char *path = "test_chambers_persist.db";
    Leo leo1;
    leo_init(&leo1, path);
    leo1.chambers.act[CH_VOID] = 0.42f;
    leo1.chambers.external[CH_FLOW] = 0.17f;
    leo_save(&leo1);
    leo_free(&leo1);

    Leo leo2;
    leo_init(&leo2, path);
    leo_load(&leo2);
    ASSERT(leo2.chambers.act[CH_VOID] > 0.41f && leo2.chambers.act[CH_VOID] < 0.43f,
           "VOID act not restored");
    ASSERT(leo2.chambers.external[CH_FLOW] > 0.16f && leo2.chambers.external[CH_FLOW] < 0.18f,
           "FLOW external not restored");
    leo_free(&leo2);

    /* cleanup */
    char cmd[600];
    snprintf(cmd, sizeof(cmd), "rm -f %s %s.state %s-shm %s-wal", path, path, path, path);
    int _ = system(cmd); (void)_;
    PASS();
}

/* ================================================================
 * VEC UTILITIES (coverage: vec_add, vec_axpy, vec_scale, vec_zero, vec_copy)
 * ================================================================ */

static void test_vec_axpy(void) {
    TEST("vec: axpy (y = y + a*x)");
    float y[4] = {1, 2, 3, 4};
    float x[4] = {1, 1, 1, 1};
    vec_axpy(y, 2.0f, x, 4);
    ASSERT(y[0] == 3 && y[1] == 4 && y[2] == 5 && y[3] == 6, "axpy incorrect");
    PASS();
}

static void test_vec_add(void) {
    TEST("vec: element-wise add");
    float dst[3] = {0}, a[3] = {1, 2, 3}, b[3] = {4, 5, 6};
    vec_add(dst, a, b, 3);
    ASSERT(dst[0] == 5 && dst[1] == 7 && dst[2] == 9, "vec_add wrong");
    PASS();
}

static void test_vec_scale(void) {
    TEST("vec: scale");
    float v[3] = {1, 2, 3};
    vec_scale(v, 3.0f, 3);
    ASSERT(v[0] == 3 && v[1] == 6 && v[2] == 9, "vec_scale wrong");
    PASS();
}

static void test_vec_zero_copy(void) {
    TEST("vec: zero and copy");
    float a[4] = {1, 2, 3, 4};
    float b[4];
    vec_copy(b, a, 4);
    ASSERT(b[0] == 1 && b[3] == 4, "vec_copy wrong");
    vec_zero(a, 4);
    ASSERT(a[0] == 0 && a[3] == 0, "vec_zero wrong");
    PASS();
}

static void test_randf_range(void) {
    TEST("randf: in [0, 1)");
    for (int i = 0; i < 100; i++) {
        float r = randf();
        ASSERT(r >= 0.0f && r < 1.0f, "randf out of range");
    }
    PASS();
}

static void test_clampf(void) {
    TEST("clampf: clamps to range");
    ASSERT(clampf(-1.0f, 0.0f, 1.0f) == 0.0f, "low clamp");
    ASSERT(clampf(2.0f, 0.0f, 1.0f) == 1.0f, "high clamp");
    ASSERT(clampf(0.5f, 0.0f, 1.0f) == 0.5f, "in-range passthrough");
    PASS();
}

/* ================================================================
 * SUBWORD TESTS (sw_init, sw_encode, sw_ingest, sw_word_score)
 * ================================================================ */

static void test_subword_init_encode(void) {
    TEST("subword: init + encode");
    SubwordField sw;
    sw_init(&sw);
    ASSERT(sw.n_tokens > 0, "subword init should seed tokens");
    int ids[64];
    int n = sw_encode(&sw, "hello world", ids, 64);
    ASSERT(n > 0, "sw_encode should produce tokens");
    sw_free(&sw);
    PASS();
}

static void test_subword_ingest_grows(void) {
    TEST("subword: ingest updates total_tokens");
    SubwordField sw;
    sw_init(&sw);
    int total_before = sw.total_tokens;
    sw_ingest(&sw, "the quick brown fox jumps over the lazy dog");
    ASSERT(sw.total_tokens > total_before, "total_tokens should grow");
    sw_free(&sw);
    PASS();
}

static void test_subword_word_score_nonneg(void) {
    TEST("subword: sw_word_score is non-negative");
    SubwordField sw;
    sw_init(&sw);
    sw_ingest(&sw, "leo the lion loves the light");
    int ctx_ids[8];
    int ctx_n = sw_encode(&sw, "leo", ctx_ids, 8);
    float score = sw_word_score(&sw, "lion", ctx_ids, ctx_n);
    ASSERT(score >= 0.0f, "score must be non-negative");
    sw_free(&sw);
    PASS();
}

/* ================================================================
 * TOKEN CLASS + GATE (coverage for compute_gate, token_class)
 * ================================================================ */

static void test_token_class_punct(void) {
    TEST("token_class: punctuation detected");
    LeoTokenizer tok; tok_init(&tok);
    CoocField c; cooc_init(&c, 512);
    int id = tok_add(&tok, ".");
    int tc = token_class(&c, &tok, id);
    ASSERT(tc == LEO_TC_PUNCT, "'.' should be punct class");
    cooc_free(&c); tok_free(&tok);
    PASS();
}

static void test_compute_gate_range(void) {
    TEST("compute_gate: returns finite value in [0,1]");
    CoocField c; cooc_init(&c, 512);
    c.freq = calloc(16, sizeof(float));
    c.freq_size = 16;
    c.freq[5] = 10.0f;
    c.total_tokens = 100;
    float g = compute_gate(&c, 5);
    ASSERT(g >= 0.0f && g <= 1.0f, "gate out of range");
    free(c.freq); c.freq = NULL;
    cooc_free(&c);
    PASS();
}

/* ================================================================
 * SOFTMAX + SAMPLE_TOKEN
 * ================================================================ */

static void test_softmax_sums_to_one(void) {
    TEST("softmax: probabilities sum to 1.0");
    float logits[5] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f};
    softmax(logits, 5, 1.0f);
    float sum = 0;
    for (int i = 0; i < 5; i++) sum += logits[i];
    ASSERT(fabsf(sum - 1.0f) < 1e-5f, "softmax must sum to 1");
    PASS();
}

static void test_softmax_monotonic(void) {
    TEST("softmax: higher logit = higher prob");
    float logits[3] = {0.1f, 1.0f, 5.0f};
    softmax(logits, 3, 1.0f);
    ASSERT(logits[2] > logits[1] && logits[1] > logits[0], "monotonicity broken");
    PASS();
}

static void test_sample_token_deterministic_peak(void) {
    TEST("sample_token: peaked distribution usually picks peak");
    float probs[4] = {0.01f, 0.01f, 0.97f, 0.01f};
    int hits = 0;
    for (int i = 0; i < 100; i++) {
        if (sample_token(probs, 4) == 2) hits++;
    }
    ASSERT(hits > 80, "peaked sample should hit peak most of the time");
    PASS();
}

/* ================================================================
 * COMPUTE FUNCTIONS (compute_novelty, compute_arousal, compute_quality)
 * ================================================================ */

static void test_compute_arousal_punctuation(void) {
    TEST("compute_arousal: exclamations raise arousal");
    float calm = compute_arousal("the cat sits");
    float excited = compute_arousal("THE CAT!!! WHAT??");
    ASSERT(excited > calm, "caps + !? should increase arousal");
    PASS();
}

static void test_compute_quality_range(void) {
    TEST("compute_quality: returns [0,1] for arbitrary text");
    float q = compute_quality("Leo is here and the world is kind.", 500);
    ASSERT(q >= 0.0f && q <= 1.0f, "quality out of range");
    PASS();
}

static void test_compute_novelty_with_leo(void) {
    TEST("compute_novelty: returns finite value for short context");
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_novelty.db");
    /* empty context */
    float n0 = compute_novelty(&leo);
    ASSERT(n0 >= 0.0f && n0 <= 1.0f, "novelty out of range");
    leo_free(&leo);
    remove("/tmp/test_leo_novelty.db.state");
    remove("/tmp/test_leo_novelty.db");
    PASS();
}

/* ================================================================
 * MATHBRAIN
 * ================================================================ */

static void test_mathbrain_init_forward(void) {
    TEST("mathbrain: init + forward produces finite output");
    MathBrain mb;
    mathbrain_init(&mb);
    float feat[MB_INPUT] = {0};
    float hidden[MB_HIDDEN] = {0};
    float out = mathbrain_forward(&mb, feat, hidden);
    ASSERT(out == out /* NaN check */, "output NaN");
    ASSERT(out >= -100.0f && out <= 100.0f, "output out of sensible range");
    PASS();
}

static void test_mathstate_features(void) {
    TEST("mathstate_to_features: fills MB_INPUT floats");
    MathState s; memset(&s, 0, sizeof(s));
    s.entropy = 0.5f; s.novelty = 0.3f; s.arousal = 0.4f;
    s.overthinking = 1.0f; s.expert_id = 2;
    float feat[MB_INPUT] = {0};
    mathstate_to_features(&s, feat);
    ASSERT(feat[0] == 0.5f, "entropy not set");
    ASSERT(feat[1] == 0.3f, "novelty not set");
    ASSERT(feat[14] == 1.0f, "overthinking not set");
    PASS();
}

/* ================================================================
 * PHASE4 (island transitions)
 * ================================================================ */

static void test_phase4_init(void) {
    TEST("phase4: init clears state");
    Phase4 p4;
    phase4_init(&p4);
    ASSERT(p4.n_transitions == 0, "transitions not zero");
    PASS();
}

static void test_phase4_record_and_suggest(void) {
    TEST("phase4: record produces suggestion after warmup");
    Phase4 p4;
    phase4_init(&p4);
    float metrics[MB_INPUT] = {0.3f, 0.4f, 0.5f};
    for (int i = 0; i < 20; i++) {
        phase4_record(&p4, i % 3, metrics, 0.6f, 0.2f, 0.1f, 0.1f);
    }
    /* suggest should not crash even if no good match */
    int s = phase4_suggest(&p4, 0);
    ASSERT(s >= -1 && s < 8, "suggest out of range");
    PASS();
}

static void test_phase4_cosine(void) {
    TEST("phase4_cosine: self-similarity = 1");
    float v[3] = {1, 2, 3};
    float c = phase4_cosine(v, v, 3);
    ASSERT(fabsf(c - 1.0f) < 1e-5f, "self cosine != 1");
    PASS();
}

/* ================================================================
 * DARIO COMPUTE (integration check — logits produced, no NaN)
 * ================================================================ */

static void test_dario_compute_runs(void) {
    TEST("dario_compute: runs without crash, logits finite");
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_dario.db");
    leo_ingest(&leo, "the quick brown fox jumps over");
    int V = leo.tok.n_words;
    if (V < 5) { leo_free(&leo); remove("/tmp/test_leo_dario.db.state");
                 remove("/tmp/test_leo_dario.db"); FAIL("vocab too small after ingest"); return; }
    float *logits = calloc(V, sizeof(float));
    float *buf = calloc(7 * V, sizeof(float));
    dario_compute(&leo, logits, V, buf);
    int finite = 1;
    for (int i = 0; i < V; i++) if (logits[i] != logits[i]) { finite = 0; break; }
    ASSERT(finite, "logits contain NaN");
    free(logits); free(buf);
    leo_free(&leo);
    remove("/tmp/test_leo_dario.db.state");
    remove("/tmp/test_leo_dario.db");
    PASS();
}

/* ================================================================
 * PROMPT CAPTURE — verifies the human-only ingestion contract
 * (Leo must NOT self-capture his output into bi/cooc during generate)
 * ================================================================ */

static void test_generate_does_not_self_capture(void) {
    TEST("leo_generate: output tokens not captured into bigram/cooc");
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_nocapture.db");
    leo_bootstrap(&leo);
    int bi_before = leo.bigrams.n_entries;
    int cooc_before = leo.cooc.n_entries;
    float freq_before_sum = 0;
    for (int i = 0; i < leo.cooc.freq_size; i++) freq_before_sum += leo.cooc.freq[i];

    /* Call generate with NO prompt — any new bi/cooc entries would be self-capture. */
    char buf[256];
    leo_generate(&leo, "", buf, sizeof(buf));

    int bi_after = leo.bigrams.n_entries;
    int cooc_after = leo.cooc.n_entries;
    float freq_after_sum = 0;
    for (int i = 0; i < leo.cooc.freq_size; i++) freq_after_sum += leo.cooc.freq[i];

    ASSERT(bi_after == bi_before, "bigram entries grew during empty-prompt generate");
    ASSERT(cooc_after == cooc_before, "cooc entries grew during empty-prompt generate");
    ASSERT(fabsf(freq_after_sum - freq_before_sum) < 0.01f,
           "cooc.freq accumulated from self-output");
    leo_free(&leo);
    remove("/tmp/test_leo_nocapture.db.state");
    remove("/tmp/test_leo_nocapture.db");
    PASS();
}

static void test_generate_captures_prompt_tokens(void) {
    TEST("leo_generate: human words captured via prompt ingestion");
    Leo leo;
    leo_init(&leo, "/tmp/test_leo_capture.db");
    leo_bootstrap(&leo);
    int vocab_before = leo.tok.n_words;
    char buf[256];
    /* Use intentionally novel words the bootstrap does not have. */
    leo_generate(&leo, "pumpernickel xylophone quokka", buf, sizeof(buf));
    int vocab_after = leo.tok.n_words;
    ASSERT(vocab_after > vocab_before, "novel prompt words should grow vocab");
    leo_free(&leo);
    remove("/tmp/test_leo_capture.db.state");
    remove("/tmp/test_leo_capture.db");
    PASS();
}

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

    /* Kuramoto chambers (paper Appendix B) */
    test_chambers_init();
    test_chambers_decay();
    test_chambers_decay_rates_paper();
    test_chambers_coupling_antisymmetric_pairs();
    test_chambers_crossfire_propagates();
    test_chambers_external_input();
    test_chambers_clamped_to_unit_interval();
    test_chamber_mods_identity_at_zero();
    test_chamber_mods_paper_formulas();
    test_chambers_persist_through_save_load();

    /* Vec utilities */
    test_vec_axpy();
    test_vec_add();
    test_vec_scale();
    test_vec_zero_copy();
    test_randf_range();
    test_clampf();

    /* Subword */
    test_subword_init_encode();
    test_subword_ingest_grows();
    test_subword_word_score_nonneg();

    /* Token class + gate */
    test_token_class_punct();
    test_compute_gate_range();

    /* Softmax + sample */
    test_softmax_sums_to_one();
    test_softmax_monotonic();
    test_sample_token_deterministic_peak();

    /* Compute helpers */
    test_compute_arousal_punctuation();
    test_compute_quality_range();
    test_compute_novelty_with_leo();

    /* Mathbrain */
    test_mathbrain_init_forward();
    test_mathstate_features();

    /* Phase4 */
    test_phase4_init();
    test_phase4_record_and_suggest();
    test_phase4_cosine();

    /* Dario integration */
    test_dario_compute_runs();

    /* Prompt capture contract (human-only, no self-capture) */
    test_generate_does_not_self_capture();
    test_generate_captures_prompt_tokens();

    printf("\n=== Results: %d passed, %d failed ===\n\n",
           tests_passed, tests_failed);
    return tests_failed > 0 ? 1 : 0;
}
