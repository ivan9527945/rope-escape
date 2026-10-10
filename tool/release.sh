#!/usr/bin/env bash
# Builds a clean App Store archive and uploads it with the Apple ID that is
# signed in to Xcode (no API key needed).
#
#   tool/release.sh            # upload the version in pubspec.yaml
#   tool/release.sh --bump     # first bump the build number (1.0.0+5 → +6)
#
# Always cleans first: a simulator build (store_capture.sh, flutter run on a
# simulator) leaves a simulator slice in objective_c.framework that App Store
# Connect rejects.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" = "--bump" ]; then
  python3 - <<'PY'
import re
p='pubspec.yaml'; s=open(p).read()
m=re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)$', s, re.M)
s=s.replace(m.group(0), f'version: {m.group(1)}+{int(m.group(2))+1}')
open(p,'w').write(s); print('version:', m.group(1), '+', int(m.group(2))+1)
PY
fi
PLIST=$(mktemp -t upload).plist
cat > "$PLIST" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>2ZBG57M754</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
XML
flutter clean >/dev/null
flutter pub get >/dev/null
flutter build ipa --export-method app-store
xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist "$PLIST" -exportPath build/ios/upload -allowProvisioningUpdates \
  | grep -i "upload succeeded\|export succeeded\|error:"
