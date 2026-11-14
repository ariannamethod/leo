#define NEO_NO_MAIN
#include "../neoleo.c"
#include <assert.h>

static void finish(Leo *leo) {
    leo_model_free(&leo->model);
    free(leo);
}

static void directional_learning(void) {
    NeoExpert e = {0};
    float previous[LEO_DIM] = {1}, actual[LEO_DIM] = {0}, prediction[LEO_DIM];
    actual[1] = 1;
    neo_prediction(&e, previous, prediction);
    assert(prediction[1] == 0);
    neo_observe(&e, previous, actual);
    neo_prediction(&e, previous, prediction);
    assert(prediction[1] > 0.99f && prediction[0] == 0);
    /* Reversing a transition must not silently learn its reverse. */
    neo_prediction(&e, actual, prediction);
    assert(leo_dot(prediction, prediction, LEO_DIM) == 0);
    assert(e.observations == 1);
}

static void independent_votes(void) {
    NeoParliament p = {.gain=NEO_GAIN, .mask=15};
    Leo *leo = calloc(1, sizeof *leo);
    assert(leo);
    leo->model.bpe.vocab = 2;
    leo->model.bpe.token[0].semantic[0] = 1;
    leo->model.bpe.token[1].semantic[1] = 1;
    for (int e=0; e<NEO_SEATS; e++) {
        p.prediction[e][e % 2] = 1;
        p.gate[e] = 0.25f;
    }
    neo_owner = &p;
    float votes[NEO_SEATS];
    float all = neo_votes(&p, leo, 0, votes);
    assert(votes[0] == 1 && votes[1] == 0 && votes[2] == 1 && votes[3] == 0);
    p.gate[0] = 0;
    assert(neo_votes(&p, leo, 0, votes) < all);
    /* The intervention must be capable of reversing the chosen ranking. */
    p.base_best = p.voted_best = -INFINITY;
    for (int e=0; e<NEO_SEATS; e++) {
        p.prediction[e][0]=0; p.prediction[e][1]=1; p.gate[e]=0.25f;
    }
    neo_score(leo, 0, NULL, 1.0f);
    neo_score(leo, 1, NULL, 0.5f);
    assert(p.base_id == 0 && p.voted_id == 1);
    p.gain=0;
    assert(neo_score(leo, 1, NULL, 0.5f) == 0);
    free(leo);
    neo_owner=NULL;
}

int main(void) {
    directional_learning();
    independent_votes();
    char directory[] = "/tmp/neoleo-test.XXXXXX";
    assert(mkdtemp(directory));
    char corpus[1200], saved[1200], damaged[1200];
    snprintf(corpus, sizeof corpus, "%s/corpus.txt", directory);
    snprintf(saved, sizeof saved, "%s/snapshot.neostate", directory);
    snprintf(damaged, sizeof damaged, "%s/damaged.neostate", directory);
    FILE *f = fopen(corpus, "w"); assert(f);
    for(int i=0;i<8;i++) fputs(
      "Leo likes the quiet room. Leo hears the small bell. The bell is quiet. "
      "The room is warm. I am here with Leo. I hear the bell. The bell is loud. "
      "Leo likes the light. The light is warm. I am listening to you.\n", f);
    assert(!fclose(f));
    NeoParliament control={.gain=NEO_GAIN,.mask=15}, off={.gain=0,.mask=15};
    Leo *a=neo_birth(corpus,&control), *b=neo_birth(corpus,&off);
    assert(a&&b);
    assert(neo_memory_valid(&control.memory));
    assert(!memcmp(&control.memory,&off.memory,sizeof control.memory));
    assert(control.memory.expert[0].observations > 0);
    assert(memcmp(control.memory.expert[0].association,
                  control.memory.expert[3].association,
                  sizeof control.memory.expert[0].association));
    const char *lines[]={"I am here with Leo.", "The bell is quiet.",
                         "The bell is loud.", "I am listening to you."};
    for(int i=0;i<4;i++) {
        char left[LEO_LINE_BYTES],right[LEO_LINE_BYTES];
        neo_hear_line(&control,a,lines[i]);
        neo_hear_line(&off,b,lines[i]);
        NeoMemory before=off.memory;
        neo_owner=NULL; leo_respond(a,lines[i],left,sizeof left);
        neo_owner=&off; leo_respond(b,lines[i],right,sizeof right);
        assert(!strcmp(left,right));
        assert(a->rng==b->rng && a->turns==b->turns);
        assert(!memcmp(&before,&off.memory,sizeof before));
        assert(!memcmp(a->presence,b->presence,sizeof a->presence));
    }
    assert(off.choices > 0 && off.changed_top == 0);
    assert(!memcmp(&control.memory,&off.memory,sizeof control.memory));
    /* Online learning changes a later decision surface, without learning
     * from the expert's own generated continuation. */
    NeoMemory before=off.memory;
    neo_hear_line(&off,b,"The bell is loud.");
    assert(memcmp(&before,&off.memory,sizeof before));
    off.gain=NEO_GAIN;
    neo_owner=&off;
    before=off.memory;
    char response[LEO_LINE_BYTES];
    leo_respond(b,"The bell is loud.",response,sizeof response);
    assert(!memcmp(&before,&off.memory,sizeof before));
    assert(neo_save(b,&off,saved));
    assert(!neo_save(b,&off,saved)); /* existing snapshot is preserved */
    NeoParliament resumed={.gain=NEO_GAIN,.mask=15};
    Leo *c=neo_birth(corpus,&resumed); assert(c);
    assert(neo_load(c,&resumed,saved));
    assert(!memcmp(&off.memory,&resumed.memory,sizeof off.memory));
    assert(b->rng==c->rng && b->turns==c->turns);
    for(int i=0;i<2;i++) {
        char original[LEO_LINE_BYTES],continued[LEO_LINE_BYTES];
        neo_hear_line(&off,b,lines[i]); neo_hear_line(&resumed,c,lines[i]);
        neo_owner=&off; leo_respond(b,lines[i],original,sizeof original);
        neo_owner=&resumed; leo_respond(c,lines[i],continued,sizeof continued);
        assert(!strcmp(original,continued) && b->rng==c->rng);
        assert(!memcmp(&off.memory,&resumed.memory,sizeof off.memory));
    }
    /* A different corpus and a damaged body must reject the snapshot. */
    uint64_t hash=c->model.corpus_hash;
    c->model.corpus_hash^=1;
    assert(!neo_load(c,&resumed,saved));
    c->model.corpus_hash=hash;
    FILE *src=fopen(saved,"rb"),*dst=fopen(damaged,"wb");assert(src&&dst);
    int byte; long count=0;
    while((byte=fgetc(src))!=EOF) {if(count++==100)byte^=1;fputc(byte,dst);}
    fclose(src);fclose(dst);
    before=resumed.memory;
    assert(!neo_load(c,&resumed,damaged));
    assert(!memcmp(&before,&resumed.memory,sizeof before));
    dst=fopen(damaged,"wb");assert(dst);fputs("NEOLEO01",dst);fclose(dst);
    assert(!neo_load(c,&resumed,damaged));
    neo_owner=NULL;
    finish(a);finish(b);finish(c);
    unlink(corpus);unlink(saved);unlink(damaged);rmdir(directory);
    puts("Neo Leo: causal learning, four votes, disabled parity, source isolation, "
         "online updates, exact resume, exclusive save and corruption gates passed.");
    return 0;
}
