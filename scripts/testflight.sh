#!/bin/bash
#
# Archives Suze Solitaire and uploads it to App Store Connect for TestFlight.
#
#   scripts/testflight.sh              archive and upload
#   scripts/testflight.sh --no-upload  archive and export a signed .ipa to build/export instead
#
# The team and bundle ID come from Signing.xcconfig, overridden by Signing.local.xcconfig if present.
#
# Authentication: with an App Store Connect API key, the archive is built unsigned and the export step signs it
# with Apple's cloud-managed distribution certificate, so no keychain access is needed.  Set ASC_KEY_ID and
# ASC_ISSUER_ID (in the environment, or in the git-ignored scripts/testflight.local.env), and put the key at
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 or point ASC_KEY_PATH at it.
# Without a key, signing and upload use your keychain and the account Xcode is signed in to.
#
# The build number defaults to the current date and time; set BUILD_NUMBER to override it.

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f scripts/testflight.local.env ]]; then
    source scripts/testflight.local.env
fi

destination=upload
if [[ "${1:-}" == "--no-upload" ]]; then
    destination=export
fi

build_number="${BUILD_NUMBER:-$(date +%Y%m%d.%H%M)}"
archive="build/Suze Solitaire.xcarchive"
export_dir="build/export"

auth=(-allowProvisioningUpdates)
archive_signing=()
if [[ -n "${ASC_KEY_ID:-}" ]]; then
    key_path="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
    auth+=(-authenticationKeyPath "$key_path" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
    # The export step signs with the cloud-managed certificate
    archive_signing=(CODE_SIGNING_ALLOWED=NO)
fi

# An unsigned archive doesn't record its team, so tell the export which one to sign for
team=$(xcodebuild -project "Suze Solitaire.xcodeproj" -target "Suze Solitaire" -configuration Release -showBuildSettings 2>/dev/null \
    | awk '$1 == "DEVELOPMENT_TEAM" { print $3 }')

mkdir -p build
cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>$destination</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$team</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
EOF

echo "Archiving build $build_number..."
xcodebuild -project "Suze Solitaire.xcodeproj" -scheme "Suze Solitaire" -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$archive" \
    CURRENT_PROJECT_VERSION="$build_number" ${archive_signing[@]+"${archive_signing[@]}"} "${auth[@]}" archive

echo "Exporting ($destination)..."
rm -rf "$export_dir"
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export_dir" \
    -exportOptionsPlist build/ExportOptions.plist "${auth[@]}"

if [[ "$destination" == upload ]]; then
    echo "Uploaded build $build_number.  It will appear in App Store Connect > TestFlight once processing finishes."
else
    echo "Exported to $export_dir"
fi
