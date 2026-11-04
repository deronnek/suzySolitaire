#!/usr/bin/env python3
#
# Uploads the App Store listing in AppStore/ to the version waiting for submission in App Store Connect, so it can be
# reviewed and submitted there:
#
#   Metadata/description.txt, keywords.txt, promotional_text.txt, support_url.txt, and whats_new.txt if there is one
#     (the first version can't have release notes)
#   Metadata/subtitle.txt, privacy_policy_url.txt and copyright.txt
#   Metadata/age_rating.json, the answers to the age rating questions
#   Metadata/review_notes.txt, the Notes in App Review Information
#   Screenshots/iPhone-6.9.png, iPad-13.png and iPhone-Duo.png (from scripts/screenshots.sh), replacing the ones already
#     there
#
# It also sets the category to Games > Card and picks the build: BUILD, or else the newest processed build of that
# version.  It never submits anything for review.  Run it again after changing any of those files:
#
#   scripts/appstore-metadata.py
#
# Uses the App Store Connect API key in scripts/testflight.local.env (see asc.py).

import hashlib, json, os, sys, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc import call

ROOT      = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AppStore")
BUNDLE_ID = "net.dseelig.SuzeSolitaire"
LOCALE    = "en-US"
# The display types App Store Connect files each screenshot under: its 6.9" iPhone and 13" iPad sizes, and iPhone Duo
SCREENSHOTS = {"iPhone-6.9.png": "APP_IPHONE_67", "iPad-13.png": "APP_IPAD_PRO_3GEN_129", "iPhone-Duo.png": "APP_IPHONE_DUO"}
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}


def text(name):
    path = os.path.join(ROOT, "Metadata", name)
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return f.read().strip()


def patch(kind, id, attributes=None, relationships=None):
    data = {"type": kind, "id": id}
    if attributes:
        data["attributes"] = attributes
    if relationships:
        data["relationships"] = relationships
    call("PATCH", f"/v1/{kind}/{id}", {"data": data})


def localization(path, kind, parent_kind, parent_id):
    existing = call("GET", path)["data"]
    found = next((l for l in existing if l["attributes"]["locale"] == LOCALE), None)
    if found:
        return found["id"]
    return call("POST", f"/v1/{kind}", {"data": {"type": kind, "attributes": {"locale": LOCALE}, "relationships": {
        parent_kind.rstrip("s"): {"data": {"type": parent_kind, "id": parent_id}}}}})["data"]["id"]


def upload_screenshot(set_id, path):
    with open(path, "rb") as f:
        data = f.read()
    shot = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
    for operation in shot["attributes"]["uploadOperations"]:
        part = data[operation["offset"]:operation["offset"] + operation["length"]]
        request = urllib.request.Request(operation["url"], data=part, method=operation["method"],
                                         headers={h["name"]: h["value"] for h in operation["requestHeaders"]})
        urllib.request.urlopen(request).read()
    patch("appScreenshots", shot["id"], {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()})
    # App Store Connect checks the image after it arrives
    for _ in range(60):
        state = call("GET", f"/v1/appScreenshots/{shot['id']}")["data"]["attributes"]["assetDeliveryState"]
        if state["state"] == "COMPLETE":
            return
        if state["state"] == "FAILED":
            sys.exit(f"{path} was refused: {json.dumps(state.get('errors'))}")
        time.sleep(2)
    print(f"  {os.path.basename(path)} is still processing; check it in App Store Connect")


def main():
    app = call("GET", "/v1/apps", query={"filter[bundleId]": BUNDLE_ID})["data"][0]
    versions = call("GET", f"/v1/apps/{app['id']}/appStoreVersions", query={"filter[platform]": "IOS"})["data"]
    version = next((v for v in versions if v["attributes"]["appStoreState"] in EDITABLE), None)
    if version is None:
        sys.exit("No version is waiting for submission; add one in App Store Connect first")
    version_string = version["attributes"]["versionString"]
    print(f"Version {version_string}")

    patch("appStoreVersions", version["id"], {"copyright": text("copyright.txt")})
    attributes = {"description": text("description.txt"), "keywords": text("keywords.txt"),
                  "promotionalText": text("promotional_text.txt"), "supportUrl": text("support_url.txt")}
    if text("whats_new.txt"):
        attributes["whatsNew"] = text("whats_new.txt")
    version_localization = localization(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations",
                                        "appStoreVersionLocalizations", "appStoreVersions", version["id"])
    patch("appStoreVersionLocalizations", version_localization, attributes)
    print("  description, keywords, promotional text, support URL and copyright")

    infos = call("GET", f"/v1/apps/{app['id']}/appInfos")["data"]
    info = next(i for i in infos if i["attributes"]["state"] != "READY_FOR_DISTRIBUTION")
    info_localization = localization(f"/v1/appInfos/{info['id']}/appInfoLocalizations",
                                     "appInfoLocalizations", "appInfos", info["id"])
    patch("appInfoLocalizations", info_localization,
          {"subtitle": text("subtitle.txt"), "privacyPolicyUrl": text("privacy_policy_url.txt")})
    patch("appInfos", info["id"], relationships={
        "primaryCategory": {"data": {"type": "appCategories", "id": "GAMES"}},
        "primarySubcategoryOne": {"data": {"type": "appCategories", "id": "GAMES_CARD"}}})
    print("  subtitle, privacy policy URL and category")

    with open(os.path.join(ROOT, "Metadata", "age_rating.json")) as f:
        patch("ageRatingDeclarations", info["id"], json.load(f))
    print("  age rating")

    review = call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")["data"]
    patch("appStoreReviewDetails", review["id"], {"notes": text("review_notes.txt")})
    print("  App Review notes")

    builds = call("GET", "/v1/builds", query={"filter[app]": app["id"], "filter[preReleaseVersion.version]": version_string,
                                               "filter[processingState]": "VALID", "sort": "-uploadedDate", "limit": 200})["data"]
    wanted = os.environ.get("BUILD")
    build = next((b for b in builds if b["attributes"]["version"] == wanted), None) if wanted else (builds[0] if builds else None)
    if build:
        call("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build", {"data": {"type": "builds", "id": build["id"]}})
        print(f"  build {build['attributes']['version']}")
    else:
        # A build belongs to the version in its MARKETING_VERSION, which has to match the App Store version
        print(f"  no processed build {wanted or ''} of version {version_string} to attach (check MARKETING_VERSION)")

    sets = call("GET", f"/v1/appStoreVersionLocalizations/{version_localization}/appScreenshotSets")["data"]
    for name, display_type in SCREENSHOTS.items():
        found = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None)
        if found:
            set_id = found["id"]
            for old in call("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")["data"]:
                call("DELETE", f"/v1/appScreenshots/{old['id']}")
        else:
            set_id = call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": version_localization}}}}})["data"]["id"]
        upload_screenshot(set_id, os.path.join(ROOT, "Screenshots", name))
        print(f"  {name} screenshot")

    print("Done.  Review it in App Store Connect, then submit it there.")


if __name__ == "__main__":
    main()
