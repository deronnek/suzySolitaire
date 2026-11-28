#!/usr/bin/env python3
"""Finds deals that can be won, for Winnable Deals Only, and writes them into both apps:

    scripts/winnable-deals.py [how many to try]    # defaults to 3400

Each deal is shuffled from a fixed seed, so the list comes out the same every run, and goes to scripts/winnable-deals/
solve.c, which searches for a way to win it.  Those it wins go into the apps, one per line, as 52 letters: the cards in
the order Table.deal takes them, each card id (Clubs, Diamonds, Hearts, then Spades, Ace to King) as a letter A-Z then
a-z.  Deals the solver couldn't finish within its limit are left out with the ones that can't be won.

The first 100 wins also go, with the moves that win them, to the Android unit tests, which play them through with the
app's rules (WinnableDealsTest).
"""
import os
import random
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOLVER = os.path.join(ROOT, 'scripts', 'winnable-deals', 'solve.c')
IOS = os.path.join(ROOT, 'Suze Solitaire', 'Assets.xcassets', 'WinnableDeals.dataset')
ANDROID = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw', 'winnable_deals.txt')
SOLUTIONS = os.path.join(ROOT, 'android', 'app', 'src', 'test', 'resources', 'winnable_solutions.txt')
LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
# Nodes the solver searches before giving up on a deal
LIMIT = 3_000_000


def main():
    tries = int(sys.argv[1]) if len(sys.argv) > 1 else 3400
    rng = random.Random(20261128)
    deals = []
    for _ in range(tries):
        deck = list(range(52))
        rng.shuffle(deck)
        deals.append(' '.join(map(str, deck)))

    with tempfile.TemporaryDirectory() as tmp:
        solver = os.path.join(tmp, 'solve')
        subprocess.run(['cc', '-O3', '-o', solver, SOLVER], check=True)
        out = subprocess.run([solver, str(LIMIT)], input='\n'.join(deals) + '\n', capture_output=True, text=True, check=True).stdout

    won = [line for line in out.splitlines() if line.startswith('W ')]
    lines = [''.join(LETTERS[int(c)] for c in line[2:].split(' | ')[0].split()) for line in won]
    print(f'{len(won)} of {tries} deals won')

    os.makedirs(IOS, exist_ok=True)
    with open(os.path.join(IOS, 'WinnableDeals.txt'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    with open(os.path.join(IOS, 'Contents.json'), 'w') as f:
        f.write('{\n  "data" : [\n    {\n      "filename" : "WinnableDeals.txt",\n      "idiom" : "universal"\n    }\n  ],\n'
                '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n')
    with open(ANDROID, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    os.makedirs(os.path.dirname(SOLUTIONS), exist_ok=True)
    with open(SOLUTIONS, 'w') as f:
        f.write('\n'.join(line[2:].split(' #')[0] for line in won[:100]) + '\n')


if __name__ == '__main__':
    main()
