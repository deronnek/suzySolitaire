#!/bin/zsh
# Builds the Android app and uploads it to Google Play's internal testing track, Android's equivalent of TestFlight.
#
#   WHATS_NEW='...' scripts/play-upload.sh          build and upload
#   scripts/play-upload.sh --no-upload              build the signed bundle only, to android/app/build/outputs/bundle
#
# Signing: release builds are signed with the upload key named in ~/.android/suze-solitaire-signing.properties
# (storeFile, storePassword, keyAlias, keyPassword), or the file SUZE_SIGNING points to.  Google Play re-signs each
# build with the app's own key, so a lost upload key can be replaced from the Play Console.
#
# Upload: needs the Play Console service account's JSON key at PLAY_KEY_PATH (in the environment, or in the
# git-ignored scripts/play.local.env).  PLAY_TRACK picks another track (alpha is closed testing, production is the
# store).  The release notes come from WHATS_NEW, or the latest commit's subject if that isn't set.
#
# The build number (versionCode) is the date and time, as two-digit year, day of the year, hour and minute, so each
# build's is higher than the last; set BUILD_NUMBER to override it.
set -euo pipefail
cd "$(dirname "$0")/.."

export JAVA_HOME=${JAVA_HOME:-$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home}
build_number=${BUILD_NUMBER:-$(date +%y%j%H%M)}

echo "Building $build_number..."
(cd android && ./gradlew -q bundleRelease -PversionCode=$build_number)
bundle=android/app/build/outputs/bundle/release/app-release.aab
# Make sure it was signed with the upload key, not left unsigned
if ! jarsigner_out=$("$JAVA_HOME/bin/jarsigner" -verify "$bundle" 2>&1) || [[ $jarsigner_out != *"jar verified"* ]]; then
    echo "The bundle isn't signed; see the signing notes at the top of this script." >&2
    exit 1
fi
echo "Built $bundle"

if [[ "${1:-}" == "--no-upload" ]]; then
    exit 0
fi
python3 -I scripts/play-upload.py "$bundle" "${PLAY_TRACK:-internal}" "${WHATS_NEW:-$(git log -1 --format=%s)}"
