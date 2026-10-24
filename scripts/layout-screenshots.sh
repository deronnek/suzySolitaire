#!/bin/zsh
# Screenshots every layout, for checking how the table fits each device and orientation:
#
#   iPhone        portrait, landscape
#   iPad          portrait, landscape
#   iPhone Duo    folded (outer screen) portrait and landscape; unfolded (inner screen) portrait and landscape
#
#   scripts/layout-screenshots.sh [output folder]      (default build/layouts)
#
# Each is a fresh install showing the same deal (-ScreenshotSeed), in landscape when asked (-ScreenshotOrientation).
# iPhone Duo's inner screen only shows while it's unfolded, which only Device Hub's controls can do: unfold it there
# and run this again to get those two.  An iPad turns only from the Simulator app's Device menu (⌘← and ⌘→); the
# script says when a screenshot came out the wrong way round, and skips it.  Uses the newest Xcode with the iPhone Duo simulator unless DEVELOPER_DIR is set.
# Override the simulators by name or UDID with IPHONE_SIM, IPAD_SIM and DUO_SIM.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=${1:-build/layouts}
export DEVELOPER_DIR=${DEVELOPER_DIR:-$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1)/Contents/Developer}
IPHONE_SIM=${IPHONE_SIM:-"iPhone 18 Pro"}
IPAD_SIM=${IPAD_SIM:-"iPad Pro 13-inch (M5)"}
DUO_SIM=${DUO_SIM:-"iPhone Duo"}
SEED=${SEED:-12}
BUNDLE_ID=net.dseelig.SuzeSolitaire
DERIVED=$(mktemp -d)
trap 'rm -rf "$DERIVED"' EXIT

udid() {
    xcrun simctl list devices available | grep -F "$1 (" | head -1 | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' ||
        { echo "No simulator named $1" >&2; exit 1; }
}

echo "Building with $DEVELOPER_DIR..."
xcodebuild -project "Suze Solitaire.xcodeproj" -scheme "Suze Solitaire" -configuration Release \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" build -quiet
APP="$DERIVED/Build/Products/Release-iphonesimulator/Suze Solitaire.app"
mkdir -p "$OUT"

# shoot <simulator> <portrait|landscape> <file> [display]
shoot() {
    local sim=$(udid "$1") file="$OUT/$3.png"
    xcrun simctl boot "$sim" 2>/dev/null || true
    xcrun simctl bootstatus "$sim" >/dev/null
    xcrun simctl uninstall "$sim" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$sim" "$APP"
    xcrun simctl launch "$sim" "$BUNDLE_ID" -ScreenshotSeed "$SEED" -ScreenshotOrientation "$2" >/dev/null
    sleep 10
    xcrun simctl io "$sim" screenshot ${4:+--display=$4} "$file" >/dev/null 2>&1
    xcrun simctl terminate "$sim" "$BUNDLE_ID" 2>/dev/null || true
    # A screen that's off comes back black
    if [[ $(magick "$file" -background black -alpha remove -colorspace gray -format '%[fx:mean>0.02]' info:) == 0 ]]; then
        rm "$file"
        echo "$3: that screen is off"
        return 1
    fi
    # The app can only ask to rotate; an iPad that runs apps in windows keeps its own orientation
    local tall=$(magick "$file" -format '%[fx:h>w]' info:)
    if [[ $2 == landscape && $tall == 1 || $2 == portrait && $tall == 0 ]]; then
        rm "$file"
        echo "$3: the simulator didn't turn $2 (turn it in the Simulator app with ⌘← or ⌘→, then run this again)"
        return 1
    fi
    echo "$3: $file"
}

shoot "$IPHONE_SIM" portrait  iphone-portrait  || true
shoot "$IPHONE_SIM" landscape iphone-landscape || true
shoot "$IPAD_SIM"   portrait  ipad-portrait    || true
shoot "$IPAD_SIM"   landscape ipad-landscape   || true
shoot "$DUO_SIM"    portrait  duo-folded-portrait  primary   || true
shoot "$DUO_SIM"    landscape duo-folded-landscape primary   || true
shoot "$DUO_SIM"    portrait  duo-open-portrait    primary-1 || echo "  (unfold the Duo in Device Hub, then run this again)"
shoot "$DUO_SIM"    landscape duo-open-landscape   primary-1 || true
