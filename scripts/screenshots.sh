#!/bin/zsh
# Regenerates the App Store screenshots in AppStore/Screenshots: one for 6.9" iPhones and one for 13" iPads (in
# landscape), the sizes App Store Connect requires (it scales them down for smaller devices), and one of iPhone Duo
# folded.
#
# Each is a fresh install, in light mode, with a clean status bar (9:41 AM on Jan 9), showing the same game in
# progress: AppStore/Screenshots/game-in-progress.json, put where the app keeps its saved game before it launches.
# Run it again whenever the app's look changes:
#
#   scripts/screenshots.sh
#
# Override the simulators (by name or UDID) with IPHONE_SIM, IPAD_SIM and DUO_SIM.
set -euo pipefail

cd "$(dirname "$0")/.."
IPHONE_SIM=${IPHONE_SIM:-"iPhone 18 Pro Max"}
IPAD_SIM=${IPAD_SIM:-"iPad Pro 13-inch (M5)"}
DUO_SIM=${DUO_SIM:-"iPhone Duo"}
# iPhone Duo needs the newest Xcode
export DEVELOPER_DIR=${DEVELOPER_DIR:-$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1)/Contents/Developer}
BUNDLE_ID=net.dseelig.SuzeSolitaire
OUT=AppStore/Screenshots
DERIVED=$(mktemp -d)
trap 'rm -rf "$DERIVED"' EXIT

GAME=AppStore/Screenshots/game-in-progress.json
# A simulator's UDID, given its name or UDID
udid() {
    xcrun simctl list devices available | grep -F "$1 (" | head -1 | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' ||
        xcrun simctl list devices available | grep -oE "$1" | head -1 ||
        { echo "No simulator named $1; set IPHONE_SIM, IPAD_SIM or DUO_SIM" >&2; exit 1; }
}

echo "Building..."
xcodebuild -project "Suze Solitaire.xcodeproj" -scheme "Suze Solitaire" -configuration Release \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" build -quiet
APP="$DERIVED/Build/Products/Release-iphonesimulator/Suze Solitaire.app"
# An iPad that runs apps in windows ignores the app's request to turn, but turns a full-screen app, so the landscape
# screenshot uses a copy of the app marked full screen
FULL_SCREEN_APP="$DERIVED/FullScreen/Suze Solitaire.app"
mkdir -p "$(dirname "$FULL_SCREEN_APP")"
cp -R "$APP" "$FULL_SCREEN_APP"
plutil -replace UIRequiresFullScreen -bool YES "$FULL_SCREEN_APP/Info.plist"
codesign --force --sign - "$FULL_SCREEN_APP" 2>/dev/null

mkdir -p "$OUT"
# The status bar takes the time in UTC and shows it in this Mac's time zone
TIME=$(date -u -r "$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-01-09 09:41:00' +%s)" +%Y-%m-%dT%H:%M:%S.000Z)
# shoot <simulator> <file name> <portrait|landscape> [display]: iPhone Duo's folded, outer screen is display "primary"
shoot() {
    local sim=$(udid "$1") file="$OUT/$2.png" app="$APP" display=${4-}
    [[ $3 == landscape ]] && app="$FULL_SCREEN_APP"
    echo "$1 -> $file"
    local was_booted=$(xcrun simctl list devices | grep -F "$sim" | grep -c Booted || true)
    xcrun simctl boot "$sim" 2>/dev/null || true
    xcrun simctl bootstatus "$sim" >/dev/null
    xcrun simctl ui "$sim" appearance light
    xcrun simctl status_bar "$sim" override --time "$TIME" --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
    # A fresh install, so there's no saved game, record or settings
    xcrun simctl uninstall "$sim" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$sim" "$app"
    local documents="$(xcrun simctl get_app_container "$sim" "$BUNDLE_ID" data)/Documents"
    mkdir -p "$documents"
    cp "$GAME" "$documents/SavedGame.json"
    xcrun simctl launch "$sim" "$BUNDLE_ID" -ScreenshotOrientation "$3" >/dev/null
    # Let the deal finish and the launch screen fade (a simulator that was just booted takes longer)
    sleep 10
    xcrun simctl io "$sim" screenshot ${display:+--display=$display} "$file" >/dev/null 2>&1
    xcrun simctl status_bar "$sim" clear
    xcrun simctl uninstall "$sim" "$BUNDLE_ID"
    if [[ $was_booted == 0 ]]; then
        xcrun simctl shutdown "$sim"
    fi
    # The screenshot stays the way up the iPad is held, with the app turned on it
    if [[ $3 == landscape && $(magick "$file" -format '%[fx:h>w]' info:) == 1 ]]; then
        magick "$file" -rotate -90 "$file"
    fi
    sips -g pixelWidth -g pixelHeight "$file" | tail -2 | tr -s ' ' | tr '\n' ' '
    echo
}

shoot "$IPHONE_SIM" iPhone-6.9 portrait
shoot "$IPAD_SIM" iPad-13 landscape
shoot "$DUO_SIM" iPhone-Duo portrait primary
