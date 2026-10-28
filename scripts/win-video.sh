#!/bin/zsh
# Records a video of winning a game in the simulator: AppStore/Screenshots/game-almost-won.json, with Auto Moves
# putting up the last cards on its own, then the celebration through to the New Game button.
#
#   scripts/win-video.sh [output.mp4] [simulator name or UDID] [portrait|landscape]
#
# Defaults to build/win.mp4 on an iPhone 18 Pro, in portrait.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=${1:-build/win.mp4}
SIM_NAME=${2:-"iPhone 18 Pro"}
ORIENTATION=${3:-portrait}
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
documents="$(xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" data)/Documents"
mkdir -p "$documents"
cp AppStore/Screenshots/game-almost-won.json "$documents/SavedGame.json"

mkdir -p "$(dirname "$OUT")"
raw=$(mktemp -d)/win.mov
# The app waits for the launch to settle before the last move, and the recording starts once it has
xcrun simctl launch "$SIM" "$BUNDLE_ID" -ScreenshotOrientation "$ORIENTATION" -FinishTurnAfter 6 >/dev/null
sleep 5.2
xcrun simctl io "$SIM" recordVideo --codec h264 --force "$raw" >/dev/null 2>&1 &
recorder=$!
sleep 9
kill -INT $recorder
wait $recorder || true
xcrun simctl uninstall "$SIM" "$BUNDLE_ID"
# Small enough to send around, at the simulator's frame rate
ffmpeg -v error -y -i "$raw" -vf "scale='min(720,iw)':-2" -c:v libx264 -crf 24 -pix_fmt yuv420p -movflags +faststart "$OUT"
rm -rf "$(dirname "$raw")"
echo "$OUT"
