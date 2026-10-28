#!/usr/bin/env python3
#
# Sets up the Unlimited Undo in-app product in the Play Console: a one-time product with the product ID the app asks
# for (UpgradeStore.PRODUCT_ID), its name and description, and a purchase option priced in every region, then makes it
# active so the app can sell it.  Run it again to bring an existing one up to date.
#
#   scripts/play-iap.py
#
# PRICE is the US price (default 5.00), as on the App Store; Google Play converts it to every other region's currency.  Play takes in-app
# products only once a build that uses Play Billing has been uploaded (scripts/play-upload.sh).
#
# Uses the service account key in scripts/play.local.env (see play.py).

import os, sys
from decimal import Decimal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play

PRODUCT_ID  = "unlimited_undo"
OPTION_ID   = "buy"
NAME        = "Unlimited Undo"
DESCRIPTION = "Undo as many moves as you like, even auto moves."
PRICE       = Decimal(os.environ.get("PRICE", "5.00"))


def money(currency, amount):
    units = int(amount)
    return {"currencyCode": currency, "units": str(units), "nanos": int((amount - units) * 1_000_000_000)}


def main():
    converted = play.call("POST", "/pricing:convertRegionPrices", {"price": money("USD", PRICE)})
    # Play rounds its conversions to its own price points (5.00 becomes 4.99), so the US gets PRICE exactly
    regions = [{"regionCode": code, "price": money("USD", PRICE) if code == "US" else region["price"],
                "availability": "AVAILABLE"}
               for code, region in sorted(converted["convertedRegionPrices"].items())]
    product = {
        "packageName": play.PACKAGE,
        "productId": PRODUCT_ID,
        "listings": [{"languageCode": "en-US", "title": NAME, "description": DESCRIPTION}],
        "purchaseOptions": [{
            "purchaseOptionId": OPTION_ID,
            "buyOption": {"legacyCompatible": True, "multiQuantityEnabled": False},
            "regionalPricingAndAvailabilityConfigs": regions,
            "newRegionsConfig": {**converted["convertedOtherRegionsPrice"], "availability": "AVAILABLE"},
        }],
    }
    play.call("PATCH", f"/onetimeproducts/{PRODUCT_ID}", product, query={
        "allowMissing": "true", "updateMask": "listings,purchaseOptions",
        "regionsVersion.version": converted["regionVersion"]["version"]})
    play.call("POST", f"/oneTimeProducts/{PRODUCT_ID}/purchaseOptions:batchUpdateStates", {"requests": [
        {"activatePurchaseOptionRequest": {"packageName": play.PACKAGE, "productId": PRODUCT_ID,
                                           "purchaseOptionId": OPTION_ID}}]})
    us = next(r["price"] for r in regions if r["regionCode"] == "US")
    print(f"{NAME} ({PRODUCT_ID}) is active at ${us['units']}.{us.get('nanos', 0) // 10_000_000:02d} in the US "
          f"and {len(regions)} regions in all")


main()
