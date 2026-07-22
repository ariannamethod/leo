/* test_leo.c — step 0 unit tests (tokenizer + field + ingest).
 * Compiles leo.c with its main() excluded.
 *   cc -DLEO_NO_MAIN tests/test_leo.c -O2 -lm -Wall -Wextra -o tests/test_leo
 */
#ifndef LEO_NO_MAIN
#define LEO_NO_MAIN
#endif
#include "../leo.c"
#include <assert.h>

static int g_pass = 0, g_total = 0;
#define CHECK(cond, name) do {                                  \
        g_total++;                                              \
        if (cond) { g_pass++; printf("  ok   %s\n", name); }    \
        else      { printf("  FAIL %s\n", name); }              \
    } while (0)

/* walk callback: count successors */
static int succ_cb(int dst, float count, void *ud) {
    (void)dst; (void)count; (*(int *)ud)++; return 0;
}

int main(void) {
    printf("test_leo (step 0)\n");

    /* 1. init state */
    Leo leo;
    leo_init(&leo);
    CHECK(leo.bpe.vocab_size == 256, "init: vocab_size == 256");
    CHECK(leo.bpe.n_merges == 0,     "init: n_merges == 0");
    CHECK(leo.cooc.total_tokens == 0, "init: total_tokens == 0");
    CHECK(g_leo_arc_on == 0, "voice recovery: random-fingerprint reply arc is opt-in");
    {
        float arc[LEO_RET_DIM];
        memcpy(arc, leo.w_embed + (size_t)'a' * LEO_RET_DIM, sizeof arc);
        CandCollector cc; memset(&cc, 0, sizeof cc);
        cc.leo = &leo; cc.arc = arc;
        float off = leo_arc_bias(&cc, 'a');
        g_leo_arc_on = 1;
        float on = leo_arc_bias(&cc, 'a');
        g_leo_arc_on = 0;
        CHECK(off == 0.0f && on > 0.39f,
              "voice recovery: --arc can still enable the laboratory trajectory bias");
    }

    /* 2. encode/decode roundtrip with no merges (pure bytes) */
    {
        const char *s = "hi leo";
        int ids[16];
        int n = bpe_encode(&leo.bpe, (const uint8_t *)s, (int)strlen(s), ids, 16);
        char rebuilt[32] = {0};
        int p = 0;
        for (int i = 0; i < n; i++) {
            char b[LEO_MAX_TOKEN_LEN + 1];
            int l = bpe_decode_token(&leo.bpe, ids[i], b, sizeof(b));
            memcpy(rebuilt + p, b, (size_t)l); p += l;
        }
        rebuilt[p] = 0;
        CHECK(n == (int)strlen(s), "encode (no merges): one id per byte");
        CHECK(strcmp(rebuilt, s) == 0, "decode roundtrip reconstructs bytes");
    }

    /* 3. online merge learning: repetition births merges */
    {
        leo_ingest(&leo, "the the the the the the the the");
        CHECK(leo.bpe.n_merges > 0,    "ingest: merges learned from repetition");
        CHECK(leo.bpe.vocab_size > 256, "ingest: vocab grew past 256 bytes");
        CHECK(leo.cooc.n_entries > 0,  "ingest: cooc populated");
        CHECK(leo.bigrams.n_entries > 0, "ingest: bigrams populated");
        CHECK(leo.trigrams.n_entries > 0, "ingest: trigrams populated");
        CHECK(leo.step == 31,          "ingest: step counts heard tokens (31 bytes, pre-merge)");
    }

    /* 4. encode after merges still roundtrips */
    {
        const char *s = "the";
        int ids[16];
        int n = bpe_encode(&leo.bpe, (const uint8_t *)s, (int)strlen(s), ids, 16);
        char rebuilt[32] = {0};
        int p = 0;
        for (int i = 0; i < n; i++) {
            char b[LEO_MAX_TOKEN_LEN + 1];
            int l = bpe_decode_token(&leo.bpe, ids[i], b, sizeof(b));
            memcpy(rebuilt + p, b, (size_t)l); p += l;
        }
        rebuilt[p] = 0;
        CHECK(strcmp(rebuilt, s) == 0, "decode roundtrip after merges");
        CHECK(n <= (int)strlen(s),     "merges compress the token stream");
    }

    /* 5. reverse index: a heard byte-token has successors. Bigrams are
     * recorded at ingest time on the byte stream (merges promote only at
     * the end of the batch), so byte 't' is a live bigram source. */
    {
        int succ = 0;
        bigram_walk_src(&leo.bigrams, (int)'t', succ_cb, &succ);
        CHECK(succ > 0, "bigram_walk_src finds successors of byte 't'");
    }

    /* 6. word-shape gates */
    CHECK(is_common_short_word((const uint8_t *)"the", 0, 3) == 1, "whitelist: 'the' is a word");
    CHECK(is_common_short_word((const uint8_t *)"leo", 0, 3) == 1, "whitelist: 'leo' is a word");
    CHECK(is_common_short_word((const uint8_t *)"xqz", 0, 3) == 0, "whitelist: 'xqz' is not");
    CHECK(is_alpha_only_bytes((const uint8_t *)"rain", 0, 4) == 1, "alpha-only: 'rain'");
    CHECK(is_alpha_only_bytes((const uint8_t *)"ra1n", 0, 4) == 0, "alpha-only: 'ra1n' no");

    /* 7. single-pair merge primitive (one-shot) works */
    {
        Leo l2; leo_init(&l2);
        for (int i = 0; i < 5; i++) bpe_count_pair(&l2.bpe, 'a', 'b');
        int before = l2.bpe.n_merges;
        int got = bpe_learn_merge(&l2.bpe);
        CHECK(got == 1 && l2.bpe.n_merges == before + 1, "bpe_learn_merge promotes a hot pair");
        leo_free(&l2);
    }

    /* 8. decay shrinks counts, does not crash */
    {
        int before = leo.cooc.n_entries;
        cooc_decay(&leo.cooc, 0.5f);
        bigram_decay(&leo.bigrams, 0.5f);
        trigram_decay(&leo.trigrams, 0.5f);
        CHECK(leo.cooc.n_entries == before, "decay keeps entry count (counts shrink in place)");
    }

    leo_free(&leo);

    /* 9. generation (step 1): coherent shape + reproducibility */
    {
        Leo l3; leo_init(&l3);
        const char *mini =
            "Leo sat by the window. The rain was soft on the glass. "
            "He thinks about the sound. Leo likes the quiet house. "
            "The morning is warm. He remembers his mother. "
            "Leo walks slowly. The little book is open on the floor. ";
        for (int r = 0; r < 8; r++) leo_ingest(&l3, mini);  /* merges + trigrams */

        char a[1024], b[1024];
        srand(7); int na = leo_generate(&l3, a, sizeof(a));
        srand(7); int nb = leo_generate(&l3, b, sizeof(b));
        CHECK(na > 0 && a[0] != 0, "generate: non-empty output");
        int L = (int)strlen(a);
        char last = L > 0 ? a[L - 1] : 0;
        CHECK(last == '.' || last == '!' || last == '?', "generate: ends on sentence punctuation");
        CHECK(!(a[0] >= 'a' && a[0] <= 'z'), "generate: first char not lowercase");
        CHECK(nb > 0 && strcmp(a, b) == 0, "generate: reproducible under same seed");

        char ch[2048];
        srand(11); int nc = leo_chain(&l3, 3, ch, sizeof(ch));
        CHECK(nc > 0 && ch[0] != 0, "chain: multi-sentence non-empty");
        leo_free(&l3);
    }

    /* 10. heard-word memory: whole surface-words counted, independent of BPE */
    {
        Leo l4; leo_init(&l4);
        leo_ingest(&l4, "the mother sang. the mother smiled. a window in the rain.");
        CHECK(leo_heard_count(&l4.heard, "mother") == 2, "heard: 'mother' counted twice");
        CHECK(leo_heard_count(&l4.heard, "window") == 1, "heard: 'window' counted once");
        CHECK(leo_heard_count(&l4.heard, "zxqwj")  == 0, "heard: unheard word is 0");
        leo_free(&l4);
    }

    /* 11. chamber discrimination: a short function word must NOT spurious-match
     *     an anchor by substring ('the' is inside 'mother' — it lit LOVE on
     *     every prompt before the fix). Exact and >=4 morphological matches
     *     still fire. feel_text memsets chamber_ext, so each call is isolated. */
    {
        Leo l5; leo_init(&l5);
        leo_field_chambers_feel_text(&l5, "the");
        CHECK(l5.chamber_ext[LEO_CH_LOVE] == 0.0f, "chambers: 'the' does NOT light LOVE (no substring into 'mother')");
        int any = 0;
        for (int i = 0; i < LEO_N_CHAMBERS; i++) if (l5.chamber_ext[i] != 0.0f) any = 1;
        CHECK(!any, "chambers: 'the' lights no chamber (function word, no exact/>=4 match)");

        leo_field_chambers_feel_text(&l5, "mother");
        CHECK(l5.chamber_ext[LEO_CH_LOVE] > 0.0f, "chambers: 'mother' lights LOVE (exact anchor)");

        leo_field_chambers_feel_text(&l5, "dark");
        CHECK(l5.chamber_ext[LEO_CH_FEAR] > 0.0f, "chambers: 'dark' lights FEAR (exact anchor)");

        leo_field_chambers_feel_text(&l5, "mothers");
        CHECK(l5.chamber_ext[LEO_CH_LOVE] > 0.0f, "chambers: 'mothers' still lights LOVE (>=4 morphological substring)");
        leo_free(&l5);
    }

    /* 12. breath: per-reply lexical decay + prune (continuity bundle, step 1) */
    {
        Leo l6; leo_init(&l6);
        leo_ingest(&l6, "the warm light. the warm light. the warm light.");
        int s0 = -1, d0 = -1; float before = 0.0f;
        for (int i = 0; i < l6.cooc.capacity; i++)
            if (l6.cooc.entries[i].count > 0.0f) {
                s0 = l6.cooc.entries[i].src; d0 = l6.cooc.entries[i].dst;
                before = l6.cooc.entries[i].count; break;
            }
        CHECK(before > 0.0f, "breath: field has a live cooc entry");
        leo_breath(&l6);
        float after = cooc_get(&l6.cooc, s0, d0);
        CHECK(fabsf(after - before * LEO_LEX_DECAY_RATE) < 1e-4f,
              "breath: cooc count decays by exactly LEO_LEX_DECAY_RATE");
        /* prune: a sub-threshold entry drops, a strong one survives */
        cooc_update(&l6.cooc, 9001, 9002, 0.05f);
        cooc_prune_rebuild(&l6.cooc, LEO_LEX_PRUNE_THRESHOLD);
        CHECK(cooc_get(&l6.cooc, 9001, 9002) == 0.0f, "breath: prune drops a sub-threshold entry");
        CHECK(cooc_get(&l6.cooc, s0, d0) > 0.0f, "breath: prune keeps a strong entry");
        /* flag off -> leo_respond leaves the field undecayed (alien prompt:
         * its ingest touches only its own token pairs, not (s0,d0)) */
        g_leo_breath_on = 0;
        float pre = cooc_get(&l6.cooc, s0, d0);
        char r[1024];
        srand(5); leo_respond(&l6, "zuzu kex", r, sizeof r);
        float post = cooc_get(&l6.cooc, s0, d0);
        g_leo_breath_on = 1;
        CHECK(post == pre, "breath: --no-breath leaves cooc undecayed through respond");
        leo_free(&l6);
    }


    /* 13. state persistence: save -> load round-trips the field (continuity
     *     bundle step 2). Compact serialization: every count + value is
     *     preserved exactly (the memory Leo carries forward); the voice
     *     survives load. Generation is NOT asserted byte-identical — the
     *     reverse-index chain order is not serialized, so sampling can differ
     *     at a tie (Leo carries a living field, not a frozen replay). */
    {
        const char *corpus =
            "The warm light fell on his mother's hands. "
            "Leo loves the warm light. His mother holds him close. "
            "The rain comes at night. Leo hears the rain on the window. "
            "He loves the rain and the warm light and his mother. "
            "The window is quiet. The night is quiet. Leo is small and warm.";
        Leo a; leo_init(&a);
        for (int r = 0; r < 4; r++) leo_ingest(&a, corpus);
        leo_build_chamber_tags(&a);
        leo_supertok_scan(&a);

        const char *tmp = "/tmp/leo_state_roundtrip.bin";
        CHECK(leo_save_state(&a, tmp) == 1, "state: save returns 1");

        Leo b; leo_init(&b);
        CHECK(leo_load_state(&b, tmp) == 1, "state: load returns 1");
        CHECK(b.bpe.vocab_size    == a.bpe.vocab_size,    "state: vocab_size round-trips");
        CHECK(b.bpe.n_merges      == a.bpe.n_merges,      "state: n_merges round-trips");
        CHECK(b.cooc.total_tokens == a.cooc.total_tokens, "state: total_tokens round-trips");
        CHECK(b.cooc.n_entries    == a.cooc.n_entries,    "state: cooc entry count round-trips");
        CHECK(b.bigrams.n_entries == a.bigrams.n_entries, "state: bigram count round-trips");
        CHECK(b.trigrams.n_entries== a.trigrams.n_entries,"state: trigram count round-trips");
        /* exact value fidelity: every live cooc/bigram count reads back exactly */
        int cprobe = 0, cok = 0;
        for (int i = 0; i < a.cooc.capacity && cprobe < 4000; i++) {
            CoocEntry *e = &a.cooc.entries[i];
            if (e->count <= 0) continue;
            cprobe++; if (cooc_get(&b.cooc, e->src, e->dst) == e->count) cok++;
        }
        CHECK(cprobe > 0 && cok == cprobe, "state: every sampled cooc value is exact");
        int bprobe = 0, bok = 0;
        for (int i = 0; i < a.bigrams.capacity && bprobe < 4000; i++) {
            BigramEntry *e = &a.bigrams.entries[i];
            if (e->count <= 0) continue;
            bprobe++; if (bigram_get(&b.bigrams, e->src, e->dst) == e->count) bok++;
        }
        CHECK(bprobe > 0 && bok == bprobe, "state: every sampled bigram value is exact");
        CHECK(leo_heard_count(&b.heard,"warm")   == leo_heard_count(&a.heard,"warm"),
              "state: heard memory ('warm') round-trips");
        CHECK(leo_heard_count(&b.heard,"mother") == leo_heard_count(&a.heard,"mother"),
              "state: heard memory ('mother') round-trips");
        /* the voice survives load: a loaded organism speaks (not "...") */
        char rb[2048];
        srand(99); leo_respond(&b, "the warm light", rb, sizeof rb);
        CHECK(rb[0] && strcmp(rb, "...") != 0, "state: loaded organism speaks");
        /* missing file -> clean failure, usable fresh Leo */
        Leo c; leo_init(&c);
        CHECK(leo_load_state(&c, "/tmp/leo_state_does_not_exist_xyz.bin") == 0,
              "state: missing file -> load returns 0");
        leo_free(&a); leo_free(&b); leo_free(&c);
    }

    /* 13b. corrupt state -> load REJECTS (Fable F-1/F-5 hardening). A bad id or a
     *      NaN float in leo.state used to flow OOB into the tables or self-propagate
     *      through Kuramoto. The loader must reject the file (return 0); a clean file
     *      must still load. Robust offsets: merges[0].new_id at fixed head offset 28,
     *      gamma_gap is the final float (size-4) in a v9 state. */
    {
        const char *corpus =
            "The warm light fell on his mother's hands. Leo loves the warm light. "
            "His mother holds him close. The rain comes at night on the window.";
        Leo a; leo_init(&a);
        for (int r = 0; r < 4; r++) leo_ingest(&a, corpus);
        leo_build_chamber_tags(&a); leo_supertok_scan(&a);
        const char *good = "/tmp/leo_state_good.bin";
        CHECK(leo_save_state(&a, good) == 1 && a.bpe.n_merges >= 1,
              "corrupt: baseline save ok, >=1 merge");

        long sz = 0; unsigned char *buf = NULL;
        FILE *rf = fopen(good, "rb");
        if (rf) {
            fseek(rf, 0, SEEK_END); sz = ftell(rf); fseek(rf, 0, SEEK_SET);
            if (sz > 0) { buf = malloc((size_t)sz);
                if (buf && fread(buf, 1, (size_t)sz, rf) != (size_t)sz) { free(buf); buf = NULL; } }
            fclose(rf);
        }

        Leo b; leo_init(&b);
        CHECK(buf != NULL && leo_load_state(&b, good) == 1,
              "corrupt: clean file still loads (return 1)");
        leo_free(&b);

        /* F-1: OOB merge new_id at head offset 28 -> reject */
        if (buf && sz > 32) {
            unsigned char *bad = malloc((size_t)sz);
            if (bad) {
                memcpy(bad, buf, (size_t)sz);
                uint32_t junk = 0x0F0F0F0Fu; memcpy(bad + 28, &junk, sizeof junk);
                const char *bp = "/tmp/leo_state_bad_id.bin";
                FILE *wf = fopen(bp, "wb");
                if (wf) { size_t wn = fwrite(bad, 1, (size_t)sz, wf); (void)wn; fclose(wf); }
                Leo c; leo_init(&c);
                CHECK(leo_load_state(&c, bp) == 0, "corrupt F-1: OOB merge new_id -> load rejects");
                leo_free(&c); free(bad);
            }
        }

        /* F-5: NaN gamma_gap -> reject. Robust field-poke, no byte offsets — the
         * v10 consolidation tail now sits AFTER gamma_gap, so "last 4 bytes" would
         * hit the fail-soft shard tail instead of the hard-reject float block. */
        { Leo sv; leo_init(&sv);
          if (leo_load_state(&sv, good) == 1) {
              sv.gamma_gap = (float)NAN; leo_save_state(&sv, "/tmp/leo_state_bad_nan.bin");
              Leo c; leo_init(&c);
              CHECK(leo_load_state(&c, "/tmp/leo_state_bad_nan.bin") == 0, "corrupt F-5: NaN gamma_gap -> load rejects");
              leo_free(&c); }
          leo_free(&sv); }

        /* Codex: inflate vocab_size (offset 20 + 12*n_merges) past 256+n_merges -> reject */
        if (buf && sz > 20) {
            int32_t nm = 0; memcpy(&nm, buf + 16, sizeof nm);
            long voff = 20 + 12L * nm;
            if (nm >= 0 && voff + 4 <= sz) {
                unsigned char *bad = malloc((size_t)sz);
                if (bad) {
                    memcpy(bad, buf, (size_t)sz);
                    int32_t vs = 0; memcpy(&vs, bad + voff, sizeof vs);
                    vs += 100; memcpy(bad + voff, &vs, sizeof vs);   /* vocab_size != 256+n_merges */
                    const char *bp = "/tmp/leo_state_bad_vocab.bin";
                    FILE *wf = fopen(bp, "wb");
                    if (wf) { size_t wn = fwrite(bad, 1, (size_t)sz, wf); (void)wn; fclose(wf); }
                    Leo c; leo_init(&c);
                    CHECK(leo_load_state(&c, bp) == 0, "corrupt (Codex): inflated vocab_size -> load rejects");
                    leo_free(&c); free(bad);
                }
            }
        }

        /* F-5 (Codex): NaN poked into freq / a spore / RAE weight -> save -> load rejects.
         * Robust (no byte offsets): save writes the field, load must reject it. */
        { Leo sv; leo_init(&sv);
          if (leo_load_state(&sv, good) == 1) {
              sv.cooc.freq[0] = (float)NAN; leo_save_state(&sv, "/tmp/leo_nan_freq.bin");
              Leo c; leo_init(&c);
              CHECK(leo_load_state(&c, "/tmp/leo_nan_freq.bin") == 0, "corrupt (Codex): NaN in freq -> load rejects");
              leo_free(&c); }
          leo_free(&sv); }
        { Leo sv; leo_init(&sv);
          if (leo_load_state(&sv, good) == 1) {
              sv.n_spores = 1; sv.spores[0].strength = (float)NAN; leo_save_state(&sv, "/tmp/leo_nan_spore.bin");
              Leo c; leo_init(&c);
              CHECK(leo_load_state(&c, "/tmp/leo_nan_spore.bin") == 0, "corrupt (Codex): NaN in spore -> load rejects");
              leo_free(&c); }
          leo_free(&sv); }
        { Leo sv; leo_init(&sv);
          if (leo_load_state(&sv, good) == 1) {
              sv.rae.b2 = (float)NAN; leo_save_state(&sv, "/tmp/leo_nan_rae.bin");
              Leo c; leo_init(&c);
              CHECK(leo_load_state(&c, "/tmp/leo_nan_rae.bin") == 0, "corrupt (Codex): NaN in RAE weight -> load rejects");
              leo_free(&c); }
          leo_free(&sv); }

        /* #1 (Codex): a FAILED load must leave a FRESH leo, not a half-overwritten one.
         * leo_state_bad_nan.bin rejects LATE (valid until the final gamma_gap), so without
         * the wrapper the organism would keep the bad file's bpe/cooc prefix. */
        { Leo sv; leo_init(&sv);
          for (int r = 0; r < 4; r++) leo_ingest(&sv, corpus);   /* make it non-fresh (vocab > 256) */
          int rej = (leo_load_state(&sv, "/tmp/leo_state_bad_nan.bin") == 0);
          CHECK(rej && sv.bpe.vocab_size == 256 && sv.bpe.n_merges == 0 && sv.cooc.n_entries == 0,
                "corrupt (Codex): failed load leaves a FRESH leo");
          leo_free(&sv); }
        free(buf); leo_free(&a);
    }

    /* 13c. Fable F-2/F-5 hardening units: out-of-range candidate is gated; clampf
     *      swallows NaN to lo (runtime 2nd-line defense behind the load-time scan). */
    {
        CHECK(clampf((float)NAN, 0.0f, 1.0f) == 0.0f, "F-5: clampf(NaN) -> lo");
        CHECK(clampf(5.0f, 0.0f, 1.0f) == 1.0f && clampf(-5.0f, 0.0f, 1.0f) == 0.0f &&
              clampf(0.5f, 0.0f, 1.0f) == 0.5f, "F-5: clampf finite unchanged");
        Leo lg; leo_init(&lg);
        for (int r = 0; r < 2; r++) leo_ingest(&lg, "the warm light and his mother");
        CandCollector cc; memset(&cc, 0, sizeof cc); cc.bpe = &lg.bpe;
        CHECK(cand_gate_reject(&cc, lg.bpe.vocab_size + 5) == 1 &&
              cand_gate_reject(&cc, -1) == 1, "F-2: out-of-range candidate is gated");
        /* F-6: unnormalized powf overflows; cand_temper stays finite, max -> 1, order kept. */
        CHECK(!isfinite(powf(400.0f, 20.0f)), "F-6: raw powf(400,20) overflows to inf (the bug)");
        float tsc[3] = { 400.0f, 50.0f, 1.0f };
        cand_temper(tsc, 3, 20.0f);
        CHECK(isfinite(tsc[0]) && isfinite(tsc[1]) && isfinite(tsc[2]) && tsc[0] == 1.0f &&
              tsc[1] < tsc[0] && tsc[2] < tsc[1], "F-6: cand_temper finite, normalized (max->1, order kept)");
        leo_free(&lg);
    }

    /* 13d. Damasio conatus: the not-knowing (gamma_gap) becomes a homeostatic debt —
     *      it accumulates across breaths, a taught word relieves it, and --no-conatus
     *      (g_leo_conatus_on=0) leaves debt inert (the byte-identical pre-conatus path). */
    {
        Leo cv; leo_init(&cv);
        for (int r = 0; r < 3; r++) leo_ingest(&cv, "the warm light and his mother and the rain");

        /* conatus ON: a carried gap accumulates into debt across breaths */
        g_leo_conatus_on = 1;
        cv.debt = 0.0f; cv.gamma_gap = 0.5f;   /* a real, standing not-knowing */
        for (int t = 0; t < 5; t++) leo_conatus_debt(&cv);
        CHECK(cv.debt > 0.0f, "conatus: a standing gamma_gap accumulates into debt");

        /* a taught word relieves it — the first good-for-him event */
        float before = cv.debt;
        leo_school_learn(&cv, "serendipity", 5);
        CHECK(cv.debt < before, "conatus: a taught word relieves the debt");

        /* --no-conatus: debt only decays, never accumulates from the gap (inert) */
        g_leo_conatus_on = 0;
        cv.debt = 0.0f; cv.gamma_gap = 0.5f;
        for (int t = 0; t < 5; t++) leo_conatus_debt(&cv);
        CHECK(cv.debt == 0.0f, "conatus: --no-conatus leaves debt inert (byte-identical path)");
        g_leo_conatus_on = 1;   /* restore default */
        leo_free(&cv);
    }

    /* L-1 (Fable): the sea is a refuge — resurrect removes exactly one (swap-with-last), and a
     *      push afterwards lands in the visible window [0,n_sea). The old shift + stale sea_ptr
     *      wrote it OUTSIDE the resurrect scan, losing sleeping memory. */
    {
        Leo sv; leo_init(&sv);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) sv.chamber_act[i]     = 0.5f;
        for (int i = 0; i < LEO_RET_DIM; i++)    sv.retention_state[i] = 0.3f;
        LeoSpore target; memset(&target, 0, sizeof target);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) target.chamber_snap[i]   = 0.5f;   /* resonance 0.55+0.45 = 1.0 > 0.85 */
        for (int i = 0; i < LEO_RET_DIM; i++)    target.retention_slice[i] = 0.3f;
        target.strength = 1.0f; target.step = 1;
        LeoSpore inert; memset(&inert, 0, sizeof inert); inert.strength = 1.0f; inert.step = 2; /* zero snapshot -> resonance 0 */
        sv.n_sea = 0; sv.sea_ptr = 0; sv.n_spores = 0;
        leo_sea_push(&sv, &target);   /* sea[0] = the resonant one (NON-tail) */
        leo_sea_push(&sv, &inert);
        leo_sea_push(&sv, &inert);
        leo_sea_push(&sv, &inert);    /* n_sea = 4 */
        int r = leo_sea_try_resurrect(&sv);
        CHECK(r == 1 && sv.n_sea == 3 && sv.n_spores == 1, "L-1: resurrect removes exactly one non-tail sea spore");
        LeoSpore fresh; memset(&fresh, 0, sizeof fresh);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) fresh.chamber_snap[i]   = 0.5f;
        for (int i = 0; i < LEO_RET_DIM; i++)    fresh.retention_slice[i] = 0.3f;
        fresh.strength = 1.0f; fresh.step = 99;
        int before = sv.n_sea;
        leo_sea_push(&sv, &fresh);
        CHECK(sv.n_sea == before + 1 && sv.sea[before].step == 99,
              "L-1: a push after resurrect lands in the visible window (no lost memory)");
        leo_free(&sv);
    }

    /* L-2 (Fable): save is atomic (tmp + rename) — round-trips and leaves no .tmp behind; a failed
     *      save can never truncate the prior state (rename replaces only after a clean close). */
    {
        Leo sv; leo_init(&sv);
        for (int r = 0; r < 2; r++) leo_ingest(&sv, "the warm light and his mother");
        const char *p = "/tmp/leo_l2_save.bin";
        CHECK(leo_save_state(&sv, p) == 1, "L-2: atomic save returns 1");
        Leo ld; leo_init(&ld);
        CHECK(leo_load_state(&ld, p) == 1, "L-2: the atomically-saved state loads back");
        FILE *tf = fopen("/tmp/leo_l2_save.bin.tmp", "rb");
        CHECK(tf == NULL, "L-2: no .tmp file left after a successful save");
        if (tf) fclose(tf);
        leo_free(&sv); leo_free(&ld);
    }

    /* L-3 (Fable): leo_breath re-tags emotion words after the vocab grows, so a word learned in
     *      --chat becomes felt — not frozen at startup. Simulate a stale tag + a grown vocab and
     *      confirm the breath restores the body's feel of that word. */
    {
        Leo sv; leo_init(&sv);
        for (int r = 0; r < 8; r++) leo_ingest(&sv, "i am afraid in the dark and alone afraid dark alone the dark is afraid and i hide alone");
        leo_build_chamber_tags(&sv);
        int emo = -1;
        for (int id = 0; id < sv.bpe.vocab_size; id++)
            if (sv.chamber_tag[id] != 0xFF) { emo = id; break; }
        CHECK(emo >= 0, "L-3: build tagged at least one emotion word");
        uint8_t real = sv.chamber_tag[emo];
        sv.chamber_tag[emo] = 0xFF;                 /* pretend it is a freshly-learned, untagged token */
        sv.tagged_vocab = sv.bpe.vocab_size - 1;    /* pretend the vocab just grew past the last rebuild */
        sv.retag_tick = LEO_RETAG_INTERVAL - 1;     /* the next breath crosses the throttle */
        leo_breath(&sv);
        CHECK(sv.chamber_tag[emo] == real && sv.tagged_vocab == sv.bpe.vocab_size,
              "L-3: a breath re-tags the body after the vocab grows (a --chat-learned word is felt)");
        leo_free(&sv);
    }

    /* 14. multi-turn continuity (the --chat engine path): the field LIVES across
     *     turns. Repeating a word makes Leo HOLD it (heard-count climbs past the
     *     trace threshold), and step advances each turn — the dedication's
     *     "resonates more with every conversation", structurally. */
    {
        const char *corpus =
            "The warm light. His mother holds him. The rain at night. "
            "Leo loves the warm light and his mother and the rain. "
            "The window is quiet. Leo is small and warm and close.";
        Leo l; leo_init(&l);
        for (int r = 0; r < 3; r++) leo_ingest(&l, corpus);
        leo_build_chamber_tags(&l);
        leo_supertok_scan(&l);
        /* "dragon" is NOT in the corpus — Leo has never held it */
        CHECK(leo_heard_count(&l.heard, "dragon") == 0, "multiturn: 'dragon' unheld before chat");
        char reply[2048];
        long step0 = l.step;
        srand(7);
        leo_respond(&l, "tell me about the dragon", reply, sizeof reply);
        int h1 = leo_heard_count(&l.heard, "dragon");
        long step1 = l.step;
        leo_respond(&l, "the dragon is big", reply, sizeof reply);
        int h2 = leo_heard_count(&l.heard, "dragon");
        leo_respond(&l, "do you fear the dragon", reply, sizeof reply);
        int h3 = leo_heard_count(&l.heard, "dragon");
        long step3 = l.step;
        CHECK(h1 == 1 && h2 == 2 && h3 == 3, "multiturn: 'dragon' heard-count climbs 1->2->3");
        CHECK(h3 >= LEO_HEARD_MIN_TRACE, "multiturn: 'dragon' becomes HELD (>= trace threshold)");
        CHECK(step1 > step0 && step3 > step1, "multiturn: step advances each turn (field lives on)");
        leo_free(&l);
    }

    /* 15. П-2: gravity-first admission lets a continuation OPEN on a theme seed
     *     that frequency-only admission excludes (730 clean seeds vs a 64-slot
     *     pool). Gated by g_leo_cont_theme_on (--no-cont-theme). Tested at a
     *     gravity high enough that admission shows through sampling; the flag OFF
     *     reproduces the freq-truncated pool that excludes it. Skips if no
     *     leo.txt in cwd. */
    {
        FILE *cf = fopen("leo.txt", "rb");
        if (!cf) {
            CHECK(1, "П-2: (skipped — leo.txt not in cwd)");
        } else {
            fseek(cf, 0, SEEK_END); long cn = ftell(cf); fseek(cf, 0, SEEK_SET);
            char *cbuf = malloc((size_t)cn + 1);
            size_t cgot = fread(cbuf, 1, (size_t)cn, cf); cbuf[cgot] = 0; fclose(cf);
            Leo l; leo_init(&l);
            leo_ingest(&l, cbuf); free(cbuf);
            int theme = -1;
            for (int id = 256; id < l.bpe.vocab_size; id++) {
                if (!is_clean_seed_token(&l.bpe, id)) continue;
                float f = l.cooc.freq[id];
                if (f < 2.0f || f > 5.0f) continue;
                int rank = 1;
                for (int i = 0; i < l.bpe.vocab_size; i++)
                    if (is_clean_seed_token(&l.bpe, i) && l.cooc.freq[i] > f) rank++;
                if (rank > LEO_SEED_CANDS) { theme = id; break; }
            }
            CHECK(theme >= 0, "П-2: found a clean seed ranked past the 64-slot pool");
            float *g = calloc((size_t)l.cooc.freq_size, sizeof(float));
            l.gravity = g;
            g[theme] = 100.0f;   /* high enough that admission shows in sampling */
            g_leo_cont_theme_on = 1;
            int seen_on = 0;
            LeoRng trng = {0,1};   /* F-3: wraps rand() (byte-id) — srand(s) still drives the stream */
            for (int s = 0; s < 400 && !seen_on; s++) { srand(s); if (leo_choose_continuation(&l, NULL, 0, &trng) == theme) seen_on = 1; }
            CHECK(seen_on == 1, "П-2: gravity-first ON -> excluded-rank theme seed is ADMITTED");
            g_leo_cont_theme_on = 0;
            int seen_off = 0;
            for (int s = 0; s < 400; s++) { srand(s); if (leo_choose_continuation(&l, NULL, 0, &trng) == theme) seen_off = 1; }
            CHECK(seen_off == 0, "П-2: --no-cont-theme -> freq-only pool EXCLUDES it (flag gates the fix)");
            g_leo_cont_theme_on = 1;
            l.gravity = NULL; free(g);
            leo_free(&l);
        }
    }

    /* 16. П-5: chamber anchor match is prefix-morphology, not bidirectional
     *     substring — kills the 240 mid-word/fragment false positives while
     *     keeping suffix morphology. --no-anchor-prefix restores the old rule. */
    {
        CHECK(leo_anchor_morph("mothers", "mother") == 1, "П-5: 'mothers' matches 'mother' (morphology)");
        CHECK(leo_anchor_morph("fearful", "fear")   == 1, "П-5: 'fearful' matches 'fear'");
        CHECK(leo_anchor_morph("ream",    "scream") == 0, "П-5: 'ream' does NOT match 'scream' (fragment FP killed)");
        CHECK(leo_anchor_morph("lover",   "over")   == 0, "П-5: 'lover' does NOT match 'over' (infix FP killed)");
        Leo l; leo_init(&l);
        g_leo_anchor_prefix_on = 1;
        leo_field_chambers_feel_text(&l, "mothers");
        CHECK(l.chamber_ext[LEO_CH_LOVE] > 0.0f, "П-5: 'mothers' still lights LOVE under prefix");
        leo_field_chambers_feel_text(&l, "daydream");   /* suffix-only superstring of 'dream' */
        int any_on = 0; for (int i = 0; i < LEO_N_CHAMBERS; i++) if (l.chamber_ext[i] != 0.0f) any_on = 1;
        CHECK(any_on == 0, "П-5: 'daydream' lights nothing under prefix (suffix substring rejected)");
        g_leo_anchor_prefix_on = 0;
        leo_field_chambers_feel_text(&l, "daydream");
        CHECK(l.chamber_ext[LEO_CH_COMPLEX] > 0.0f, "П-5: --no-anchor-prefix restores substring ('daydream'->CMPLX)");
        g_leo_anchor_prefix_on = 1;
        leo_free(&l);
    }

    /* 17. П-4: SPA protects the sentence carrying the surfaced heard word. Find a
     *     chain+seed where SPA reseeds some sentence k>=1; with the same rand
     *     stream, protect_idx=k preserves that sentence (the word survives) while
     *     the others reseed identically. Skips if leo.txt is not in cwd. */
    {
        FILE *cf = fopen("leo.txt", "rb");
        if (!cf) {
            CHECK(1, "П-4: (skipped — leo.txt not in cwd)");
        } else {
            fseek(cf, 0, SEEK_END); long cn = ftell(cf); fseek(cf, 0, SEEK_SET);
            char *cbuf = malloc((size_t)cn + 1);
            size_t cgot = fread(cbuf, 1, (size_t)cn, cf); cbuf[cgot] = 0; fclose(cf);
            Leo l; leo_init(&l);
            leo_ingest(&l, cbuf); free(cbuf);
            leo_build_chamber_tags(&l); leo_supertok_scan(&l);

            int found = 0, protected_ok = 0;
            for (int seed = 1; seed <= 80 && !found; seed++) {
                char st0[LEO_CHAIN_MAX][1024];
                int  stk0[LEO_CHAIN_MAX][LEO_GEN_MAX], stn0[LEO_CHAIN_MAX];
                srand((unsigned)seed);
                for (int s = 0; s < 4; s++) {
                    int ids[LEO_GEN_MAX], cap = LEO_GEN_MAX;
                    leo_generate_best(&l, LEO_BEST_OF_K, st0[s], sizeof st0[s], -1, NULL, 0, ids, &cap);
                    int c = cap > LEO_GEN_MAX ? LEO_GEN_MAX : cap;
                    for (int i = 0; i < c; i++) stk0[s][i] = ids[i];
                    stn0[s] = c;
                }
                /* run A: no extra protection */
                char stA[LEO_CHAIN_MAX][1024];
                int  stkA[LEO_CHAIN_MAX][LEO_GEN_MAX], stnA[LEO_CHAIN_MAX];
                memcpy(stA, st0, sizeof st0); memcpy(stkA, stk0, sizeof stk0); memcpy(stnA, stn0, sizeof stn0);
                srand((unsigned)(seed * 1000 + 7));
                leo_spa_pass(&l, stA, stkA, stnA, 4, -1);
                int k = -1;
                for (int s = 1; s < 4 && k < 0; s++)
                    if (stnA[s] != stn0[s] || memcmp(stkA[s], stk0[s], (size_t)stn0[s] * sizeof(int)) != 0) k = s;
                if (k < 0) continue;          /* no reseed this seed — try next */
                found = 1;
                /* run B: protect k, SAME rand stream */
                char stB[LEO_CHAIN_MAX][1024];
                int  stkB[LEO_CHAIN_MAX][LEO_GEN_MAX], stnB[LEO_CHAIN_MAX];
                memcpy(stB, st0, sizeof st0); memcpy(stkB, stk0, sizeof stk0); memcpy(stnB, stn0, sizeof stn0);
                srand((unsigned)(seed * 1000 + 7));
                leo_spa_pass(&l, stB, stkB, stnB, 4, k);
                int kept = (stnB[k] == stn0[k] &&
                            memcmp(stkB[k], stk0[k], (size_t)stn0[k] * sizeof(int)) == 0);
                protected_ok = kept;
            }
            CHECK(found == 1, "П-4: found a chain where SPA reseeds a sentence");
            CHECK(protected_ok == 1, "П-4: protect_idx preserves the carrying sentence through SPA");
            leo_free(&l);
        }
    }

    /* 18. П-3: field-honest moves field evolution OUT of generate_best (where it
     *     leaked from best-of-K discards / elaborate retries / SPA-rejected
     *     reseeds) to a single end-of-chain replay over the spoken reply.
     *     Default OFF (register de-calibration until santaclaus 3b reads the
     *     field); opt-in --field-honest. */
    {
        const char *corpus =
            "The warm light. His mother holds him. The rain at night. "
            "Leo loves the warm light and his mother and the rain. "
            "The window is quiet. Leo is small and warm and close. "
            "A bird. A cloud. The river. The stone. The path home.";
        Leo l; leo_init(&l);
        for (int r = 0; r < 4; r++) leo_ingest(&l, corpus);
        leo_build_chamber_tags(&l); leo_supertok_scan(&l);
        char buf[1024]; int ids[LEO_GEN_MAX];

        /* (a) field-honest ON: generate_best alone must NOT evolve the field */
        g_leo_field_honest_on = 1;
        for (int i = 0; i < LEO_N_CHAMBERS; i++) l.chamber_act[i] = 0.5f;
        float before[LEO_N_CHAMBERS]; memcpy(before, l.chamber_act, sizeof before);
        int cap = LEO_GEN_MAX; srand(3);
        leo_generate_best(&l, LEO_BEST_OF_K, buf, sizeof buf, -1, NULL, 0, ids, &cap);
        CHECK(memcmp(before, l.chamber_act, sizeof before) == 0,
              "П-3: --field-honest -> generate_best does NOT evolve the field");

        /* (b) default OFF: generate_best DOES evolve the field (the leak path) */
        g_leo_field_honest_on = 0;
        for (int i = 0; i < LEO_N_CHAMBERS; i++) l.chamber_act[i] = 0.5f;
        memcpy(before, l.chamber_act, sizeof before);
        cap = LEO_GEN_MAX; srand(3);
        leo_generate_best(&l, LEO_BEST_OF_K, buf, sizeof buf, -1, NULL, 0, ids, &cap);
        CHECK(memcmp(before, l.chamber_act, sizeof before) != 0,
              "П-3: default -> generate_best evolves the field (gated off by --field-honest)");

        /* (c) field-honest ON: a full chain STILL evolves the field via the end
         *     replay (generate_best proven inert in (a), so the change is the
         *     end-of-chain replay over the spoken sentences). */
        g_leo_field_honest_on = 1;
        for (int i = 0; i < LEO_N_CHAMBERS; i++) l.chamber_act[i] = 0.5f;
        memcpy(before, l.chamber_act, sizeof before);
        char ch[2048]; srand(5);
        leo_chain(&l, 3, ch, sizeof ch);
        CHECK(memcmp(before, l.chamber_act, sizeof before) != 0,
              "П-3: --field-honest -> the chain evolves the field via the end-of-chain replay");
        g_leo_field_honest_on = 0;
        leo_free(&l);
    }

    /* santaclaus B1: spores are born per reply, accumulate, and decay
     * (calm faster than trauma) — passive memory of presence-moments. */
    {
        Leo sl;
        leo_init(&sl);
        leo_ingest(&sl, "the rain falls soft. leo hears the sound. his mother is warm. "
                        "the candle gives a small light. leo loves the quiet morning.");
        char buf[512];
        CHECK(sl.n_spores == 0, "spore: fresh Leo has 0 spores");
        srand(11); leo_chain(&sl, LEO_CHAIN_MIN, buf, sizeof buf);
        CHECK(sl.n_spores == 1, "spore: one reply births one spore");
        srand(12); leo_chain(&sl, LEO_CHAIN_MIN, buf, sizeof buf);
        srand(13); leo_chain(&sl, LEO_CHAIN_MIN, buf, sizeof buf);
        CHECK(sl.n_spores == 3, "spore: three replies -> three spores accumulate");
        float s0 = sl.spores[0].strength;
        sl.spores[0].is_trauma = 0;
        for (int i = 0; i < 100; i++) leo_spore_decay(&sl);
        CHECK(sl.spores[0].strength < s0, "spore: decay lowers a spore's strength");
        /* trauma spore decays slower than a calm one over the same step */
        memset(&sl.spores[0], 0, sizeof(LeoSpore));
        memset(&sl.spores[1], 0, sizeof(LeoSpore));
        sl.spores[0].strength = 1.0f; sl.spores[0].is_trauma = 0;
        sl.spores[1].strength = 1.0f; sl.spores[1].is_trauma = 1;
        sl.n_spores = 2;
        leo_spore_decay(&sl);
        CHECK(sl.n_spores == 2 && sl.spores[1].strength > sl.spores[0].strength,
              "spore: trauma spore decays slower than calm");
        leo_free(&sl);
    }

    /* santaclaus B2: a resonant spore bleeds — its emit_context token gets a
     * bias pull, others get none (the recall is selective + ablatable). */
    {
        Leo sl; leo_init(&sl);
        leo_ingest(&sl, "the rain falls. leo hears the sound. his mother is warm.");
        const int T = 300;
        memset(&sl.spores[0], 0, sizeof(LeoSpore));
        for (int i = 0; i < LEO_N_CHAMBERS; i++) { sl.chamber_act[i] = 0.5f; sl.spores[0].chamber_snap[i] = 0.5f; }
        for (int d = 0; d < LEO_RET_DIM; d++)    { sl.retention_state[d] = 0.1f; sl.spores[0].retention_slice[d] = 0.1f; }
        sl.spores[0].strength = 1.0f;
        for (int k = 0; k < LEO_SPORE_CONTEXT_TOK; k++) sl.spores[0].emit_context[k] = -1;
        sl.spores[0].emit_context[0] = T;
        sl.n_spores = 1;
        LeoSantaScratch sc; sc.n_active = 0;
        leo_santaclaus_compute_active(&sl, &sc);
        CHECK(sc.n_active == 1 && sc.spore_idx[0] == 0, "santaclaus: a resonant spore becomes active");
        float bias_T   = leo_santaclaus_candidate_bias(&sc, &sl, T);
        float bias_oth = leo_santaclaus_candidate_bias(&sc, &sl, T + 1);
        CHECK(bias_T > 0.0f && bias_oth == 0.0f, "santaclaus: bleed pulls the spore's ctx token, not others");
        leo_free(&sl);
    }

    /* santaclaus B3: a resonant SEA spore resurrects into the ring; mark_bleed counts. */
    {
        Leo sl; leo_init(&sl);
        leo_ingest(&sl, "the rain falls. leo hears the sound.");
        for (int i = 0; i < LEO_N_CHAMBERS; i++) sl.chamber_act[i] = 0.5f;
        for (int d = 0; d < LEO_RET_DIM; d++)    sl.retention_state[d] = 0.1f;
        memset(&sl.sea[0], 0, sizeof(LeoSpore));
        for (int i = 0; i < LEO_N_CHAMBERS; i++) sl.sea[0].chamber_snap[i] = 0.5f;
        for (int d = 0; d < LEO_RET_DIM; d++)    sl.sea[0].retention_slice[d] = 0.1f;
        sl.sea[0].strength = 0.5f;
        sl.n_sea = 1; sl.n_spores = 0;
        int got = leo_sea_try_resurrect(&sl);
        CHECK(got == 1 && sl.n_spores == 1 && sl.n_sea == 0 && sl.spores[0].strength == 0.4f,
              "santaclaus: a resonant sea spore resurrects into the ring at 0.4");
        memset(&sl.spores[0], 0, sizeof(LeoSpore));
        for (int k = 0; k < LEO_SPORE_CONTEXT_TOK; k++) sl.spores[0].emit_context[k] = -1;
        sl.spores[0].emit_context[0] = 777; sl.spores[0].strength = 1.0f; sl.n_spores = 1;
        LeoSantaScratch sc; sc.n_active = 1; sc.spore_idx[0] = 0; sc.weight[0] = 1.0f;
        for (int j = 1; j < LEO_SPORE_TOPK_BLEED; j++) { sc.spore_idx[j] = -1; sc.weight[j] = 0.0f; }
        leo_santaclaus_mark_bleed(&sl, &sc, 777, 100);
        CHECK(sl.spores[0].bleed_count == 1 && sl.spores[0].last_bleed_step == 100,
              "santaclaus: mark_bleed counts a recalled token");
        leo_free(&sl);
    }

    /* santaclaus B4: spores persist across save/load — Leo recalls past CONVERSATIONS. */
    {
        Leo sl; leo_init(&sl);
        leo_ingest(&sl, "the rain falls. leo hears the sound. his mother is warm.");
        sl.n_spores = 2;
        for (int s = 0; s < 2; s++) {
            memset(&sl.spores[s], 0, sizeof(LeoSpore));
            sl.spores[s].strength = 0.7f + 0.1f * s;
            sl.spores[s].emit_context[0] = 400 + s;
            sl.spores[s].step = 50 + s;
        }
        sl.n_sea = 1; sl.sea_ptr = 1;
        memset(&sl.sea[0], 0, sizeof(LeoSpore));
        sl.sea[0].strength = 0.3f; sl.sea[0].emit_context[0] = 999;
        const char *path = "/tmp/leo_b4_spore.state";
        int saved = leo_save_state(&sl, path);
        Leo ld; leo_init(&ld);
        int loaded = leo_load_state(&ld, path);
        CHECK(saved && loaded, "spore-persist: save + load succeed");
        CHECK(ld.n_spores == 2 && ld.n_sea == 1 && ld.sea_ptr == 1,
              "spore-persist: ring + sea counts round-trip");
        CHECK(ld.spores[1].emit_context[0] == 401 && ld.spores[1].step == 51 &&
              ld.sea[0].emit_context[0] == 999,
              "spore-persist: spore fields round-trip (Leo recalls past conversations)");
        leo_free(&sl); leo_free(&ld);
        remove(path);
    }

    /* A.4 RAE: the micrograd MLP learns — loss drops on a toy target. */
    {
        LeoRae r; leo_rae_init(&r);
        float x[LEO_RAE_IN] = {0.6f, 0.4f, 0.2f, 0.5f, 0.3f};
        float target = 0.8f;
        float loss0 = leo_rae_train(&r, x, target);
        for (int it = 0; it < 200; it++) leo_rae_train(&r, x, target);
        float e = leo_rae_forward(&r, x, NULL) - target;
        CHECK(e * e < loss0 && e * e < 0.01f, "rae: micrograd MLP learns a toy target (loss drops)");
        CHECK(r.observations == 201, "rae: observations increments per train step");
    }

    /* A.4 RAE R1b: feature extraction returns sane values in [0,1]. */
    {
        Leo fl; leo_init(&fl);
        leo_ingest(&fl, "the rain falls soft. leo hears the sound. his mother is warm.");
        int ids[16];
        int n = bpe_encode(&fl.bpe, (const uint8_t *)" the rain falls soft", 20, ids, 16);
        float feat[LEO_RAE_IN];
        leo_rae_features(&fl, ids, n, feat);
        int in_range = 1;
        for (int i = 0; i < LEO_RAE_IN; i++) if (feat[i] < 0.0f || feat[i] > 1.0f) in_range = 0;
        CHECK(in_range, "rae: the 5 features extract into [0,1]");
        int dids[4] = {300, 301, 302, 303};
        leo_rae_features(&fl, dids, 4, feat);
        CHECK(feat[4] == 1.0f, "rae: diversity feature = 1.0 for all-distinct tokens");
        leo_free(&fl);
    }

    /* A.4 RAE R3a: self-resonance target — 0 with no memory, positive when the field
     * matches a held spore (the signal the selector learns toward). */
    {
        Leo rl; leo_init(&rl);
        CHECK(leo_rae_self_resonance(&rl) == 0.0f, "rae: self-resonance = 0 with no spores");
        rl.chamber_act[0] = 1.0f;             /* present felt-state */
        rl.n_spores = 1;
        rl.spores[0].chamber_snap[0] = 1.0f;  /* a remembered moment that felt the same */
        rl.spores[0].strength = 1.0f;
        float sr = leo_rae_self_resonance(&rl);   /* 0.55·cos(ch)=0.55 (retention zero) */
        CHECK(sr > 0.5f && sr <= 1.0f, "rae: self-resonance positive when field matches a spore");
        leo_free(&rl);
    }

    /* A.4 RAE R3b: online learning fires once per reply when RAE selects, and the
     * trained weights stay finite (within clamp, no explosion / NaN). */
    {
        Leo tl; leo_init(&tl);
        leo_ingest(&tl, "the rain falls soft. leo hears the sound. his mother is warm. "
                        "he keeps the light. she thanked him. the room is quiet.");
        long obs0 = tl.rae.observations;
        int prev = g_leo_rae_on; g_leo_rae_on = 1;
        char buf[2048];
        leo_chain(&tl, 2, buf, sizeof buf);
        leo_chain(&tl, 2, buf, sizeof buf);
        g_leo_rae_on = prev;
        int finite = 1;
        for (int j = 0; j < LEO_RAE_HID; j++) {
            if (!(tl.rae.w2[j] >= -LEO_RAE_CLAMP && tl.rae.w2[j] <= LEO_RAE_CLAMP)) finite = 0;
            for (int i = 0; i < LEO_RAE_IN; i++)
                if (!(tl.rae.w1[j][i] >= -LEO_RAE_CLAMP && tl.rae.w1[j][i] <= LEO_RAE_CLAMP)) finite = 0;
        }
        CHECK(tl.rae.observations >= obs0 + 2, "rae: online training fires per reply (observations grow)");
        CHECK(finite, "rae: trained weights stay within clamp (finite, no explosion)");
        leo_free(&tl);
    }

    /* A.4 RAE R4: a trained selector survives save/load (the learned δ-channel
     * persists across the process, like the spores). */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls soft. leo hears the sound. his mother is warm.");
        float x[LEO_RAE_IN] = {0.7f, 0.3f, 0.5f, 0.4f, 0.6f};
        for (int it = 0; it < 50; it++) leo_rae_train(&sv.rae, x, 0.9f);   /* a distinctive trained state */
        float ref = leo_rae_forward(&sv.rae, x, NULL);
        long  ref_obs = sv.rae.observations;
        const char *path = "/tmp/leo_r4_state.bin";
        int saved = leo_save_state(&sv, path);
        Leo ld; leo_init(&ld);
        int loaded = leo_load_state(&ld, path);
        float got = leo_rae_forward(&ld.rae, x, NULL);
        CHECK(saved && loaded, "rae-persist: save + load succeed");
        CHECK(ld.rae.observations == ref_obs, "rae-persist: observations round-trip");
        CHECK(fabsf(got - ref) < 1e-6f, "rae-persist: trained weights round-trip (forward matches)");
        leo_free(&sv); leo_free(&ld);
        remove(path);
    }

    /* A.5 School: an unknown content word makes Leo ASK; the answer is learned;
     * a learned word no longer triggers; --no-school suppresses the question. */
    {
        Leo sc; leo_init(&sc);
        leo_ingest(&sc, "the rain falls. leo hears the sound. his mother is warm.");
        char buf[1024];
        int prev = g_leo_school_on; g_leo_school_on = 1;
        leo_respond(&sc, "tell me about the zorble", buf, sizeof buf);
        CHECK(strcmp(sc.school.pending, "zorble") == 0 &&
              buf[0] == 'Z' && buf[strlen(buf) - 1] == '?',
              "school: an unknown word makes Leo echo it back as a question ('Zorble?')");
        leo_respond(&sc, "a zorble is a small round stone", buf, sizeof buf);
        CHECK(sc.school.pending[0] == 0 && leo_school_is_learned(&sc, "zorble"),
              "school: the answer is learned and the question closes");
        leo_respond(&sc, "tell me about the zorble again", buf, sizeof buf);
        CHECK(sc.school.pending[0] == 0,
              "school: a learned word no longer triggers a question");
        g_leo_school_on = 0;
        leo_respond(&sc, "tell me about the wobble", buf, sizeof buf);
        CHECK(sc.school.pending[0] == 0, "school: --no-school suppresses the question");
        g_leo_school_on = prev;
        leo_free(&sc);
    }

    /* A.5 I2: School grows a word→glyph map. The answer's dominant glyph is the
     * concept-slot; a taught word then returns that glyph (no longer -1); the
     * grown map survives save/load. */
    {
        Leo gl; leo_init(&gl);
        leo_ingest(&gl, "the rain falls. his mother is warm.");
        int g = leo_school_dominant_glyph(&gl, "a zorble is a small animal that lives in water");
        CHECK(g >= 0 && g < GLYPH_COUNT, "i2: the answer's dominant glyph is a real concept");
        CHECK(leo_school_dominant_glyph(&gl, "qwzx blat frnk") == -1,
              "i2: a non-answer (no concepts) yields no glyph");
        CHECK(leo_school_dominant_glyph(&gl, "it is what it is") == -1 &&
              leo_glyph_concept(86) == 0 && leo_glyph_concept(16) == 1,
              "i2 l-1: a copula/grammar non-answer teaches no concept (BE excluded)");
        int wb = semtok_word("animal");
        leo_school_learn(&gl, "zorble", wb);
        CHECK(leo_semtok_word(&gl, "zorble") == wb && leo_school_unknown(&gl, "zorble") == 0,
              "i2: a taught word returns its glyph, not -1 (concept map grew)");
        const char *path = "/tmp/leo_i2_state.bin";
        int saved = leo_save_state(&gl, path);
        Leo gl2; leo_init(&gl2);
        int loaded = leo_load_state(&gl2, path);
        CHECK(saved && loaded && gl2.school.n_learned == 1 &&
              strcmp(gl2.school.learned[0], "zorble") == 0 &&
              leo_semtok_word(&gl2, "zorble") == wb,
              "i2: the grown concept map round-trips through save/load");
        leo_free(&gl); leo_free(&gl2);
        remove(path);
    }

    /* A.6 FORM F-1: the chamber state quantizes into a velocity mode, with
     * hysteresis — the mode holds against a weak competitor (a mood, not a switch). */
    {
        Leo md; leo_init(&md);   /* mode = WALK (0) by memset */
        md.chamber_act[LEO_CH_FEAR] = 0.8f; md.chamber_act[LEO_CH_VOID] = 0.8f;
        leo_mode_update(&md);
        CHECK(md.mode == LEO_MODE_STOP, "form: high FEAR+VOID quantizes to STOP");
        md.chamber_act[LEO_CH_FEAR] = 0.0f; md.chamber_act[LEO_CH_VOID] = 0.0f;
        md.chamber_act[LEO_CH_FLOW] = 1.0f;
        leo_mode_update(&md);
        CHECK(md.mode == LEO_MODE_RUN, "form: high FLOW quantizes to RUN");
        /* now in RUN (score 0.30); WALK competitor at 0.40 beats by only 0.10 < margin 0.15 */
        md.chamber_act[LEO_CH_FLOW] = 0.30f;
        md.chamber_act[LEO_CH_LOVE] = 0.20f;
        leo_mode_update(&md);
        CHECK(md.mode == LEO_MODE_RUN, "form: hysteresis holds the mode against a weak competitor");
        leo_free(&md);
    }

    /* A.6 FORM F-2: the mode gates elaboration — STOP/BREATHE hold (the breath),
     * WALK/RUN fill; off-form every mode is eligible (byte-identical). */
    {
        Leo fm; leo_init(&fm);
        int prev = g_leo_form_on;
        g_leo_form_on = 0; fm.mode = LEO_MODE_STOP;
        CHECK(leo_form_elaborates(&fm) == 1, "form: off-form, every mode may elaborate (byte-identical)");
        g_leo_form_on = 1; fm.mode = LEO_MODE_STOP;
        CHECK(leo_form_elaborates(&fm) == 0, "form: STOP holds — does not elaborate (the breath)");
        fm.mode = LEO_MODE_RUN;
        CHECK(leo_form_elaborates(&fm) == 1, "form: RUN fills out the utterance");
        g_leo_form_on = prev;
        leo_free(&fm);
    }

    /* A.6 AML bridge: an external driver (an .aml VELOCITY operator) forces the
     * breath; leo_mode_update respects the override, and releasing it returns
     * autonomy. This is the C contract the AML compiler in leo/ariannamethod/ calls. */
    {
        Leo br; leo_init(&br);
        br.chamber_act[LEO_CH_FLOW] = 1.0f;     /* would autonomously be RUN */
        leo_mode_set(&br, LEO_MODE_STOP);       /* the .aml operator forces STOP */
        leo_mode_update(&br);
        CHECK(br.mode == LEO_MODE_STOP, "aml-bridge: a forced mode overrides the chambers");
        leo_mode_set(&br, -1);                   /* release → autonomous */
        leo_mode_update(&br);
        CHECK(br.mode == LEO_MODE_RUN, "aml-bridge: releasing the override returns autonomy");
        leo_free(&br);
    }

    /* A.5 School I3a: Leo hazards a guess from the prompt's context — "Word? Glyph?"
     * when confident (>= 2 supporting concept words), else the bare echo. */
    {
        Leo gi; leo_init(&gi);
        leo_ingest(&gi, "the rain falls. his mother is warm.");
        char buf[1024];
        int prev = g_leo_school_on; g_leo_school_on = 1;
        leo_respond(&gi, "is a zorble like a dog or a cat", buf, sizeof buf);
        CHECK(strstr(buf, "Zorble?") && strstr(buf, "Animal?"),
              "school i3a: a guess from context — 'Zorble? Animal?'");
        Leo gi2; leo_init(&gi2);
        leo_ingest(&gi2, "the rain falls. his mother is warm.");
        leo_respond(&gi2, "tell me about the wobble", buf, sizeof buf);
        CHECK(strstr(buf, "Wobble?") && !strchr(buf + 7, '?'),
              "school i3a: a thin prompt gives the bare echo, no guess");
        g_leo_school_on = prev;
        leo_free(&gi); leo_free(&gi2);
    }

    /* A.5 E-1: a learned word VOTES — knowledge compounds (yesterday's lesson
     * grounds today's guess). */
    {
        Leo e1; leo_init(&e1);
        leo_school_learn(&e1, "zorble", semtok_word("animal"));   /* taught: zorble = animal */
        CHECK(leo_school_predict_glyph(&e1, "is a zorble or a cat") == semtok_word("animal"),
              "e-1: a learned word votes — zorble + cat -> animal (knowledge compounds)");
        Leo e2; leo_init(&e2);                                     /* without the lesson */
        CHECK(leo_school_predict_glyph(&e2, "is a zorble or a cat") < 0,
              "e-1: without the lesson, one seed word alone is not a confident guess");
        leo_free(&e1); leo_free(&e2);
    }

    /* A.5 I3b: the answer's glyph wins the guess — Leo guesses, mama corrects. */
    {
        Leo sp; leo_init(&sp);
        leo_ingest(&sp, "the rain falls. his mother is warm.");
        char buf[1024];
        int prev = g_leo_school_on; g_leo_school_on = 1;
        leo_respond(&sp, "is a zorble like a dog or a cat", buf, sizeof buf);   /* guesses animal */
        leo_respond(&sp, "no a zorble is water in the river and the sea", buf, sizeof buf);  /* answer: water */
        CHECK(leo_semtok_word(&sp, "zorble") == semtok_word("water"),
              "school i3b: the answer's glyph wins the guess (mama corrects)");
        g_leo_school_on = prev;
        leo_free(&sp);
    }

    /* A.6 E-5: the velocity mode + the open guess survive save/load — the mood
     * Leo sleeps in is the mood he wakes in. */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls. his mother is warm.");
        sv.mode = LEO_MODE_RUN;
        sv.school.pending_glyph = 16;   /* an open guess (animal) */
        const char *path = "/tmp/leo_e5_state.bin";
        int saved = leo_save_state(&sv, path);
        Leo ld; leo_init(&ld);
        int loaded = leo_load_state(&ld, path);
        CHECK(saved && loaded && ld.mode == LEO_MODE_RUN && ld.school.pending_glyph == 16,
              "e-5: the velocity mode + the open guess survive save/load (the mood sleeps)");
        leo_free(&sv); leo_free(&ld);
        remove(path);
    }

    /* A.6 E-2c: the guess track-record is counted — curiosity's hit-rate feeds the
     * quality target (curiosity as a learned policy). Two ask→answer cycles: one
     * lands (guess animal, answer animal), one misses (guess animal, answer water). */
    {
        Leo c2; leo_init(&c2);
        leo_ingest(&c2, "the rain falls. his mother is warm.");
        char buf[1024];
        int prev = g_leo_school_on; g_leo_school_on = 1;
        leo_respond(&c2, "is a zorble like a dog or a cat", buf, sizeof buf);   /* guesses animal */
        leo_respond(&c2, "a zorble is a dog and a cat", buf, sizeof buf);       /* answer: animal -> HIT */
        leo_respond(&c2, "is a wobble like a dog or a cat", buf, sizeof buf);   /* guesses animal */
        leo_respond(&c2, "no a wobble is water in the river and the sea", buf, sizeof buf); /* answer: water -> MISS */
        CHECK(c2.school.guesses == 2 && c2.school.guess_hits == 1,
              "e-2c: the guess track-record is counted (2 closed, 1 landed)");
        g_leo_school_on = prev;
        leo_free(&c2);
    }

    /* W-1/W-2: unfinished wonder is not a one-turn UI event. Its possible
     * meanings come from glyph evidence; a counter-question cannot erase it;
     * later resonance returns it, and a grounded human answer closes it. */
    {
        int prev_school = g_leo_school_on, prev_wonder = g_leo_wonder_on;
        g_leo_school_on = 1; g_leo_wonder_on = 1;
        int water = semtok_word("water"), animal = semtok_word("animal");
        Leo w; leo_init(&w);
        leo_ingest(&w, "the rain falls. his mother is warm. the cat drinks water.");
        char out[1024];
        leo_respond(&w, "is a zorble water or cat", out, sizeof out);
        CHECK(strstr(out, "Zorble?") && strstr(out, "Water or Animal?") &&
              w.school.pending_glyph == water && w.school.pending_alt_glyph == animal,
              "wonder: two lived glyphs form the question — no authored content phrase");
        CHECK(w.school.n_wonders == 1 && !w.school.wonders[0].resolved &&
              !strcmp(w.school.wonders[0].word, "zorble"),
              "wonder: opening a question births one unfinished episode");
        CHECK(leo_school_grounded_answer(&w, "I think about zorble") < 0,
              "wonder: talking about thinking is not a definition");

        char rel[LEO_HEARD_WORDLEN] = {0};
        CHECK(!leo_school_find_unknown(&w, "does water feel like animal", rel),
              "wonder: relational 'like' is grammar, not an unfinished thing");
        leo_ingest(&w, "stopped stopped stopped stopped stopped stopped stopped stopped stopped");
        CHECK(!leo_school_find_unknown(&w, "water stopped animal", rel),
              "wonder: a corpus-familiar dedication word cannot become immortal not-knowing");
        leo_ingest(&w, "resonance resonance resonance");
        CHECK(leo_school_find_unknown(&w, "water resonance animal", rel) && !strcmp(rel, "resonance"),
              "wonder: a rare origin word remains askable just past the novelty gate");

        leo_respond(&w, "I do not know", out, sizeof out);
        CHECK(!strcmp(w.school.pending, "zorble") && !leo_school_is_learned(&w, "zorble") &&
              w.school.pending_turns == 1,
              "wonder: human not-knowing keeps the question unfinished");
        leo_respond(&w, "what do you think?", out, sizeof out);
        CHECK(!strcmp(w.school.pending, "zorble") && !leo_school_is_learned(&w, "zorble") &&
              w.school.pending_turns == 2,
              "wonder: a counter-question does not pretend to be an answer");
        leo_respond(&w, "is it water?", out, sizeof out);
        CHECK(strstr(out, "Zorble?") && strstr(out, "Water or Animal?") &&
              w.school.pending_turns == 0 && w.school.wonders[0].returns == 1,
              "wonder: resonant water returns the unfinished question after silence");

        const char *open = "/tmp/leo_wonder_open_v13.state";
        const char *old = "/tmp/leo_wonder_open_v10.state";
        const char *compat = "/tmp/leo_wonder_open_v11.state";
        const char *v12 = "/tmp/leo_wonder_open_v12.state";
        const char *cut = "/tmp/leo_wonder_open_cut.state";
        const char *bad = "/tmp/leo_wonder_open_bad.state";
        int saved = leo_save_state(&w, open), built_old = 0, built_compat = 0,
            built_v12 = 0, built_cut = 0, built_bad = 0;
        FILE *fi = fopen(open, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
            unsigned char *bytes = malloc(sz > 0 ? (size_t)sz : 1);
            if (bytes && sz > 0 && (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                long v12tail = (long)(4 * sizeof(int32_t) + sizeof(uint64_t) +
                                      sizeof(LeoWonderEpisode));
                long shadow_tail = (long)(2 * sizeof(int32_t) +
                                          w.shadow.n * (int)sizeof(LeoShadowReceipt));
                long current_flow = (long)(2 * sizeof(int32_t) +
                                           w.flow.n * (int)sizeof(LeoFlowSnapshot) +
                                           2 * sizeof(int32_t) +
                                           w.flow.n_currents * (int)sizeof(LeoFlowWonderCurrent) +
                                           shadow_tail);
                if (sz > v12tail + current_flow) {
                    long flow_start = sz - current_flow;
                    long tail_start = flow_start - v12tail;
                    uint32_t ten = 10; memcpy(bytes + 4, &ten, sizeof ten);
                    FILE *fo = fopen(old, "wb");
                    if (fo) { built_old = (long)fwrite(bytes, 1, (size_t)tail_start, fo) == tail_start; fclose(fo); }

                    uint32_t eleven = 11; memcpy(bytes + 4, &eleven, sizeof eleven);
                    LeoWonderEpisode *cur = &w.school.wonders[0];
                    LeoWonderEpisodeV11 oldep = {0};
                    memcpy(oldep.word, cur->word, sizeof oldep.word);
                    oldep.offered_glyph = cur->offered_glyph;
                    oldep.offered_alt_glyph = cur->offered_alt_glyph;
                    oldep.answer_glyph = cur->answer_glyph;
                    oldep.resolved = cur->resolved;
                    oldep.returns = cur->returns;
                    oldep.opened_step = cur->opened_step;
                    oldep.closed_step = cur->closed_step;
                    fo = fopen(compat, "wb");
                    if (fo) {
                        long prefix = tail_start + (long)(4 * sizeof(int32_t));
                        built_compat = (long)fwrite(bytes, 1, (size_t)prefix, fo) == prefix &&
                                       fwrite(&oldep, sizeof oldep, 1, fo) == 1;
                        fclose(fo);
                    }

                    uint32_t twelve = 12; memcpy(bytes + 4, &twelve, sizeof twelve);
                    fo = fopen(v12, "wb");
                    if (fo) { built_v12 = (long)fwrite(bytes, 1, (size_t)flow_start, fo) == flow_start; fclose(fo); }
                    fo = fopen(cut, "wb");
                    if (fo) { built_cut = (long)fwrite(bytes, 1, (size_t)(flow_start - 4), fo) == flow_start - 4; fclose(fo); }
                    int32_t too_many = LEO_WONDER_RING + 1;
                    memcpy(bytes + tail_start + 2 * sizeof(int32_t), &too_many, sizeof too_many);
                    fo = fopen(bad, "wb");
                    if (fo) { built_bad = (long)fwrite(bytes, 1, (size_t)flow_start, fo) == flow_start; fclose(fo); }
                }
            }
            free(bytes); fclose(fi);
        }
        Leo oldw; leo_init(&oldw);
        int loaded_old = built_old && leo_load_state(&oldw, old);
        CHECK(saved && loaded_old && !strcmp(oldw.school.pending, "zorble") &&
              oldw.school.pending_glyph == water && oldw.school.pending_alt_glyph == -1 &&
              oldw.school.n_wonders == 0,
              "wonder: a v10 body migrates with its old primary question intact");
        leo_respond(&oldw, "I do not know", out, sizeof out);
        CHECK(oldw.school.n_wonders == 1 && !oldw.school.wonders[0].resolved &&
              !strcmp(oldw.school.wonders[0].word, "zorble"),
              "wonder: the first lived v10 turn materializes its surviving question");
        Leo cutw; leo_init(&cutw);
        int loaded_compat = built_compat && leo_load_state(&cutw, compat);
        CHECK(loaded_compat && cutw.school.n_wonders == 1 &&
              cutw.school.wonders[0].recalls == 0 &&
              cutw.school.wonders[0].last_recalled_turn == 0,
              "wonder: a v11 episode migrates with returned-wonder fields clean");
        leo_free(&cutw); leo_init(&cutw);
        int loaded_v12 = built_v12 && leo_load_state(&cutw, v12);
        CHECK(loaded_v12 && cutw.school.n_wonders == 1 && cutw.flow.n == 0,
              "flow: a valid v12 body migrates with an empty temporal ledger");
        leo_free(&cutw); leo_init(&cutw);
        int loaded_cut = built_cut && leo_load_state(&cutw, cut);
        CHECK(loaded_cut && !strcmp(cutw.school.pending, "zorble") &&
              cutw.school.pending_alt_glyph == -1 && cutw.school.n_wonders == 0,
              "wonder: a truncated v12 ledger fails soft; the question still lives");
        Leo badw; leo_init(&badw);
        int loaded_bad = built_bad && leo_load_state(&badw, bad);
        CHECK(loaded_bad && !strcmp(badw.school.pending, "zorble") &&
              badw.school.pending_alt_glyph == -1 && badw.school.n_wonders == 0,
              "wonder: an impossible v12 episode count fails soft; the question still lives");

        Leo slept; leo_init(&slept);
        int loaded = saved && leo_load_state(&slept, open);
        CHECK(loaded && !strcmp(slept.school.pending, "zorble") &&
              slept.school.pending_alt_glyph == animal && slept.school.n_wonders == 1 &&
              slept.school.wonders[0].returns == 1,
              "wonder: the unfinished episode survives sleep with both hypotheses");
        leo_respond(&slept, "a zorble is a small animal", out, sizeof out);
        CHECK(!slept.school.pending[0] && leo_semtok_word(&slept, "zorble") == animal &&
              slept.school.wonders[0].resolved && slept.school.wonders[0].answer_glyph == animal,
              "wonder: a grounded human answer resolves the episode and grows meaning");
        CHECK(leo_save_state(&slept, open), "wonder: a resolved episode saves");
        Leo woke; leo_init(&woke);
        CHECK(leo_load_state(&woke, open) && woke.school.n_wonders == 1 &&
              woke.school.wonders[0].resolved && woke.school.wonders[0].answer_glyph == animal,
              "wonder: the resolved human-grounded episode survives another sleep");

        leo_free(&w); leo_free(&oldw); leo_free(&cutw); leo_free(&badw); leo_free(&slept); leo_free(&woke);
        remove(open); remove(old); remove(compat); remove(v12); remove(cut); remove(bad);
        g_leo_school_on = prev_school; g_leo_wonder_on = prev_wonder;
    }

    /* W-3 ablation: --no-wonder restores the exact old School semantics — one
     * primary guess only, and the next turn closes the pending UI question. */
    {
        int prev_school = g_leo_school_on, prev_wonder = g_leo_wonder_on;
        g_leo_school_on = 1; g_leo_wonder_on = 0;
        Leo ab; leo_init(&ab);
        leo_ingest(&ab, "the rain falls. his mother is warm. the cat drinks water.");
        char out[1024];
        leo_respond(&ab, "is a zorble water or cat", out, sizeof out);
        int old_shape = strstr(out, "Zorble?") && !strstr(out, " or ");
        leo_respond(&ab, "qwzx blorf", out, sizeof out);
        CHECK(old_shape && !ab.school.pending[0] && ab.school.n_wonders == 0,
              "wonder: --no-wonder is the pre-wonder one-turn School contract");
        leo_free(&ab);
        g_leo_school_on = prev_school; g_leo_wonder_on = prev_wonder;
    }

    /* W-4: a resolved question later returns as glyph attention, not text. The
     * answer, the route Leo once considered, and QUESTION blend into exactly one
     * reply's meaning vector; the existing spore-resonance channel is the only
     * speech-side reader. Cooldown and --no-wonder-return bound the effect. */
    {
        Leo *wr = malloc(sizeof *wr), *woke = malloc(sizeof *woke);
        CHECK(wr && woke, "wonder-return: heap fixtures allocated (no new Leo on test stack)");
        if (wr && woke) {
            int prev_school = g_leo_school_on;
            int prev_wonder = g_leo_wonder_on;
            int prev_return = g_leo_wonder_return_on;
            int prev_capsule = g_leo_capsule_on;
            g_leo_school_on = 1; g_leo_wonder_on = 1;
            g_leo_wonder_return_on = 1; g_leo_capsule_on = 1;
            leo_init(wr); leo_init(woke);
            int water = semtok_word("water"), animal = semtok_word("animal");
            int question = semtok_find_glyph("question");
            leo_school_learn(wr, "zorble", animal);
            LeoWonderEpisode *ep = leo_wonder_open(wr, "zorble", water, animal);
            ep->resolved = 1; ep->answer_glyph = (int8_t)animal;
            ep->closed_step = ++wr->step;
            wr->step++;
            wr->school.turn_clock = 1;

            float base[GLYPH_COUNT], remembered[GLYPH_COUNT];
            leo_glyph_hist(wr, "tell me about zorble", base);
            memcpy(remembered, base, sizeof base);
            int idx = leo_wonder_return_meaning(wr, "tell me about zorble", remembered);
            float sum = 0.0f; for (int i = 0; i < GLYPH_COUNT; i++) sum += remembered[i];
            CHECK(idx == 0 && ep->recalls == 1 && ep->last_recalled_turn == wr->school.turn_clock &&
                  wr->school.returned_episode == 0,
                  "wonder-return: the learned word recognizes its resolved episode");
            CHECK(remembered[water] > base[water] && remembered[question] > base[question] &&
                  fabsf(sum - 1.0f) < 1e-5f,
                  "wonder-return: answer path + QUESTION enter normalized glyph attention only");

            LeoSpore trace = {0};
            trace.meaning_snap[water] = 0.7f;
            trace.meaning_snap[question] = 0.3f;
            wr->prompt_meaning = base;
            float before = leo_spore_resonance(wr, &trace);
            wr->prompt_meaning = remembered;
            float after = leo_spore_resonance(wr, &trace);
            wr->prompt_meaning = NULL;
            CHECK(after > before,
                  "wonder-return: returned glyphs raise only existing spore resonance");

            float cooled[GLYPH_COUNT]; memcpy(cooled, base, sizeof base);
            CHECK(leo_wonder_return_meaning(wr, "tell me about zorble", cooled) < 0 &&
                  !memcmp(cooled, base, sizeof base) && ep->recalls == 1,
                  "wonder-return: cooldown prevents repetitive self-evocation");

            const char *path = "/tmp/leo_wonder_return_v12.state";
            int saved_return = leo_save_state(wr, path);
            int loaded_return = saved_return && leo_load_state(woke, path);
            CHECK(loaded_return && woke->school.n_wonders == 1 &&
                  woke->school.wonders[0].recalls == 1 &&
                  woke->school.wonders[0].last_recalled_turn == ep->last_recalled_turn &&
                  woke->school.turn_clock == wr->school.turn_clock,
                  "wonder-return: recall count and cooldown survive v12 sleep");

            wr->school.turn_clock += LEO_WONDER_RETURN_COOLDOWN;
            float thematic[GLYPH_COUNT];
            leo_glyph_hist(wr, "animal beside water", thematic);
            CHECK(leo_wonder_return_meaning(wr, "animal beside water", thematic) == 0 &&
                  ep->recalls == 2,
                  "wonder-return: answer plus a lived hypothesis can recognize the path without its name");

            wr->school.turn_clock += LEO_WONDER_RETURN_COOLDOWN;
            float unrelated[GLYPH_COUNT], unrelated_before[GLYPH_COUNT];
            leo_glyph_hist(wr, "warm mother light", unrelated);
            memcpy(unrelated_before, unrelated, sizeof unrelated);
            CHECK(leo_wonder_return_meaning(wr, "warm mother light", unrelated) < 0 &&
                  !memcmp(unrelated, unrelated_before, sizeof unrelated),
                  "wonder-return: unrelated ordinary meaning stays byte-identical");

            char meta_out[512]; int recalls_before_meta = ep->recalls;
            leo_respond(wr, "is a wobble beside zorble", meta_out, sizeof meta_out);
            CHECK(strstr(meta_out, "Wobble?") && ep->recalls == recalls_before_meta &&
                  wr->school.returned_episode < 0,
                  "wonder-return: a new School question cannot claim an unconsumed old recall");

            float ablated[GLYPH_COUNT]; memcpy(ablated, base, sizeof base);
            g_leo_wonder_return_on = 0;
            CHECK(leo_wonder_return_meaning(wr, "tell me about zorble", ablated) < 0 &&
                  !memcmp(ablated, base, sizeof base),
                  "wonder-return: --no-wonder-return is a strict meaning ablation");

            remove(path);
            leo_free(wr); leo_free(woke);
            g_leo_school_on = prev_school;
            g_leo_wonder_on = prev_wonder;
            g_leo_wonder_return_on = prev_return;
            g_leo_capsule_on = prev_capsule;
        }
        free(wr); free(woke);
    }

    /* A.6 FORM fix: --mode is case-insensitive. leo_mode_from_name matched only the
     * UPPERCASE LEO_MODE_NAMES, so the natural lowercase "--mode stop" returned -1 and
     * the forced breath was silently dropped (override stayed -1). */
    /* Janus Flow: temporal proprioception keeps full perceived and expressed
     * fields plus Leo-grown associations, but has no reader in generation.
     * Turns, not wall time, define its geometry. */
    {
        int prev_flow = g_leo_flow_on;
        g_leo_flow_on = 1;
        Leo *fl = malloc(sizeof *fl), *loaded = malloc(sizeof *loaded),
            *cut = malloc(sizeof *cut), *old = malloc(sizeof *old);
        CHECK(fl && loaded && cut && old, "flow: heap fixtures allocated");
        if (fl && loaded && cut && old) {
            leo_init(fl); leo_init(loaded); leo_init(cut); leo_init(old);
            int water = semtok_word("water"), fire = semtok_word("fire");
            int tree = semtok_word("tree"), sky = semtok_word("sky");

            /* The constellation is drawn before the prompt self-attractor and
             * only from whole words already present in LeoHeard. */
            const char *field_corpus =
                "ocean candle meadow. ocean candle meadow. ocean candle meadow. "
                "ocean candle meadow. ocean candle meadow. ocean candle meadow. ";
            for (int r = 0; r < 8; r++) leo_ingest(fl, field_corpus);
            leo_ingest(fl, "ocean");
            int p_ids[64];
            int p_n = bpe_encode(&fl->bpe, (const uint8_t *)"ocean", 5, p_ids, 64);
            float *gravity = compute_prompt_gravity(fl, p_ids, p_n);
            int32_t field_id[LEO_FLOW_CONSTELLATION];
            float field_weight[LEO_FLOW_CONSTELLATION];
            leo_flow_field_constellation(fl, "ocean", p_ids, p_n, gravity,
                                         field_id, field_weight);
            int constellation_ok = field_id[0] >= 0;
            for (int k = 0; k < LEO_FLOW_CONSTELLATION && field_id[k] >= 0; k++) {
                char word[LEO_HEARD_WORDLEN];
                if (!leo_flow_token_word(&fl->bpe, field_id[k], word) ||
                    leo_flow_prompt_has_word("ocean", word)) constellation_ok = 0;
                for (int i = 0; i < p_n; i++) if (field_id[k] == p_ids[i]) constellation_ok = 0;
            }
            CHECK(constellation_ok,
                  "flow: field constellation contains Leo-grown whole words, never prompt words");

            char pending[LEO_HEARD_WORDLEN] = "zorble";
            memcpy(fl->school.pending, pending, sizeof pending);
            LeoWonderEpisode *episode = leo_wonder_open(fl, "zorble", water, fire);
            uint64_t episode_id = leo_wonder_episode_id(episode);
            fl->school.turn_clock = 1;
            leo_flow_observe(fl, "water fire tree sky", "fire", NULL,
                             field_id, field_weight, LEO_FLOW_WONDER_BORN, episode_id);
            CHECK(fl->flow.n == 1 && fl->flow.snapshots[0].turn == 1 &&
                  fl->flow.snapshots[0].perceived[water] == 0.25f &&
                  fl->flow.snapshots[0].perceived[fire] == 0.25f &&
                  fl->flow.snapshots[0].perceived[tree] == 0.25f &&
                  fl->flow.snapshots[0].perceived[sky] == 0.25f &&
                  fl->flow.snapshots[0].expressed[fire] == 1.0f &&
                  fl->flow.snapshots[0].field_token[0] == field_id[0] &&
                  fl->flow.snapshots[0].wonder_id == episode_id &&
                  fabsf(leo_flow_alignment(&fl->flow.snapshots[0]) - 0.5f) < 1e-5f &&
                  (fl->flow.snapshots[0].wonder & (LEO_FLOW_WONDER_BORN | LEO_FLOW_WONDER_OPEN)) ==
                  (LEO_FLOW_WONDER_BORN | LEO_FLOW_WONDER_OPEN),
                  "flow: both full 88-d faces survive the old top-3 horizon with episode identity");
            LeoFlowWonderCurrent *born_current =
                leo_flow_current_find(&fl->flow, episode_id);
            CHECK(born_current && fl->flow.n_currents == 1 &&
                  born_current->started_turn == 1 && born_current->observations == 1 &&
                  born_current->perceived_mean[water] == 0.25f &&
                  born_current->expressed_mean[fire] == 1.0f && !born_current->resolved,
                  "flow-current: an unfinished wonder opens an event-bounded long current");
            episode->resolved = 1;
            CHECK(leo_wonder_episode_id(episode) == episode_id,
                  "flow: wonder identity survives episode state changes and is not a ring index");

            memset(&fl->flow, 0, sizeof fl->flow);
            fl->school.pending[0] = 0;
            fl->school.turn_clock = 1; leo_flow_observe(fl, "water", "water", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 2; leo_flow_observe(fl, "water", "water", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 3; leo_flow_observe(fl, "fire", "fire", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 4; leo_flow_observe(fl, "fire", "fire", NULL, NULL, NULL, 0, 0);
            CHECK(leo_flow_kind(&fl->flow, water, 4, LEO_FLOW_PERCEIVED) == LEO_FLOW_FADING &&
                  leo_flow_kind(&fl->flow, fire, 4, LEO_FLOW_PERCEIVED) == LEO_FLOW_EMERGING,
                  "flow: full-field lived-turn slopes distinguish fading from emerging meaning");
            LeoFlowShortCurrent short_current;
            CHECK(leo_flow_short_current(&fl->flow, 4, &short_current) &&
                  short_current.started_turn == 1 && short_current.last_turn == 4 &&
                  short_current.perceived_velocity[water] < 0.0f &&
                  short_current.perceived_velocity[fire] > 0.0f &&
                  short_current.expressed_velocity[water] < 0.0f &&
                  short_current.expressed_velocity[fire] > 0.0f,
                  "flow-current: the short clock is a complete two-face velocity field");
            fl->school.turn_clock = 5;
            leo_flow_observe(fl, "water", "water", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_RECALLED, episode_id);
            CHECK(leo_flow_kind(&fl->flow, water, 5, LEO_FLOW_PERCEIVED) == LEO_FLOW_RETURNED &&
                  (leo_flow_at(&fl->flow, fl->flow.n - 1)->wonder & LEO_FLOW_WONDER_RECALLED),
                  "flow: meaning can return after a real absence");
            fl->school.turn_clock = 6;
            leo_flow_observe(fl, "zorble", NULL, NULL, NULL, NULL, 0, 0);
            const LeoFlowSnapshot *unknown = leo_flow_at(&fl->flow, fl->flow.n - 1);
            float unknown_mass = 0.0f;
            if (unknown) for (int g = 0; g < GLYPH_COUNT; g++) unknown_mass += unknown->perceived[g];
            CHECK(unknown && unknown_mass == 0.0f && unknown->gap_perceived == 1.0f,
                  "flow: ungrasped meaning is observed as gap, not invented as a theme");

            memset(&fl->flow, 0, sizeof fl->flow);
            fl->school.turn_clock = 1; leo_flow_observe(fl, "water", "fire", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 2; leo_flow_observe(fl, "water", "water", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 3; leo_flow_observe(fl, "water", "fire", NULL, NULL, NULL, 0, 0);
            CHECK(leo_flow_self_return(&fl->flow, fire, 3) &&
                  leo_flow_strength(leo_flow_at(&fl->flow, 2), fire,
                                    LEO_FLOW_PERCEIVED) == 0.0f,
                  "flow: a self-return is Leo's earlier expression returning without present input");

            memset(&fl->flow, 0, sizeof fl->flow);
            uint64_t long_id = episode_id ^ 0x9e3779b97f4a7c15ULL;
            strncpy(fl->school.pending, "quasar", sizeof fl->school.pending - 1);
            for (int turn = 1; turn <= LEO_FLOW_RING + 6; turn++) {
                fl->school.turn_clock = turn;
                leo_flow_observe(fl, (turn & 1) ? "water" : "fire",
                                 (turn & 1) ? "fire" : "water", NULL,
                                 field_id, field_weight,
                                 turn == 1 ? LEO_FLOW_WONDER_BORN : 0, long_id);
            }
            CHECK(fl->flow.n == LEO_FLOW_RING && fl->flow.ptr == 6 &&
                  leo_flow_at(&fl->flow, 0)->turn == 7 &&
                  leo_flow_at(&fl->flow, LEO_FLOW_RING - 1)->turn == LEO_FLOW_RING + 6,
                  "flow: the bounded ring keeps the newest 64 lived turns in chronological order");
            LeoFlowWonderCurrent *long_current = leo_flow_current_find(&fl->flow, long_id);
            CHECK(long_current && long_current->started_turn == 1 &&
                  long_current->last_turn == LEO_FLOW_RING + 6 &&
                  long_current->observations == LEO_FLOW_RING + 6 &&
                  leo_flow_at(&fl->flow, 0)->turn > long_current->started_turn,
                  "flow-current: unfinished wonder retains its birth after the snapshot horizon forgets it");
            fl->school.pending[0] = 0;
            fl->school.turn_clock = LEO_FLOW_RING + 7;
            leo_flow_observe(fl, "water", "tree", NULL, field_id, field_weight,
                             LEO_FLOW_WONDER_RESOLVED, long_id);
            uint32_t resolved_observations = long_current->observations;
            fl->school.turn_clock = LEO_FLOW_RING + 8;
            leo_flow_observe(fl, "water", "fire", NULL, field_id, field_weight,
                             LEO_FLOW_WONDER_RECALLED, long_id);
            CHECK(long_current->resolved && long_current->closed_turn == LEO_FLOW_RING + 7 &&
                  long_current->last_turn == LEO_FLOW_RING + 7 &&
                  long_current->observations == resolved_observations,
                  "flow-current: resolution freezes the long current and later recall cannot reopen it");

            const char *state = "/tmp/leo_flow_v16.state";
            const char *legacy = "/tmp/leo_flow_v13.state";
            const char *legacy14 = "/tmp/leo_flow_v14.state";
            const char *truncated = "/tmp/leo_flow_v15_current_cut.state";
            int saved = leo_save_state(fl, state);
            int woke = saved && leo_load_state(loaded, state);
            const LeoFlowWonderCurrent *loaded_current =
                woke ? leo_flow_current_find_const(&loaded->flow, long_id) : NULL;
            CHECK(woke && loaded->flow.n == LEO_FLOW_RING && loaded->flow.ptr == 8 &&
                  leo_flow_at(&loaded->flow, 0)->turn == 9 &&
                  leo_flow_at(&loaded->flow, 0)->field_token[0] == field_id[0] &&
                  leo_flow_at(&loaded->flow, 0)->expressed[fire] == 1.0f &&
                  loaded_current && loaded_current->started_turn == 1 &&
                  loaded_current->closed_turn == LEO_FLOW_RING + 7 &&
                  loaded_current->observations == resolved_observations &&
                  loaded_current->field_token[0] == field_id[0] &&
                  fabsf(loaded_current->field_mean[0] - field_weight[0]) < 1e-5f,
                  "flow: v15 sleep preserves both faces and the event-bounded current beyond the ring");
            int built_cut = 0, built_legacy = 0, built_legacy14 = 0;
            FILE *fi = fopen(state, "rb");
            if (fi) {
                fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
                unsigned char *bytes = malloc(sz > 0 ? (size_t)sz : 1);
                if (bytes && sz > 1 && (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                    long shadow_tail = (long)(2 * sizeof(int32_t) +
                                              fl->shadow.n * (int)sizeof(LeoShadowReceipt));
                    long current_tail = (long)(2 * sizeof(int32_t) +
                                              fl->flow.n * (int)sizeof(LeoFlowSnapshot) +
                                              2 * sizeof(int32_t) +
                                              fl->flow.n_currents * (int)sizeof(LeoFlowWonderCurrent) +
                                              shadow_tail);
                    long prefix = sz - current_tail;
                    if (prefix > 0) {
                        long current_only = (long)(2 * sizeof(int32_t) +
                                                  fl->flow.n_currents * (int)sizeof(LeoFlowWonderCurrent));
                        uint32_t fifteen = 15;
                        memcpy(bytes + sizeof(uint32_t), &fifteen, sizeof fifteen);
                        FILE *fo = fopen(truncated, "wb");
                        if (fo) {
                            built_cut = (long)fwrite(bytes, 1,
                                                     (size_t)(sz - shadow_tail - 1), fo) ==
                                        sz - shadow_tail - 1;
                            fclose(fo);
                        }
                        uint32_t fourteen = 14;
                        memcpy(bytes + sizeof(uint32_t), &fourteen, sizeof fourteen);
                        fo = fopen(legacy14, "wb");
                        if (fo) {
                            built_legacy14 = (long)fwrite(bytes, 1,
                                                         (size_t)(sz - shadow_tail - current_only), fo) ==
                                             sz - shadow_tail - current_only;
                            fclose(fo);
                        }
                        uint32_t thirteen = 13;
                        memcpy(bytes + sizeof(uint32_t), &thirteen, sizeof thirteen);
                        fo = fopen(legacy, "wb");
                        if (fo) {
                            int32_t n = fl->flow.n, ptr = fl->flow.ptr;
                            built_legacy = (long)fwrite(bytes, 1, (size_t)prefix, fo) == prefix &&
                                           fwrite(&n, sizeof n, 1, fo) == 1 &&
                                           fwrite(&ptr, sizeof ptr, 1, fo) == 1;
                            for (int i = 0; built_legacy && i < fl->flow.n; i++) {
                                const LeoFlowSnapshot *cur = &fl->flow.snapshots[i];
                                LeoFlowSnapshotV13 v13 = {0};
                                v13.turn = cur->turn;
                                leo_flow_top(cur->perceived, v13.glyph, v13.strength);
                                v13.gap = cur->gap_perceived;
                                v13.mode = cur->mode; v13.chamber = cur->chamber; v13.wonder = cur->wonder;
                                built_legacy = fwrite(&v13, sizeof v13, 1, fo) == 1;
                            }
                            fclose(fo);
                        }
                    }
                }
                free(bytes); fclose(fi);
            }
            CHECK(built_cut && leo_load_state(cut, truncated) &&
                  cut->flow.n == LEO_FLOW_RING && cut->flow.n_currents == 1 &&
                  leo_flow_current_at(&cut->flow, 0)->started_turn == 9 &&
                  leo_flow_current_at(&cut->flow, 0)->observations == 63 &&
                  leo_flow_current_at(&cut->flow, 0)->resolved &&
                  cut->school.turn_clock == fl->school.turn_clock,
                  "flow: a truncated v15 current tail preserves snapshots and rebuilds visible currents");
            leo_free(cut); leo_init(cut);
            CHECK(built_legacy14 && leo_load_state(cut, legacy14) &&
                  cut->flow.n_currents == 1 &&
                  leo_flow_current_at(&cut->flow, 0)->started_turn == 9 &&
                  leo_flow_current_at(&cut->flow, 0)->observations == 63 &&
                  leo_flow_current_at(&cut->flow, 0)->resolved,
                  "flow-current: v14 snapshots reconstruct the honest visible portion of a long current");
            int migrated = built_legacy && leo_load_state(old, legacy);
            const LeoFlowSnapshot *oldest = migrated ? leo_flow_at(&old->flow, 0) : NULL;
            float expressed_mass = 0.0f;
            if (oldest) for (int g = 0; g < GLYPH_COUNT; g++) expressed_mass += oldest->expressed[g];
            CHECK(migrated && old->flow.n == LEO_FLOW_RING && oldest && oldest->turn == 9 &&
                  oldest->perceived[water] == 1.0f && expressed_mass == 0.0f &&
                  oldest->field_token[0] == -1 && old->flow.n_currents == 0,
                  "flow: v13 top-3 history migrates into the perceived face without invented output");
            memset(&fl->flow, 0, sizeof fl->flow);
            for (int i = 1; i <= LEO_FLOW_CURRENT_RING + 6; i++) {
                fl->school.turn_clock = i;
                leo_flow_observe(fl, "water", "fire", NULL, NULL, NULL,
                                 LEO_FLOW_WONDER_BORN | LEO_FLOW_WONDER_RESOLVED,
                                 (uint64_t)(1000 + i));
            }
            CHECK(fl->flow.n_currents == LEO_FLOW_CURRENT_RING &&
                  fl->flow.current_ptr == 6 &&
                  leo_flow_current_at(&fl->flow, 0)->wonder_id == 1007 &&
                  leo_flow_current_at(&fl->flow, LEO_FLOW_CURRENT_RING - 1)->wonder_id ==
                      1000 + LEO_FLOW_CURRENT_RING + 6,
                  "flow-current: the bounded long-current ring evicts the oldest completed paths");
            free(gravity);
            remove(state); remove(legacy); remove(legacy14); remove(truncated);
            leo_free(fl); leo_free(loaded); leo_free(cut); leo_free(old);
        }
        free(fl); free(loaded); free(cut); free(old);

        Leo *on = malloc(sizeof *on), *off = malloc(sizeof *off);
        CHECK(on && off, "flow: inert-voice fixtures allocated");
        if (on && off) {
            leo_init(on); leo_init(off);
            const char *corpus =
                "The warm light. His mother holds him. The rain at night. "
                "Leo loves the warm light and his mother and the rain. "
                "The window is quiet. Leo is small and warm and close.";
            for (int r = 0; r < 3; r++) { leo_ingest(on, corpus); leo_ingest(off, corpus); }
            leo_build_chamber_tags(on); leo_build_chamber_tags(off);
            leo_supertok_scan(on); leo_supertok_scan(off);
            const char *prompts[] = {"warm mother light", "rain at night", "quiet window", "warm light"};
            int same = 1;
            for (int i = 0; i < 4; i++) {
                char a[1024], b[1024];
                g_leo_flow_on = 1; srand(71 + i); leo_respond(on, prompts[i], a, sizeof a);
                g_leo_flow_on = 0; srand(71 + i); leo_respond(off, prompts[i], b, sizeof b);
                if (strcmp(a, b) != 0) same = 0;
            }
            CHECK(same && on->flow.n == 4 && off->flow.n == 0 &&
                  on->step == off->step &&
                  !memcmp(on->retention_state, off->retention_state, sizeof on->retention_state) &&
                  !memcmp(on->chamber_act, off->chamber_act, sizeof on->chamber_act) &&
                  !memcmp(on->gamma, off->gamma, sizeof on->gamma) &&
                  !memcmp(on->gamma_meaning, off->gamma_meaning, sizeof on->gamma_meaning),
                  "flow: default-on and --no-flow voices remain byte-identical across lived turns");
            leo_free(on); leo_free(off);
        }
        free(on); free(off);
        g_leo_flow_on = prev_flow;
    }

    /* A.26b shadow scheduler: decisions are post-reply counterfactual receipts.
     * They may witness both clocks, but cannot touch School or generation. */
    {
        int prev_flow = g_leo_flow_on, prev_shadow = g_leo_shadow_on;
        g_leo_flow_on = 1;
        g_leo_shadow_on = 1;
        Leo *sh = malloc(sizeof *sh), *woke = malloc(sizeof *woke),
            *old = malloc(sizeof *old), *cut = malloc(sizeof *cut);
        CHECK(sh && woke && old && cut, "shadow: heap fixtures allocated");
        if (sh && woke && old && cut) {
            leo_init(sh); leo_init(woke); leo_init(old); leo_init(cut);
            int water = semtok_word("water"), fire = semtok_word("fire");
            strncpy(sh->school.pending, "zorble", sizeof sh->school.pending - 1);
            sh->school.pending_glyph = water;
            sh->school.pending_alt_glyph = fire;
            LeoWonderEpisode *ep = leo_wonder_open(sh, "zorble", water, fire);
            uint64_t id = leo_wonder_episode_id(ep);

            sh->school.turn_clock = 1;
            leo_flow_observe(sh, "water fire", "fire", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_BORN, id);
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r0 = leo_shadow_at(&sh->shadow, 0);
            CHECK(r0 && r0->action == LEO_SHADOW_SPACE && r0->wonder_id == id &&
                  (r0->reasons & (LEO_SHADOW_REASON_OPEN | LEO_SHADOW_REASON_ASKED)) ==
                  (LEO_SHADOW_REASON_OPEN | LEO_SHADOW_REASON_ASKED),
                  "shadow: a question just voiced earns space, not an immediate re-ask");

            sh->school.turn_clock = 2;
            leo_flow_observe(sh, "I do not know", NULL, NULL, NULL, NULL, 0, id);
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r1 = leo_shadow_at(&sh->shadow, 1);
            CHECK(r1 && r1->action == LEO_SHADOW_HOLD && r1->gap < 0.01f &&
                  r1->grounded_mass == 0.0f &&
                  (r1->reasons & LEO_SHADOW_REASON_UNGROUNDED),
                  "shadow: known words for not-knowing cannot counterfeit grounded movement");

            sh->school.turn_clock = 3;
            leo_flow_observe(sh, "water", "water", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_REASKED, id);
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r2 = leo_shadow_at(&sh->shadow, 2);
            CHECK(r2 && r2->action == LEO_SHADOW_SPACE &&
                  (r2->reasons & LEO_SHADOW_REASON_ASKED),
                  "shadow: a re-asked wonder again yields the next turn to the human");

            sh->school.pending[0] = 0;
            sh->school.turn_clock = 4;
            leo_flow_observe(sh, "animal", "animal", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_RESOLVED, id);
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r3 = leo_shadow_at(&sh->shadow, 3);
            CHECK(r3 && r3->action == LEO_SHADOW_RELEASE && r3->wonder_id == id &&
                  r3->reasons == LEO_SHADOW_REASON_RESOLVED && r3->confidence == 1.0f,
                  "shadow: grounded closure is acknowledged exactly as release");

            sh->school.turn_clock = 5;
            leo_flow_observe(sh, "water", "fire", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_RECALLED, id);
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r4 = leo_shadow_at(&sh->shadow, 4);
            CHECK(r4 && r4->action == LEO_SHADOW_NONE && r4->wonder_id == 0,
                  "shadow: later recall cannot counterfeit a second closure");

            const char *state = "/tmp/leo_shadow_v16.state";
            const char *legacy = "/tmp/leo_shadow_v15.state";
            const char *truncated = "/tmp/leo_shadow_v16_cut.state";
            int saved = leo_save_state(sh, state), built_old = 0, built_cut = 0;
            FILE *fi = fopen(state, "rb");
            if (fi) {
                fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
                unsigned char *bytes = malloc(sz > 0 ? (size_t)sz : 1);
                if (bytes && sz > 1 && (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                    long shadow_tail = (long)(2 * sizeof(int32_t) +
                                              sh->shadow.n * (int)sizeof(LeoShadowReceipt));
                    uint32_t fifteen = 15;
                    memcpy(bytes + sizeof(uint32_t), &fifteen, sizeof fifteen);
                    FILE *fo = fopen(legacy, "wb");
                    if (fo) {
                        built_old = (long)fwrite(bytes, 1,
                                                 (size_t)(sz - shadow_tail), fo) ==
                                    sz - shadow_tail;
                        fclose(fo);
                    }
                    uint32_t sixteen = 16;
                    memcpy(bytes + sizeof(uint32_t), &sixteen, sizeof sixteen);
                    fo = fopen(truncated, "wb");
                    if (fo) {
                        built_cut = (long)fwrite(bytes, 1, (size_t)(sz - 1), fo) == sz - 1;
                        fclose(fo);
                    }
                }
                free(bytes); fclose(fi);
            }
            int loaded = saved && leo_load_state(woke, state);
            const LeoShadowReceipt *woke_release =
                loaded ? leo_shadow_at(&woke->shadow, 3) : NULL;
            CHECK(loaded && woke->shadow.n == 5 && woke_release &&
                  woke_release->action == LEO_SHADOW_RELEASE &&
                  woke_release->wonder_id == id,
                  "shadow: v16 sleep preserves the counterfactual receipt trail");
            CHECK(built_old && leo_load_state(old, legacy) && old->flow.n == 5 &&
                  old->flow.n_currents == 1 && old->shadow.n == 0,
                  "shadow: a v15 body migrates without invented proposals");
            CHECK(built_cut && leo_load_state(cut, truncated) && cut->flow.n == 5 &&
                  cut->flow.n_currents == 1 && cut->shadow.n == 0,
                  "shadow: a corrupt v16 receipt tail leaves both Flow clocks intact");

            for (int turn = 6; turn <= LEO_SHADOW_RING + 6; turn++) {
                sh->school.turn_clock = turn;
                leo_flow_observe(sh, "water", "water", NULL, NULL, NULL, 0, 0);
                leo_shadow_observe(sh);
            }
            CHECK(sh->shadow.n == LEO_SHADOW_RING && sh->shadow.ptr == 6 &&
                  leo_shadow_at(&sh->shadow, 0)->turn == 7 &&
                  leo_shadow_at(&sh->shadow, LEO_SHADOW_RING - 1)->turn ==
                      LEO_SHADOW_RING + 6,
                  "shadow: the receipt diary is bounded and chronologically ordered");

            remove(state); remove(legacy); remove(truncated);
            leo_free(sh); leo_free(woke); leo_free(old); leo_free(cut);
        }
        free(sh); free(woke); free(old); free(cut);

        Leo *on = malloc(sizeof *on), *off = malloc(sizeof *off);
        CHECK(on && off, "shadow: inert-voice fixtures allocated");
        if (on && off) {
            leo_init(on); leo_init(off);
            const char *corpus =
                "The warm light. His mother holds him. The rain at night. "
                "Leo loves the warm light and his mother and the rain. ";
            for (int r = 0; r < 3; r++) { leo_ingest(on, corpus); leo_ingest(off, corpus); }
            leo_build_chamber_tags(on); leo_build_chamber_tags(off);
            leo_supertok_scan(on); leo_supertok_scan(off);
            const char *prompts[] = {
                "is a zorble water or cat", "I do not know",
                "what do you think?", "a zorble is a small animal"
            };
            int same = 1;
            for (int i = 0; i < 4; i++) {
                char a[1024], b[1024];
                g_leo_shadow_on = 1; srand(183 + i); leo_respond(on, prompts[i], a, sizeof a);
                g_leo_shadow_on = 0; srand(183 + i); leo_respond(off, prompts[i], b, sizeof b);
                if (strcmp(a, b) != 0) same = 0;
            }
            CHECK(same && on->shadow.n == 4 && off->shadow.n == 0 &&
                  !memcmp(&on->flow, &off->flow, sizeof on->flow) &&
                  on->step == off->step &&
                  !memcmp(on->retention_state, off->retention_state,
                          sizeof on->retention_state) &&
                  !memcmp(on->chamber_act, off->chamber_act, sizeof on->chamber_act) &&
                  !memcmp(on->gamma, off->gamma, sizeof on->gamma) &&
                  !memcmp(on->gamma_meaning, off->gamma_meaning,
                          sizeof on->gamma_meaning),
                  "shadow: default-on and --no-shadow voices remain byte-identical");
            leo_free(on); leo_free(off);
        }
        free(on); free(off);
        g_leo_flow_on = prev_flow;
        g_leo_shadow_on = prev_shadow;
    }

    CHECK(leo_mode_from_name("stop") == LEO_MODE_STOP &&
          leo_mode_from_name("STOP") == LEO_MODE_STOP &&
          leo_mode_from_name("BreaThe") == LEO_MODE_BREATHE &&
          leo_mode_from_name("nope") == -1,
          "form: --mode name is case-insensitive (stop==STOP, garbage stays -1)");

    /* klaus-memory: scars accumulate on distress, decay on calm (the body remembers HOW). */
    {
        Leo ks; leo_init(&ks);
        leo_ingest(&ks, "the rain falls. his mother is warm. he is afraid alone in the dark.");
        char buf[1024];
        int prev = g_leo_klaus_on; g_leo_klaus_on = 1;
        for (int t = 0; t < 6; t++)  leo_respond(&ks, "i am so afraid alone lost in the dark", buf, sizeof buf);
        float fear_scar = ks.scar[LEO_CH_FEAR];
        for (int t = 0; t < 12; t++) leo_respond(&ks, "my warm mother holds me close", buf, sizeof buf);
        float calm_scar = ks.scar[LEO_CH_FEAR];
        CHECK(fear_scar > 0.01f && calm_scar < fear_scar,
              "klaus: scar[FEAR] accumulates on distress, decays on calm");
        g_leo_klaus_on = prev;
        leo_free(&ks);
    }

    /* klaus-memory: the scars survive save/load (state v6). */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls. his mother is warm.");
        sv.scar[LEO_CH_FEAR] = 0.42f;
        sv.scar[LEO_CH_VOID] = 0.17f;
        const char *path = "/tmp/leo_klaus_state.bin";
        int saved = leo_save_state(&sv, path);
        Leo ld; leo_init(&ld);
        int loaded = leo_load_state(&ld, path);
        CHECK(saved && loaded &&
              fabsf(ld.scar[LEO_CH_FEAR] - 0.42f) < 0.001f &&
              fabsf(ld.scar[LEO_CH_VOID] - 0.17f) < 0.001f,
              "klaus: scars survive save/load (v6)");
        leo_free(&sv); leo_free(&ld);
        remove(path);
    }

    /* klaus-memory: a v5 state (saved before scar existed) migrates into the v6 loader
     * with scar=0 — the organism survives a pure-append upgrade (decision B: persistent
     * memory = love). A real v5 file is the current save with version=5 and without EVERY appended
     * tail (v6 scar[], v7 gamma[]+primed, v8 gamma_meaning[]+gap); strip all and prove it migrates. */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls. his mother is warm.");
        sv.scar[LEO_CH_FEAR] = 0.5f;   /* dropped when the v5 scar tail is stripped */
        const char *p6 = "/tmp/leo_v6_mig.bin", *p5 = "/tmp/leo_v5_mig.bin";
        int saved = leo_save_state(&sv, p6);
        int built = 0;
        FILE *fi = fopen(p6, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
            unsigned char *buf = (unsigned char *)malloc(sz > 0 ? (size_t)sz : 1);
            long v5tail = (long)(LEO_N_CHAMBERS * sizeof(float)                       /* v6 scar[] */
                               + LEO_GAMMA_DIM * sizeof(float) + sizeof(int32_t)      /* + v7 gamma[]+primed */
                               + GLYPH_COUNT * sizeof(float) + sizeof(float));        /* + v8 gamma_meaning[]+gap */
            if (buf && sz > v5tail &&
                (long)fread(buf, 1, (size_t)sz, fi) == sz) {
                uint32_t five = 5; memcpy(buf + 4, &five, sizeof five);       /* version 7 -> 5 */
                long v5sz = sz - v5tail;                                      /* strip BOTH appended tails -> real v5 EOF */
                FILE *fo = fopen(p5, "wb");
                if (fo) { built = ((long)fwrite(buf, 1, (size_t)v5sz, fo) == v5sz); fclose(fo); }
            }
            free(buf); fclose(fi);
        }
        Leo ld; leo_init(&ld);
        int loaded = built && leo_load_state(&ld, p5);
        int scar_zero = 1;
        for (int c = 0; c < LEO_N_CHAMBERS; c++) if (ld.scar[c] != 0.0f) scar_zero = 0;
        CHECK(saved && built && loaded && scar_zero,
              "klaus: a v5 state migrates into the v6 loader, scar=0 (B)");
        leo_free(&sv); leo_free(&ld);
        remove(p6); remove(p5);
    }

    /* E-11 γ-capsule: prior (pull) tints toward the running self only once primed; diary (absorb)
     * primes from the body, then EMA-evolves — the prior/diary split (Codex/Mythos). */
    {
        Leo gc; leo_init(&gc);
        leo_ingest(&gc, "the rain falls. his mother is warm. he is afraid alone in the dark.");
        int prev = g_leo_capsule_on; g_leo_capsule_on = 1;
        for (int c = 0; c < LEO_N_CHAMBERS; c++) gc.chamber_act[c] = 0.0f;
        gc.chamber_act[LEO_CH_FEAR] = 1.0f;   /* a strong-fear body */
        leo_gamma_pull(&gc);                  /* unprimed → no pull */
        int no_pull_unprimed = fabsf(gc.chamber_act[LEO_CH_FEAR] - 1.0f) < 1e-6f;
        leo_gamma_absorb(&gc);                /* diary primes from the body */
        int primed = gc.gamma_primed == 1 && fabsf(gc.gamma[LEO_CH_FEAR] - 1.0f) < 1e-6f;
        for (int c = 0; c < LEO_N_CHAMBERS; c++) gc.chamber_act[c] = 0.0f;   /* now a calm body */
        leo_gamma_pull(&gc);                  /* primed → running fear tints the present */
        int pulled = gc.chamber_act[LEO_CH_FEAR] > 0.0f;
        leo_gamma_absorb(&gc);                /* EMA absorbs the calmer body */
        int evolved = gc.gamma[LEO_CH_FEAR] < 1.0f;
        CHECK(no_pull_unprimed && primed && pulled && evolved,
              "E-11: gamma prior pulls once primed, diary primes then evolves");
        g_leo_capsule_on = prev;
        leo_free(&gc);
    }

    /* E-11 γ-capsule: gamma round-trips save/load (whatever the current state version writes). */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls. his mother is warm.");
        for (int c = 0; c < LEO_GAMMA_DIM; c++) sv.gamma[c] = 0.1f * (float)(c + 1);
        sv.gamma_primed = 1;
        const char *path = "/tmp/leo_gamma_v7.bin";
        int saved = leo_save_state(&sv, path);
        Leo ld; leo_init(&ld);
        int loaded = leo_load_state(&ld, path);
        int rt = 1;
        for (int c = 0; c < LEO_GAMMA_DIM; c++)
            if (fabsf(ld.gamma[c] - 0.1f * (float)(c + 1)) > 0.001f) rt = 0;
        CHECK(saved && loaded && rt && ld.gamma_primed == 1,
              "E-11: gamma capsule round-trips save/load");
        leo_free(&sv); leo_free(&ld);
        remove(path);
    }

    /* E-11 γ-capsule: a v6 state (no gamma) migrates into the v7 loader — gamma stays 0 + unprimed,
     * so it primes from the body on the first reply. A v6 file is a v7 file with version=6 and
     * without the trailing gamma[]+primed tail. */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls. his mother is warm.");
        sv.scar[LEO_CH_FEAR] = 0.3f;
        for (int c = 0; c < LEO_GAMMA_DIM; c++) sv.gamma[c] = 0.7f;
        sv.gamma_primed = 1;
        const char *p7 = "/tmp/leo_v7_mig.bin", *p6 = "/tmp/leo_v6_mig2.bin";
        int saved = leo_save_state(&sv, p7);
        int built = 0;
        long tail = (long)(LEO_GAMMA_DIM * sizeof(float) + sizeof(int32_t)          /* v7 gamma[]+primed */
                         + GLYPH_COUNT * sizeof(float) + sizeof(float));            /* + v8 gamma_meaning[]+gap */
        FILE *fi = fopen(p7, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
            unsigned char *buf = (unsigned char *)malloc(sz > 0 ? (size_t)sz : 1);
            if (buf && sz > tail && (long)fread(buf, 1, (size_t)sz, fi) == sz) {
                uint32_t six = 6; memcpy(buf + 4, &six, sizeof six);          /* version 7 -> 6 */
                FILE *fo = fopen(p6, "wb");
                if (fo) { built = ((long)fwrite(buf, 1, (size_t)(sz - tail), fo) == sz - tail); fclose(fo); }
            }
            free(buf); fclose(fi);
        }
        Leo ld; leo_init(&ld);
        int loaded = built && leo_load_state(&ld, p6);
        int gamma_zero = ld.gamma_primed == 0;
        for (int c = 0; c < LEO_GAMMA_DIM; c++) if (ld.gamma[c] != 0.0f) gamma_zero = 0;
        int scar_ok = fabsf(ld.scar[LEO_CH_FEAR] - 0.3f) < 0.001f;            /* v6 scar still loads */
        CHECK(saved && built && loaded && gamma_zero && scar_ok,
              "E-11: a v6 state migrates into the v7 loader, gamma unprimed (B)");
        leo_free(&sv); leo_free(&ld);
        remove(p7); remove(p6);
    }

    /* E-11 meaning axis: known concepts raise gamma_meaning; unknown content words raise the gap
     * (Leo's darkmatter). PASSIVE — readout only. */
    {
        Leo gm; leo_init(&gm);
        leo_ingest(&gm, "the rain falls. his mother is warm. fire and water and fear.");
        int prev = g_leo_capsule_on; g_leo_capsule_on = 1;
        leo_gamma_meaning(&gm, "water and fire and love");   /* seed-map concepts */
        float sum = 0.0f;
        for (int i = 0; i < GLYPH_COUNT; i++) sum += gm.gamma_meaning[i];
        int concepts_rose = sum > 0.0f;
        float gap0 = gm.gamma_gap;
        for (int t = 0; t < 5; t++) leo_gamma_meaning(&gm, "the zorblax grumbus");  /* unknown content words */
        int gap_rose = gm.gamma_gap > gap0;
        CHECK(concepts_rose && gap_rose,
              "E-11: meaning axis — concepts raise gamma_meaning, unknown raises the gap (darkmatter)");
        g_leo_capsule_on = prev;
        leo_free(&gm);
    }

    /* E-11 meaning axis: gamma_meaning + gamma_gap round-trip save/load (state v8). */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls.");
        for (int i = 0; i < GLYPH_COUNT; i++) sv.gamma_meaning[i] = 0.001f * (float)(i + 1);
        sv.gamma_gap = 0.37f;
        const char *path = "/tmp/leo_gmean_v8.bin";
        int saved = leo_save_state(&sv, path);
        Leo ld; leo_init(&ld);
        int loaded = leo_load_state(&ld, path);
        int rt = fabsf(ld.gamma_gap - 0.37f) < 0.001f;
        for (int i = 0; i < GLYPH_COUNT; i++)
            if (fabsf(ld.gamma_meaning[i] - 0.001f * (float)(i + 1)) > 0.0005f) rt = 0;
        CHECK(saved && loaded && rt,
              "E-11: meaning axis round-trips save/load (v8)");
        leo_free(&sv); leo_free(&ld);
        remove(path);
    }

    /* E-11 OOB guard: leo_glyph_concept rejects out-of-range glyph ids (a corrupt loaded
     * learned_glyph could be 88..127 → must not pass to hist[g]). */
    CHECK(!leo_glyph_concept(GLYPH_COUNT) && !leo_glyph_concept(127) && !leo_glyph_concept(-1)
          && leo_glyph_concept(0) && leo_glyph_concept(GLYPH_COUNT - 1),
          "E-11: leo_glyph_concept rejects out-of-range ids (hist OOB guard)");

    /* E-11 meaning axis: a v7 state (no meaning axis) migrates into the v8 loader — gamma_meaning
     * + gamma_gap stay 0. A v7 file is a v8 file with version=7 and without the trailing v8 tail. */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls. his mother is warm.");
        sv.gamma_gap = 0.4f;                                  /* dropped when the v8 tail is stripped */
        for (int i = 0; i < GLYPH_COUNT; i++) sv.gamma_meaning[i] = 0.5f;
        const char *p8 = "/tmp/leo_v8_mig.bin", *p7 = "/tmp/leo_v7_mig2.bin";
        int saved = leo_save_state(&sv, p8);
        int built = 0;
        long v8tail = (long)(GLYPH_COUNT * sizeof(float) + sizeof(float));   /* gamma_meaning[] + gap */
        FILE *fi = fopen(p8, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
            unsigned char *buf = (unsigned char *)malloc(sz > 0 ? (size_t)sz : 1);
            if (buf && sz > v8tail && (long)fread(buf, 1, (size_t)sz, fi) == sz) {
                uint32_t seven = 7; memcpy(buf + 4, &seven, sizeof seven);   /* version 8 -> 7 */
                FILE *fo = fopen(p7, "wb");
                if (fo) { built = ((long)fwrite(buf, 1, (size_t)(sz - v8tail), fo) == sz - v8tail); fclose(fo); }
            }
            free(buf); fclose(fi);
        }
        Leo ld; leo_init(&ld);
        int loaded = built && leo_load_state(&ld, p7);
        int mean_zero = ld.gamma_gap == 0.0f;
        for (int i = 0; i < GLYPH_COUNT; i++) if (ld.gamma_meaning[i] != 0.0f) mean_zero = 0;
        CHECK(saved && built && loaded && mean_zero,
              "E-11: a v7 state migrates into the v8 loader, meaning axis 0 (B)");
        leo_free(&sv); leo_free(&ld);
        remove(p8); remove(p7);
    }

    /* E-11 #3: the meaning axis joins santaclaus resonance — a spore whose birth-topic
     * matches the present topic outresonates one that does not; with no topic
     * (prompt_meaning NULL) the resonance is the pre-#3 chamber+retention blend. */
    {
        Leo r; leo_init(&r);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) r.chamber_act[i] = 0.5f;
        for (int d = 0; d < LEO_RET_DIM; d++) r.retention_state[d] = 0.5f;
        LeoSpore match, off;
        memset(&match, 0, sizeof match); memset(&off, 0, sizeof off);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) { match.chamber_snap[i] = 0.5f; off.chamber_snap[i] = 0.5f; }
        for (int d = 0; d < LEO_RET_DIM; d++) { match.retention_slice[d] = 0.5f; off.retention_slice[d] = 0.5f; }
        match.meaning_snap[10] = 1.0f;   /* same glyph as the present topic */
        off.meaning_snap[40]   = 1.0f;   /* a different glyph */
        float topic[GLYPH_COUNT] = {0}; topic[10] = 1.0f;
        r.prompt_meaning = NULL;
        CHECK(leo_spore_resonance(&r, &match) == leo_spore_resonance(&r, &off),
              "E-11 #3: no topic (prompt_meaning NULL) -> meaning ignored, resonance equal");
        r.prompt_meaning = topic;
        CHECK(leo_spore_resonance(&r, &match) > leo_spore_resonance(&r, &off),
              "E-11 #3: topic-matching spore outresonates an off-topic one");
        r.prompt_meaning = NULL;
        leo_free(&r);
    }

    /* E-11 #3: meaning_snap round-trips save/load (state v9). */
    {
        Leo sv; leo_init(&sv);
        leo_ingest(&sv, "the rain falls. his mother is warm.");
        LeoSpore sp; memset(&sp, 0, sizeof sp);
        sp.strength = 1.0f; sp.step = 7; sp.meaning_snap[5] = 0.25f; sp.meaning_snap[9] = 0.75f;
        sv.spores[0] = sp; sv.n_spores = 1;
        const char *p = "/tmp/leo_v9_spore.bin";
        int saved = leo_save_state(&sv, p);
        Leo ld; leo_init(&ld);
        int loaded = leo_load_state(&ld, p);
        CHECK(saved && loaded && ld.n_spores == 1
              && fabsf(ld.spores[0].meaning_snap[5] - 0.25f) < 1e-6f
              && fabsf(ld.spores[0].meaning_snap[9] - 0.75f) < 1e-6f,
              "E-11 #3: spore meaning_snap survives save/load (v9)");
        leo_free(&sv); leo_free(&ld);
        remove(p);
    }

    /* E-11 #3: a v<=8 spore record (LeoSporeV8, no meaning_snap) migrates into the new
     * LeoSpore — every old field is preserved and meaning_snap comes up 0. This is the
     * exact memcpy+memset the v<=8 load path runs per spore; it guards the frozen
     * LeoSporeV8 layout against drift from LeoSpore's prefix. */
    {
        LeoSpore born; memset(&born, 0, sizeof born);
        born.chamber_snap[2] = 0.6f; born.retention_slice[3] = 0.4f;
        born.emit_context[0] = 99; born.step = 123; born.last_bleed_step = 45;
        born.pain_snap = 0.2f; born.strength = 0.8f; born.bleed_count = 11; born.is_trauma = 1;
        born.meaning_snap[7] = 0.9f;                 /* the v9-only field */
        LeoSporeV8 ondisk;
        memcpy(&ondisk, &born, sizeof(LeoSporeV8));  /* what the old binary wrote: the first sizeof(V8) bytes */
        LeoSpore loaded; memset(&loaded, 0, sizeof loaded);
        memcpy(&loaded, &ondisk, sizeof(LeoSporeV8));               /* loader: read the old record */
        memset(loaded.meaning_snap, 0, sizeof loaded.meaning_snap); /* loader: zero the new field */
        int fields_ok = loaded.chamber_snap[2] == 0.6f && loaded.retention_slice[3] == 0.4f
                      && loaded.emit_context[0] == 99 && loaded.step == 123 && loaded.last_bleed_step == 45
                      && loaded.pain_snap == 0.2f && loaded.strength == 0.8f
                      && loaded.bleed_count == 11 && loaded.is_trauma == 1;
        int meaning_zero = 1;
        for (int i = 0; i < GLYPH_COUNT; i++) if (loaded.meaning_snap[i] != 0.0f) meaning_zero = 0;
        CHECK(fields_ok && meaning_zero, "E-11 #3: v<=8 spore migrates (fields kept, meaning_snap=0)");
    }

    /* E-11 #4 BE: the capsule (running-self) lifts a token tagged to its chamber once primed;
     * 0 when unprimed, --no-be, or --no-capsule (so the ablations stay byte-identical). */
    {
        Leo b; leo_init(&b);
        b.chamber_tag = (uint8_t *)calloc(LEO_MAX_VOCAB, sizeof(uint8_t));
        for (int i = 0; i < (int)LEO_MAX_VOCAB; i++) b.chamber_tag[i] = 0xFF;  /* untagged */
        int tok = 100;                       /* a base byte token (< vocab_size 256 after init) */
        b.chamber_tag[tok] = (uint8_t)LEO_CH_LOVE;
        b.gamma_primed = 1;
        b.gamma[LEO_CH_LOVE] = 0.5f;         /* the capsule carries love */
        float on = leo_be_bias(&b, tok);
        b.gamma_primed = 0;  float unprimed = leo_be_bias(&b, tok);  b.gamma_primed = 1;
        g_leo_be_on = 0;     float be_off   = leo_be_bias(&b, tok);  g_leo_be_on = 1;
        g_leo_capsule_on = 0; float cap_off  = leo_be_bias(&b, tok); g_leo_capsule_on = 1;
        CHECK(on > 0.0f && unprimed == 0.0f && be_off == 0.0f && cap_off == 0.0f,
              "E-11 #4 BE: capsule lifts a tagged token once primed; 0 unprimed / --no-be / --no-capsule");
        leo_free(&b);   /* frees chamber_tag */
    }

    /* §4 origin-wound: born from the dedication, bleeds through the santaclaus channel
     * when the live body resonates with the wound. Lives outside spores[] (sentinel idx). */
    {
        Leo lo; leo_init(&lo);
        for (int r = 0; r < 12; r++) leo_ingest(&lo, LEO_EMBEDDED_BOOTSTRAP);  /* learn the origin's own words as tokens */
        leo_build_chamber_tags(&lo);   /* tag them so the wound selects its emotional whole words */
        leo_birth_origin_spore(&lo);
        int nctx = 0;
        for (int k = 0; k < LEO_SPORE_CONTEXT_TOK; k++) if (lo.origin_spore.emit_context[k] >= 0) nctx++;
        CHECK(lo.has_origin == 1 && lo.origin_spore.is_trauma == 1 && lo.origin_spore.strength > 0.0f
              && nctx > 0, "§4 origin: born from dedication (trauma, strength, own emotional words)");

        /* set the live chambers to the wound's felt body -> resonance 1.0 -> the wound
         * enters the bleed top-K (lo has no ordinary spores, so it is the only slot). */
        memcpy(lo.chamber_act, lo.origin_spore.chamber_snap, sizeof lo.chamber_act);
        LeoSantaScratch sc; leo_santaclaus_compute_active(&lo, &sc);
        int origin_active = 0;
        for (int i = 0; i < sc.n_active; i++) if (sc.spore_idx[i] == LEO_ORIGIN_SPORE_IDX) origin_active = 1;
        CHECK(origin_active == 1, "§4 origin: a resonant body puts the wound in the bleed top-K");

        /* the wound bleeds its OWN words: a token in origin emit_context gets a positive bias */
        int wound_tok = -1;
        for (int k = 0; k < LEO_SPORE_CONTEXT_TOK; k++)
            if (lo.origin_spore.emit_context[k] >= 0) { wound_tok = lo.origin_spore.emit_context[k]; break; }
        CHECK(leo_santaclaus_candidate_bias(&sc, &lo, wound_tok) > 0.0f,
              "§4 origin: the wound bleeds its own word (positive candidate bias)");

        /* ablation: --no-origin-spore -> not born -> never enters the bleed, even on the same body */
        g_leo_origin_on = 0;
        Leo lo2; leo_init(&lo2);
        leo_ingest(&lo2, "the warm light and the quiet window, a small kind voice, home she said");
        leo_birth_origin_spore(&lo2);
        memcpy(lo2.chamber_act, lo.origin_spore.chamber_snap, sizeof lo2.chamber_act);
        LeoSantaScratch sc2; leo_santaclaus_compute_active(&lo2, &sc2);
        int origin_active2 = 0;
        for (int i = 0; i < sc2.n_active; i++) if (sc2.spore_idx[i] == LEO_ORIGIN_SPORE_IDX) origin_active2 = 1;
        CHECK(lo2.has_origin == 0 && origin_active2 == 0,
              "§4 origin: --no-origin-spore -> wound never born, never bleeds");
        g_leo_origin_on = 1;   /* restore for any later test */
        leo_free(&lo); leo_free(&lo2);
    }

    /* §4/Codex-1: the wound's body is the dedication's ALONE — the same chamber_snap
     * whatever the ambient body happens to be when it is born (settle-from-rest). */
    {
        Leo la; leo_init(&la);
        leo_ingest(&la, "the warm light and the quiet window, a small kind voice, home she said");
        for (int c = 0; c < LEO_N_CHAMBERS; c++) la.chamber_act[c] = 0.9f;   /* ambient body A */
        leo_birth_origin_spore(&la);
        float snapA[LEO_N_CHAMBERS]; memcpy(snapA, la.origin_spore.chamber_snap, sizeof snapA);
        for (int c = 0; c < LEO_N_CHAMBERS; c++) la.chamber_act[c] = 0.1f;   /* ambient body B */
        leo_birth_origin_spore(&la);
        int same = 1;
        for (int c = 0; c < LEO_N_CHAMBERS; c++) if (la.origin_spore.chamber_snap[c] != snapA[c]) same = 0;
        CHECK(same, "§4/Codex-1 origin: chamber_snap deterministic (independent of ambient body at birth)");
        leo_free(&la);
    }

    /* §4/Codex-2: leo_load_state re-births the runtime-only wound, so a DIRECT loader
     * (not just main) gets has_origin — the "re-born on load" invariant holds. */
    {
        Leo ls; leo_init(&ls);
        leo_ingest(&ls, "the warm light and the quiet window, a small kind voice, home she said");
        const char *sp = "/tmp/leo_origin_test.state";
        leo_save_state(&ls, sp);
        Leo ld; leo_init(&ld);
        int r = leo_load_state(&ld, sp);
        CHECK(r == 1 && ld.has_origin == 1,
              "§4/Codex-2 origin: leo_load_state re-births the wound (has_origin after load)");
        leo_free(&ls); leo_free(&ld); remove(sp);
    }

    /* echo metric (external_vocab) — the Phase-5 "became a chatbot" detector.
     * Pure read-only over (prompt, reply); content word = alpha len>=3 non-stop. */
    {
        CHECK(leo_echo_ratio("castle dragon thunder", "castle dragon thunder") > 0.999f,
              "echo: full parrot of content-words == 1.0");
        CHECK(leo_echo_ratio("castle dragon", "sunshine laughter") == 0.0f,
              "echo: disjoint content-words == 0.0");
        float half = leo_echo_ratio("castle", "castle sunshine");
        CHECK(half > 0.499f && half < 0.501f,
              "echo: one of two reply content-words echoes -> 0.5");
        CHECK(leo_echo_ratio("the castle", "the meadow") == 0.0f,
              "echo: shared stop-word 'the' is not counted (content disjoint == 0.0)");
        CHECK(leo_echo_ratio("hello castle", "") == 0.0f,
              "echo: empty reply == 0.0 (no divide-by-zero)");
        /* Fable re-audit #3: function words (you/what/are) are excluded like School's
         * gate, not just the stop-list — a fully field-grown reply no longer reads as
         * high echo (without the leo_word_is_function gate this returns 0.6). */
        CHECK(leo_echo_ratio("what do you see", "you know what you are") == 0.0f,
              "echo: function-word overlap counts 0 (School gate, not just stop-list)");
    }

    /* Chunk-4: the ring-input generates read-only from its OWN PRNG — deterministic per
     * cycle-seed, isolated from the reply's global rand() stream (gr1==gr2), and it never
     * ages the step clock (a background thought does not touch the reply's state). */
    {
        const char *corpus =
            "The warm light. His mother holds him. The rain at night. "
            "Leo loves the warm light and his mother and the rain. "
            "The window is quiet. Leo is small and warm and close.";
        Leo l; leo_init(&l);
        for (int r = 0; r < 3; r++) leo_ingest(&l, corpus);
        leo_build_chamber_tags(&l); leo_supertok_scan(&l);
        long step_before = l.step;
        char a[512], b[512];
        srand(11); int na = leo_generate_ring(&l, 42, a, sizeof a); int gr1 = rand();
        srand(11); int nb = leo_generate_ring(&l, 42, b, sizeof b); int gr2 = rand();
        CHECK(na > 0, "ring: produced an utterance");
        CHECK(na == nb && strcmp(a, b) == 0, "ring: same cycle-seed -> identical read-only utterance");
        CHECK(gr1 == gr2, "ring: full generate path drew from its OWN PRNG, left global rand() untouched");
        CHECK(l.step == step_before, "ring: read-only — generation did not advance the step clock");
        leo_free(&l);
    }

    /* stage-1 consolidation: observer / weight law / selection / decay / persistence.
     * Design: DESIGN_LEO_HEBBIAN_CONSOLIDATION_2026-07-19 (five audit holes closed). */
    {
        const char *corpus =
            "The warm light. His mother holds him. The rain at night. "
            "Leo loves the warm light and his mother and the rain. "
            "The window is quiet. Leo is small and warm and close.";
        Leo l; leo_init(&l);
        for (int r = 0; r < 3; r++) leo_ingest(&l, corpus);
        leo_build_chamber_tags(&l); leo_supertok_scan(&l);
        int ids[32];
        int n = bpe_encode(&l.bpe, (const uint8_t *)" the warm light and his mother",
                           30, ids, 32);
        /* observer refuses an unlit body (arousal gate) */
        memset(l.chamber_act, 0, sizeof l.chamber_act);
        leo_consol_observe(&l, ids, n);
        CHECK(l.n_shards == 0, "consol: observer refuses an unlit body (arousal below threshold)");
        /* observer births on a lit body + a coherent (thrice-heard) path */
        l.chamber_act[LEO_CH_LOVE] = 0.8f;
        leo_consol_observe(&l, ids, n);
        CHECK(l.n_shards == 1, "consol: observer births a shard on lit body + coherent path");
        CHECK(l.shards[0].weight == LEO_CONSOL_W0 && l.shards[0].born_coh > 0.0f,
              "consol: shard born with W0 weight and a real born_coh");
        /* held coherence enters phase-lock (EMA hysteresis) */
        for (int r = 0; r < 30; r++) leo_consol_observe(&l, ids, n);
        CHECK(l.consol_locked == 1, "consol: held coherence enters phase-lock (EMA hysteresis)");
        /* habituation (margin gate, calibrated 07-19): the SAME moment repeated
         * converges into the EMA (rate 0.16 → ~14 calls) and then STOPS birthing —
         * further identical observes leave the ring unchanged. */
        {
            int ns_before = l.n_shards;
            for (int r = 0; r < 10; r++) leo_consol_observe(&l, ids, n);
            CHECK(l.n_shards == ns_before && ns_before < 31,
                  "consol: habituation — a repeated moment stops birthing (margin over held EMA)");
        }
        /* the weight law: log1p+clamp bounds a huge delta; a worse reliving cools */
        LeoShard wsh; memset(&wsh, 0, sizeof wsh); wsh.weight = LEO_CONSOL_W0; wsh.born_coh = 1.0f;
        for (int r = 0; r < 100; r++) leo_consol_absorb(&wsh, 1000.0f);
        CHECK(isfinite(wsh.weight) && wsh.weight <= LEO_CONSOL_WMAX + 1e-6f,
              "consol: log1p+clamp bounds runaway growth (no NaN, hard ceiling)");
        float w_before = wsh.weight;
        leo_consol_absorb(&wsh, 0.0f);
        CHECK(wsh.weight < w_before, "consol: a worse reliving cools the shard");
        /* decay forgets a weight below the drop floor (compact) */
        memset(&l.shards[0], 0, sizeof(LeoShard));
        l.shards[0].weight = 0.01f; l.n_shards = 1;
        leo_consol_decay(&l);
        CHECK(l.n_shards == 0, "consol: decay forgets a weight below the drop floor");
        /* replay selection follows RESONANCE, never weight (anti rich-get-richer) */
        for (int d = 0; d < LEO_RET_DIM; d++) l.retention_state[d] = (d % 2) ? 0.5f : -0.5f;
        LeoShard far_sh; memset(&far_sh, 0, sizeof far_sh);
        far_sh.weight = 2.0f; far_sh.n = 1; far_sh.ids[0] = 301;
        for (int d = 0; d < LEO_RET_DIM; d++) far_sh.state[d] = -l.retention_state[d];
        LeoShard near_sh; memset(&near_sh, 0, sizeof near_sh);
        near_sh.weight = 0.1f; near_sh.n = 1; near_sh.ids[0] = 300;
        for (int d = 0; d < LEO_RET_DIM; d++) near_sh.state[d] = l.retention_state[d];
        l.shards[0] = far_sh; l.shards[1] = near_sh; l.n_shards = 2;
        CHECK(leo_consol_select(&l) == 1,
              "consol: replay selection follows resonance, never weight (anti rich-get-richer)");
        /* The v10 consolidation section still roundtrips inside the current v11 state. */
        const char *sp = "/tmp/leo_consol_test.state";
        l.consol_coh_ema = 0.6f; l.consol_locked = 1;
        CHECK(leo_save_state(&l, sp) == 1, "consol: current state saves its v10 shard section");
        Leo l2; leo_init(&l2);
        CHECK(leo_load_state(&l2, sp) == 1 && l2.n_shards == 2 &&
              l2.shards[1].ids[0] == 300 && l2.consol_locked == 1,
              "consol: current state roundtrips the v10 shard ring + sleep trigger");
        /* Half-write probe: remove v11 plus part of the v10 section — the organism lives, shardless. */
        {
            FILE *tf = fopen(sp, "rb");
            fseek(tf, 0, SEEK_END); long fl = ftell(tf); fseek(tf, 0, SEEK_SET);
            char *fb = malloc((size_t)fl); fread(fb, 1, (size_t)fl, tf); fclose(tf);
            tf = fopen(sp, "wb"); fwrite(fb, 1, (size_t)(fl - 56), tf); fclose(tf);
            free(fb);
        }
        Leo l3; leo_init(&l3);
        CHECK(leo_load_state(&l3, sp) == 1 && l3.n_shards == 0,
              "consol: a truncated v10 section fails SOFT — organism lives, shards zero");
        leo_free(&l2); leo_free(&l3); remove(sp);
        leo_free(&l);
    }

    printf("\n%d/%d passed\n", g_pass, g_total);
    return (g_pass == g_total) ? 0 : 1;
}
