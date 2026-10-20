#!/bin/bash
#
# Archives Suze Solitaire and uploads it to App Store Connect for TestFlight.
#
#   scripts/testflight.sh              archive and upload
#   scripts/testflight.sh --no-upload  archive and export a signed .ipa to build/export instead
#
# The team and bundle ID come from Signing.xcconfig, overridden by Signing.local.xcconfig if present.
# Authentication uses the account Xcode is signed in to (Xcode > Settings > Accounts).  To use an App Store
# Connect API key instead, set ASC_KEY_PATH (the .p8 file), ASC_KEY_ID and ASC_ISSUER_ID.
# The build number defaults to the current date and time; set BUILD_NUMBER to override it.

set -euo pipefail
cd "$(dirname "$0")/.."

destination=upload
if [[ "${1:-}" == "--no-upload" ]]; then
    destination=export
fi

build_number="${BUILD_NUMBER:-$(date +%Y%m%d.%H%M)}"
archive="build/Suze Solitaire.xcarchive"
export_dir="build/export"

auth=(-allowProvisioningUpdates)
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
    auth+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

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
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
EOF

echo "Archiving build $build_number..."
xcodebuild -project "Suze Solitaire.xcodeproj" -scheme "Suze Solitaire" -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$archive" \
    CURRENT_PROJECT_VERSION="$build_number" "${auth[@]}" archive

echo "Exporting ($destination)..."
rm -rf "$export_dir"
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export_dir" \
    -exportOptionsPlist build/ExportOptions.plist "${auth[@]}"

if [[ "$destination" == upload ]]; then
    echo "Uploaded build $build_number.  It will appear in App Store Connect > TestFlight once processing finishes."
else
    echo "Exported to $export_dir"
fi
