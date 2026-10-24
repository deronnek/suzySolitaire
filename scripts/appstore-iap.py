#!/usr/bin/env python3
#
# Sets up the Unlimited Undo in-app purchase in App Store Connect: a non-consumable with the product ID the app asks
# for (UndoStore.productID), its name and description, its price in every territory, and the screenshot App Review
# needs.  Run it again to bring an existing one up to date; it never submits anything for review.
#
#   scripts/appstore-iap.py
#
# PRICE is the US price (default 5.00); App Store Connect sets the other territories' prices from it.  The screenshot
# is AppStore/Screenshots/iPhone-6.9.png.  The first in-app purchase goes to App Review with the next app version, so
# add it to that version's In-App Purchases section in App Store Connect before submitting.
#
# Uses the App Store Connect API key in scripts/testflight.local.env (see asc.py).

import hashlib, os, sys, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc import call

ROOT        = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AppStore")
BUNDLE_ID   = "net.dseelig.SuzeSolitaire"
PRODUCT_ID  = "unlimited_undo"
NAME        = "Unlimited Undo"
DESCRIPTION = "Undo as many moves as you like, even auto moves."
PRICE       = os.environ.get("PRICE", "5.00")
SCREENSHOT  = os.path.join(ROOT, "Screenshots", "iPhone-6.9.png")


def main():
    app = call("GET", "/v1/apps", query={"filter[bundleId]": BUNDLE_ID})["data"][0]
    existing = call("GET", f"/v1/apps/{app['id']}/inAppPurchasesV2", query={"filter[productId]": PRODUCT_ID})["data"]
    if existing:
        iap = existing[0]["id"]
        call("PATCH", f"/v2/inAppPurchases/{iap}", {"data": {"type": "inAppPurchases", "id": iap,
            "attributes": {"name": NAME, "familySharable": True}}})
        print(f"{NAME} ({PRODUCT_ID}) already exists")
    else:
        iap = call("POST", "/v2/inAppPurchases", {"data": {"type": "inAppPurchases",
            "attributes": {"name": NAME, "productId": PRODUCT_ID, "inAppPurchaseType": "NON_CONSUMABLE", "familySharable": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})["data"]["id"]
        print(f"Created {NAME} ({PRODUCT_ID})")

    localizations = call("GET", f"/v2/inAppPurchases/{iap}/inAppPurchaseLocalizations")["data"]
    english = next((l for l in localizations if l["attributes"]["locale"] == "en-US"), None)
    if english:
        call("PATCH", f"/v1/inAppPurchaseLocalizations/{english['id']}", {"data": {"type": "inAppPurchaseLocalizations",
            "id": english["id"], "attributes": {"name": NAME, "description": DESCRIPTION}}})
    else:
        call("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
            "attributes": {"locale": "en-US", "name": NAME, "description": DESCRIPTION},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}}}})
    print("  name and description")

    points = call("GET", f"/v2/inAppPurchases/{iap}/pricePoints", query={"filter[territory]": "USA", "limit": 8000})["data"]
    point = next((p for p in points if float(p["attributes"]["customerPrice"]) == float(PRICE)), None)
    if not point:
        sys.exit(f"No US price point of ${PRICE}")
    call("POST", "/v1/inAppPurchasePriceSchedules", {"data": {"type": "inAppPurchasePriceSchedules",
        "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${price}", "attributes": {"startDate": None},
            "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point["id"]}}}}]})
    print(f"  ${PRICE} in the US, and the matching price everywhere else")

    territories = []
    query = {"limit": 200}
    path = "/v1/territories"
    while path:
        page = call("GET", path, query=query)
        territories += [t["id"] for t in page["data"]]
        next_url = page["links"].get("next")
        path, query = (next_url.replace("https://api.appstoreconnect.apple.com", ""), None) if next_url else (None, None)
    call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {"type": "inAppPurchaseAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
            "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]}}}})
    print(f"  available in all {len(territories)} territories")

    # App Review's screenshot, replaced each time
    try:
        old = call("GET", f"/v2/inAppPurchases/{iap}/appStoreReviewScreenshot")["data"]
    except Exception:
        old = None
    if old:
        call("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{old['id']}")
    with open(SCREENSHOT, "rb") as f:
        data = f.read()
    shot = call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {"fileName": os.path.basename(SCREENSHOT), "fileSize": len(data)},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}}}})["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        request = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                         headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(request).read()
    call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{shot['id']}", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("  App Review screenshot")

    state = call("GET", f"/v2/inAppPurchases/{iap}")["data"]["attributes"]["state"]
    print(f"Done.  It's {state.replace('_', ' ').lower()} in App Store Connect.")


if __name__ == "__main__":
    main()
