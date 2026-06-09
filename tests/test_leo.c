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

    printf("\n%d/%d passed\n", g_pass, g_total);
    return (g_pass == g_total) ? 0 : 1;
}
