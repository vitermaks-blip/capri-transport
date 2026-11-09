#!/bin/sh
# Local gate before Archive / TestFlight (run on Mac with Xcode 27).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "→ Timetable parser smoke…"
python3 backend/timetable-sync/sync.py --dry-run

echo "→ Xcode build…"
xcodebuild -scheme "Capri Transport" \
  -destination 'generic/platform=iOS Simulator' \
  -quiet build

SIM="$(xcrun simctl list devices available | awk -F'[()]' '/iPhone 1[567]/ {gsub(/^ +| +$/, "", $1); print $1; exit}')"
echo "→ Tests on ${SIM:-iPhone simulator}…"
xcodebuild -scheme "Capri Transport" \
  -destination "platform=iOS Simulator,name=${SIM:-iPhone 17}" \
  -quiet test

echo "OK — ready for Product → Archive in Xcode."
