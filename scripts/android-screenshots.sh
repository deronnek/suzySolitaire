#!/bin/zsh
# Screenshots the Android app in every layout, for checking and for Google Play:
#
#   phone          portrait, landscape     (emulator suze_phone)
#   tablet         portrait, landscape     (emulator suze_tablet)
#   foldable       unfolded                (emulator suze_fold)
#
#   scripts/android-screenshots.sh [output folder]      (default build/android-screenshots)
#
# Or, with --play, the Google Play store screenshots, each exactly 16:9 or 9:16 as Play requires:
#
#   phone-1 to phone-4     1080 x 1920 / 1920 x 1080: a game in progress in portrait and landscape, a game
#                          nearly won (AppStore/Screenshots/game-almost-won.json), and that game won, in dark mode
#   tablet-7in             1080 x 1920 at a 7-inch tablet's density, portrait
#   tablet-10in            2560 x 1440, landscape
#
#   scripts/android-screenshots.sh --play [output folder]      (default android/store/screenshots)
#
# Each is a fresh install of the debug build showing the App Store screenshots' game in progress
# (AppStore/Screenshots/game-in-progress.json, put where the app keeps its saved game), with a clean status bar.  The
# phone is shot at 1080 x 2160, since Google Play takes screenshots no more than twice as tall as they are wide.
# The emulators are made by scripts/android-emulators.sh.  Uses JAVA_HOME and ANDROID_HOME if they're set.
set -euo pipefail

cd "$(dirname "$0")/.."
PLAY=false
if [[ ${1:-} == --play ]]; then
    PLAY=true
    shift
fi
OUT=${1:-$($PLAY && echo android/store/screenshots || echo build/android-screenshots)}
export JAVA_HOME=${JAVA_HOME:-$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home}
export ANDROID_HOME=${ANDROID_HOME:-$HOME/Library/Android/sdk}
ADB=$ANDROID_HOME/platform-tools/adb
EMULATOR=$ANDROID_HOME/emulator/emulator
PACKAGE=net.dseelig.suzesolitaire
GAME=AppStore/Screenshots/game-in-progress.json
mkdir -p "$OUT"

echo "Building..."
(cd android && ./gradlew -q assembleDebug)
APK=android/app/build/outputs/apk/debug/app-debug.apk

# A clean status bar: 9:41, full battery and signal, no notifications.  Changing the screen size turns it off again.
demo() {
    "$ADB" -s $1 shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
    for command in "clock -e hhmm 0941" "battery -e level 100 -e plugged false" "network -e wifi show -e level 4 -e fully true" \
                   "network -e mobile hide" "notifications -e visible false"; do
        "$ADB" -s $1 shell am broadcast -a com.android.systemui.demo -e command ${=command} >/dev/null
    done
}

# Boots an emulator on its own port and prints its serial
boot() {
    local port=$2
    "$EMULATOR" -avd "$1" -port $port -no-window -no-snapshot -no-boot-anim -no-audio >/dev/null 2>&1 &
    local serial=emulator-$port
    "$ADB" -s $serial wait-for-device
    until [[ $("$ADB" -s $serial shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') == 1 ]]; do sleep 2; done
    "$ADB" -s $serial shell settings put global sysui_demo_allowed 1
    demo $serial
    # Light mode, whatever an earlier run left it in
    "$ADB" -s $serial shell cmd uimode night no >/dev/null
    # Turned by the script, not the sensor
    "$ADB" -s $serial shell settings put system accelerometer_rotation 0
    echo $serial
}

# start <serial> <portrait|landscape> [rotation]: a fresh install showing $GAME.  The rotation turns the device itself
# (0 to 3, a quarter turn each), since Android 16 ignores the app's orientation on large screens.
start() {
    [[ -n ${3:-} ]] && "$ADB" -s $1 shell settings put system user_rotation $3
    "$ADB" -s $1 install -r "$APK" >/dev/null
    "$ADB" -s $1 shell am force-stop $PACKAGE
    "$ADB" -s $1 shell pm clear $PACKAGE >/dev/null
    "$ADB" -s $1 shell run-as $PACKAGE mkdir -p files
    "$ADB" -s $1 shell run-as $PACKAGE sh -c "'cat > files/SavedGame.json'" < $GAME
    "$ADB" -s $1 shell am start -W -n $PACKAGE/.MainActivity --es screenshotOrientation $2 >/dev/null
    demo $1
    sleep 4
}

# capture <serial> <file>
capture() {
    # A foldable has a display for each screen; the first is the one showing
    local display=$("$ADB" -s $1 shell dumpsys SurfaceFlinger --display-id | head -1 | grep -o 'Display [0-9]*' | grep -o '[0-9]*')
    "$ADB" -s $1 exec-out screencap -p ${display:+-d $display} > "$OUT/$2.png"
    echo "$2: $OUT/$2.png ($(magick identify -format '%wx%h' "$OUT/$2.png"))"
}

# shoot <serial> <portrait|landscape> <file> [rotation]
shoot() {
    start $1 $2 ${4:-}
    capture $1 $3
}

# bottomOf <serial> <description>: the middle of the bottom card of the stack TalkBack calls description, in pixels
bottomOf() {
    "$ADB" -s $1 shell uiautomator dump /sdcard/ui.xml >/dev/null
    "$ADB" -s $1 shell cat /sdcard/ui.xml | python3 -I -c '
import re, sys
for node in re.findall(r"<node [^>]*>", sys.stdin.read()):
    if f"content-desc=\"{sys.argv[1]}\"" in node:
        l, t, r, b = map(int, re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node).groups())
        print((l + r) // 2, b - (r - l) // 2)
        break
' "$2"
}

if $PLAY; then
    serial=$(boot suze_phone 5580)
    "$ADB" -s $serial shell wm size 1080x1920
    shoot $serial portrait phone-1-portrait
    shoot $serial landscape phone-2-landscape
    GAME=AppStore/Screenshots/game-almost-won.json
    shoot $serial portrait phone-3-almost-won
    # Won, by moving the last 3 of Diamonds up; Auto Moves puts up the rest
    "$ADB" -s $serial shell cmd uimode night yes >/dev/null
    start $serial portrait
    from=($(bottomOf $serial "Lower stack 4"))
    to=($(bottomOf $serial "Upper stack 4"))
    "$ADB" -s $serial shell input swipe $from[1] $from[2] $to[1] $to[2] 500
    sleep 6
    capture $serial phone-4-won-dark
    "$ADB" -s $serial shell cmd uimode night no >/dev/null
    "$ADB" -s $serial emu kill >/dev/null

    GAME=AppStore/Screenshots/game-in-progress.json
    serial=$(boot suze_tablet 5582)
    # A 7-inch tablet is about 600 x 1000 dp
    "$ADB" -s $serial shell wm size 1080x1920
    "$ADB" -s $serial shell wm density 280
    shoot $serial portrait tablet-7in 0
    "$ADB" -s $serial shell wm size 2560x1440
    "$ADB" -s $serial shell wm density reset
    shoot $serial landscape tablet-10in 0
    "$ADB" -s $serial emu kill >/dev/null
    exit 0
fi

serial=$(boot suze_phone 5580)
"$ADB" -s $serial shell wm size 1080x2160
shoot $serial portrait phone-portrait
"$ADB" -s $serial shell wm size reset
shoot $serial landscape phone-landscape
"$ADB" -s $serial emu kill >/dev/null

serial=$(boot suze_tablet 5582)
shoot $serial landscape tablet-landscape 0
shoot $serial portrait tablet-portrait 1
"$ADB" -s $serial emu kill >/dev/null

serial=$(boot suze_fold 5584)
shoot $serial portrait fold-unfolded
"$ADB" -s $serial emu kill >/dev/null
