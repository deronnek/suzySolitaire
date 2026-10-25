#!/usr/bin/env python3
# Uploads an Android App Bundle to a Google Play track, with release notes:
#
#   scripts/play-upload.py <bundle.aab> <track> <release notes>
#
# Used by scripts/play-upload.sh.  While the app has never been published, Play takes only draft releases, which are
# then rolled out from the Play Console; after that, each upload goes out to the track's testers straight away.

import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play

bundle, track, notes = sys.argv[1:4]
# Play shows at most 500 characters of release notes
notes = notes[:500]

edit = play.call("POST", "/edits", {})["id"]
print("Uploading...")
version = play.upload(f"/edits/{edit}/bundles", bundle)["versionCode"]


def release(status):
    return {"track": track, "releases": [{"versionCodes": [str(version)], "status": status,
                                           "releaseNotes": [{"language": "en-US", "text": notes}]}]}


play.call("PUT", f"/edits/{edit}/tracks/{track}", release("completed"))
try:
    play.call("POST", f"/edits/{edit}:commit")
    print(f"Build {version} is out to the {track} track's testers.")
except SystemExit as error:
    if "draft app" not in str(error):
        raise
    # A new app's first releases have to be drafts
    play.call("PUT", f"/edits/{edit}/tracks/{track}", release("draft"))
    play.call("POST", f"/edits/{edit}:commit")
    print(f"Build {version} is a draft release on the {track} track: roll it out from the Play Console "
          "(Test and release > Testing > Internal testing).")
