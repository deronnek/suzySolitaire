#!/usr/bin/env python3
#
# Sends an uploaded build to an external TestFlight group: waits for App Store Connect to finish processing it, sets
# its "What to Test" notes, adds it to the group and submits it for beta app review.  testflight.sh runs this after an
# upload when TESTFLIGHT_GROUP is set.
#
#   scripts/testflight-distribute.py <build number> <group name> [what to test]
#
# Uses the same App Store Connect API key as testflight.sh (ASC_KEY_ID, ASC_ISSUER_ID and optionally ASC_KEY_PATH).
# Needs only the standard library and openssl (see asc.py).

import os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc import call


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: testflight-distribute.py <build number> <group name> [what to test]")
    version, group_name = sys.argv[1], sys.argv[2]
    whats_new = sys.argv[3] if len(sys.argv) > 3 else ""
    bundle_id = os.environ["BUNDLE_ID"]

    app = call("GET", "/v1/apps", query={"filter[bundleId]": bundle_id})["data"][0]
    groups = call("GET", f"/v1/apps/{app['id']}/betaGroups", query={"limit": 200})["data"]
    group = next((g for g in groups if g["attributes"]["name"] == group_name), None)
    if group is None:
        sys.exit(f"No TestFlight group named {group_name!r}; there are: {', '.join(g['attributes']['name'] for g in groups)}")

    # The build shows up a few minutes after the upload, then takes a while longer to process
    print(f"Waiting for App Store Connect to process build {version}...", flush=True)
    deadline = time.time() + 60 * 60
    while True:
        builds = call("GET", "/v1/builds", query={"filter[app]": app["id"], "filter[version]": version})["data"]
        state = builds[0]["attributes"]["processingState"] if builds else "NOT_YET_VISIBLE"
        if state == "VALID":
            build = builds[0]
            break
        if state in ("FAILED", "INVALID"):
            sys.exit(f"Build {version} failed processing ({state})")
        if time.time() > deadline:
            sys.exit(f"Gave up waiting for build {version} (still {state})")
        time.sleep(30)

    if whats_new:
        localizations = call("GET", f"/v1/builds/{build['id']}/betaBuildLocalizations")["data"]
        english = next((l for l in localizations if l["attributes"]["locale"] == "en-US"), None)
        if english:
            call("PATCH", f"/v1/betaBuildLocalizations/{english['id']}", {"data": {
                "type": "betaBuildLocalizations", "id": english["id"], "attributes": {"whatsNew": whats_new}}})
        else:
            call("POST", "/v1/betaBuildLocalizations", {"data": {
                "type": "betaBuildLocalizations", "attributes": {"locale": "en-US", "whatsNew": whats_new},
                "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}}}})

    call("POST", f"/v1/betaGroups/{group['id']}/relationships/builds", {"data": [{"type": "builds", "id": build["id"]}]})
    print(f"Added build {version} to {group_name}.")

    submissions = call("GET", "/v1/betaAppReviewSubmissions", query={"filter[build]": build["id"]})["data"]
    if submissions:
        print(f"Already submitted for beta review ({submissions[0]['attributes']['betaReviewState']}).")
    else:
        call("POST", "/v1/betaAppReviewSubmissions", {"data": {
            "type": "betaAppReviewSubmissions", "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}}}})
        print("Submitted for beta review; testers get it once Apple approves it.")


if __name__ == "__main__":
    main()
