#!/usr/bin/env python3
#
# Brings the Google Play store listing up to date from android/store: the short and full descriptions, the icon, the
# feature graphic, and the phone, 7-inch and 10-inch tablet screenshots (scripts/android-screenshots.sh --play).
# Each set of images is replaced as a whole, in the order the files sort in.
#
#   scripts/play-metadata.py
#
# Uses the service account key in scripts/play.local.env (see play.py).

import glob, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play

STORE    = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "store")
LANGUAGE = "en-US"
TITLE    = "Suze Solitaire"
IMAGES   = {
    "icon":                 ["icon-512.png"],
    "featureGraphic":       ["feature-graphic.png"],
    "phoneScreenshots":     ["screenshots/phone-*.png"],
    "sevenInchScreenshots": ["screenshots/tablet-7in*.png"],
    "tenInchScreenshots":   ["screenshots/tablet-10in*.png"],
}


def text(name):
    with open(os.path.join(STORE, name)) as f:
        return f.read().strip()


def main():
    edit = play.call("POST", "/edits", {})["id"]
    listing = f"/edits/{edit}/listings/{LANGUAGE}"
    play.call("PUT", listing, {"language": LANGUAGE, "title": TITLE,
                               "shortDescription": text("short_description.txt"),
                               "fullDescription": text("full_description.txt")})
    print("Descriptions")
    for kind, patterns in IMAGES.items():
        files = sorted(f for pattern in patterns for f in glob.glob(os.path.join(STORE, pattern)))
        if not files:
            sys.exit(f"No {kind} in {STORE}")
        play.call("DELETE", f"{listing}/{kind}")
        for file in files:
            play.upload(f"{listing}/{kind}", file, "image/png")
        print(f"{kind}: {', '.join(os.path.basename(f) for f in files)}")
    play.call("POST", f"/edits/{edit}:commit")
    print("The store listing is up to date.")


main()
