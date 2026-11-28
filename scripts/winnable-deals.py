#!/usr/bin/env python3
"""Finds deals that can be won, for the Dealing settings other than Totally Random, and writes them into both apps:

    scripts/winnable-deals.py [theory|cunning]    # both if neither is named; cunning takes about ten minutes

    theory    Winnable in Theory: deals scripts/winnable-deals/solve.c can win knowing where every card is
    cunning   Winnable with Cunning: deals it wins playing as a careful player could, without peeking at the covered
              cards in the blind or deck cards that have never come to the top of the deal, and without taking a move
              back

The deals are shuffled from a fixed seed, so each list comes out the same every run.  Those won go into the apps, one
per line, as 52 letters: the cards in the order Table.deal takes them, each card id (Clubs, Diamonds, Hearts, then
Spades, Ace to King) as a letter A-Z then a-z.

The first 100 of each list also go, with the moves that won them, to the Android unit tests, which play them through
with the app's rules (WinnableDealsTest).
"""
import os
import random
from concurrent.futures import ThreadPoolExecutor
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOLVER = os.path.join(ROOT, 'scripts', 'winnable-deals', 'solve.c')
LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
# How many deals to try for each list, and the solver's arguments: for theory, how many tables to search before giving
# up; for cunning, how many ways to imagine the unknown cards before each move, and how far to search each for a win
KINDS = {
    'theory': (3400, ['theory', '3000000']),
    'cunning': (5400, ['cunning', '20', '20000']),
}


def deals(tries):
    rng = random.Random(20261128)
    out = []
    for _ in range(tries):
        deck = list(range(52))
        rng.shuffle(deck)
        out.append(' '.join(map(str, deck)))
    return out


def generate(kind, solver):
    tries, args = KINDS[kind]
    shuffled = deals(tries)
    # One solver per core, each on a share of the deals, put back in order after
    cores = os.cpu_count() or 1
    def run(i):
        share = shuffled[i::cores]
        return subprocess.run([solver] + args, input='\n'.join(share) + '\n', capture_output=True, text=True,
                              check=True).stdout.splitlines()
    with ThreadPoolExecutor(cores) as pool:
        shares = list(pool.map(run, range(cores)))
    out = [shares[i % cores][i // cores] for i in range(tries)]

    won = [line for line in out if line.startswith('W ')]
    lines = [''.join(LETTERS[int(c)] for c in line[2:].split(' | ')[0].split()) for line in won]
    print(f'{kind}: {len(won)} of {tries} deals won')

    name = kind.capitalize() + 'Deals'
    ios = os.path.join(ROOT, 'Suze Solitaire', 'Assets.xcassets', name + '.dataset')
    os.makedirs(ios, exist_ok=True)
    with open(os.path.join(ios, name + '.txt'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    with open(os.path.join(ios, 'Contents.json'), 'w') as f:
        f.write('{\n  "data" : [\n    {\n      "filename" : "' + name + '.txt",\n      "idiom" : "universal"\n    }\n  ],\n'
                '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n')
    with open(os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw', f'deals_{kind}.txt'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    tests = os.path.join(ROOT, 'android', 'app', 'src', 'test', 'resources')
    os.makedirs(tests, exist_ok=True)
    with open(os.path.join(tests, f'solutions_{kind}.txt'), 'w') as f:
        f.write('\n'.join(line[2:] for line in won[:100]) + '\n')


def main():
    kinds = sys.argv[1:] or list(KINDS)
    with tempfile.TemporaryDirectory() as tmp:
        solver = os.path.join(tmp, 'solve')
        subprocess.run(['cc', '-O3', '-o', solver, SOLVER], check=True)
        for kind in kinds:
            generate(kind, solver)


if __name__ == '__main__':
    main()
