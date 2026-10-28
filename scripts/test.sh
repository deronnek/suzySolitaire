#!/bin/zsh
# Runs the tests in the simulator, quickly and without hanging:
#
#   scripts/test.sh [simulator name or UDID] [extra xcodebuild arguments, such as -only-testing:...]
#
# Defaults to an iPhone 18 Pro.  Each test gets a minute before it fails rather than hanging the run, and xcodebuild
# skips collecting diagnostics from the simulator after a run, which can take it ten minutes to time out of.
set -euo pipefail

cd "$(dirname "$0")/.."
SIM_NAME=${1:-"iPhone 18 Pro"}
[[ $# -gt 0 ]] && shift
SIM=$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' || echo "$SIM_NAME")
LOG=build/test.log

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" >/dev/null
mkdir -p build
start=$SECONDS
result=0
xcodebuild -project "Suze Solitaire.xcodeproj" -scheme "Suze Solitaire" -destination "id=$SIM" -derivedDataPath build/test \
    -collect-test-diagnostics never -test-timeouts-enabled YES -default-test-execution-time-allowance 60 \
    -parallel-testing-enabled NO "$@" test > "$LOG" 2>&1 || result=$?
grep -E "error:|: error -|Executed [0-9]+ tests?|\*\* (TEST|BUILD) [A-Z]+ \*\*" "$LOG" | sort -u | tail -15
echo "$(( SECONDS - start ))s; full log in $LOG"
exit $result
