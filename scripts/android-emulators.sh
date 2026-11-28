#!/bin/zsh
# Sets up what the Android app needs on a Mac, and the emulators the tests and screenshots use:
#
#   JDK 21 and the Android command-line tools (Homebrew), the SDK packages, and four emulators:
#   suze_phone (Pixel 10, Android 16), suze_tablet (Pixel Tablet), suze_fold (Pixel 10 Pro Fold), and
#   suze_phone_14 (Pixel 9, Android 14, the oldest version the app runs on)
#
#   scripts/android-emulators.sh
#
# Safe to run again; it skips what's already there.
set -euo pipefail

brew list openjdk@21 >/dev/null 2>&1 || brew install openjdk@21
brew list --cask android-commandlinetools >/dev/null 2>&1 || brew install --cask android-commandlinetools
export JAVA_HOME=$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=${ANDROID_HOME:-$HOME/Library/Android/sdk}
SDKMANAGER=$(brew --prefix)/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager

yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses >/dev/null
"$SDKMANAGER" --sdk_root="$ANDROID_HOME" "cmdline-tools;latest" "platform-tools" "emulator" "platforms;android-37.0" \
    "build-tools;36.1.0" "system-images;android-36;google_apis_playstore;arm64-v8a" \
    "system-images;android-34;google_apis_playstore;arm64-v8a" >/dev/null

AVDMANAGER=$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager
existing=$("$ANDROID_HOME/emulator/emulator" -list-avds)
for spec in suze_phone:android-36:pixel_10 suze_tablet:android-36:pixel_tablet suze_fold:android-36:pixel_10_pro_fold suze_phone_14:android-34:pixel_9; do
    name=${spec%%:*}; rest=${spec#*:}; api=${rest%%:*}; device=${rest#*:}
    if ! grep -qx "$name" <<< "$existing"; then
        echo no | "$AVDMANAGER" create avd -n "$name" -k "system-images;$api;google_apis_playstore;arm64-v8a" -d "$device" >/dev/null
        echo "Created $name"
    fi
done
echo "sdk.dir=$ANDROID_HOME" > "$(dirname "$0")/../android/local.properties"
echo "Ready.  Build with: cd android && JAVA_HOME=$JAVA_HOME ./gradlew assembleDebug"
