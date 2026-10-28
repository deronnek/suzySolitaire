#!/bin/zsh
# Records a video of the edge swipes in the simulator: a deal, a swipe in from the left that undoes it, then one in from
# the right that shows a hint.  The app plays the swipes itself (-DemoEdgeSwipes), with a dot for the finger.
#
#   scripts/swipe-video.sh [output.mp4] [simulator name or UDID]
#
# Defaults to build/swipe.mp4 on an iPhone 18 Pro.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=${1:-build/swipe.mp4}
SIM_NAME=${2:-"iPhone 18 Pro"}
BUNDLE_ID=net.dseelig.SuzeSolitaire
DERIVED=build/win-video
SIM=$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' || echo "$SIM_NAME")

echo "Building..."
xcodebuild -project "Suze Solitaire.xcodeproj" -scheme "Suze Solitaire" -configuration Debug \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" build -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Suze Solitaire.app"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" >/dev/null
xcrun simctl ui "$SIM" appearance light
xcrun simctl uninstall "$SIM" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"

mkdir -p "$(dirname "$OUT")"
raw=$(mktemp -d)/swipe.mov
xcrun simctl io "$SIM" recordVideo --codec h264 --force "$raw" >/dev/null 2>&1 &
recorder=$!
sleep 1
xcrun simctl launch "$SIM" "$BUNDLE_ID" -DemoEdgeSwipes YES >/dev/null
sleep 11
kill -INT $recorder
wait $recorder || true
xcrun simctl uninstall "$SIM" "$BUNDLE_ID"
ffmpeg -v error -y -i "$raw" -vf "scale='min(720,iw)':-2" -c:v libx264 -crf 24 -pix_fmt yuv420p -movflags +faststart "$OUT"
rm -rf "$(dirname "$raw")"
echo "$OUT"
