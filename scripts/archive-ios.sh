#!/bin/sh
# Release archive for TestFlight (signing via Xcode automatic).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ARCHIVE="$ROOT/build/CapriTransport.xcarchive"
xcodebuild -scheme "Capri Transport" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  archive
echo "Archive: $ARCHIVE"
echo "Next: Xcode Organizer → Distribute, or xcodebuild -exportArchive with ExportOptions.plist"
