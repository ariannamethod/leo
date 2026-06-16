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
            for (int s = 0; s < 400 && !seen_on; s++) { srand(s); if (leo_choose_continuation(&l, NULL, 0) == theme) seen_on = 1; }
            CHECK(seen_on == 1, "П-2: gravity-first ON -> excluded-rank theme seed is ADMITTED");
            g_leo_cont_theme_on = 0;
            int seen_off = 0;
            for (int s = 0; s < 400; s++) { srand(s); if (leo_choose_continuation(&l, NULL, 0) == theme) seen_off = 1; }
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

    /* A.6 FORM fix: --mode is case-insensitive. leo_mode_from_name matched only the
     * UPPERCASE LEO_MODE_NAMES, so the natural lowercase "--mode stop" returned -1 and
     * the forced breath was silently dropped (override stayed -1). */
    CHECK(leo_mode_from_name("stop") == LEO_MODE_STOP &&
          leo_mode_from_name("STOP") == LEO_MODE_STOP &&
          leo_mode_from_name("BreaThe") == LEO_MODE_BREATHE &&
          leo_mode_from_name("nope") == -1,
          "form: --mode name is case-insensitive (stop==STOP, garbage stays -1)");

    printf("\n%d/%d passed\n", g_pass, g_total);
    return (g_pass == g_total) ? 0 : 1;
}
