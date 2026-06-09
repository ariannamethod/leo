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

    printf("\n%d/%d passed\n", g_pass, g_total);
    return (g_pass == g_total) ? 0 : 1;
}
