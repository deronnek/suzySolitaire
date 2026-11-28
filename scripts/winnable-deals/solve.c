// Plays Suze Solitaire deals as a careful player would, for scripts/winnable-deals.py, to find the ones a person can win.
//
// It never peeks.  It knows only what a player can see: the lower and upper stacks, the top of the blind, and every
// card that has come to the top of the deal, since a player can deal through the deck as often as they like to see
// those.  The covered cards in the blind, and deck cards that have never been on top of the deal, are unknown to it.
//
// Before each move it imagines a few ways the unknown cards might lie, works out how to win each of those (a
// depth-first search that remembers the tables it has seen), and makes the move that wins the most of them.  It never
// takes a move back.  Once every card it hasn't put up is known, it plays out the win if there is one.  A player who
// made the same moves would win every deal it wins, without knowing anything they couldn't see.
//
// Reads deals (52 card ids, the shuffled order Table.deal takes) one per line on stdin, and for each writes
//   W <ids> | <moves>     (won; moves are D for a deal, or card>U / card>L<i>)
//   L <ids>               (lost)
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

static uint64_t rng = 0x2545F4914F6CDD1DULL;
static uint64_t nextRandom(void) { rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17; return rng; }

typedef struct {
    uint8_t up[4];          // cards up per suit
    uint8_t blind[13], nb;  // top is blind[nb-1]
    uint8_t S[34], L, k;    // deal + deck.reversed(); deal top is S[k-1]
    uint8_t low[4][52], nl[4];
} St;

static int starter;
static inline int rankOf(int c) { return c % 13 + 1; }
static inline int suitOf(int c) { return c / 13; }
static inline int isRed(int c) { int s = c / 13; return s == 1 || s == 2; }
static inline int prevR(int r) { return r == 1 ? 13 : r - 1; }
static inline int upRank(int c) { return (rankOf(c) - starter + 13) % 13; }

// A card the player hasn't seen
#define UNKNOWN 52
static inline int canUp(const St *s, int c) { return c != UNKNOWN && s->up[suitOf(c)] == upRank(c); }
// May c go on lower stack t (fromBlind: whether it comes from the blind)
static inline int lowerTakes(const St *s, int c, int t, int fromBlind) {
    if (c == UNKNOWN) return 0;
    if (s->nl[t] == 0) return fromBlind || (s->nb == 0 && rankOf(c) == prevR(starter));
    int top = s->low[t][s->nl[t] - 1];
    return isRed(c) != isRed(top) && rankOf(c) == prevR(rankOf(top));
}
// Safe to put up: every card that could sit on it below is already up
static int safeUp(const St *s, int c) {
    if (c == UNKNOWN) return 0;
    int r = upRank(c);
    if (r == 0) return 0;
    int red = isRed(c);
    for (int su = 0; su < 4; su++) {
        int sr = (su == 1 || su == 2);
        if (sr != red && s->up[su] < r) return 0;
    }
    return 1;
}

// ---- tables seen in one search.  Each search has its own generation, so the table needn't be cleared between them.
#define TBITS 22
typedef struct { uint64_t hash; uint32_t gen; } Seen;
static Seen *table;
static uint32_t generation;
static uint64_t mix(uint64_t h) { h ^= h >> 33; h *= 0xff51afd7ed558ccdULL; h ^= h >> 33; h *= 0xc4ceb9fe1a85ec53ULL; h ^= h >> 33; return h; }
static uint64_t hashSt(const St *s) {
    uint64_t h = 1469598103934665603ULL;
    #define H(x) do { h ^= (uint8_t)(x); h *= 1099511628211ULL; } while (0)
    for (int i = 0; i < 4; i++) H(s->up[i]);
    H(s->nb); H(s->L); H(s->k % 3 == 0 ? 0 : s->k);
    for (int i = 0; i < s->L; i++) H(s->S[i]);
    // lower stacks are interchangeable: combine them order-independently
    uint64_t lh = 0;
    for (int t = 0; t < 4; t++) {
        uint64_t x = 0x9e3779b97f4a7c15ULL;
        for (int i = 0; i < s->nl[t]; i++) x = mix(x ^ (s->low[t][i] + 1) * 0x100000001b3ULL);
        x = mix(x + s->nl[t]);
        lh += x;
    }
    h = mix(h ^ lh);
    return h ? h : 1;
}
// returns 1 if newly inserted
static int insert(uint64_t h) {
    uint64_t m = (1ULL << TBITS) - 1, i = h & m;
    while (table[i].gen == generation) { if (table[i].hash == h) return 0; i = (i + 1) & m; }
    table[i] = (Seen){h, generation};
    return 1;
}

// ---- moves
enum { SRC_BLIND, SRC_STOCK, SRC_LOW };
typedef struct { uint8_t src, from, idx, to; } Mv;  // to: 4 = up, 0..3 lower; from: stock position or lower index
#define MAXPATH 4000

static int cardOf(const St *s, Mv m) {
    if (m.src == SRC_BLIND) return s->blind[s->nb - 1];
    if (m.src == SRC_STOCK) return s->S[m.from];
    return s->low[m.from][m.idx];
}

static void apply(St *s, Mv m) {
    if (m.src == SRC_BLIND) {
        int c = s->blind[--s->nb];
        if (m.to == 4) s->up[suitOf(c)]++; else s->low[m.to][s->nl[m.to]++] = c;
    } else if (m.src == SRC_STOCK) {
        int c = s->S[m.from];
        memmove(s->S + m.from, s->S + m.from + 1, s->L - m.from - 1);
        s->L--; s->k = m.from;  // the card under it is now on top of the deal
        if (m.to == 4) s->up[suitOf(c)]++; else s->low[m.to][s->nl[m.to]++] = c;
    } else {
        int f = m.from, n = s->nl[f] - m.idx;
        if (m.to == 4) { s->up[suitOf(s->low[f][m.idx])]++; }
        else { memcpy(s->low[m.to] + s->nl[m.to], s->low[f] + m.idx, n); s->nl[m.to] += n; }
        s->nl[f] = m.idx;
    }
}

// Stock positions reachable as the deal's top card, by dealing on (and turning over)
static int reachable(const St *s, int *out) {
    int n = 0, L = s->L;
    if (L == 0) return 0;
    char seen[35] = {0};
    if (s->k > 0) seen[s->k] = 1;
    for (int p = s->k; ; p += 3) { int q = p > L ? L : p; if (q > 0) seen[q] = 1; if (q == L) break; }
    for (int p = 3; ; p += 3) { int q = p > L ? L : p; seen[q] = 1; if (q == L) break; }
    for (int p = 1; p <= L; p++) if (seen[p]) out[n++] = p - 1;
    return n;
}

static int won(const St *s) { return s->up[0] + s->up[1] + s->up[2] + s->up[3] == 52; }

// Puts up cards nothing still needs to sit on
static void forceSafe(St *s, Mv *path, int *depth) {
    for (;;) {
        Mv m = {0, 0, 0, 4};
        int found = 0;
        if (s->nb && canUp(s, s->blind[s->nb - 1]) && safeUp(s, s->blind[s->nb - 1])) { m.src = SRC_BLIND; found = 1; }
        for (int t = 0; t < 4 && !found; t++) if (s->nl[t]) {
            int c = s->low[t][s->nl[t] - 1];
            if (canUp(s, c) && safeUp(s, c)) { m = (Mv){SRC_LOW, t, s->nl[t] - 1, 4}; found = 1; }
        }
        if (!found) return;
        apply(s, m);
        path[(*depth)++] = m;
    }
}

// The moves worth trying, blind first
static int genMoves(const St *s, Mv *moves) {
    int n = 0;
    int pos[34], np = reachable(s, pos);
    if (s->nb) {
        int c = s->blind[s->nb - 1];
        if (canUp(s, c)) moves[n++] = (Mv){SRC_BLIND, 0, 0, 4};
        int empty = 0;
        for (int t = 0; t < 4; t++) if (lowerTakes(s, c, t, 1)) { if (s->nl[t] == 0) { if (empty) continue; empty = 1; } moves[n++] = (Mv){SRC_BLIND, 0, 0, t}; }
    }
    for (int t = 0; t < 4; t++) if (s->nl[t]) { int c = s->low[t][s->nl[t] - 1]; if (canUp(s, c)) moves[n++] = (Mv){SRC_LOW, t, s->nl[t] - 1, 4}; }
    for (int i = 0; i < np; i++) if (canUp(s, s->S[pos[i]])) moves[n++] = (Mv){SRC_STOCK, pos[i], 0, 4};
    // Lower stacks are always runs, so a run moving onto another stack only trades places with its twin.  That's worth
    // it to empty a stack, or to let the card under it go up.
    for (int f = 0; f < 4; f++) for (int i = 0; i < s->nl[f]; i++) {
        int c = s->low[f][i];
        int empty = 0;
        for (int t = 0; t < 4; t++) {
            if (t == f) continue;
            if (s->nl[t] == 0) {
                // to an empty stack: only a run headed by the card below the starter, once the blind is empty, and not a whole stack
                if (i == 0 || empty || !lowerTakes(s, c, t, 0)) continue;
                empty = 1; moves[n++] = (Mv){SRC_LOW, f, i, t};
                continue;
            }
            if (!lowerTakes(s, c, t, 0)) continue;
            if (i == 0 || canUp(s, s->low[f][i - 1])) moves[n++] = (Mv){SRC_LOW, f, i, t};
        }
    }
    for (int i = 0; i < np; i++) {
        int c = s->S[pos[i]], empty = 0;
        for (int t = 0; t < 4; t++) if (lowerTakes(s, c, t, 0)) { if (s->nl[t] == 0) { if (empty) continue; empty = 1; } moves[n++] = (Mv){SRC_STOCK, pos[i], 0, t}; }
    }
    return n;
}

// ---- searching for a win on a table where every card is known
static long nodes, limit;
static Mv path[MAXPATH];
static int depth;

// 1 won, with the moves in path; 0 not, or gave up at the limit
static int dfs(St *s) {
    if (++nodes > limit || depth > MAXPATH - 60) return 0;
    int base = depth;
    forceSafe(s, path, &depth);
    if (won(s)) return 1;
    if (insert(hashSt(s))) {
        Mv moves[1000];
        int n = genMoves(s, moves), mid = depth;
        for (int i = 0; i < n && nodes <= limit; i++) {
            St c = *s;
            apply(&c, moves[i]);
            path[mid] = moves[i];
            depth = mid + 1;
            if (dfs(&c)) return 1;
        }
    }
    depth = base;
    return 0;
}

static int search(St *s, long nodeLimit) {
    St c = *s;
    generation++;
    nodes = 0; depth = 0; limit = nodeLimit;
    return dfs(&c);
}

// ---- playing a deal
static Mv played[MAXPATH];
static int playedCount;
static int samples = 10;
static long sampleLimit = 20000, finalLimit = 3000000;

static void play1(St *s, Mv m) { apply(s, m); played[playedCount++] = m; }

static int sameMove(Mv a, Mv b) { return a.src == b.src && a.from == b.from && a.idx == b.idx && a.to == b.to; }

// Plays the deal through, returning whether it was won
static int play(St *s) {
    char seen[53] = {0};
    playedCount = 0;
    for (int turn = 0; turn < 1500 && playedCount < MAXPATH - 60; turn++) {
        forceSafe(s, played, &playedCount);
        if (won(s)) return 1;
        // What dealing through the deck shows, and the top of the blind
        int pos[34], np = reachable(s, pos);
        for (int i = 0; i < np; i++) seen[s->S[pos[i]]] = 1;
        if (s->nb) seen[s->blind[s->nb - 1]] = 1;

        int unknown[52], nu = 0;
        for (int i = 0; i < s->nb - 1; i++) unknown[nu++] = s->blind[i];
        for (int i = 0; i < s->L; i++) if (!seen[s->S[i]]) unknown[nu++] = s->S[i];
        if (nu == 0) {
            // Nothing left to guess at
            if (!search(s, finalLimit)) return 0;
            for (int i = 0; i < depth; i++) play1(s, path[i]);
            return won(s);
        }

        // The move that wins the most of the ways the unknown cards might lie
        Mv cand[64]; int votes[64], nc = 0;
        for (int k = 0; k < samples; k++) {
            int deck[52];
            memcpy(deck, unknown, sizeof(int) * nu);
            for (int i = nu - 1; i > 0; i--) { int j = nextRandom() % (i + 1), t = deck[i]; deck[i] = deck[j]; deck[j] = t; }
            St guess = *s;
            int d = 0;
            for (int i = 0; i < guess.nb - 1; i++) guess.blind[i] = deck[d++];
            for (int i = 0; i < guess.L; i++) if (!seen[guess.S[i]]) guess.S[i] = deck[d++];
            if (!search(&guess, sampleLimit) || depth == 0) continue;
            int c = 0;
            while (c < nc && !sameMove(cand[c], path[0])) c++;
            if (c == nc) { if (nc == 64) continue; cand[nc] = path[0]; votes[nc++] = 0; }
            votes[c]++;
        }
        if (nc == 0) return 0;
        int bestMove = 0;
        for (int c = 1; c < nc; c++) if (votes[c] > votes[bestMove]) bestMove = c;
        play1(s, cand[bestMove]);
    }
    return 0;
}

// Replays the moves played, writing them as the app's actions
static void writePath(const St *start) {
    St s = *start;
    for (int i = 0; i < playedCount; i++) {
        Mv m = played[i];
        if (m.src == SRC_STOCK) {
            // deal until position m.from is on top of the deal
            int want = m.from + 1, guard = 0;
            while (s.k != want) {
                if (s.k == s.L) s.k = 0; else s.k = s.k + 3 > s.L ? s.L : s.k + 3;
                printf(" D");
                if (++guard > 100) { fprintf(stderr, "bad deal path\n"); exit(1); }
            }
        }
        int c = cardOf(&s, m);
        if (m.to == 4) printf(" %d>U", c); else printf(" %d>L%d", c, m.to);
        apply(&s, m);
    }
}

// solve [ways to imagine the unknown cards before each move] [nodes to search in each]
int main(int argc, char **argv) {
    if (argc > 1) samples = atoi(argv[1]);
    if (argc > 2) sampleLimit = atol(argv[2]);
    table = calloc(1ULL << TBITS, sizeof(Seen));
    int ids[52];
    char line[1024];
    while (fgets(line, sizeof line, stdin)) {
        char *p = line; int n = 0;
        while (n < 52) { char *e; long v = strtol(p, &e, 10); if (e == p) break; ids[n++] = (int)v; p = e; }
        if (n != 52) continue;
        St s; memset(&s, 0, sizeof s);
        for (int i = 0; i < 13; i++) s.blind[i] = ids[i];
        s.nb = 13;
        starter = rankOf(ids[13]);
        s.up[suitOf(ids[13])] = 1;
        s.L = 34;
        for (int i = 0; i < 34; i++) s.S[i] = ids[47 - i];
        s.k = 0;
        for (int t = 0; t < 4; t++) { s.low[t][0] = ids[48 + t]; s.nl[t] = 1; }
        // Imagine the same unknown cards for a deal however the deals are shared out
        rng = 0x2545F4914F6CDD1DULL;
        for (int i = 0; i < 52; i++) rng = mix(rng ^ ids[i]);
        rng |= 1;
        St start = s;
        int r = play(&s);
        putchar(r ? 'W' : 'L');
        for (int i = 0; i < 52; i++) printf(" %d", ids[i]);
        if (r) { printf(" |"); writePath(&start); }
        printf("\n");
        fflush(stdout);
    }
    return 0;
}
