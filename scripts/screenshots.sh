#!/bin/zsh
# Regenerates the App Store screenshots in AppStore/Screenshots: one for 6.9" iPhones and one for 13" iPads, the sizes
# App Store Connect requires (it scales them down for smaller devices).
#
# Each is a fresh install, in light mode, with a clean status bar (9:41 AM on Jan 9), showing the same deal every time
# (the app shuffles with -ScreenshotSeed).  Run it again whenever the app's look changes:
#
#   scripts/screenshots.sh
#
# Override the simulators (by name or UDID) or the deal with IPHONE_SIM, IPAD_SIM and SEED.
set -euo pipefail

cd "$(dirname "$0")/.."
IPHONE_SIM=${IPHONE_SIM:-"iPhone 18 Pro Max"}
IPAD_SIM=${IPAD_SIM:-"iPad Pro 13-inch (M5)"}
SEED=${SEED:-12}
BUNDLE_ID=net.dseelig.SuzeSolitaire
OUT=AppStore/Screenshots
DERIVED=$(mktemp -d)
trap 'rm -rf "$DERIVED"' EXIT

# A simulator's UDID, given its name or UDID
udid() {
    xcrun simctl list devices available | grep -F "$1 (" | head -1 | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' ||
        xcrun simctl list devices available | grep -oE "$1" | head -1 ||
        { echo "No simulator named $1; set IPHONE_SIM or IPAD_SIM" >&2; exit 1; }
}

echo "Building..."
xcodebuild -project "Suze Solitaire.xcodeproj" -scheme "Suze Solitaire" -configuration Release \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" build -quiet
APP="$DERIVED/Build/Products/Release-iphonesimulator/Suze Solitaire.app"

mkdir -p "$OUT"
# The status bar takes the time in UTC and shows it in this Mac's time zone
TIME=$(date -u -r "$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-01-09 09:41:00' +%s)" +%Y-%m-%dT%H:%M:%S.000Z)
shoot() {
    local sim=$(udid "$1") file="$OUT/$2.png"
    echo "$1 -> $file"
    local was_booted=$(xcrun simctl list devices | grep -F "$sim" | grep -c Booted || true)
    xcrun simctl boot "$sim" 2>/dev/null || true
    xcrun simctl bootstatus "$sim" >/dev/null
    xcrun simctl ui "$sim" appearance light
    xcrun simctl status_bar "$sim" override --time "$TIME" --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
    # A fresh install, so there's no saved game, record or settings
    xcrun simctl uninstall "$sim" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$sim" "$APP"
    xcrun simctl launch "$sim" "$BUNDLE_ID" -ScreenshotSeed "$SEED" >/dev/null
    # Let the deal finish and the launch screen fade
    sleep 4
    xcrun simctl io "$sim" screenshot "$file" >/dev/null 2>&1
    xcrun simctl status_bar "$sim" clear
    xcrun simctl uninstall "$sim" "$BUNDLE_ID"
    if [[ $was_booted == 0 ]]; then
        xcrun simctl shutdown "$sim"
    fi
    sips -g pixelWidth -g pixelHeight "$file" | tail -2 | tr -s ' ' | tr '\n' ' '
    echo
}

shoot "$IPHONE_SIM" iPhone-6.9
shoot "$IPAD_SIM" iPad-13
