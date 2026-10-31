#!/usr/bin/env python3
"""Copies the card faces from a checkout of github.com/seeligd/svg-playing-cards into the iOS and Android apps, as
vector images they draw at any card size.

    scripts/import-cards.py [path to svg-playing-cards]    # defaults to ~/code/svg-playing-cards

Four decks go into each app:

    Small..., SmallAbril   big corner ranks, for the small cards of a phone-sized table
    Large..., LargeAbril   the full card design, for the big cards of a roomy table

the first of each in Arial on iOS, which comes with the phone, and Roboto on Android, which doesn't have Arial; Roboto
is close to it and freely licensed.

iOS gets them as vector images in Assets.xcassets/Cards, each deck a folder that names its images
(Cards/SmallArial/queen_of_hearts).  Android gets them in android/app/src/main/res/raw (card_smallroboto_queen_of_hearts),
first converted with Android Studio's own converter (scripts/svg2vector), which flattens each card into plain paths,
clips and gradients, then written as numbers the app draws straight from (see VectorArt.kt), where reading the SVGs or
even the converter's XML took seconds; CardVectors.kt lists them.
The games use the Arial or Roboto ones; the Cards menu can switch to any of them (see CardFaces in Card.swift and
CardArt.kt).

The large decks' face art is written more compactly on the way in, with tools/make_small.py's rounding, which needs
fontTools and svgpathtools (pip install fonttools svgpathtools).  The Android conversion needs the JDK that
scripts/android-emulators.sh installs.
"""
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS_CARDS = os.path.join(ROOT, 'Suze Solitaire', 'Assets.xcassets', 'Cards')
ANDROID_RAW = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw')
ANDROID_LIST = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'kotlin', 'net', 'dseelig', 'suzesolitaire', 'ui',
                            'CardVectors.kt')
DECKS = {'SmallArial': 'arial/small', 'SmallRoboto': 'roboto/small', 'SmallAbril': 'small',
         'LargeArial': 'arial', 'LargeRoboto': 'roboto', 'LargeAbril': '.'}
IOS_DECKS = ['SmallArial', 'SmallAbril', 'LargeArial', 'LargeAbril']
ANDROID_DECKS = ['SmallRoboto', 'SmallAbril', 'LargeRoboto', 'LargeAbril']
CARD_W, CARD_H = 167.0869141, 242.6669922
SUITS = ['clubs', 'diamonds', 'hearts', 'spades']
RANKS = ['ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king']
INFO = {'author': 'xcode', 'version': 1}
# The size each card says it is on iOS, in points.  Xcode keeps the vectors, which the app draws at whatever size a card
# is, but also makes bitmaps of every card at this size for each screen scale, used only to draw a card at exactly this
# size, which the game never does.  At the cards' own 167 x 243 those come to 18 MB, so they're made tiny.
NATURAL_WIDTH = 16


def write_json(path, contents):
    with open(path, 'w') as f:
        json.dump(contents, f, indent=2)
        f.write('\n')


def write(path, text):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def fresh(folder):
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)


def main():
    source = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else '~/code/svg-playing-cards')
    sys.path.insert(0, os.path.join(source, 'tools'))
    import make_small
    fresh(IOS_CARDS)
    android_svgs = tempfile.mkdtemp()
    write_json(os.path.join(IOS_CARDS, 'Contents.json'), {'info': INFO})
    for deck, folder in DECKS.items():
        ios_deck = os.path.join(IOS_CARDS, deck)
        if deck in IOS_DECKS:
            os.makedirs(ios_deck)
            write_json(os.path.join(ios_deck, 'Contents.json'), {'info': INFO, 'properties': {'provides-namespace': True}})
        for suit in SUITS:
            for rank in RANKS:
                name = f'{rank}_of_{suit}'
                with open(os.path.join(source, folder, f'{name}.svg'), encoding='utf-8') as f:
                    svg = f.read()
                if deck.startswith('Large') and rank in ('jack', 'queen', 'king'):
                    # Everything kept, with coordinates rounded to a tenth of a unit: under a fiftieth of a pixel
                    svg = make_small.trim(svg, (-1e9, -1e9, 1e9, 1e9))
                if deck in ANDROID_DECKS:
                    write(os.path.join(android_svgs, f'card_{deck.lower()}_{name}.svg'), svg)
                if deck not in IOS_DECKS:
                    continue

                imageset = os.path.join(ios_deck, f'{name}.imageset')
                os.makedirs(imageset)
                svg = re.sub(r'(<svg\b[^>]*?)\swidth="[^"]*"', rf'\1 width="{NATURAL_WIDTH}pt"', svg, count=1)
                height = NATURAL_WIDTH * CARD_H / CARD_W
                svg = re.sub(r'(<svg\b[^>]*?)\sheight="[^"]*"', rf'\1 height="{height:.3f}pt"', svg, count=1)
                write(os.path.join(imageset, f'{name}.svg'), svg)
                # One vector image for every scale, kept as vectors so it stays sharp at any card size
                write_json(os.path.join(imageset, 'Contents.json'), {
                    'images': [{'filename': f'{name}.svg', 'idiom': 'universal'}],
                    'info': INFO,
                    'properties': {'preserves-vector-representation': True},
                })
    import_android(android_svgs)
    shutil.rmtree(android_svgs)
    print(f'Imported {len(IOS_DECKS) * 52} cards into {os.path.relpath(IOS_CARDS, ROOT)} and {len(ANDROID_DECKS) * 52} into '
          f'{os.path.relpath(ANDROID_RAW, ROOT)}')


# The card files VectorArt.kt reads.  Big-endian throughout.
#
#   "SUZ1", viewport width and height (floats)
#   then nodes until END:
#     GROUP ... GROUP_END   a save and restore around what's inside, which a CLIP in it clips
#     CLIP path             clips what follows it in its group
#     SHAPE flags [fill colour (int)] [gradient] [stroke colour (int), stroke width (float), join (byte)] path
#       flags: 1 even-odd fill, 2 a fill colour, 4 a gradient, 8 a stroke
#       gradient: 0 and x1, y1, x2, y2 for linear, or 1 and cx, cy, r for radial (floats), then a stop count (byte) and
#       each stop's offset (float) and colour (int)
#   path: commands until 'E', each 'M', 'L', 'Q', 'C' or 'Z' and its points, each coordinate the change from the last
#   one written, in hundredths of a unit, as a zigzag varint
END, GROUP, GROUP_END, CLIP, SHAPE = 0, 1, 2, 3, 4
ANDROID_NS = '{http://schemas.android.com/apk/res/android}'


def varint(value):
    value = (value << 1) ^ (value >> 63)
    out = bytearray()
    while True:
        byte = value & 0x7f
        value >>= 7
        if value:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return bytes(out)


def encode_path(d):
    from svgpathtools import Arc, CubicBezier, Line, QuadraticBezier, parse_path
    out = bytearray()
    last = [0, 0]

    def point(z):
        for i, v in enumerate((z.real, z.imag)):
            q = round(v * 100)
            out.extend(varint(q - last[i]))
            last[i] = q

    for shape in parse_path(d).continuous_subpaths():
        if not len(shape):
            continue
        out.extend(b'M')
        point(shape[0].start)
        for seg in shape:
            if isinstance(seg, Line):
                out.extend(b'L')
                point(seg.end)
            elif isinstance(seg, QuadraticBezier):
                out.extend(b'Q')
                point(seg.control)
                point(seg.end)
            elif isinstance(seg, CubicBezier):
                out.extend(b'C')
                for z in (seg.control1, seg.control2, seg.end):
                    point(z)
            elif isinstance(seg, Arc):
                for curve in seg.as_cubic_curves():
                    out.extend(b'C')
                    for z in (curve.control1, curve.control2, curve.end):
                        point(z)
        if shape.isclosed():
            out.extend(b'Z')
    out.extend(b'E')
    return bytes(out)


def argb(text):
    hex = text.lstrip('#')
    if len(hex) <= 4:
        hex = ''.join(c * 2 for c in hex)
    if len(hex) == 6:
        hex = 'ff' + hex
    return struct.pack('>I', int(hex, 16))


def encode_vector(xml):
    root = ET.fromstring(xml)
    out = bytearray(b'SUZ1')
    out.extend(struct.pack('>ff', float(root.get(ANDROID_NS + 'viewportWidth')), float(root.get(ANDROID_NS + 'viewportHeight'))))

    def node(element):
        tag = element.tag
        if tag == 'group':
            out.append(GROUP)
            for child in element:
                node(child)
            out.append(GROUP_END)
        elif tag == 'clip-path':
            out.append(CLIP)
            out.extend(encode_path(element.get(ANDROID_NS + 'pathData')))
        elif tag == 'path':
            fill = element.get(ANDROID_NS + 'fillColor')
            stroke = element.get(ANDROID_NS + 'strokeColor')
            width = float(element.get(ANDROID_NS + 'strokeWidth') or 0)
            gradient = element.find('.//gradient')
            has_stroke = stroke is not None and argb(stroke)[0] != 0 and width > 0
            flags = (1 if element.get(ANDROID_NS + 'fillType') == 'evenOdd' else 0) | (2 if fill and gradient is None else 0) | \
                (4 if gradient is not None else 0) | (8 if has_stroke else 0)
            out.append(SHAPE)
            out.append(flags)
            if flags & 2:
                out.extend(argb(fill))
            if flags & 4:
                get = lambda name: float(gradient.get(ANDROID_NS + name) or 0)
                if gradient.get(ANDROID_NS + 'type') == 'radial':
                    out.append(1)
                    out.extend(struct.pack('>fff', get('centerX'), get('centerY'), get('gradientRadius')))
                else:
                    out.append(0)
                    out.extend(struct.pack('>ffff', get('startX'), get('startY'), get('endX'), get('endY')))
                stops = gradient.findall('item')
                out.append(len(stops))
                for stop in stops:
                    out.extend(struct.pack('>f', float(stop.get(ANDROID_NS + 'offset'))))
                    out.extend(argb(stop.get(ANDROID_NS + 'color')))
            if flags & 8:
                join = {'round': 1, 'bevel': 2}.get(element.get(ANDROID_NS + 'strokeLineJoin'), 0)
                out.extend(argb(stroke) + struct.pack('>f', width) + bytes([join]))
            out.extend(encode_path(element.get(ANDROID_NS + 'pathData')))

    for child in root:
        node(child)
    out.append(END)
    return bytes(out)


def import_android(svgs):
    os.makedirs(ANDROID_RAW, exist_ok=True)
    for old in os.listdir(ANDROID_RAW):
        if old.startswith('card_'):
            os.remove(os.path.join(ANDROID_RAW, old))
    vectors = tempfile.mkdtemp()
    env = dict(os.environ)
    if not env.get('JAVA_HOME'):
        prefix = subprocess.run(['brew', '--prefix', 'openjdk@21'], capture_output=True, text=True, check=True).stdout.strip()
        env['JAVA_HOME'] = os.path.join(prefix, 'libexec', 'openjdk.jdk', 'Contents', 'Home')
    subprocess.run([os.path.join(ROOT, 'android', 'gradlew'), '--quiet', '--console=plain', '-p', os.path.join(ROOT, 'scripts', 'svg2vector'), 'run',
                    f'--args={svgs} {vectors}'], env=env, check=True)
    for name in sorted(os.listdir(vectors)):
        with open(os.path.join(vectors, name), encoding='utf-8') as f:
            data = encode_vector(f.read())
        with open(os.path.join(ANDROID_RAW, name[:-4] + '.bin'), 'wb') as f:
            f.write(data)
    shutil.rmtree(vectors)
    # The app looks the files up through this list, which also keeps the release build's resource shrinking from
    # dropping the ones the game doesn't show by default
    lines = ['package net.dseelig.suzesolitaire.ui', '', 'import net.dseelig.suzesolitaire.R', '',
             '// Made by scripts/import-cards.py: each set of card faces, in Card number order (see Card)',
             'object CardVectors {']
    for deck in ANDROID_DECKS:
        lines.append(f'    val {deck[0].lower() + deck[1:]} = intArrayOf(')
        for suit in SUITS:
            for rank in RANKS:
                lines.append(f'        R.raw.card_{deck.lower()}_{rank}_of_{suit},')
        lines.append('    )')
    lines.append('}')
    write(ANDROID_LIST, '\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
