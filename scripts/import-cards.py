#!/usr/bin/env python3
"""Copies the card faces from a checkout of github.com/seeligd/svg-playing-cards into the asset catalog, as vector
images the app scales to any card size.

    scripts/import-cards.py [path to svg-playing-cards]    # defaults to ~/code/svg-playing-cards

Four decks go in, each a folder in Assets.xcassets/Cards that names its images (Cards/SmallArial/queen_of_hearts):

    SmallArial, SmallAbril   big corner ranks, for the small cards of a phone-sized table
    LargeArial, LargeAbril   the full card design, for the big cards of a roomy table

The game uses the Arial ones; the Debug menu can switch to any of them (see CardFaces in Card.swift).

The large decks' face art is written more compactly on the way in, with tools/make_small.py's rounding, which needs
fontTools and svgpathtools (pip install fonttools svgpathtools).
"""
import json
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARDS = os.path.join(ROOT, 'Suze Solitaire', 'Assets.xcassets', 'Cards')
DECKS = {'SmallArial': 'arial/small', 'SmallAbril': 'small', 'LargeArial': 'arial', 'LargeAbril': '.'}
CARD_W, CARD_H = 167.0869141, 242.6669922
SUITS = ['clubs', 'diamonds', 'hearts', 'spades']
RANKS = ['ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king']
INFO = {'author': 'xcode', 'version': 1}
# The size each card says it is, in points.  Xcode keeps the vectors, which the app draws at whatever size a card is,
# but also makes bitmaps of every card at this size for each screen scale, used only to draw a card at exactly this
# size, which the game never does.  At the cards' own 167 x 243 those come to 18 MB, so they're made tiny.
NATURAL_WIDTH = 16


def write_json(path, contents):
    with open(path, 'w') as f:
        json.dump(contents, f, indent=2)
        f.write('\n')


def main():
    global make_small
    source = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else '~/code/svg-playing-cards')
    sys.path.insert(0, os.path.join(source, 'tools'))
    import make_small
    if os.path.isdir(CARDS):
        shutil.rmtree(CARDS)
    os.makedirs(CARDS)
    write_json(os.path.join(CARDS, 'Contents.json'), {'info': INFO})
    for deck, folder in DECKS.items():
        deck_dir = os.path.join(CARDS, deck)
        os.makedirs(deck_dir)
        write_json(os.path.join(deck_dir, 'Contents.json'), {'info': INFO, 'properties': {'provides-namespace': True}})
        for suit in SUITS:
            for rank in RANKS:
                name = f'{rank}_of_{suit}'
                imageset = os.path.join(deck_dir, f'{name}.imageset')
                os.makedirs(imageset)
                with open(os.path.join(source, folder, f'{name}.svg'), encoding='utf-8') as f:
                    svg = f.read()
                if deck.startswith('Large') and rank in ('jack', 'queen', 'king'):
                    # Everything kept, with coordinates rounded to a tenth of a unit: under a fiftieth of a pixel
                    svg = make_small.trim(svg, (-1e9, -1e9, 1e9, 1e9))
                svg = re.sub(r'(<svg\b[^>]*?)\swidth="[^"]*"', rf'\1 width="{NATURAL_WIDTH}pt"', svg, count=1)
                height = NATURAL_WIDTH * CARD_H / CARD_W
                svg = re.sub(r'(<svg\b[^>]*?)\sheight="[^"]*"', rf'\1 height="{height:.3f}pt"', svg, count=1)
                with open(os.path.join(imageset, f'{name}.svg'), 'w', encoding='utf-8') as f:
                    f.write(svg)
                # One vector image for every scale, kept as vectors so it stays sharp at any card size
                write_json(os.path.join(imageset, 'Contents.json'), {
                    'images': [{'filename': f'{name}.svg', 'idiom': 'universal'}],
                    'info': INFO,
                    'properties': {'preserves-vector-representation': True},
                })
    print(f'Imported {len(DECKS) * 52} cards into {os.path.relpath(CARDS, ROOT)}')


if __name__ == '__main__':
    main()
