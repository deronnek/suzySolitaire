// Finds a way to win Suze Solitaire deals, for scripts/winnable-deals.py: a depth-first search that remembers the tables
// it has seen.  The deck turns over as often as it's needed, so dealing through it costs nothing, and any card the deal
// can bring to the top is a move.  Lower stacks are interchangeable, so tables differing only in their order count as one.
//
// Reads deals (52 card ids, the shuffled order Table.deal takes) one per line on stdin, and for each writes
//   W <ids> | <moves>     (won; moves are D for a deal, or card>U / card>L<i>)
//   L <ids>               (proven lost: whole space searched)
//   ? <ids>               (gave up at the node limit)
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

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
static inline int nextR(int r) { return r == 13 ? 1 : r + 1; }
static inline int prevR(int r) { return r == 1 ? 13 : r - 1; }
static inline int upRank(int c) { return (rankOf(c) - starter + 13) % 13; }

static inline int canUp(const St *s, int c) { return s->up[suitOf(c)] == upRank(c); }
// May c go on lower stack t (fromBlind: whether it comes from the blind)
static inline int lowerTakes(const St *s, int c, int t, int fromBlind) {
    if (s->nl[t] == 0) return fromBlind || (s->nb == 0 && rankOf(c) == prevR(starter));
    int top = s->low[t][s->nl[t] - 1];
    return isRed(c) != isRed(top) && rankOf(c) == prevR(rankOf(top));
}
// Safe to put up: every card that could sit on it below is already up
static int safeUp(const St *s, int c) {
    int r = upRank(c);
    if (r == 0) return 0;
    int red = isRed(c);
    for (int su = 0; su < 4; su++) {
        int sr = (su == 1 || su == 2);
        if (sr != red && s->up[su] < r) return 0;
    }
    return 1;
}

// ---- transposition table
#define TBITS 24
static uint64_t *table;
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
    while (table[i]) { if (table[i] == h) return 0; i = (i + 1) & m; }
    table[i] = h;
    return 1;
}

// ---- moves
enum { SRC_BLIND, SRC_STOCK, SRC_LOW };
typedef struct { uint8_t src, from, idx, to; } Mv;  // to: 4 = up, 0..3 lower; from: stock position or lower index
static long nodes, limit;
static long filled;
static Mv path[4000]; static int depth;

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

static int dfs(St *s) {
    if (++nodes > limit || depth > 3900) return -1;
    // forced safe moves up
    int base = depth;
    for (;;) {
        int moved = 0;
        if (s->nb && safeUp(s, s->blind[s->nb - 1]) && canUp(s, s->blind[s->nb - 1])) { Mv m = {SRC_BLIND, 0, 0, 4}; apply(s, m); path[depth++] = m; moved = 1; continue; }
        for (int t = 0; t < 4 && !moved; t++) if (s->nl[t]) { int c = s->low[t][s->nl[t] - 1]; if (canUp(s, c) && safeUp(s, c)) { Mv m = {SRC_LOW, t, s->nl[t] - 1, 4}; apply(s, m); path[depth++] = m; moved = 1; } }
        if (!moved) break;
    }
    if (won(s)) return 1;
    if (!insert(hashSt(s))) { depth = base; return 0; }

    Mv moves[1000]; int n = 0;
    int pos[34], np = reachable(s, pos);
    // blind first
    if (s->nb) {
        int c = s->blind[s->nb - 1];
        if (canUp(s, c)) moves[n++] = (Mv){SRC_BLIND, 0, 0, 4};
        int empty = 0;
        for (int t = 0; t < 4; t++) if (lowerTakes(s, c, t, 1)) { if (s->nl[t] == 0) { if (empty) continue; empty = 1; } moves[n++] = (Mv){SRC_BLIND, 0, 0, t}; }
    }
    for (int t = 0; t < 4; t++) if (s->nl[t]) { int c = s->low[t][s->nl[t] - 1]; if (canUp(s, c)) moves[n++] = (Mv){SRC_LOW, t, s->nl[t] - 1, 4}; }
    for (int i = 0; i < np; i++) if (canUp(s, s->S[pos[i]])) moves[n++] = (Mv){SRC_STOCK, pos[i], 0, 4};
    // emptying a lower stack, and swapping a run to a twin so the card under it can go up
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
    for (int i = 0; i < n; i++) {
        St c = *s;
        apply(&c, moves[i]);
        path[depth++] = moves[i];
        int r = dfs(&c);
        if (r) return r;
        depth--;
    }
    depth = base;
    return 0;
}

// Replays the path, writing it as the app's actions
static void writePath(const St *start) {
    St s = *start;
    int k = 0;  // real deal count position, tracks s.k
    for (int i = 0; i < depth; i++) {
        Mv m = path[i];
        if (m.src == SRC_STOCK) {
            // deal until position m.from is on top: k == m.from + 1
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
    (void)k;
}

int main(int argc, char **argv) {
    limit = argc > 1 ? atol(argv[1]) : 2000000;
    table = calloc(1ULL << TBITS, sizeof(uint64_t));
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
        memset(table, 0, (1ULL << TBITS) * sizeof(uint64_t));
        nodes = 0; depth = 0;
        St start = s;
        int r = dfs(&s);
        putchar(r == 1 ? 'W' : r == 0 ? 'L' : '?');
        for (int i = 0; i < 52; i++) printf(" %d", ids[i]);
        if (r == 1) { printf(" |"); writePath(&start); }
        printf(" # %ld\n", nodes);
        fflush(stdout);
    }
    return 0;
}
