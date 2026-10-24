#!/bin/zsh
# Screenshots the Android app in every layout, for checking and for Google Play:
#
#   phone          portrait, landscape     (emulator suze_phone)
#   tablet         portrait, landscape     (emulator suze_tablet)
#   foldable       unfolded                (emulator suze_fold)
#
#   scripts/android-screenshots.sh [output folder]      (default build/android-screenshots)
#
# Each is a fresh install of the debug build showing the App Store screenshots' game in progress
# (AppStore/Screenshots/game-in-progress.json, put where the app keeps its saved game), with a clean status bar.  The
# phone is shot at 1080 x 2160, since Google Play takes screenshots no more than twice as tall as they are wide.
# The emulators are made by scripts/android-emulators.sh.  Uses JAVA_HOME and ANDROID_HOME if they're set.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=${1:-build/android-screenshots}
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

# Boots an emulator on its own port and prints its serial
boot() {
    local port=$2
    "$EMULATOR" -avd "$1" -port $port -no-window -no-snapshot -no-boot-anim -no-audio >/dev/null 2>&1 &
    local serial=emulator-$port
    "$ADB" -s $serial wait-for-device
    until [[ $("$ADB" -s $serial shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') == 1 ]]; do sleep 2; done
    # A clean status bar: 9:41, full battery and signal, no notifications
    "$ADB" -s $serial shell settings put global sysui_demo_allowed 1
    "$ADB" -s $serial shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
    for command in "clock -e hhmm 0941" "battery -e level 100 -e plugged false" "network -e wifi show -e level 4 -e fully true" \
                   "network -e mobile hide" "notifications -e visible false"; do
        "$ADB" -s $serial shell am broadcast -a com.android.systemui.demo -e command ${=command} >/dev/null
    done
    # Turned by the script, not the sensor
    "$ADB" -s $serial shell settings put system accelerometer_rotation 0
    echo $serial
}

# shoot <serial> <portrait|landscape> <file> [rotation]: the rotation turns the device itself (0 to 3, a quarter turn
# each), since Android 16 ignores the app's orientation on large screens
shoot() {
    [[ -n ${4:-} ]] && "$ADB" -s $1 shell settings put system user_rotation $4
    "$ADB" -s $1 install -r "$APK" >/dev/null
    "$ADB" -s $1 shell am force-stop $PACKAGE
    "$ADB" -s $1 shell pm clear $PACKAGE >/dev/null
    "$ADB" -s $1 shell run-as $PACKAGE mkdir -p files
    "$ADB" -s $1 shell run-as $PACKAGE sh -c "'cat > files/SavedGame.json'" < $GAME
    "$ADB" -s $1 shell am start -W -n $PACKAGE/.MainActivity --es screenshotOrientation $2 >/dev/null
    sleep 4
    # A foldable has a display for each screen; the first is the one showing
    local display=$("$ADB" -s $1 shell dumpsys SurfaceFlinger --display-id | head -1 | grep -o 'Display [0-9]*' | grep -o '[0-9]*')
    "$ADB" -s $1 exec-out screencap -p ${display:+-d $display} > "$OUT/$3.png"
    echo "$3: $OUT/$3.png ($(magick identify -format '%wx%h' "$OUT/$3.png"))"
}

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
